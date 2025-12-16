#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Groq Whisper - Voice-to-Text for Linux (Wispr Flow Alternative)         ║
# ║  Works on any distro with Wayland or X11                                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# --- CONFIG ---
# Get your free API key from: https://console.groq.com/keys
API_KEY="${GROQ_API_KEY:-YOUR_API_KEY_HERE}"

# Temp files location
FILENAME="/tmp/groq_rec.flac"
PIDFILE="/tmp/groq_rec.pid"

# --- CLIPBOARD TOOL DETECTION ---
# Automatically detect Wayland vs X11 and set clipboard command
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    COPY_CMD="wl-copy"
else
    COPY_CMD="xclip -selection clipboard"
fi
# ----------------

if [ -f "$PIDFILE" ]; then
    # --- STOP RECORDING & TRANSCRIBE ---
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        notify-send -u low -t 1000 "Groq" "Finishing..."
        sleep 1.5
        # Send SIGINT (Ctrl+C) so SoX writes the file header properly
        kill -INT "$PID"
        # Wait for the process to actually finish writing
        wait "$PID" 2>/dev/null
        sleep 0.5
    fi
    rm "$PIDFILE"

    notify-send -u low -t 2000 "Groq" "Transcribing..."

    # Retry configuration (handles cold-start HTTP 400 errors)
    MAX_RETRIES=3
    RETRY_DELAY=1
    HTTP_CODE=""
    TEXT=""

    for ((attempt=1; attempt<=MAX_RETRIES; attempt++)); do
        RESPONSE=$(curl -s -w "\n%{http_code}" "https://api.groq.com/openai/v1/audio/transcriptions" \
          -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: multipart/form-data" \
          -F "file=@$FILENAME" \
          -F "model=whisper-large-v3" \
          -F "response_format=text" \
          --connect-timeout 15 \
          --max-time 300 \
          --retry 2 \
          --retry-delay 1 \
          --retry-connrefused)

        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        TEXT=$(echo "$RESPONSE" | sed '$d')

        if [[ "$HTTP_CODE" == "200" ]]; then
            break
        fi

        # Retry on transient errors
        if [[ "$HTTP_CODE" =~ ^(400|429|500|502|503|504)$ ]] && [[ $attempt -lt $MAX_RETRIES ]]; then
            notify-send -u low -t 1500 "Groq" "Retrying... (attempt $((attempt+1))/$MAX_RETRIES)"
            sleep $RETRY_DELAY
            RETRY_DELAY=$((RETRY_DELAY * 2))
        else
            break
        fi
    done

    if [[ "$HTTP_CODE" != "200" ]]; then
        echo "Error (HTTP $HTTP_CODE) after $attempt attempts: $TEXT" > /tmp/groq_error.log
        notify-send -u critical "Groq Error" "Failed (Code $HTTP_CODE). Check /tmp/groq_error.log"
    else
        # Success - copy to clipboard
        echo -n "$TEXT" | $COPY_CMD
        notify-send -u low -t 2000 "Groq" "Copied to clipboard!"
        
        # --- AUTO-PASTE (Optional - Uncomment for your environment) ---
        # Hyprland (Wayland):
        # hyprctl dispatch sendshortcut CTRL, V, activewindow
        # Alternative (Super+V):
        # hyprctl dispatch sendshortcut SUPER, V, activewindow
        
        # Sway (Wayland):
        # swaymsg exec 'wtype -M ctrl v -m ctrl'
        
        # GNOME/KDE (X11):
        # xdotool key ctrl+v
        
        # i3 (X11):
        # xdotool key ctrl+v
    fi

else
    # --- START RECORDING ---
    # Uses FLAC (lossless compression) to stay under Groq's 25MB limit
    rec -q -r 16000 -c 1 -b 16 "$FILENAME" &
    echo $! > "$PIDFILE"
    notify-send -u low -t 1000 "Groq" "🎤 Listening... (Press again to finish)"
fi
