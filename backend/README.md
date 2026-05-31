# Kokoro Local TTS Backend

FastAPI service for local Kokoro ONNX text-to-speech. It exposes:

- `GET /health`
- `GET /voices`
- `POST /tts`
- `GET /cache`
- `DELETE /cache`

Generated audio is returned as WAV and cached under `backend/cache`.

## Requirements

- macOS
- Python 3.10 to 3.13. Python 3.12 is recommended.
- `uv` or `venv`
- Kokoro model files downloaded once during setup

If audio generation fails because phonemization dependencies cannot find eSpeak, install it:

```sh
brew install espeak-ng
```

## Quick Setup

From `backend`:

```sh
scripts/setup.sh
```

That installs dependencies and downloads the model files.

Run the backend:

```sh
scripts/run.sh
```

## Setup With uv

From `backend`:

```sh
uv sync
scripts/download_models.sh
```

The download script fetches the Kokoro ONNX model files from the `kokoro-onnx` model-file release. Manual equivalent:

```sh
curl -L -o models/kokoro-v1.0.onnx https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
curl -L -o models/voices-v1.0.bin https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin
```

Run the backend:

```sh
scripts/run.sh
```

## Setup With venv

From `backend`:

```sh
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
scripts/download_models.sh
```

Then run:

```sh
scripts/run.sh
```

## API Examples

Check health:

```sh
curl http://127.0.0.1:8880/health
```

List voices:

```sh
curl http://127.0.0.1:8880/voices
```

Generate speech:

```sh
curl -X POST http://127.0.0.1:8880/tts \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello from local Kokoro.","voice":"af_sarah","speed":1.0}' \
  --output speech.wav
```

Inspect or clear generated audio cache:

```sh
curl http://127.0.0.1:8880/cache
curl -X DELETE http://127.0.0.1:8880/cache
```

## Offline Use

After dependencies and the two model files are installed, the backend does not need internet access. Keep `backend/models/kokoro-v1.0.onnx` and `backend/models/voices-v1.0.bin` in place.

## Configuration

Environment variables:

- `KOKORO_MODEL_PATH`: path to `kokoro-v1.0.onnx`
- `KOKORO_VOICES_PATH`: path to `voices-v1.0.bin`
- `KOKORO_CACHE_DIR`: path for generated WAV cache
- `KOKORO_DEFAULT_VOICE`: default voice, `af_sarah`
- `KOKORO_LANG`: language, `en-us`
- `LOG_LEVEL`: logging level, `INFO`

## Upstream

- `kokoro-onnx`: https://github.com/thewh1teagle/kokoro-onnx
- PyPI package: https://pypi.org/project/kokoro-onnx/
