from __future__ import annotations

import base64
import logging

import httpx

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
        # ElevenLabs is preferred; OpenAI remains as a fallback provider.
        self._available = bool(s.ELEVENLABS_API_KEY or s.OPENAI_API_KEY)
        if not self._available:
            log.info("TTS: no provider configured, using browser TTS fallback")

    @property
    def is_available(self) -> bool:
        return self._available

    def set_speed(self, speed: float) -> None:
        self._speed = max(0.5, min(2.0, speed))

    def set_voice(self, voice: str) -> None:
        self._voice = voice

    def _empty_result(self, normalized: str, *, fallback: bool = True) -> dict:
        return {
            "audio_base64": "",
            "duration_ms": 0,
            "sample_rate": 24000,
            "fallback": fallback,
            "normalized_text": normalized,
        }

    async def synthesize(self, text: str, speed: float | None = None) -> dict:
        """Synthesize text to audio. Returns dict with audio_base64, duration_ms.

        Provider priority: ElevenLabs (preferred) -> OpenAI -> browser fallback.
        """
        normalized = AcademicSpeechNormalizer.normalize(text)

        if not self._available:
            return self._empty_result(normalized)

        from app.config.settings import get_settings

        s = get_settings()
        targets: list[tuple[str, float]] = []
        if s.ELEVENLABS_API_KEY:
            targets.append(("elevenlabs", 0.0))
        if s.OPENAI_API_KEY:
            targets.append(("openai", 0.0))

        for provider, _ in targets:
            try:
                audio_bytes = await self._synthesize_with_provider(
                    provider, normalized, s, speed
                )
                audio_b64 = base64.b64encode(audio_bytes).decode()
                duration_ms = int(len(audio_bytes) * 8 / 128)
                return {
                    "audio_base64": audio_b64,
                    "duration_ms": duration_ms,
                    "sample_rate": 24000,
                    "fallback": False,
                    "normalized_text": normalized,
                }
            except Exception as e:
                log.warning("TTS provider %s failed: %s", provider, e)

        log.warning("All TTS providers failed; using browser TTS fallback")
        return self._empty_result(normalized)

    async def _synthesize_with_provider(
        self,
        provider: str,
        normalized: str,
        s,
        speed: float | None,
    ) -> bytes:
        if provider == "elevenlabs":
            return await self._synthesize_elevenlabs(normalized, s, speed)
        return await self._synthesize_openai(normalized, s, speed)

    async def _synthesize_elevenlabs(
        self, normalized: str, s, speed: float | None
    ) -> bytes:
        url = f"https://api.elevenlabs.io/v1/text-to-speech/{s.ELEVENLABS_VOICE_ID}"
        headers = {
            "xi-api-key": s.ELEVENLABS_API_KEY,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        }
        payload = {
            "text": normalized,
            "model_id": s.ELEVENLABS_MODEL,
            "voice_settings": {
                "stability": 0.5,
                "similarity_boost": 0.75,
                "speed": 1.0,
            },
        }
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(url, headers=headers, json=payload)
            resp.raise_for_status()
            return resp.content

    async def _synthesize_openai(
        self, normalized: str, s, speed: float | None
    ) -> bytes:
        from openai import AsyncOpenAI

        client = AsyncOpenAI(api_key=s.OPENAI_API_KEY)
        response = await client.audio.speech.create(
            model="tts-1",
            voice=self._voice,
            input=normalized,
            response_format="mp3",
            speed=speed or self._speed,
        )
        return await response.aread()

    def segment_for_streaming(self, text: str) -> list[str]:
        """Split text into sentence-level segments for streaming TTS."""
        import re

        normalized = AcademicSpeechNormalizer.normalize(text)
        segments = re.split(r"(?<=[.!?])\s+", normalized)
        return [s.strip() for s in segments if s.strip()]


tts_service = TTSService()
