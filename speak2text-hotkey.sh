#!/bin/bash
PIDFILE="/tmp/speak2text-hotkey.pid"
AUDIO="/tmp/speak2text-hotkey_recording.wav"
MODEL="$HOME/.local/share/whisper-cpp/models/ggml-base.bin"
OUTFILE="/tmp/speak2text-hotkey_transcript"
BACKUP_DIR="/home/tito/Music/Aux/S2TByTheBoss"
LOGFILE="/tmp/speak2text-hotkey.log"

notify() {
    local title="$1"
    local body="$2"
    if command -v notify-send >/dev/null 2>&1; then
        local id
        id=$(notify-send -p -t 2500 -h boolean:transient:true \
            -h string:x-canonical-private-synchronous:speak2text \
            "$title" "$body" 2>/dev/null)
        # GNOME Shell ignores -t sometimes and leaves the banner frozen;
        # close it explicitly after a short delay.
        if [ -n "$id" ] && command -v gdbus >/dev/null 2>&1; then
            setsid bash -c "sleep 3; gdbus call --session \
                --dest org.freedesktop.Notifications \
                --object-path /org/freedesktop/Notifications \
                --method org.freedesktop.Notifications.CloseNotification $id" \
                >/dev/null 2>&1 < /dev/null &
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$title] $body" >> "$LOGFILE"
    fi
}

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
    PID=$(cat "$PIDFILE")
    kill "$PID" 2>/dev/null
    wait "$PID" 2>/dev/null
    rm -f "$PIDFILE"

    whisper-cli -m "$MODEL" -f "$AUDIO" -otxt -of "$OUTFILE" -l auto > /dev/null 2>&1

    TRANSCRIPT="${OUTFILE}.txt"

    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy < "$TRANSCRIPT"
        wl-copy --primary < "$TRANSCRIPT"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [speak2text-hotkey] wl-copy not found, install wl-clipboard" >> "$LOGFILE"
    fi

    {
        mkdir -p "$BACKUP_DIR"
        if [ -f "$BACKUP_DIR/temporal_1.txt" ]; then
            mv -f "$BACKUP_DIR/temporal_1.txt" "$BACKUP_DIR/temporal_2.txt"
        fi
        cp "$TRANSCRIPT" "$BACKUP_DIR/temporal_1.txt"
    } > /dev/null 2>&1

    rm -f "$AUDIO"

    notify "Speak2Text" "Transcript ready and copied to clipboard."
else
    rm -f "$PIDFILE" "$AUDIO"

    pw-record --rate 16000 --channels 1 --format s16 "$AUDIO" > /dev/null 2>&1 &
    echo $! > "$PIDFILE"
    disown

    notify "Speak2Text" "Recording... press the shortcut again to stop."
fi
