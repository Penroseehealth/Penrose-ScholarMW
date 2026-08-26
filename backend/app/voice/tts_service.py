from __future__ import annotations

import base64
import logging

from app.voice.speech_normalizer import AcademicSpeechNormalizer

log = logging.getLogger(__name__)


class TTSService:
    """Penrose Voice Synthesis Engine.

    Converts text to speech with academic normalization.
    Supports streaming synthesis for real-time playback.
    """

    _instance: TTSService | None = None

    def __new__(cls) -> TTSService:
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self) -> None:
        if self._initialized:
            return
        self._initialized = True
        self._speed = 1.0
        self._voice = "alloy"
        self._available = False
        self._check_availability()

    def _check_availability(self) -> None:
        from app.config.settings import get_settings

        s = get_settings()
        self._available = bool(s.OPENAI_API_KEY)
        if not self._available:
            log.info("TTS: OpenAI not configured, using browser TTS fallback")

    @property
    def is_available(self) -> bool:
        return self._available

    def set_speed(self, speed: float) -> None:
        self._speed = max(0.5, min(2.0, speed))

    def set_voice(self, voice: str) -> None:
        self._voice = voice

    async def synthesize(self, text: str, speed: float | None = None) -> dict:
        """Synthesize text to audio. Returns dict with audio_base64, duration_ms."""
        normalized = AcademicSpeechNormalizer.normalize(text)

        if not self._available:
            return {
                "audio_base64": "",
                "duration_ms": 0,
                "sample_rate": 24000,
                "fallback": True,
                "normalized_text": normalized,
            }

        try:
            from openai import AsyncOpenAI

            from app.config.settings import get_settings

            s = get_settings()
            client = AsyncOpenAI(api_key=s.OPENAI_API_KEY)
            response = await client.audio.speech.create(
                model="tts-1",
                voice=self._voice,
                input=normalized,
                response_format="mp3",
                speed=speed or self._speed,
            )

            audio_bytes = await response.aread()
            audio_b64 = base64.b64encode(audio_bytes).decode()

            duration_ms = int(len(audio_bytes) * 8 / 16)

            return {
                "audio_base64": audio_b64,
                "duration_ms": duration_ms,
                "sample_rate": 24000,
                "fallback": False,
                "normalized_text": normalized,
            }
        except Exception as e:
            log.warning("TTS synthesis failed: %s", e)
            return {
                "audio_base64": "",
                "duration_ms": 0,
                "sample_rate": 24000,
                "fallback": True,
                "normalized_text": normalized,
            }

    def segment_for_streaming(self, text: str) -> list[str]:
        """Split text into sentence-level segments for streaming TTS."""
        import re

        normalized = AcademicSpeechNormalizer.normalize(text)
        segments = re.split(r"(?<=[.!?])\s+", normalized)
        return [s.strip() for s in segments if s.strip()]


tts_service = TTSService()
