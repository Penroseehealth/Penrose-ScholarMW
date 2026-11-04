import asyncio
from types import SimpleNamespace

import pytest
from pydantic import ValidationError

from app.speech.schemas import SynthesisRequest
from app.voice.models import SpeechDeliveryStyle, SpeechMode, SpeechScenario, TTSRequest
from app.voice.tts_service import (
    _applied_controls,
    _edge_rate,
    _openai_instructions,
    _split_for_provider,
    tts_service,
)


def test_tts_request_accepts_delivery_scenario_and_faithful_reading():
    request = TTSRequest(
        text="Read this source exactly.",
        scenario=SpeechScenario.SCIENTIFIC_EXPLANATION,
        delivery_style=SpeechDeliveryStyle.PROFESSIONAL,
        mode=SpeechMode.FAITHFUL_READING,
    )

    assert request.scenario is SpeechScenario.SCIENTIFIC_EXPLANATION
    assert request.delivery_style is SpeechDeliveryStyle.PROFESSIONAL
    assert request.mode is SpeechMode.FAITHFUL_READING


def test_speech_endpoint_validates_delivery_style():
    with pytest.raises(ValidationError):
        SynthesisRequest(text="A short sample.", delivery_style="random")


def test_provider_chunking_preserves_all_source_characters():
    text = ("A complete sentence. " * 220) + "The final sentence remains."

    chunks = _split_for_provider(text, max_chars=180)

    assert all(len(chunk) <= 180 for chunk in chunks)
    assert "".join(chunks) == text


def test_faithful_reading_does_not_apply_conversation_length_cap():
    text = "The source contains every detail. " * 80
    was_available = tts_service._available
    tts_service._available = False
    try:
        result = asyncio.run(
            tts_service.synthesize(text, mode=SpeechMode.FAITHFUL_READING.value)
        )
    finally:
        tts_service._available = was_available

    assert result["audio_base64"] == ""
    assert result["normalized_text"] == text
    assert len(result["normalized_text"]) > 1200


def test_edge_delivery_adjusts_pace_by_scenario_without_random_fillers():
    base = _edge_rate(1.0, "natural_conversation", "clean_natural")
    scientific = _edge_rate(1.0, "scientific_explanation", "professional")

    assert scientific < base


def test_provider_capabilities_report_only_controls_the_provider_supports():
    settings = SimpleNamespace(
        OPENAI_TTS_MODEL="gpt-4o-mini-tts",
        ELEVENLABS_MODEL="eleven_multilingual_v2",
    )
    edge = _applied_controls(
        "edge", settings, 1.0, "classroom_teaching", "conversational", "conversation"
    )
    openai = _applied_controls(
        "openai", settings, 1.0, "classroom_teaching", "conversational", "conversation"
    )

    assert edge["scenario_instructions"] is False
    assert edge["fillers_supported"] is False
    assert openai["scenario_instructions"] is True
    assert openai["prosody_instructions_sent"] is True


def test_openai_instructions_distinguish_faithful_reading_from_conversation():
    faithful = _openai_instructions(
        SpeechScenario.CLASSROOM_TEACHING.value,
        SpeechDeliveryStyle.HIGHLY_EXPRESSIVE.value,
        SpeechMode.FAITHFUL_READING.value,
    )
    conversational = _openai_instructions(
        SpeechScenario.PODCAST_DISCUSSION.value,
        SpeechDeliveryStyle.CONVERSATIONAL.value,
        SpeechMode.CONVERSATION.value,
    )

    assert "Do not add, remove" in faithful
    assert "Do not add fillers" in faithful
    assert "only when context genuinely calls for them" in conversational
