"""The trained voice narrates AI replies unless a catalog voice is named."""

from __future__ import annotations

import base64
import io
import wave

from app.voice.clone_narration import (
    clone_applied_controls,
    clone_audio_metadata,
    is_automatic_voice,
)


def _wav_bytes(*, rate: int = 22050, seconds: int = 1) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        handle.writeframes(b"\x00\x00" * rate * seconds)
    return buffer.getvalue()


def test_automatic_voice_covers_sentinels_and_the_catalog_default():
    assert is_automatic_voice("")
    assert is_automatic_voice("default")
    assert is_automatic_voice("AUTO")
    # The app sent this before the trained voice existed; it means "whatever
    # the app defaults to", not an explicit British narrator.
    assert is_automatic_voice("en-gb-female")


def test_explicit_catalog_voice_is_not_automatic():
    assert not is_automatic_voice("en-us-male")
    assert not is_automatic_voice("en-in-female-2")


def test_clone_metadata_reads_wav_duration_and_rate():
    audio = _wav_bytes(rate=22050, seconds=2)
    envelope = {
        "audio_base64": base64.b64encode(audio).decode("ascii"),
        "mime": "audio/wav",
    }

    duration_ms, sample_rate = clone_audio_metadata(envelope)

    assert sample_rate == 22050
    assert duration_ms == 2000


def test_clone_metadata_falls_back_for_non_wav_audio():
    envelope = {
        "audio_base64": base64.b64encode(b"\xff" * 16000).decode("ascii"),
        "mime": "audio/mpeg",
    }

    duration_ms, sample_rate = clone_audio_metadata(envelope)

    assert sample_rate == 24000
    assert duration_ms == 1000


def test_clone_controls_report_only_honoured_settings():
    controls = clone_applied_controls(
        {
            "provider": "openvoice",
            "display_name": "Amin Voice Test - Amidzo",
            "applied": {
                "base_speaker": "EN-US",
                "speed": 1.0,
                "style_ignored": "the OpenVoice engine has no speaking-style control",
            },
        }
    )

    assert controls["base_speaker"] == "EN-US"
    assert controls["speed"] == 1.0
    assert controls["clone_provider"] == "openvoice"
    assert controls["clone_voice"] == "Amin Voice Test - Amidzo"
