from __future__ import annotations

import asyncio
import hashlib
import logging
import os
import time
from pathlib import Path
from typing import Annotated

import soundfile as sf
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

try:
    from kokoro_onnx import Kokoro
except Exception:  # pragma: no cover - startup diagnostics handle this path.
    Kokoro = None  # type: ignore[assignment]


ROOT_DIR = Path(__file__).resolve().parents[1]
MODEL_PATH = Path(os.getenv("KOKORO_MODEL_PATH", ROOT_DIR / "models" / "kokoro-v1.0.onnx"))
VOICES_PATH = Path(os.getenv("KOKORO_VOICES_PATH", ROOT_DIR / "models" / "voices-v1.0.bin"))
CACHE_DIR = Path(os.getenv("KOKORO_CACHE_DIR", ROOT_DIR / "cache"))
DEFAULT_VOICE = os.getenv("KOKORO_DEFAULT_VOICE", "af_sarah")
LANG = os.getenv("KOKORO_LANG", "en-us")

logger = logging.getLogger("kokoro_backend")
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO").upper(),
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)

app = FastAPI(title="Local Kokoro TTS", version="0.1.0")
_kokoro: Kokoro | None = None
_model_lock = asyncio.Lock()


class TTSRequest(BaseModel):
    text: Annotated[str, Field(min_length=1, max_length=20_000)]
    voice: str = DEFAULT_VOICE
    speed: Annotated[float, Field(ge=0.5, le=2.0)] = 1.0


class HealthResponse(BaseModel):
    ok: bool
    model_loaded: bool
    model_path: str
    voices_path: str
    cache_dir: str
    cache_files: int
    cache_bytes: int
    error: str | None = None


class CacheResponse(BaseModel):
    cache_dir: str
    files: int
    bytes: int


class TTSMetadata(BaseModel):
    text_sha256: str
    voice: str
    speed: float
    file: str
    bytes: int
    cached: bool


def _missing_setup_error() -> str | None:
    if Kokoro is None:
        return "kokoro-onnx is not installed or failed to import."
    missing = [str(path) for path in (MODEL_PATH, VOICES_PATH) if not path.exists()]
    if missing:
        return "Missing model files: " + ", ".join(missing)
    return None


async def get_kokoro() -> Kokoro:
    global _kokoro
    if _kokoro is not None:
        return _kokoro

    setup_error = _missing_setup_error()
    if setup_error:
        raise HTTPException(status_code=503, detail=setup_error)

    async with _model_lock:
        if _kokoro is None:
            logger.info("Loading Kokoro model from %s", MODEL_PATH)
            _kokoro = await asyncio.to_thread(Kokoro, str(MODEL_PATH), str(VOICES_PATH))
            logger.info("Kokoro model loaded with %d voices", len(_kokoro.get_voices()))
    return _kokoro


def _cache_path(text: str, voice: str, speed: float) -> Path:
    key = hashlib.sha256(f"{voice}\0{speed:.3f}\0{LANG}\0{text}".encode("utf-8")).hexdigest()
    return CACHE_DIR / f"{key}.wav"


def _cache_stats() -> tuple[int, int]:
    if not CACHE_DIR.exists():
        return 0, 0
    files = [path for path in CACHE_DIR.glob("*.wav") if path.is_file()]
    return len(files), sum(path.stat().st_size for path in files)


def _create_wav(kokoro: Kokoro, request: TTSRequest, output_path: Path) -> None:
    logger.info(
        "Generating TTS voice=%s speed=%.2f chars=%d",
        request.voice,
        request.speed,
        len(request.text),
    )
    samples, sample_rate = kokoro.create(
        request.text,
        voice=request.voice,
        speed=request.speed,
        lang=LANG,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = output_path.with_suffix(".tmp.wav")
    sf.write(str(temp_path), samples, sample_rate)
    temp_path.replace(output_path)
    os.utime(output_path, None)


@app.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    error = _missing_setup_error()
    cache_files, cache_bytes = _cache_stats()
    return HealthResponse(
        ok=error is None,
        model_loaded=_kokoro is not None,
        model_path=str(MODEL_PATH),
        voices_path=str(VOICES_PATH),
        cache_dir=str(CACHE_DIR),
        cache_files=cache_files,
        cache_bytes=cache_bytes,
        error=error,
    )


@app.get("/voices")
async def voices() -> dict[str, list[str]]:
    kokoro = await get_kokoro()
    return {"voices": kokoro.get_voices()}


@app.post("/tts")
async def tts(request: TTSRequest) -> FileResponse:
    text = request.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text is empty.")

    kokoro = await get_kokoro()
    if request.voice not in kokoro.get_voices():
        raise HTTPException(status_code=400, detail=f"Unknown voice: {request.voice}")

    output_path = _cache_path(text, request.voice, request.speed)
    cached = output_path.exists()
    if not cached:
        try:
            await asyncio.to_thread(_create_wav, kokoro, TTSRequest(text=text, voice=request.voice, speed=request.speed), output_path)
        except Exception as exc:
            logger.exception("TTS generation failed")
            raise HTTPException(status_code=500, detail=f"TTS generation failed: {exc}") from exc
    else:
        os.utime(output_path, (time.time(), time.time()))
        logger.info("Serving cached TTS audio %s", output_path.name)

    metadata = TTSMetadata(
        text_sha256=hashlib.sha256(text.encode("utf-8")).hexdigest(),
        voice=request.voice,
        speed=request.speed,
        file=output_path.name,
        bytes=output_path.stat().st_size,
        cached=cached,
    )
    return FileResponse(
        output_path,
        media_type="audio/wav",
        filename="kokoro-tts.wav",
        headers={"X-Kokoro-TTS-Metadata": metadata.model_dump_json()},
    )


@app.get("/cache", response_model=CacheResponse)
async def cache_info() -> CacheResponse:
    files, bytes_used = _cache_stats()
    return CacheResponse(cache_dir=str(CACHE_DIR), files=files, bytes=bytes_used)


@app.delete("/cache", response_model=CacheResponse)
async def clear_cache() -> CacheResponse:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    for path in CACHE_DIR.glob("*.wav"):
        if path.is_file():
            path.unlink()
    files, bytes_used = _cache_stats()
    logger.info("Cleared generated audio cache")
    return CacheResponse(cache_dir=str(CACHE_DIR), files=files, bytes=bytes_used)
