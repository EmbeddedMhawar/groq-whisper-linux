#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Groq Ask - Super Fast Q&A                                              ║
# ║  Records voice -> Transcribes -> Asks AI -> Pastes Answer                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# --- CONFIG ---
API_KEY="${GROQ_API_KEY:-YOUR_API_KEY_HERE}"
MODEL="openai/gpt-oss-120b"  # Fastest Large Model (~500 T/s)
# MODEL="llama-3.3-70b-versatile" # Alternative if you prefer Meta models

FILENAME="/tmp/groq_ask.flac"
PIDFILE="/tmp/groq_ask.pid"

# --- CLIPBOARD DETECTION ---
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    COPY_CMD="wl-copy"
else
    COPY_CMD="xclip -selection clipboard"
fi
# ----------------

if [ -f "$PIDFILE" ]; then
    # --- STOP & PROCESS ---
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        notify-send -u low -t 1000 "Groq Ask" "Thinking..."
        sleep 0.2
        # Use SIGINT for safe SoX header writing
        kill -INT "$PID"
        wait "$PID" 2>/dev/null
    fi
    rm "$PIDFILE"

    # 1. TRANSCRIBE (Whisper)
    TEXT=""
    RESPONSE=$(curl -s "https://api.groq.com/openai/v1/audio/transcriptions" \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: multipart/form-data" \
      -F "file=@$FILENAME" \
      -F "model=whisper-large-v3" \
      -F "response_format=text")
    
    TEXT=$(echo "$RESPONSE" | sed '$d') # Remove trailing newline if any
    
    # Simple error check
    if [[ "$TEXT" == *'"error":'* || -z "$TEXT" ]]; then
        notify-send -u critical "Groq Ask" "Transcription failed."
        exit 1
    fi

    notify-send -u low -t 2000 "Groq Ask" "Question: $TEXT"

    # 2. ASK AI (LLM)
    # Check for jq
    if ! command -v jq &> /dev/null; then
        notify-send -u critical "Groq Error" "jq is required. Please install it."
        exit 1
    fi

    JSON_PAYLOAD=$(jq -n \
      --arg model "$MODEL" \
      --arg content "$TEXT" \
      '{
        model: $model,
        messages: [
          {
            role: "system",
            content: "You are a highly intelligent, super-fast assistant. Provide a direct, concise, and accurate answer to the user'\''s question. Do not waffle. Always include explicit quotes and cite the source of your information. Use Markdown for clarity."
          },
          {
            role: "user",
            content: $content
          }
        ]
      }')

    ANSWER_RESPONSE=$(curl -s "https://api.groq.com/openai/v1/chat/completions" \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: application/json" \
      -d "$JSON_PAYLOAD")

    ANSWER=$(echo "$ANSWER_RESPONSE" | jq -r '.choices[0].message.content')

    if [[ "$ANSWER" == "null" || -z "$ANSWER" ]]; then
         notify-send -u critical "Groq Ask" "AI failed to answer."
    else
         # 3. OUTPUT
         echo -n "$ANSWER" | $COPY_CMD
         notify-send -u low -t 4000 "Groq Ask" "Answer Copied!"
         
         # Auto-Paste
         if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
            hyprctl dispatch sendshortcut CTRL SHIFT, V, activewindow
         else
            xdotool key ctrl+shift+v
         fi
    fi

else
    # --- START RECORDING ---
    # Smart VAD: Record until 0.6s silence or 10s max
    rec -q -r 16000 -c 1 -b 16 "$FILENAME" silence 1 0.1 3% 1 0.6 3% trim 0 10 2>/dev/null &
    PID=$!
    echo $PID > "$PIDFILE"
    notify-send -u low -t 1000 "Groq Ask" "🎤 Ask me anything..."
    
    # Wait for recording to finish (background process)
    wait $PID
    
    # If it finished naturally (silence detection), trigger the processing logic immediately
    # by calling the script recursively
    if [ -f "$PIDFILE" ]; then
        $0 &
    fi
fi
