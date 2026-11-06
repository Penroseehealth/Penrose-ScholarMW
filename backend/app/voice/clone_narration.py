"""Default trained-voice narration for the AI audio endpoints.

``/speech/synthesize`` has always preferred a trained voice, but the two paths
the AI chat surfaces call (``/voice/tts`` and ``/ai/multimodal/tts/synthesize``)
used the built-in provider chain unconditionally. The helpers here resolve the
default clone for those paths when the caller is not asking for a specific
catalog voice.

An explicit catalog voice still wins. A voice id that *is* the configured
catalog default is treated as automatic too: those callers predate the trained
voice and send ``en-gb-female`` merely as "whatever the app defaults to", not as
a deliberate choice. Every other catalog id is left alone.
"""

from __future__ import annotations

import base64
import io
import wave

from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.speech.clone_service import VoiceCloneService
from app.speech.repository import VoiceModelRepository

_AUTOMATIC_VOICE_IDS = frozenset({"", "default", "auto"})


def is_automatic_voice(voice_id: str | None) -> bool:
    """Whether the caller left the voice to the app's own default."""
    normalized = (voice_id or "").strip().lower()
    if normalized in _AUTOMATIC_VOICE_IDS:
        return True

    from app.voice.voice_catalog import resolve_default_voice_id

    return normalized == resolve_default_voice_id().strip().lower()


async def synthesize_default_clone(
    db: Session,
    *,
    text: str,
    voice_id: str | None,
    speed: float | None = None,
    language: str | None = None,
) -> dict | None:
    """Speak ``text`` in the default trained voice when one is selected.

    Returns the same envelope ``/speech/synthesize`` returns, or ``None`` when
    the request named an explicit voice or no default clone exists.

    Provider failures are deliberately not swallowed: the caller lets them
    surface as the structured 5xx the rest of the speech layer uses, so a
    request never silently switches to a different narrator.
    """
    if not is_automatic_voice(voice_id):
        return None

    from app.config.settings import get_settings

    if not (get_settings().CLONE_PROVIDER or "").strip():
        return None

    clones = VoiceCloneService(VoiceModelRepository(db))
    model = clones.resolve_default()
    if model is None:
        return None

    # OpenVoice synthesis is CPU-bound and synchronous. Running it in the
    # threadpool keeps the event loop responsive while the sidecar works; the
    # sidecar itself serialises synthesis so two requests never share the CPU.
    return await run_in_threadpool(
        clones.synthesize, model.id, text, speed=speed, language=language
    )


def clone_audio_metadata(envelope: dict) -> tuple[int, int]:
    """Duration in milliseconds and sample rate for a clone envelope.

    The clone envelope carries the encoded audio but not these two fields, which
    the voice API promises. WAV (what OpenVoice returns) is read from its header;
    any other container falls back to the same bitrate estimate the built-in
    chain uses.
    """
    audio = base64.b64decode(envelope.get("audio_base64") or "")
    mime = str(envelope.get("mime") or "").lower()
    if "wav" in mime:
        try:
            with wave.open(io.BytesIO(audio), "rb") as handle:
                frames = handle.getnframes()
                rate = handle.getframerate() or 24000
                return int(frames * 1000 / rate), rate
        except (wave.Error, EOFError, ValueError):
            pass
    return int(len(audio) * 8 / 128), 24000


def clone_applied_controls(envelope: dict) -> dict[str, str | float | bool]:
    """Flatten what the clone engine actually honoured for the API response."""
    controls: dict[str, str | float | bool] = {}
    applied = envelope.get("applied")
    if isinstance(applied, dict):
        for key, value in applied.items():
            if isinstance(value, (str, float, int, bool)):
                controls[str(key)] = value
    controls["clone_provider"] = str(envelope.get("provider") or "")
    controls["clone_voice"] = str(envelope.get("display_name") or "")
    return controls
