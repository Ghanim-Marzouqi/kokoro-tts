# Local Kokoro TTS Menu Bar App

Personal-use macOS text-to-speech app backed by a local Kokoro ONNX FastAPI service. No cloud TTS services are used.

## Project Structure

```text
backend/
  app/main.py              FastAPI Kokoro service
  models/                  Place Kokoro ONNX model files here
  cache/                   Generated WAV cache
  pyproject.toml           uv project config
  requirements.txt         venv/pip fallback

macos/
  Package.swift            Swift Package executable app
  Sources/KokoroBar/       SwiftUI menu bar app
```

## 1. Backend Setup

From `backend`:

```sh
scripts/setup.sh
```

That installs dependencies and downloads the model files.

Manual `uv` setup:

```sh
uv sync
scripts/download_models.sh
```

Manual venv setup:

```sh
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
scripts/download_models.sh
```

Run:

```sh
scripts/run.sh
```

## 2. macOS App

Build a personal app bundle:

```sh
cd macos
scripts/build_app.sh
```

The app is created at `macos/dist/KokoroBar.app`. Move it to `/Applications` if you want it installed like a normal personal utility. Run `backend/scripts/setup.sh` before building if you want the app bundle to include your prepared `.venv` and downloaded model files.

Check:

```sh
curl http://127.0.0.1:8880/health
curl http://127.0.0.1:8880/voices
```

Generate a test WAV:

```sh
curl -X POST http://127.0.0.1:8880/tts \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello from Kokoro.","voice":"af_sarah","speed":1.0}' \
  --output speech.wav
```

After dependencies and model files are installed, the backend does not need internet access.

Run from source instead:

```sh
cd macos
swift run KokoroBar
```

Or open it in Xcode:

```sh
open Package.swift
```

The app lives in the menu bar and includes:

- Read Clipboard
- Save Clipboard Audio...
- Read Selected Text
- Stop Speaking
- Start/Stop Backend
- Check Backend
- Settings
- Quit

Global shortcut:

- `Cmd+Shift+R`: read selected text when available, otherwise read clipboard

Settings:

- Backend URL, default `http://127.0.0.1:8880`
- Backend folder
- Voice selection
- Speed slider
- Auto-start backend toggle
- Backend logs
- Cache refresh/clear

## Accessibility Permission

Selected-text reading uses macOS Accessibility APIs. Enable permission in:

System Settings > Privacy & Security > Accessibility

Add or enable the running terminal, Xcode, or packaged app. If permission is missing, clipboard reading still works.

## Known Limitations

- Selected text depends on each app exposing `AXSelectedText`.
- The generated `.app` is unsigned. macOS may require right-click > Open the first time.
- Auto-start expects `uv` or a prepared backend `.venv`.
- Long-text queueing and pause/resume are not implemented yet.

## References

The backend uses [`kokoro-onnx`](https://github.com/thewh1teagle/kokoro-onnx). Its current setup documents installing `kokoro-onnx`, downloading `kokoro-v1.0.onnx` and `voices-v1.0.bin`, and using `Kokoro(...).create(...)` to generate WAV audio. The package release used here is [`kokoro-onnx==0.5.0`](https://pypi.org/project/kokoro-onnx/).
