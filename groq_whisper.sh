#!/bin/bash

# --- CONFIG ---
API_KEY="${GROQ_API_KEY:-YOUR_API_KEY_HERE}"
REFINEMENT_MODEL="openai/gpt-oss-120b"
FILENAME="/tmp/groq_rec.flac" 
PIDFILE="/tmp/groq_rec.pid"
# ----------------

# MODE HANDLING
MODE="${1:-fix}" # Default to fix

if [ -f "$PIDFILE" ]; then
    # --- STOP RECORDING & TRANSCRIBE ---
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        notify-send -u low -t 1000 "Groq" "Finishing..."
        kill -INT "$PID"
        wait "$PID" 2>/dev/null
        sleep 0.5
    fi
    rm "$PIDFILE"

    notify-send -u low -t 2000 "Groq" "Transcribing..."

    # Retry configuration
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
        if [[ "$MODE" == "fix" ]]; then
            notify-send -u low -t 2000 "Groq" "Refining..."
            
            JSON_PAYLOAD=$(jq -n \
              --arg model "$REFINEMENT_MODEL" \
              --arg content "$TEXT" \
              '{
                model: $model,
                messages: [
                  {
                    role: "system",
                    content: "You are an expert technical editor. Fix grammar, correct technical terminology, and format the provided text into clean Markdown. Important: If the text is a question, do NOT answer it; just correct the grammar/formatting of the question itself. Do not add filler. Output only the corrected text."
                  },
                  {
                    role: "user",
                    content: $content
                  }
                ]
              }')

            REFINED_RESPONSE=$(curl -s "https://api.groq.com/openai/v1/chat/completions" \
              -H "Authorization: Bearer $API_KEY" \
              -H "Content-Type: application/json" \
              -d "$JSON_PAYLOAD")
            
            REFINED_TEXT=$(echo "$REFINED_RESPONSE" | jq -r '.choices[0].message.content')
            
            if [[ "$REFINED_TEXT" == "null" || -z "$REFINED_TEXT" ]]; then
                 FINAL_TEXT="$TEXT"
            else
                 FINAL_TEXT="$REFINED_TEXT"
            fi
        else
            FINAL_TEXT="$TEXT"
        fi

        echo -n "$FINAL_TEXT" | wl-copy
        notify-send -u low -t 2000 "Groq" "Pasted!"
        hyprctl dispatch sendshortcut CTRL SHIFT, V, activewindow
    fi
else
    ffmpeg -y -f pulse -i default -ac 1 -ar 16000 -t 300 -loglevel error "$FILENAME" &
    echo $! > "$PIDFILE"
    notify-send -u low -t 1000 "Groq" "Listening ($MODE mode)... (Press to finish)"
fi
