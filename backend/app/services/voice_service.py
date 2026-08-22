"""Text-to-Speech and Speech-to-Text services for ScholarAI.

Uses Web Speech API on the client side for TTS/STT where available.
Backend provides voice library management, STEM notation normalization,
and fallback TTS via AI provider or external API.
"""

from __future__ import annotations

import logging
import uuid

log = logging.getLogger(__name__)

VOICE_LIBRARY: list[dict] = [
    {
        "voice_id": "en-us-academic-male-1",
        "name": "Academic Male 1",
        "language": "en",
        "gender": "male",
        "description": "Clear, professional academic voice",
    },
    {
        "voice_id": "en-us-academic-male-2",
        "name": "Academic Male 2",
        "language": "en",
        "gender": "male",
        "description": "Warm, engaging tutor voice",
    },
    {
        "voice_id": "en-us-academic-male-3",
        "name": "Academic Male 3",
        "language": "en",
        "gender": "male",
        "description": "Deep, authoritative narrator",
    },
    {
        "voice_id": "en-us-academic-female-1",
        "name": "Academic Female 1",
        "language": "en",
        "gender": "female",
        "description": "Clear, articulate academic voice",
    },
    {
        "voice_id": "en-us-academic-female-2",
        "name": "Academic Female 2",
        "language": "en",
        "gender": "female",
        "description": "Friendly, approachable tutor",
    },
    {
        "voice_id": "en-us-academic-female-3",
        "name": "Academic Female 3",
        "language": "en",
        "gender": "female",
        "description": "Professional narrator",
    },
    {
        "voice_id": "en-us-calm-tutor",
        "name": "Calm Tutor",
        "language": "en",
        "gender": None,
        "description": "Slow, clear pace for difficult topics",
    },
    {
        "voice_id": "en-us-energetic-tutor",
        "name": "Energetic Tutor",
        "language": "en",
        "gender": None,
        "description": "Enthusiastic, encouraging tone",
    },
    {
        "voice_id": "en-us-professional-narrator",
        "name": "Professional Narrator",
        "language": "en",
        "gender": None,
        "description": "Formal narration style",
    },
    {
        "voice_id": "en-us-friendly-assistant",
        "name": "Friendly Learning Assistant",
        "language": "en",
        "gender": None,
        "description": "Conversational, supportive tone",
    },
    {
        "voice_id": "zh-academic-female-1",
        "name": "Chinese Academic Female 1",
        "language": "zh",
        "gender": "female",
        "description": "Mandarin academic voice",
    },
    {
        "voice_id": "zh-academic-male-1",
        "name": "Chinese Academic Male 1",
        "language": "zh",
        "gender": "male",
        "description": "Mandarin professional voice",
    },
    {
        "voice_id": "ar-academic-female-1",
        "name": "Arabic Academic Female 1",
        "language": "ar",
        "gender": "female",
        "description": "Arabic academic voice",
    },
    {
        "voice_id": "ar-academic-male-1",
        "name": "Arabic Academic Male 1",
        "language": "ar",
        "gender": "male",
        "description": "Arabic professional voice",
    },
]

# In-memory voice clones (would use DB in production)
_voice_clones: dict[str, dict] = {}


def get_voice_library(language: str | None = None) -> list[dict]:
    if language and language != "all":
        return [v for v in VOICE_LIBRARY if v["language"] == language]
    return VOICE_LIBRARY


def get_voice(voice_id: str) -> dict | None:
    for v in VOICE_LIBRARY:
        if v["voice_id"] == voice_id:
            return v
    return _voice_clones.get(voice_id)


async def create_voice_clone(
    user_id: int,
    voice_name: str,
    audio_content: bytes | None = None,
    consent_confirmed: bool = False,
) -> dict:
    if not consent_confirmed:
        return {
            "status": "error",
            "message": "Voice cloning requires explicit consent. Please confirm you own or have authorization to use this voice.",
        }

    clone_id = f"clone-{user_id}-{uuid.uuid4().hex[:8]}"
    clone = {
        "clone_id": clone_id,
        "user_id": user_id,
        "voice_name": voice_name,
        "status": "created",
        "created_at": "2026-01-01T00:00:00Z",
    }
    _voice_clones[clone_id] = clone
    log.info("Voice clone created: %s for user %d", clone_id, user_id)
    return clone


def delete_voice_clone(clone_id: str, user_id: int) -> bool:
    clone = _voice_clones.get(clone_id)
    if clone and clone.get("user_id") == user_id:
        del _voice_clones[clone_id]
        return True
    return False


def get_user_voice_clones(user_id: int) -> list[dict]:
    return [c for c in _voice_clones.values() if c.get("user_id") == user_id]
