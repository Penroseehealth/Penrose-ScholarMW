"""Speech-to-text provider chain: order, fallback and honest status."""

from types import SimpleNamespace
from unittest.mock import patch

import pytest

from app.speech.exceptions import ServiceUnavailableError
from app.speech.service import SpeechService, _stt_order


class _FakeResponse:
    def __init__(self, status_code: int, payload=None, text: str = "") -> None:
        self.status_code = status_code
        self._payload = payload
        self.text = text

    def json(self):
        return self._payload


class _FakeHttp:
    """Minimal stand-in for httpx.Client with a queued response list."""

    def __init__(self, responses: list[_FakeResponse]) -> None:
        self._responses = list(responses)
        self.requests: list[tuple[str, dict]] = []

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def post(self, url: str, **kwargs):
        self.requests.append((url, kwargs))
        return self._responses.pop(0)


def _settings(**overrides) -> SimpleNamespace:
    values = {
        "upload_dir": "",
        "stt_provider": "",
        "stt_provider_priority": ["cloudflare", "groq"],
        "cloudflare_account_id": "account-1",
        "cloudflare_api_token": "cf-token",
        "cloudflare_ai_base_url": "https://cf.test/client/v4",
        "cloudflare_stt_model": "@cf/openai/whisper",
        "groq_api_key": "",
        "groq_base_url": "https://groq.test/openai/v1",
        "groq_stt_model": "whisper-large-v3-turbo",
        "groq_tts_model": "canopylabs/orpheus-v1-english",
        "tts_provider_priority": ["cloudflare", "groq"],
        "cloudflare_tts_model": "@cf/myshell-ai/melotts",
        "cloudflare_tts_lang": "en",
        "tts_voice": "hannah",
    }
    values.update(overrides)
    return SimpleNamespace(**values)


def _cloudflare_ok(text: str = "hello from whisper") -> _FakeResponse:
    return _FakeResponse(200, {"result": {"text": text, "words": []}})


def test_cloudflare_is_used_first_and_reports_the_real_provider():
    settings = _settings(groq_api_key="groq-token")
    http = _FakeHttp([_cloudflare_ok()])
    service = SpeechService(client_factory=lambda: http)

    with patch("app.speech.service.get_settings", return_value=settings):
        result = service.transcribe(b"audio", "audio/wav", language="ny")

    assert result["transcript"] == "hello from whisper"
    assert result["provider"] == "cloudflare"
    assert result["model"] == "@cf/openai/whisper"
    assert result["language"] == "ny"
    assert len(http.requests) == 1
    url, kwargs = http.requests[0]
    assert "/accounts/account-1/ai/run/@cf/openai/whisper" in url
    assert kwargs["data"] == {"language": "ny"}


def test_cloudflare_falls_through_to_groq_when_it_fails():
    settings = _settings(groq_api_key="groq-token")
    http = _FakeHttp(
        [
            _FakeResponse(401, text='{"error":"invalid key"}'),
            _FakeResponse(200, {"text": "hello from groq"}),
        ]
    )
    service = SpeechService(client_factory=lambda: http)

    with patch("app.speech.service.get_settings", return_value=settings):
        result = service.transcribe(b"audio", "audio/webm")

    assert result["provider"] == "groq"
    assert result["transcript"] == "hello from groq"
    assert len(http.requests) == 2
    assert http.requests[1][0].endswith("/audio/transcriptions")


def test_unconfigured_provider_is_skipped_and_status_names_the_active_one():
    settings = _settings(cloudflare_api_token="", groq_api_key="groq-token")
    service = SpeechService(client_factory=lambda: _FakeHttp([]))

    with patch("app.speech.service.get_settings", return_value=settings):
        order = _stt_order()
        status = service.status()

    assert order == ["groq"]
    assert status["stt_provider"] == "groq"
    assert status["stt_configured"] is True
    assert status["stt_models"] == ["whisper-large-v3-turbo"]


def test_single_provider_override_is_tried_before_the_priority_list():
    settings = _settings(
        stt_provider="groq",
        stt_provider_priority=["cloudflare", "groq"],
        groq_api_key="groq-token",
    )

    with patch("app.speech.service.get_settings", return_value=settings):
        order = _stt_order()

    assert order == ["groq", "cloudflare"]


def test_no_configured_provider_raises_an_honest_503():
    settings = _settings(cloudflare_api_token="", groq_api_key="")
    service = SpeechService(client_factory=lambda: _FakeHttp([]))

    with patch("app.speech.service.get_settings", return_value=settings):
        status = service.status()
        with pytest.raises(ServiceUnavailableError) as excinfo:
            service.transcribe(b"audio", "audio/wav")

    assert status["stt_configured"] is False
    assert status["stt_provider"] == ""
    assert excinfo.value.status_code == 503
    assert "CLOUDFLARE_API_TOKEN" in excinfo.value.message


def test_cloudflare_words_become_segments_without_invented_confidence():
    settings = _settings()
    http = _FakeHttp(
        [
            _FakeResponse(
                200,
                {
                    "result": {
                        "text": "two words",
                        "words": [
                            {"word": "two", "start": 0.0, "end": 0.4},
                            {"word": "words", "start": 0.4, "end": 0.9},
                        ],
                    }
                },
            )
        ]
    )
    service = SpeechService(client_factory=lambda: http)

    with patch("app.speech.service.get_settings", return_value=settings):
        result = service.transcribe(b"audio", "audio/wav", with_segments=True)

    assert [item["text"] for item in result["segments"]] == ["two", "words"]
    assert all(item["confidence"] is None for item in result["segments"])
    assert result["duration"] == 0.9
