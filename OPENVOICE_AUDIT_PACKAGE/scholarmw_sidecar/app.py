"""OpenVoice v2 cloning sidecar for Penrose ScholarAI.

This is a tiny FastAPI service that keeps the ~700MB MeloTTS + OpenVoice tone
converter resident in memory and exposes exactly the four endpoints the Penrose
backend's `OpenVoiceProvider` expects (see `backend/app/speech/cloning.py`):

    GET    /health          -> {"service": "openvoice-sidecar", ...}
    POST   /clone           -> {"voice_id": "...", "model_version": "..."}
    POST   /synthesize      -> audio/wav (+ x-openvoice-source-embedding header)
    GET    /voice/{id}      -> 200 / 404
    DELETE /voice/{id}      -> 200 / 204 / 404

Design notes
------------
* The engine is loaded lazily on first use so `/health` answers in milliseconds
  even while the models are still warming up. `/health` reports `engine_loaded`
  so the caller can tell "up but still loading" from "ready".
* Only ``en-us`` and ``en-india`` ship reference embeddings with the OpenVoiceV2
  checkpoints we use, so those are what we advertise. A request for any other
  accent is spoken with ``en-us`` and the substitution is reported in the
  ``x-openvoice-source-embedding`` response header, exactly as the backend
  expects. We never silently claim an accent we did not produce.
* Voices are persisted as a per-voice embedding file under ``OPENVOICE_DATA_DIR``
  plus a small JSON sidecar with its metadata, so a sidecar restart does not lose
  every trained voice.

Run it (inside WSL2 Ubuntu, see ``setup.sh``):

    python -m uvicorn app:app --host 127.0.0.1 --port 8011
"""

from __future__ import annotations

import json
import logging
import os
import re
import tempfile
import threading
import uuid
from pathlib import Path

import torch
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse, Response

log = logging.getLogger("openvoice-sidecar")
logging.basicConfig(level=logging.INFO)

# --- Configuration ---------------------------------------------------------

CHECKPOINTS_DIR = Path(os.environ.get("OPENVOICE_CHECKPOINTS", "checkpoints_v2"))
DATA_DIR = Path(os.environ.get("OPENVOICE_DATA_DIR", "voice_store"))
DATA_DIR.mkdir(parents=True, exist_ok=True)

DEVICE = os.environ.get(
    "OPENVOICE_DEVICE", "cuda:0" if torch.cuda.is_available() else "cpu"
)

# Accents that actually ship a reference embedding with the checkpoints. The
# backend advertises exactly these (cloning.py:_OPENVOICE_SPEAKERS is wider, but
# provider_status() prefers what /health reports).
BASE_SPEAKERS = ("EN-US", "EN_INDIA")
FALLBACK_SPEAKER = "EN-US"

# MeloTTS language ids for the base speakers we support here.
_MELO_LANG = "EN"
_MELO_SPEAKER_BY_BASE = {
    "EN-US": "en-us",
    "EN_INDIA": "en-india",
    "EN-AU": "en-au",
    "EN-BR": "en-br",
    "EN-Default": "en-default",
}

# A minimal pronounceability gate mirroring the backend's expectation that the
# sidecar answers 422 for text with nothing to say.
_WORD_RE = re.compile(r"[A-Za-z0-9]{2,}")


def _torch_load(path: str | Path) -> object:
    """Load a .pth, tolerant of torch>=2.6's `weights_only=True` default.

    The OpenVoice embeddings are plain tensors; the checkpoint may contain more.
    We try the safe load first and fall back to the legacy behaviour so the same
    code works across torch versions.
    """
    try:
        return torch.load(path, map_location=DEVICE, weights_only=True)
    except Exception:  # noqa: BLE001 - older checkpoints need the unsafe path
        return torch.load(path, map_location=DEVICE)

app = FastAPI(title="OpenVoice Sidecar", version="1.0.0")


# --- Engine (lazy, single instance, thread-guarded) -------------------------

class _Engine:
    """Holds the OpenVoice models. Loaded once, reused for every request."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._loaded = False
        self._voice_converter = None
        self._melotts: dict[str, object] = {}
        self._base_ses: dict[str, torch.Tensor] = {}

    @property
    def loaded(self) -> bool:
        return self._loaded

    def load(self) -> None:
        if self._loaded:
            return
        with self._lock:
            if self._loaded:
                return
            from openvoice.api import ToneColorConverter

            converter_dir = CHECKPOINTS_DIR / "converter"
            log.info("Loading OpenVoice tone converter from %s", converter_dir)
            converter = ToneColorConverter(
                str(converter_dir / "config.json"), device=DEVICE
            )
            converter.load_ckpt(str(converter_dir / "checkpoint.pth"))
            self._voice_converter = converter

            for base in BASE_SPEAKERS:
                key = _MELO_SPEAKER_BY_BASE.get(base, "en-us")
                se_path = CHECKPOINTS_DIR / "base_speakers" / "ses" / f"{key}.pth"
                if se_path.is_file():
                    self._base_ses[base] = _torch_load(se_path)
                    log.info("Loaded base speaker embedding %s", base)
                else:
                    log.warning("Missing base speaker embedding for %s (%s)", base, se_path)

            self._loaded = True
            log.info("OpenVoice engine ready on %s", DEVICE)

    def _melo(self, base_speaker: str):
        from melo.api import TTS

        key = _MELO_SPEAKER_BY_BASE.get(base_speaker, "en-us")
        if key not in self._melotts:
            log.info("Loading MeloTTS base speaker %s", key)
            self._melotts[key] = (TTS(language=_MELO_LANG, device=DEVICE), key)
        return self._melotts[key]

    def clone_from_sample(self, sample_path: Path) -> torch.Tensor:
        self.load()
        from openvoice import se_extractor

        target_se, _audio_name = se_extractor.get_se(
            str(sample_path), self._voice_converter, vad=True
        )
        return target_se

    def synthesize(
        self,
        *,
        text: str,
        target_se: torch.Tensor | None,
        base_speaker: str,
        speed: float,
    ) -> tuple[bytes, str]:
        """Return (wav_bytes, speaker_actually_used)."""
        self.load()
        model, melo_key = self._melo(base_speaker)
        speaker_ids = model.hps.data.spk2id
        speaker_id = speaker_ids.get(melo_key) or next(iter(speaker_ids.values()))

        with tempfile.TemporaryDirectory() as tmp:
            src_path = Path(tmp) / "base.wav"
            out_path = Path(tmp) / "out.wav"
            model.tts_to_file(text, speaker_id, str(src_path), speed=speed)

            if target_se is None:
                # Base-speaker-only synthesis (no clone): return the MeloTTS wav.
                return src_path.read_bytes(), f"melo:{melo_key}"

            source_se = self._base_ses.get(base_speaker) or self._base_ses.get(
                FALLBACK_SPEAKER
            )
            used = (
                base_speaker
                if base_speaker in self._base_ses
                else f"{FALLBACK_SPEAKER} (fallback)"
            )
            self._voice_converter.convert(
                audio_src_path=str(src_path),
                src_se=source_se,
                tgt_se=target_se,
                output_path=str(out_path),
                message="@Penrose",
            )
            return out_path.read_bytes(), used


engine = _Engine()


# --- Voice store ------------------------------------------------------------

def _voice_dir(voice_id: str) -> Path:
    return DATA_DIR / voice_id


def _voice_exists(voice_id: str) -> bool:
    return (_voice_dir(voice_id) / "embedding.pt").is_file()


def _load_embedding(voice_id: str) -> torch.Tensor:
    return _torch_load(_voice_dir(voice_id) / "embedding.pt")


# --- Endpoints --------------------------------------------------------------

@app.get("/health")
async def health() -> dict:
    """Identity + readiness. Must identify itself as `openvoice-sidecar`."""
    return {
        "service": "openvoice-sidecar",
        "engine_loaded": engine.loaded,
        "device": DEVICE,
        "base_speakers_available": list(BASE_SPEAKERS),
    }


@app.post("/clone")
async def clone(
    sample: UploadFile = File(...),
    name: str = Form(""),
    description: str = Form(""),
) -> JSONResponse:
    ext = Path(sample.filename or "sample.wav").suffix.lower() or ".wav"
    if ext not in (".wav", ".flac"):
        raise HTTPException(
            status_code=422,
            detail="OpenVoice trains from WAV or FLAC only. Convert the sample first.",
        )
    data = await sample.read()
    if not data:
        raise HTTPException(status_code=422, detail="The uploaded sample was empty.")

    voice_id = uuid.uuid4().hex
    target_dir = _voice_dir(voice_id)
    target_dir.mkdir(parents=True, exist_ok=True)
    sample_path = target_dir / f"sample{ext}"
    sample_path.write_bytes(data)

    try:
        target_se = engine.clone_from_sample(sample_path)
    except HTTPException:
        raise
    except Exception as exc:  # noqa: BLE001 - reported as a provider error
        log.exception("Clone failed")
        raise HTTPException(
            status_code=500, detail=f"OpenVoice could not extract a voice: {exc}"
        ) from exc

    torch.save(target_se, target_dir / "embedding.pt")
    (target_dir / "meta.json").write_text(
        json.dumps({"name": name, "description": description}, ensure_ascii=False)
    )

    return JSONResponse(
        {
            "voice_id": voice_id,
            "model_version": f"openvoice-v2/{DEVICE}",
            "labels": {"name": name},
        }
    )


@app.post("/synthesize")
async def synthesize(request: Request) -> Response:
    try:
        body = await request.json()
    except Exception:  # noqa: BLE001
        raise HTTPException(status_code=422, detail="Expected a JSON body.") from None

    text = str(body.get("text") or "").strip()
    if not _WORD_RE.search(text):
        raise HTTPException(
            status_code=422, detail="There are no words to speak in that text."
        )

    voice_id = str(body.get("voice_id") or "").strip()
    base_speaker = str(body.get("base_speaker") or FALLBACK_SPEAKER).strip()
    try:
        speed = float(body.get("speed") or 1.0)
    except (TypeError, ValueError):
        speed = 1.0

    target_se = None
    if voice_id:
        if not _voice_exists(voice_id):
            raise HTTPException(
                status_code=404,
                detail="Voice embedding not found on disk.",
            )
        try:
            target_se = _load_embedding(voice_id)
        except Exception as exc:  # noqa: BLE001
            log.exception("Could not load embedding")
            raise HTTPException(
                status_code=500, detail=f"Could not load the voice embedding: {exc}"
            ) from exc

    try:
        audio, used_speaker = engine.synthesize(
            text=text,
            target_se=target_se,
            base_speaker=base_speaker,
            speed=speed,
        )
    except HTTPException:
        raise
    except Exception as exc:  # noqa: BLE001
        log.exception("Synthesis failed")
        raise HTTPException(
            status_code=500, detail=f"OpenVoice synthesis failed: {exc}"
        ) from exc

    return Response(
        content=audio,
        media_type="audio/wav",
        headers={"x-openvoice-source-embedding": used_speaker},
    )


@app.get("/voice/{voice_id}")
async def voice_status(voice_id: str) -> dict:
    if not _voice_exists(voice_id):
        raise HTTPException(status_code=404, detail="Voice not found.")
    return {"voice_id": voice_id, "available": True}


@app.delete("/voice/{voice_id}")
async def delete_voice(voice_id: str) -> dict:
    target = _voice_dir(voice_id)
    if not target.is_dir():
        raise HTTPException(status_code=404, detail="Voice not found.")
    for child in target.iterdir():
        child.unlink(missing_ok=True)
    target.rmdir()
    return {"deleted": voice_id}
