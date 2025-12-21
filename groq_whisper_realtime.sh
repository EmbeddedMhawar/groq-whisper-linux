#!/bin/bash

# --- CONFIG ---
API_KEY="${GROQ_API_KEY:-YOUR_API_KEY_HERE}"
PIDFILE="/tmp/groq_realtime.pid"
SESSION_DIR="/tmp/groq_session_$$"
# --------------

if [ -f "$PIDFILE" ]; then
    # --- STOP SIGNAL ---
    PID=$(cat "$PIDFILE")
    
    # Check if process is running
    if kill -0 "$PID" 2>/dev/null; then
        notify-send -u low "Groq Realtime" "Stopping..."
        
        # 1. Remove PIDFILE to signal the main loop to stop
        rm "$PIDFILE"
        
        # 2. Kill the 'ffmpeg' process so the current recording stops immediately
        pkill -P "$PID" ffmpeg 2>/dev/null
    else
        # Stale PID file
        rm "$PIDFILE"
    fi
    exit 0
fi

# --- START NEW SESSION ---
notify-send -u low "Groq Realtime" "Started..."
echo $$ > "$PIDFILE"
mkdir -p "$SESSION_DIR"

# Cleanup function (runs when script finishes)
cleanup() {
    notify-send -u low "Groq Realtime" "Finalizing..."
    
    # Wait for any background curl jobs to finish
    wait
    
    # Concatenate all text files in order
    FULL_TEXT=$(find "$SESSION_DIR" -name "*.txt" | sort -V | xargs cat 2>/dev/null)
    
    if [ -n "$FULL_TEXT" ]; then
        echo -n "$FULL_TEXT" | wl-copy
        notify-send -u low "Groq Realtime" "Full Text Copied!"
    else
        notify-send -u low "Groq Realtime" "No text captured."
    fi
    
    rm -f "$PIDFILE"
    rm -rf "$SESSION_DIR"
    exit
}

# Trap signals for cleanup
trap cleanup EXIT INT TERM

START_TIME=$SECONDS

count=0
while [ -f "$PIDFILE" ]; do
    # Check for 5 minute timeout
    CURRENT_TIME=$SECONDS
    ELAPSED=$((CURRENT_TIME - START_TIME))
    if [ $ELAPSED -ge 300 ]; then
        notify-send -u critical "Groq Realtime" "Session timeout (5 mins)."
        rm "$PIDFILE"
        break
    fi

    count=$((count+1))
    FILENAME="$SESSION_DIR/${count}.flac"
    TXTNAME="$SESSION_DIR/${count}.txt"
    
    # Record in 4-second chunks
    ffmpeg -y -f pulse -i default -ac 1 -ar 16000 -t 4 -loglevel error "$FILENAME"
    
    # If file is empty or missing, skip
    if [ ! -s "$FILENAME" ]; then
        continue
    fi

    # Transcribe in background
    (
        RESPONSE=$(curl -s "https://api.groq.com/openai/v1/audio/transcriptions" \
          -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: multipart/form-data" \
          -F "file=@$FILENAME" \
          -F "model=whisper-large-v3" \
          -F "response_format=text" \
          --connect-timeout 5 \
          --max-time 10)
        
        # Clean text
        TEXT=$(echo "$RESPONSE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        # Validate text
        if [[ -n "$TEXT" && "$TEXT" != *'"error":'* ]]; then
             # 1. Save to session file
             echo -n "$TEXT " > "$TXTNAME"
             
             # 2. Paste immediately
             echo -n "$TEXT " | wl-copy
             hyprctl dispatch sendshortcut CTRL SHIFT, V, activewindow
             
             # 3. Wait briefly for paste to happen
             sleep 0.5
             
             # 4. Clear clipboard (as requested)
             wl-copy --clear
             wl-copy --primary --clear
        fi
        
        rm -f "$FILENAME"
    ) &
done
