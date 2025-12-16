#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Groq Ask - Super Fast Q&A                                              ║
# ║  Records voice -> Transcribes -> Asks AI -> Pastes Answer                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# --- CONFIG ---
API_KEY="${GROQ_API_KEY:-YOUR_API_KEY_HERE}"
PPLX_API_KEY="${PERPLEXITY_API_KEY:-}" # Optional: Set this env var for Perplexity fact-checking
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

# MODE HANDLING
MODE="${1:-default}"

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
    RESPONSE=$(curl -s -w "\n%{http_code}" "https://api.groq.com/openai/v1/audio/transcriptions" \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: multipart/form-data" \
      -F "file=@$FILENAME" \
      -F "model=whisper-large-v3" \
      -F "response_format=text")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    TEXT=$(echo "$RESPONSE" | sed '$d')
    
    # Simple error check
    if [[ "$HTTP_CODE" != "200" || -z "$TEXT" ]]; then
        notify-send -u critical "Groq Ask" "Transcription failed (HTTP $HTTP_CODE)"
        exit 1
    fi

    notify-send -u low -t 2000 "Groq Ask" "Question: $TEXT"

    # 2. ASK AI (LLM)
    # Check for jq
    if ! command -v jq &> /dev/null; then
        notify-send -u critical "Groq Error" "jq is required. Please install it."
        exit 1
    fi

    # Determine System Prompt based on Mode
    if [[ "$MODE" == "brainstorm" ]]; then
        SYSTEM_PROMPT="You are a creative brainstorming assistant. Provide multiple diverse options and ideas. Be concise and brief. Use bullet points."
    else
        # Default / Fact Check Mode
        SYSTEM_PROMPT="You are a super-concise, high-speed assistant. Answer immediately and extremely briefly. No filler words or preambles. ALWAYS include explicit quotes and cite the source of your information, but keep the explanation minimal. Use Markdown."
    fi

    JSON_PAYLOAD=$(jq -n \
      --arg model "$MODEL" \
      --arg content "$TEXT" \
      --arg system "$SYSTEM_PROMPT" \
      '{
        model: $model,
        messages: [
          {
            role: "system",
            content: $system
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

    # --- OPTIONAL: PERPLEXITY FACT CHECK (Only for default mode) ---
    if [[ "$MODE" != "brainstorm" && -n "$PPLX_API_KEY" && "$ANSWER" != "null" && -n "$ANSWER" ]]; then
        notify-send -u low -t 2000 "Groq Ask" "Fact checking..."
        
        PPLX_PAYLOAD=$(jq -n \
          --arg model "sonar" \
          --arg system "You are a diligent fact-checker. Verify the answer. If accurate, confirm it; if inaccurate, correct it. You MUST include explicit quotes. Place the direct URL citation IMMEDIATELY below each quote (not at the bottom). Output ONLY the final verified answer." \
          --arg content "Question: $TEXT\nOriginal Answer: $ANSWER" \
          '{
            model: $model,
            messages: [
              {role: "system", content: $system},
              {role: "user", content: $content}
            ]
          }')

        PPLX_RESPONSE=$(curl -s "https://api.perplexity.ai/chat/completions" \
          -H "Authorization: Bearer $PPLX_API_KEY" \
          -H "Content-Type: application/json" \
          -d "$PPLX_PAYLOAD")

        PPLX_ANSWER=$(echo "$PPLX_RESPONSE" | jq -r '.choices[0].message.content')
        
        if [[ "$PPLX_ANSWER" != "null" && -n "$PPLX_ANSWER" ]]; then
            ANSWER="$PPLX_ANSWER"
        fi
    fi
    # ---------------------------------------

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
    # We need to preserve the mode argument for the callback
    # We can write the mode to a temp file or rely on the caller to pass it again?
    # Since we call $0 & in the stop block? No, wait.
    # The stop block is triggered by running the script again. 
    # If I bind SUPER+A to "groq_ask.sh" and SUPER+B to "groq_ask.sh brainstorm"
    # When I press SUPER+A to stop, it runs with "default" mode.
    # When I press SUPER+B to stop, it runs with "brainstorm" mode.
    # We need the STOP action to know the mode, OR (better):
    # The recording phase is mode-agnostic. The STOP phase determines the processing.
    # So if I start with SUPER+A (default) and stop with SUPER+B (brainstorm), it will brainstorm.
    # This is actually a cool feature. Start recording, then decide how to process.
    
    rec -q -r 16000 -c 1 -b 16 "$FILENAME" trim 0 300 &
    echo $! > "$PIDFILE"
    if [[ "$MODE" == "brainstorm" ]]; then
        notify-send -u low -t 1000 "Groq Brainstorm" "🎤 Brainstorming... (Press to finish)"
    else
        notify-send -u low -t 1000 "Groq Ask" "🎤 Ask me anything... (Press to finish)"
    fi
fi
