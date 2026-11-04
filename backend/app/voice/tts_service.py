from __future__ import annotations

import base64
import importlib.util
import logging
import re

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

    @property
    def preferred_provider(self) -> str:
        from app.config.settings import get_settings

        settings = get_settings()
        if settings.ELEVENLABS_API_KEY:
            return "elevenlabs"
        if settings.OPENAI_API_KEY:
            return "openai"
        return "edge" if self._edge_available else "browser"

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
        scenario: str = "natural_conversation",
        delivery_style: str = "clean_natural",
        mode: str = "conversation",
    ) -> dict:
        """Synthesize text to audio. Returns dict with audio_base64, duration_ms.

        Provider priority: ElevenLabs -> OpenAI -> Edge TTS -> browser fallback.
        """
        if mode == "faithful_reading":
            normalized = text
        else:
            normalized = AcademicSpeechNormalizer.normalize(text)
            normalized = AcademicSpeechNormalizer.summarize_for_speech(normalized)
        if not normalized.strip():
            return self._empty_result(normalized)

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
                audio_parts = []
                for chunk in _split_for_provider(normalized):
                    audio_parts.append(
                        await self._synthesize_with_provider(
                            provider,
                            chunk,
                            s,
                            speed,
                            language,
                            voice_id,
                            scenario,
                            delivery_style,
                            mode,
                        )
                    )
                audio_bytes = b"".join(audio_parts)
                audio_b64 = base64.b64encode(audio_bytes).decode()
                duration_ms = int(len(audio_bytes) * 8 / 128)
                return {
                    "audio_base64": audio_b64,
                    "duration_ms": duration_ms,
                    "sample_rate": 24000,
                    "fallback": False,
                    "provider": provider,
                    "normalized_text": normalized,
                    "applied_controls": _applied_controls(
                        provider, s, speed, scenario, delivery_style, mode
                    ),
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
        scenario: str = "natural_conversation",
        delivery_style: str = "clean_natural",
        mode: str = "conversation",
    ) -> bytes:
        if provider == "elevenlabs":
            return await self._synthesize_elevenlabs(
                normalized, s, speed, delivery_style, mode
            )
        if provider == "openai":
            return await self._synthesize_openai(
                normalized, s, speed, scenario, delivery_style, mode
            )
        return await self._synthesize_edge(
            normalized, speed, language, voice_id, scenario, delivery_style
        )

    async def _synthesize_elevenlabs(
        self,
        normalized: str,
        s,
        speed: float | None,
        delivery_style: str,
        mode: str,
    ) -> bytes:
        url = f"https://api.elevenlabs.io/v1/text-to-speech/{s.ELEVENLABS_VOICE_ID}"
        headers = {
            "xi-api-key": s.ELEVENLABS_API_KEY,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        }
        stability, style = _elevenlabs_style(delivery_style, mode)
        voice_settings: dict[str, float | bool] = {
            "stability": stability,
            "similarity_boost": 0.75,
            "speed": max(0.7, min(1.2, speed or self._speed)),
        }
        if _elevenlabs_supports_style(s.ELEVENLABS_MODEL):
            voice_settings["style"] = style
        payload = {
            "text": normalized,
            "model_id": s.ELEVENLABS_MODEL,
            "voice_settings": voice_settings,
        }
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(url, headers=headers, json=payload)
            resp.raise_for_status()
            return resp.content

    async def _synthesize_openai(
        self,
        normalized: str,
        s,
        speed: float | None,
        scenario: str,
        delivery_style: str,
        mode: str,
    ) -> bytes:
        from openai import AsyncOpenAI

        client = AsyncOpenAI(api_key=s.OPENAI_API_KEY)
        model = s.OPENAI_TTS_MODEL
        options = {
            "model": model,
            "voice": self._voice,
            "input": normalized,
            "response_format": "mp3",
            "speed": speed or self._speed,
        }
        if model == "gpt-4o-mini-tts":
            options["instructions"] = _openai_instructions(
                scenario, delivery_style, mode
            )
        response = await client.audio.speech.create(**options)
        return await response.aread()

    async def _synthesize_edge(
        self,
        normalized: str,
        speed: float | None,
        language: str,
        voice_id: str,
        scenario: str,
        delivery_style: str,
    ) -> bytes:
        """Key-free synthesis via Microsoft Edge neural voices (MP3 output)."""
        import edge_tts

        voice = self._edge_voice_for(language, voice_id)
        rate = _edge_rate(speed or self._speed, scenario, delivery_style)
        pitch = _edge_pitch(scenario, delivery_style)
        audio = bytearray()
        communicate = edge_tts.Communicate(
            normalized, voice, rate=f"{rate:+d}%", pitch=pitch
        )
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


def _split_for_provider(text: str, max_chars: int = 3600) -> list[str]:
    """Split oversized provider inputs at sentence/word boundaries."""
    if len(text) <= max_chars:
        return [text]

    chunks: list[str] = []
    current = ""
    for sentence in re.split(r"(?<=[.!?])(?=\s)", text):
        candidate = current + sentence
        if current and len(candidate) > max_chars:
            chunks.append(current)
            current = sentence
        else:
            current = candidate
        while len(current) > max_chars:
            boundary = current.rfind(" ", 0, max_chars + 1)
            boundary = boundary if boundary > 0 else max_chars
            chunks.append(current[:boundary])
            current = current[boundary:]
    if current:
        chunks.append(current)
    return chunks


def _openai_instructions(scenario: str, delivery_style: str, mode: str) -> str:
    scenario_notes = {
        "natural_conversation": "Speak as a relaxed, attentive conversation partner.",
        "classroom_teaching": "Teach clearly, pausing naturally and emphasizing key ideas.",
        "academic_presentation": "Deliver a confident, polished academic presentation.",
        "one_to_one_tutoring": "Sound supportive and direct, as in one-to-one tutoring.",
        "storytelling": "Use expressive but restrained narrative pacing.",
        "scientific_explanation": "Use precise pronunciation and measured, clear pacing.",
        "podcast_discussion": "Use a warm, engaged discussion delivery.",
    }.get(scenario, "Use a clear, natural speaking delivery.")
    style_notes = {
        "clean_natural": "Use fluent connected speech with subtle natural variation.",
        "conversational": (
            "Use relaxed rhythm, brief thinking pauses, and occasional subtle fillers "
            "or a light self-correction only when context genuinely calls for them. "
            "Never add them mechanically or simulate stammers."
        ),
        "highly_expressive": (
            "Use expressive intonation and meaningful pauses, with an occasional "
            "natural hesitation or self-correction only where appropriate. Avoid "
            "theatrical overstatement, repeated facts, and exaggerated disfluencies."
        ),
        "professional": "Use controlled pacing and polished, minimally disfluent delivery.",
    }.get(delivery_style, "Use fluent, natural speech.")
    if mode == "faithful_reading":
        source_rule = (
            "Read the supplied text faithfully and in order. Do not add, remove, "
            "summarize, paraphrase, or reorder words or information. Do not add "
            "fillers or transitions."
        )
    else:
        source_rule = (
            "Preserve every claim, number, name, equation, and technical term. Do not "
            "omit or invent facts. Keep spontaneous wording brief, contextually "
            "appropriate, and do not change the order of ideas."
        )
    return f"{scenario_notes} {style_notes} {source_rule}"


def _elevenlabs_style(delivery_style: str, mode: str) -> tuple[float, float]:
    profiles = {
        "clean_natural": (0.58, 0.05),
        "conversational": (0.42, 0.15),
        "highly_expressive": (0.30, 0.32),
        "professional": (0.68, 0.08),
    }
    stability, style = profiles.get(delivery_style, profiles["clean_natural"])
    if mode == "faithful_reading":
        return max(stability, 0.58), min(style, 0.08)
    return stability, style


def _elevenlabs_supports_style(model: str) -> bool:
    unsupported = ("eleven_turbo", "eleven_flash", "eleven_multilingual_tts")
    return not any(model.startswith(prefix) for prefix in unsupported)


def _edge_pitch(scenario: str, delivery_style: str) -> str:
    if delivery_style == "highly_expressive" and scenario in {
        "storytelling",
        "podcast_discussion",
    }:
        return "+2Hz"
    if delivery_style == "professional" or scenario in {
        "academic_presentation",
        "scientific_explanation",
    }:
        return "-1Hz"
    if delivery_style == "conversational":
        return "+1Hz"
    return "+0Hz"


def _applied_controls(
    provider: str,
    settings,
    speed: float | None,
    scenario: str,
    delivery_style: str,
    mode: str,
) -> dict[str, str | float | bool]:
    controls: dict[str, str | float | bool] = {
        "delivery_style_requested": delivery_style,
        "mode": mode,
    }
    if provider == "openai":
        supports_instructions = settings.OPENAI_TTS_MODEL == "gpt-4o-mini-tts"
        controls["scenario_instructions"] = supports_instructions
        if supports_instructions:
            controls["prosody_instructions_sent"] = True
        else:
            controls["prosody_instructions_ignored"] = (
                "the configured OpenAI TTS model does not support instructions"
            )
    elif provider == "elevenlabs":
        controls["voice_settings_sent"] = True
        controls["scenario_instructions"] = False
        if _elevenlabs_supports_style(settings.ELEVENLABS_MODEL):
            controls["delivery_style_applied"] = delivery_style
        else:
            controls["delivery_style_ignored"] = (
                "the configured model has no style control"
            )
    else:
        controls["rate_and_pitch"] = True
        controls["scenario_instructions"] = False
        controls["delivery_style_effect"] = "rate and pitch only"
        controls["fillers_supported"] = False
    if speed is not None:
        controls["speed"] = (
            max(0.7, min(1.2, speed)) if provider == "elevenlabs" else speed
        )
        if provider == "elevenlabs" and controls["speed"] != speed:
            controls["speed_limited_by_provider"] = True
    if provider == "edge":
        controls["pitch"] = _edge_pitch(scenario, delivery_style)
        controls["rate_percent"] = _edge_rate(speed or 1.0, scenario, delivery_style)
        controls["scenario_rate_adjustment"] = True
    return controls


def _edge_rate(speed: float, scenario: str, delivery_style: str) -> int:
    scenario_adjustments = {
        "classroom_teaching": -0.02,
        "academic_presentation": -0.02,
        "scientific_explanation": -0.03,
        "storytelling": -0.04,
    }
    style_adjustments = {
        "conversational": 0.0,
        "highly_expressive": -0.02,
        "professional": -0.01,
    }
    adjusted_speed = speed * (
        1.0
        + scenario_adjustments.get(scenario, 0.0)
        + style_adjustments.get(delivery_style, 0.0)
    )
    adjusted_speed = max(0.5, min(2.0, adjusted_speed))
    return int(round((adjusted_speed - 1.0) * 100))
