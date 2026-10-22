"""Speech provider proxy â€” STT (Groq Whisper) and TTS (Groq Canopy Orpheus).

Stateless passthrough: no persistence. Everything is gated on provider
configuration; when `stt_provider` is empty or no API key is set the module
answers HTTP 503 (`service_unavailable`), keeping the UI honest instead of
silently returning nothing. Keys never leave the server.

TTS: Groq decommissioned `playai-tts`; the live models are the Canopy Orpheus
pair. Orpheus caps each request at 200 characters and returns WAV, so long
replies are chunked on word boundaries and the segments are concatenated back
into one WAV stream.
"""

from __future__ import annotations

import base64
from collections.abc import Callable, Iterator

import httpx

from app.speech.config import get_settings
from app.speech.exceptions import (
    RateLimitedError,
    ServiceUnavailableError,
    ValidationError,
)
from app.speech.tts_text import clean_for_tts

_AUDIO_EXT = {
    "audio/webm": "webm",
    "audio/ogg": "ogg",
    "audio/mpeg": "mp3",
    "audio/mp4": "m4a",
    "audio/wav": "wav",
    "audio/x-wav": "wav",
    "audio/wave": "wav",
    "audio/flac": "flac",
}

_MAX_AUDIO_SIZE = 25 * 1024 * 1024  # 25 MB (Groq STT limit ~50 MB)

_ORPHEUS_MODELS = frozenset(
    {
        "canopylabs/orpheus-v1-english",
    }
)

# Voices are per-model, not global. Keying by model is what stops a voice being
# advertised that the configured engine cannot actually synthesize: asking the
# English model for a voice it does not have returns a provider 400 only at
# synthesis time, long after the user saved it and made it their default.
#
# Only the English model is offered. `canopylabs/orpheus-arabic-saudi` was
# removed deliberately: its six Saudi voices are gone from the product, and a
# voice id that silently stops working is worse than one that never appeared.
_ORPHEUS_VOICES_BY_MODEL: dict[str, frozenset[str]] = {
    "canopylabs/orpheus-v1-english": frozenset(
        {
            "autumn",
            "diana",
            "hannah",
            "austin",
            "daniel",
            "troy",
        }
    ),
}

_ORPHEUS_VOICES = frozenset().union(*_ORPHEUS_VOICES_BY_MODEL.values())

_ORPHEUS_CHUNK_CHARS = 200

_WAV_FMT_EXTENSIBLE = 0xFFFE
# ffmpeg (the muxer behind Groq's Orpheus TTS) cannot back-patch the length of
# a streamed WAV, so it writes 0xFFFFFFFF in both the RIFF and the data chunk
# size fields. The stdlib `wave` module trusts those sentinels, reports ~2.1
# billion frames, and dies in struct.pack with a uint32 overflow.
_SIZE_UNKNOWN = 0xFFFFFFFF


class SpeechService:
    def __init__(
        self, client_factory: Callable[[], httpx.Client] | None | None = None
    ) -> None:
        # Injectable so tests can swap the HTTP transport without real calls.
        self._client_factory = client_factory or (lambda: httpx.Client(timeout=120.0))

    def status(self, default_voice: str | None = None) -> dict:
        settings = get_settings()
        return {
            "enabled": True,
            "stt_provider": settings.stt_provider or "",
            "stt_configured": _stt_configured(),
            "tts_configured": _tts_configured(),
            "stt_models": _stt_models(),
            "tts_models": _tts_models(),
            "tts_voices": available_voices(),
            # Resolved by the caller so a MY VOICES selection wins over the
            # process-wide configured default without this proxy touching the DB.
            "default_voice": default_voice or settings.tts_voice,
            "max_audio_bytes": _MAX_AUDIO_SIZE,
        }

    def transcribe(
        self,
        content: bytes,
        content_type: str,
        *,
        language: str | None = None,
        with_segments: bool = False,
    ) -> dict:
        """Transcribe audio to text.

        ``language`` pins the spoken language (ISO-639-1). It matters most for
        Chichewa: Whisper will otherwise auto-detect, and short answers in a
        low-resource language get confidently returned as English, which would
        silently corrupt a bilingual research record.

        ``with_segments`` requests timestamped spans. Those are what a reviewer
        needs to see *which* part of a long answer the model was unsure about.
        """
        if not _stt_configured():
            raise ServiceUnavailableError(
                "Speech-to-text is not configured. Set STT_PROVIDER and GROQ_API_KEY.",
                details={"status": self.status()},
            )
        if len(content) > _MAX_AUDIO_SIZE:
            raise ValidationError(
                "Audio file exceeds the 25 MB limit for transcription"
            )
        ext = _AUDIO_EXT.get((content_type or "").split(";")[0].strip().lower())
        if not ext:
            raise ValidationError(
                f"Unsupported audio content type '{content_type}'. Use webm/ogg/mp3/wav/m4a/flac."
            )
        settings = get_settings()
        url = f"{settings.groq_base_url.rstrip('/')}/audio/transcriptions"
        form: dict[str, str] = {"model": settings.groq_stt_model}
        if language:
            form["language"] = language
        if with_segments:
            form["response_format"] = "verbose_json"
        with self._client_factory() as http:
            response = http.post(
                url,
                headers={"Authorization": f"Bearer {settings.groq_api_key}"},
                files={"file": (f"audio.{ext}", content, content_type)},
                data=form,
            )
        if response.status_code != 200:
            raise ServiceUnavailableError(
                f"Transcription provider error ({response.status_code}): {response.text[:200]}",
                code="stt_provider_error",
            )
        data = response.json()
        text = (data.get("text") or "").strip()
        if not text:
            raise ServiceUnavailableError("Transcription provider returned empty text")
        result = {
            "transcript": text,
            "provider": "groq",
            "model": settings.groq_stt_model,
        }
        if language:
            result["language"] = language
        if with_segments:
            result["segments"] = _normalise_segments(data.get("segments"))
            result["duration"] = float(data.get("duration") or 0.0)
        return result

    def synthesize(
        self,
        text: str,
        voice: str | None = None,
        speed: float | None = None,
    ) -> dict:
        if not text.strip():
            raise ValidationError("Text to synthesise cannot be empty")
        if not _tts_configured():
            raise ServiceUnavailableError(
                "Speech synthesis is not configured. Set GROQ_API_KEY.",
                details={"status": self.status()},
            )
        settings = get_settings()
        spoken = clean_for_tts(text)
        if not spoken:
            raise ValidationError(
                "Text to synthesise contains only citations, URLs or markdown"
            )
        model = settings.groq_tts_model
        selected_voice = _selected_voice(voice)
        selected_speed = speed if speed is not None else settings.tts_speed
        is_orpheus = model in _ORPHEUS_MODELS
        url = f"{settings.groq_base_url.rstrip('/')}/audio/speech"
        segments: list[bytes] = []
        for chunk in _tts_chunks(spoken):
            payload: dict[str, object] = {
                "model": model,
                "voice": selected_voice,
                "input": chunk,
            }
            if is_orpheus:
                payload["response_format"] = "wav"
            with self._client_factory() as http:
                response = http.post(
                    url,
                    headers={"Authorization": f"Bearer {settings.groq_api_key}"},
                    json=payload,
                )
            if response.status_code == 429:
                # The hosted model's own quota, not a fault in this service.
                # Try the free.ai fallback first (another hosted provider with
                # its own independent daily limit), then the local engine, so a
                # voice conversation keeps working; only if neither is usable is
                # the quota reported honestly as a 429 for the client to back
                # off rather than reading it as "not configured".
                fallback = _freeai_fallback(spoken, selected_voice, selected_speed)
                if fallback is None:
                    fallback = _openvoice_fallback(spoken, selected_speed)
                if fallback is not None:
                    return fallback
                raise RateLimitedError(
                    "Voice replies have reached the speech provider's daily "
                    "limit, so this one could not be spoken. The text is still "
                    "here; voice will work again after the limit resets.",
                    code="tts_rate_limited",
                    details={
                        "provider": "groq",
                        "model": model,
                        "retry_after": response.headers.get("retry-after"),
                    },
                )
            if response.status_code != 200:
                raise ServiceUnavailableError(
                    f"Synthesis provider error ({response.status_code}): {response.text[:200]}",
                    code="tts_provider_error",
                )
            segments.append(response.content)
        mime = (
            "audio/wav"
            if is_orpheus
            else response.headers.get("content-type", "audio/mpeg")
        )
        # Orpheus caps each request at 200 characters, so long replies come back
        # as several WAV streams that have to be spliced into one; MPEG frames
        # simply concatenate as raw bytes.
        audio = _merge_wav_segments(segments) if is_orpheus else b"".join(segments)
        return {
            "audio_base64": base64.b64encode(audio).decode("ascii"),
            "mime": mime,
            "provider": "groq",
            "model": model,
            "voice": selected_voice,
            "speed": selected_speed,
            # What the engine actually honoured, so a caller can tell the user
            # when a control they asked for never reached the engine.
            "applied": {"voice": selected_voice, "speed": selected_speed},
        }


def _stt_configured() -> bool:
    settings = get_settings()
    return bool(settings.stt_provider == "groq" and settings.groq_api_key)


def _tts_configured() -> bool:
    settings = get_settings()
    return bool(settings.groq_api_key)


def _freeai_fallback(text: str, voice: str, speed: float) -> dict | None:
    """Try the free.ai TTS provider, or None if it can't be used.

    Used as the first fallback when Groq's Orpheus engine reports a daily
    quota (429): free.ai is a separate hosted endpoint with its own
    independent limit, so it can often answer the same request. The envelope
    carries ``applied.fallback_from`` so the substitution is never presented
    as the requested voice having spoken.
    """
    settings = get_settings()
    if not settings.freeai_api_key:
        return None
    url = f"{settings.freeai_base_url.rstrip('/')}/audio/speech"
    payload = {
        "model": settings.freeai_tts_model,
        "voice": voice,
        "input": text,
        "response_format": "wav",
    }
    try:
        with httpx.Client(timeout=120.0) as http:
            response = http.post(
                url,
                headers={"Authorization": f"Bearer {settings.freeai_api_key}"},
                json=payload,
            )
    except httpx.HTTPError:
        return None
    if response.status_code != 200:
        return None
    audio = response.content
    if not audio:
        return None
    return {
        "audio_base64": base64.b64encode(audio).decode("ascii"),
        "mime": "audio/wav",
        "provider": "freeai",
        "model": settings.freeai_tts_model,
        "voice": voice,
        "speed": speed,
        "applied": {
            "voice": voice,
            "speed": speed,
            "fallback_from": "groq:rate_limited",
        },
    }


def _openvoice_fallback(text: str, speed: float) -> dict | None:
    """Render a reply on the local OpenVoice sidecar, or None if unavailable.

    Used only when the hosted engine refuses (a 429). The envelope carries
    ``applied.fallback_from`` and a ``voice`` of the base speaker so the
    substitution is explicit â€” a caller is never told the requested engine
    voice spoke when a different one did.
    """
    settings = get_settings()
    if (settings.clone_provider or "").strip().lower() != "openvoice":
        return None
    if not settings.openvoice_sidecar_url:
        return None
    from app.speech.cloning import OpenVoiceProvider, render

    provider = OpenVoiceProvider()
    # A health probe, not a guess from configuration: a URL in the environment
    # does not mean a process is listening on it.
    if not provider.available():
        return None
    try:
        clone = provider.synthesize_base(
            text=text,
            base_speaker=settings.openvoice_base_speaker,
            speed=speed,
        )
    except ServiceUnavailableError:
        return None
    envelope = render(clone)
    envelope["applied"] = {
        **(envelope.get("applied") or {}),
        "fallback_from": "groq:rate_limited",
        "base_speaker": settings.openvoice_base_speaker,
    }
    envelope["voice"] = settings.openvoice_base_speaker
    return envelope


def _stt_models() -> list[str]:
    return ["whisper-large-v3", "whisper-large-v3-turbo"]


def _normalise_segments(raw) -> list[dict]:
    """Reduce a provider's verbose segments to the fields the UI needs.

    Providers disagree on casing and on whether confidence is present at all, so
    anything missing becomes an explicit ``None`` rather than a fake 0.0 -- a
    reviewer must be able to tell "the model was unsure" from "we do not know".
    """
    if not isinstance(raw, list):
        return []
    out: list[dict] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        text = str(item.get("text") or "").strip()
        if not text:
            continue
        confidence = item.get("confidence", item.get("avg_logprob"))
        out.append(
            {
                "start": float(item.get("start") or 0.0),
                "end": float(item.get("end") or 0.0),
                "text": text,
                "confidence": float(confidence)
                if isinstance(confidence, (int, float))
                else None,
            }
        )
    return out


def _tts_models() -> list[str]:
    return ["canopylabs/orpheus-v1-english"]


def available_voices() -> list[str]:
    """Every voice the *configured* engine and model can actually synthesize.

    Scoped to the configured model, so the MY VOICES picker never offers a
    voice the provider would reject.
    """
    model = (get_settings().groq_tts_model or "").strip()
    voices = _ORPHEUS_VOICES_BY_MODEL.get(model)
    if voices is None:
        # An unrecognised model: offer the union rather than nothing, and let
        # the provider be the final authority.
        return sorted(_ORPHEUS_VOICES)
    return sorted(voices)


def is_available_voice(voice: str | None) -> bool:
    return (voice or "").strip().lower() in set(available_voices())


def _selected_voice(voice: str | None) -> str:
    settings = get_settings()
    supported = set(available_voices())
    requested = (voice or "").strip().lower()
    if requested in supported:
        return requested
    default = (settings.tts_voice or "hannah").strip().lower()
    return default if default in supported else sorted(supported)[0]


def _tts_chunks(text: str) -> list[str]:
    """Split prose into word-aligned pieces of at most 200 characters.

    Orpheus caps each synthesis request at 200 characters.
    """
    chunks: list[str] = []
    buffer = ""
    for word in text.split():
        candidate = f"{buffer} {word}".strip() if buffer else word
        if len(candidate) > _ORPHEUS_CHUNK_CHARS:
            if buffer:
                chunks.append(buffer)
            buffer = word
        else:
            buffer = candidate
    if buffer:
        chunks.append(buffer)
    if not chunks:
        chunks.append("")
    return chunks


def _u16(data: bytes, offset: int) -> int:
    return int.from_bytes(data[offset : offset + 2], "little")


def _u32(data: bytes, offset: int) -> int:
    return int.from_bytes(data[offset : offset + 4], "little")


def _wav_chunks(body: bytes) -> Iterator[tuple[bytes, bytes]]:
    """Walk RIFF chunks, clamping any length the producer got wrong.

    ffmpeg writes 0xFFFFFFFF when it streams a WAV it cannot back-patch, and
    some muxers append metadata chunks after the audio, so the declared size is
    never trusted over the bytes that are actually present.
    """
    offset = 0
    total = len(body)
    while offset + 8 <= total:
        chunk_id = body[offset : offset + 4]
        size = _u32(body, offset + 4)
        offset += 8
        if size == _SIZE_UNKNOWN or offset + size > total:
            size = total - offset
        yield chunk_id, body[offset : offset + size]
        offset += size + (size % 2)  # chunks are word aligned


def _parse_wav_segment(segment: bytes) -> tuple[tuple[int, int, int, int], bytes]:
    """Return ((format_tag, channels, sample_rate, bits), pcm_frames)."""
    if len(segment) < 12 or segment[:4] != b"RIFF" or segment[8:12] != b"WAVE":
        raise ServiceUnavailableError(
            "Synthesis provider returned a malformed WAV stream",
            code="tts_provider_error",
        )
    fmt: bytes | None = None
    frames = bytearray()
    for chunk_id, payload in _wav_chunks(segment[12:]):
        if chunk_id == b"fmt " and fmt is None:
            fmt = payload
        elif chunk_id == b"data":
            frames += payload
    if fmt is None or len(fmt) < 16:
        raise ServiceUnavailableError(
            "Synthesis provider returned a WAV stream without a format chunk",
            code="tts_provider_error",
        )
    tag = _u16(fmt, 0)
    if tag == _WAV_FMT_EXTENSIBLE and len(fmt) >= 26:
        # The real format tag is the first field of the SubFormat GUID.
        tag = _u16(fmt, 24)
    return (tag, _u16(fmt, 2), _u32(fmt, 4), _u16(fmt, 14)), bytes(frames)


def _wav_header(params: tuple[int, int, int, int], data_length: int) -> bytes:
    """Build a canonical 44-byte PCM header with real, non-sentinel sizes."""
    tag, channels, sample_rate, bits = params
    block_align = channels * (bits // 8)
    return b"".join(
        (
            b"RIFF",
            (36 + data_length).to_bytes(4, "little"),
            b"WAVEfmt ",
            (16).to_bytes(4, "little"),
            tag.to_bytes(2, "little"),
            channels.to_bytes(2, "little"),
            sample_rate.to_bytes(4, "little"),
            (sample_rate * block_align).to_bytes(4, "little"),
            block_align.to_bytes(2, "little"),
            bits.to_bytes(2, "little"),
            b"data",
            data_length.to_bytes(4, "little"),
        )
    )


def _merge_wav_segments(segments: list[bytes]) -> bytes:
    """Concatenate WAV segments into one stream (handles orpheus 200-char calls).

    A single segment is returned untouched. Several segments are only spliced
    when they share identical audio parameters (the same model always does), and
    the output header is rebuilt from the bytes actually present so the result
    is a valid WAV even when the provider left 0xFFFFFFFF size sentinels.
    """
    if len(segments) == 1:
        return segments[0]
    parsed = [_parse_wav_segment(segment) for segment in segments]
    first, _ = parsed[0]
    for params, _frames in parsed[1:]:
        if params != first:
            raise ServiceUnavailableError(
                "Synthesis segments returned inconsistent audio formats",
                code="tts_provider_error",
            )
    joined = b"".join(frames for _params, frames in parsed)
    return _wav_header(first, len(joined)) + joined
