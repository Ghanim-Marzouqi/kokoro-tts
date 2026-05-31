#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p models

model_url="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
voices_url="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"

if [[ ! -f models/kokoro-v1.0.onnx ]]; then
  curl -L -o models/kokoro-v1.0.onnx "$model_url"
else
  echo "models/kokoro-v1.0.onnx already exists"
fi

if [[ ! -f models/voices-v1.0.bin ]]; then
  curl -L -o models/voices-v1.0.bin "$voices_url"
else
  echo "models/voices-v1.0.bin already exists"
fi

echo "Kokoro model files are ready in backend/models"
