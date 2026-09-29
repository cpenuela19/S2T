#!/bin/bash
AUDIO="/tmp/whisper_recording.wav"
MODEL="$HOME/.local/share/whisper-cpp/models/ggml-medium-q5_0.bin"
OUTFILE="/tmp/speak2text_transcript"

while true; do
    rm -f "$AUDIO"
    pw-record --rate 16000 --channels 1 --format s16 "$AUDIO" > /dev/null 2>&1 &
    PID=$!

    echo "🎙️ Recording..."
    echo "  [1] Retry recording"
    echo "  [0] Transcribe answer"
    read -n1 -s choice

    kill $PID 2>/dev/null
    wait $PID 2>/dev/null

    case $choice in
        1)
            echo "🔄 Discarded. Recording again..."
            echo ""
            ;;
        0)
            echo "📝 Transcribing..."
            TOTAL_MS=$(whisper-cli -t 8 -m "$MODEL" -f "$AUDIO" -otxt -of "$OUTFILE" -l auto 2>&1 | grep "total time" | awk '{print $(NF-1)}')
            SECONDS_TOTAL=$(echo "$TOTAL_MS / 1000" | bc)

            TRANSCRIPT="${OUTFILE}.txt"
            cat "$TRANSCRIPT"

            if command -v wl-copy >/dev/null 2>&1; then
                wl-copy < "$TRANSCRIPT"
                wl-copy --primary < "$TRANSCRIPT"
            else
                echo "⚠️ wl-copy no encontrado. Instala wl-clipboard con: sudo apt install wl-clipboard"
            fi

            {
                BACKUP_DIR="/home/tito/Music/Aux/S2TByTheBoss"
                mkdir -p "$BACKUP_DIR"
                if [ -f "$BACKUP_DIR/temporal_1.txt" ]; then
                    mv -f "$BACKUP_DIR/temporal_1.txt" "$BACKUP_DIR/temporal_2.txt"
                fi
                cp "$TRANSCRIPT" "$BACKUP_DIR/temporal_1.txt"
            } > /dev/null 2>&1

            echo "✅ Process done successfully"
            echo "⏱️ Transcription time: ${SECONDS_TOTAL}s"
            rm -f "$AUDIO"
            echo ""
            exit 0
            ;;
        c)
            rm -f "$AUDIO"
            echo ""
            exit 0
            ;;
        *)
            echo "🔄 Invalid. Recording again..."
            echo ""
            ;;
    esac
done
