#!/bin/bash

# --- CONFIG ---
API_KEY="${GROQ_API_KEY:-YOUR_API_KEY_HERE}"
# Changed to .flac for compression (approx 3x longer recording time than .wav)
FILENAME="/tmp/groq_rec.flac" 
PIDFILE="/tmp/groq_rec.pid"
# ----------------

if [ -f "$PIDFILE" ]; then
    # --- STOP RECORDING & TRANSCRIBE ---
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        notify-send -u low -t 1000 "Groq" "Finishing..."
        sleep 1.5
        # FIX 1: Send SIGINT (Ctrl+C) so SoX writes the file header properly
        kill -INT "$PID"
        # Wait for the process to actually finish writing
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
        # Capture HTTP Code to distinguish real errors from the word "error"
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

        # Extract Status Code (last line) and Body (everything else)
        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        TEXT=$(echo "$RESPONSE" | sed '$d')

        # Success - break out of retry loop
        if [[ "$HTTP_CODE" == "200" ]]; then
            break
        fi

        # Retryable errors: 400, 429 (rate limit), 500, 502, 503, 504
        if [[ "$HTTP_CODE" =~ ^(400|429|500|502|503|504)$ ]] && [[ $attempt -lt $MAX_RETRIES ]]; then
            notify-send -u low -t 1500 "Groq" "Retrying... (attempt $((attempt+1))/$MAX_RETRIES)"
            sleep $RETRY_DELAY
            RETRY_DELAY=$((RETRY_DELAY * 2))  # Exponential backoff
        else
            break
        fi
    done

    # Check HTTP Status 200 (OK) instead of grep text
    if [[ "$HTTP_CODE" != "200" ]]; then
        echo "Error (HTTP $HTTP_CODE) after $attempt attempts: $TEXT" > /tmp/groq_error.log
        notify-send -u critical "Groq Error" "Failed (Code $HTTP_CODE). Check /tmp/groq_error.log"
    else
        # --- REFINE TEXT (Grammar & Markdown) ---
        notify-send -u low -t 2000 "Groq" "Refining..."
        
        # Escape JSON string safely using jq
        JSON_PAYLOAD=$(jq -n \
          --arg model "openai/gpt-oss-20b" \
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
        
        # Extract refined content using jq
        REFINED_TEXT=$(echo "$REFINED_RESPONSE" | jq -r '.choices[0].message.content')
        
        # Fallback to original text if refinement fails or returns null
        if [[ "$REFINED_TEXT" == "null" || -z "$REFINED_TEXT" ]]; then
             FINAL_TEXT="$TEXT"
        else
             FINAL_TEXT="$REFINED_TEXT"
        fi

        # Success
        echo -n "$FINAL_TEXT" | wl-copy
        notify-send -u low -t 2000 "Groq" "Pasted!"
        
        # Hyprland Auto-Paste
        # Always use Ctrl+Shift+V
        hyprctl dispatch sendshortcut CTRL SHIFT, V, activewindow
    fi

else
    # --- START RECORDING ---
    # Uses FLAC (lossless compression) to stay under 25MB limit for longer
    # Timeout after 5 minutes (300 seconds)
    rec -q -r 16000 -c 1 -b 16 "$FILENAME" trim 0 300 &
    echo $! > "$PIDFILE"
    notify-send -u low -t 1000 "Groq" "Listening... (Press again to finish)"
fi
