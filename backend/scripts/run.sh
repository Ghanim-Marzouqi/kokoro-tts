#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

host="${KOKORO_HOST:-127.0.0.1}"
port="${KOKORO_PORT:-8880}"

if [[ -x .venv/bin/python ]]; then
  exec .venv/bin/python -m uvicorn app.main:app --host "$host" --port "$port"
fi

if command -v uv >/dev/null 2>&1; then
  exec uv run uvicorn app.main:app --host "$host" --port "$port"
fi

exec python3 -m uvicorn app.main:app --host "$host" --port "$port"
