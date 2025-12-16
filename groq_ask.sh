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
            content: "You are a super-concise, high-speed assistant. Answer immediately and extremely briefly. No filler words or preambles. ALWAYS include explicit quotes and cite the source of your information WITH LINKS/URLS, but keep the explanation minimal. Use Markdown."
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
    # Manual mode: Record until pressed again or 5 mins max
    rec -q -r 16000 -c 1 -b 16 "$FILENAME" trim 0 300 &
    echo $! > "$PIDFILE"
    notify-send -u low -t 1000 "Groq Ask" "🎤 Ask me anything... (Press to finish)"
fi
