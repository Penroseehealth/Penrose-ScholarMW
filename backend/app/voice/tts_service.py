from __future__ import annotations

import base64
import importlib.util
import logging

import httpx

from app.voice.speech_normalizer import AcademicSpeechNormalizer
from app.voice.voice_catalog import resolve_edge_voice

log = logging.getLogger(__name__)


class TTSService:
    """Penrose Voice Synthesis Engine.

    Converts text to speech with academic normalization.
    Supports streaming synthesis for real-time playback.

    Provider priority: ElevenLabs -> OpenAI -> Edge TTS (key-free) -> browser.
    Accent/gender selection lives in `voice_catalog` so callers pass stable
    voice ids such as `en-in-female` instead of provider voice names.
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
        # ElevenLabs and OpenAI are preferred; Edge TTS needs no credentials so
        # speech keeps working on installs that have no cloud keys at all.
        self._edge_available = importlib.util.find_spec("edge_tts") is not None
        self._available = bool(
            s.ELEVENLABS_API_KEY or s.OPENAI_API_KEY or self._edge_available
        )
        if not self._available:
            log.info("TTS: no provider configured, using browser TTS fallback")
        elif not (s.ELEVENLABS_API_KEY or s.OPENAI_API_KEY):
            log.info("TTS: no cloud keys, using key-free Edge TTS provider")

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
            "provider": "browser",
            "normalized_text": normalized,
        }

    def _edge_voice_for(self, language: str, voice_id: str) -> str:
        """Resolve an Edge voice from a catalog id or a language code."""
        return resolve_edge_voice(voice_id, language)

    async def synthesize(
        self,
        text: str,
        speed: float | None = None,
        language: str = "en",
        voice_id: str = "",
    ) -> dict:
        """Synthesize text to audio. Returns dict with audio_base64, duration_ms.

        Provider priority: ElevenLabs -> OpenAI -> Edge TTS -> browser fallback.
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
            targets.append(("openai", 1.0))
        if self._edge_available:
            targets.append(("edge", 2.0))

        for provider, _ in targets:
            try:
                audio_bytes = await self._synthesize_with_provider(
                    provider, normalized, s, speed, language, voice_id
                )
                audio_b64 = base64.b64encode(audio_bytes).decode()
                duration_ms = int(len(audio_bytes) * 8 / 128)
                return {
                    "audio_base64": audio_b64,
                    "duration_ms": duration_ms,
                    "sample_rate": 24000,
                    "fallback": False,
                    "provider": provider,
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
        language: str = "en",
        voice_id: str = "",
    ) -> bytes:
        if provider == "elevenlabs":
            return await self._synthesize_elevenlabs(normalized, s, speed)
        if provider == "openai":
            return await self._synthesize_openai(normalized, s, speed)
        return await self._synthesize_edge(normalized, speed, language, voice_id)

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

    async def _synthesize_edge(
        self, normalized: str, speed: float | None, language: str, voice_id: str
    ) -> bytes:
        """Key-free synthesis via Microsoft Edge neural voices (MP3 output)."""
        import edge_tts

        voice = self._edge_voice_for(language, voice_id)
        rate = int(round(((speed or self._speed) - 1.0) * 100))
        audio = bytearray()
        communicate = edge_tts.Communicate(normalized, voice, rate=f"{rate:+d}%")
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio.extend(chunk["data"])
        if not audio:
            raise RuntimeError(f"edge-tts returned no audio for voice {voice}")
        log.info("TTS: synthesized %d bytes with Edge voice %s", len(audio), voice)
        return bytes(audio)

    def segment_for_streaming(self, text: str) -> list[str]:
        """Split text into sentence-level segments for streaming TTS."""
        import re

        normalized = AcademicSpeechNormalizer.normalize(text)
        segments = re.split(r"(?<=[.!?])\s+", normalized)
        return [s.strip() for s in segments if s.strip()]


tts_service = TTSService()
