# S2T

Offline, local speech-to-text for Ubuntu (Wayland). Record your voice, transcribe it with [whisper.cpp](https://github.com/ggerganov/whisper.cpp), and get the result on your clipboard — no cloud services, no API keys, no audio leaving your machine.

The project ships two entry points:

| Script | Mode | Use case |
| --- | --- | --- |
| `speak2text-hotkey.sh` | Non-interactive toggle | Bound to a global keyboard shortcut. First press starts recording, second press stops, transcribes and copies. |
| `speak2text.sh` | Interactive terminal | Run from a shell. Supports re-recording before transcribing and reports transcription time. |

## How it works

### Hotkey mode (`speak2text-hotkey.sh`)

The script is a stateless toggle whose state is kept in a PID file (`/tmp/speak2text-hotkey.pid`).

1. **First invocation** — no live process is referenced by the PID file, so the script starts `pw-record` (PipeWire) in the background, capturing 16 kHz, mono, signed 16-bit PCM (the format Whisper expects), stores its PID, and shows a desktop notification.
2. **Second invocation** — the PID file points to a live process, so the script terminates the recorder, runs `whisper-cli` with automatic language detection (`-l auto`), and writes the transcript to a text file.
3. The transcript is copied to both the Wayland **clipboard** and **primary selection** (`wl-copy`), so it can be pasted with `Ctrl+V` or a middle click.
4. The last two transcripts are rotated into a backup directory as `temporal_1.txt` (latest) and `temporal_2.txt` (previous).
5. The temporary audio file is deleted and a final notification is shown.

Notifications are transient, replace one another, and are explicitly closed after ~3 seconds via D-Bus. This works around a GNOME Shell behavior where a banner can remain frozen on screen until the next notification arrives.

### Interactive mode (`speak2text.sh`)

Records until you press a key: `1` discards and restarts the recording, `0` stops and transcribes. The transcript is printed, copied to the clipboard, backed up as above, and the whisper.cpp processing time is displayed.

## Requirements

- **OS:** Ubuntu with a **Wayland** session and **PipeWire** (the default on recent Ubuntu releases). Other distributions or X11 sessions are not supported or tested.
- **Packages:**
  ```bash
  sudo apt install pipewire-bin wl-clipboard libnotify-bin bc
  ```
  - `pipewire-bin` — provides `pw-record`
  - `wl-clipboard` — provides `wl-copy`
  - `libnotify-bin` — provides `notify-send` (hotkey mode; falls back to a log file if absent)
  - `bc` — used by interactive mode for timing
  - `gdbus` (from `libglib2.0-bin`) is normally preinstalled and is used to close notifications.
- **whisper.cpp:** the `whisper-cli` binary must be on your `PATH` (for example `~/.local/bin`). See the [whisper.cpp build instructions](https://github.com/ggerganov/whisper.cpp#quick-start).
- **Model:** a ggml model file. The scripts default to:
  ```
  ~/.local/share/whisper-cpp/models/ggml-base.bin
  ```
  Download it with the script bundled in whisper.cpp (`models/download-ggml-model.sh base`) or from the [Hugging Face repository](https://huggingface.co/ggerganov/whisper.cpp).

## Installation

```bash
git clone https://github.com/cpenuela19/S2T.git
cd S2T
chmod +x speak2text.sh speak2text-hotkey.sh
```

### Bind a global shortcut (GNOME)

1. Open **Settings → Keyboard → Keyboard Shortcuts → Custom Shortcuts**.
2. Add a shortcut with the command:
   ```
   /absolute/path/to/S2T/speak2text-hotkey.sh
   ```
3. Assign your preferred key combination.

Press once to record, press again to transcribe. Paste anywhere.

## Configuration

Settings are shell variables at the top of each script:

| Variable | Default | Description |
| --- | --- | --- |
| `MODEL` | `~/.local/share/whisper-cpp/models/ggml-base.bin` | Path to the whisper.cpp model. Larger models are more accurate but slower. |
| `BACKUP_DIR` | `/home/tito/Music/Aux/S2TByTheBoss` | Where the last two transcripts are stored. **Change this to a path valid for your user.** |
| `-l auto` | auto-detect | Replace with a language code (e.g. `-l en`, `-l es`) to force a language and speed up inference. |

Temporary files live in `/tmp` and are removed after each run. Hotkey-mode diagnostics are appended to `/tmp/speak2text-hotkey.log`.

## Limitations

- Wayland only for clipboard integration (`wl-copy`); X11 would require `xclip`/`xsel`.
- Transcription is synchronous and CPU-bound; latency scales with recording length and model size.
- A single recording session is supported at a time (single PID file).
- Tested on Ubuntu only.

## Privacy

All processing is local. Audio is written to `/tmp` during recording and deleted after transcription. Transcripts persist only in the clipboard and the backup directory.
