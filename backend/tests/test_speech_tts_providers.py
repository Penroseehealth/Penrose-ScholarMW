"""Text-to-speech provider chain: order, fallback and honest status."""

import base64
from types import SimpleNamespace
from unittest.mock import patch

import pytest

from app.speech.exceptions import ServiceUnavailableError
from app.speech.service import SpeechService, _tts_order, _wav_header, available_voices


def _wav(frames: bytes = b"\x00\x00" * 8) -> bytes:
    return _wav_header((1, 1, 8000, 16), len(frames)) + frames


class _FakeResponse:
    def __init__(
        self,
        status_code: int,
        payload=None,
        *,
        content: bytes = b"",
        text: str = "",
        headers: dict | None = None,
    ) -> None:
        self.status_code = status_code
        self._payload = payload
        self.content = content
        self.text = text
        self.headers = headers or {}

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
        "tts_provider_priority": ["cloudflare", "groq"],
        "cloudflare_account_id": "account-1",
        "cloudflare_api_token": "cf-token",
        "cloudflare_ai_base_url": "https://cf.test/client/v4",
        "cloudflare_stt_model": "@cf/openai/whisper",
        "cloudflare_tts_model": "@cf/myshell-ai/melotts",
        "cloudflare_tts_lang": "en",
        "groq_api_key": "",
        "groq_base_url": "https://groq.test/openai/v1",
        "groq_stt_model": "whisper-large-v3-turbo",
        "groq_tts_model": "canopylabs/orpheus-v1-english",
        "tts_voice": "hannah",
        "tts_speed": 1.0,
        "tts_provider_fallback_order": ["groq", "freeai"],
    }
    values.update(overrides)
    return SimpleNamespace(**values)


def _cloudflare_ok(wav: bytes | None = None) -> _FakeResponse:
    audio = base64.b64encode(wav or _wav()).decode("ascii")
    return _FakeResponse(200, {"result": {"audio": audio}})


def test_cloudflare_melotts_is_used_first_and_reports_ignored_controls():
    settings = _settings(groq_api_key="groq-token")
    http = _FakeHttp([_cloudflare_ok()])
    service = SpeechService(client_factory=lambda: http)

    with patch("app.speech.service.get_settings", return_value=settings):
        result = service.synthesize("Hello classroom.", voice="hannah", speed=1.4)

    assert result["provider"] == "cloudflare"
    assert result["model"] == "@cf/myshell-ai/melotts"
    assert result["mime"] == "audio/wav"
    assert result["voice"] == "default"
    assert result["speed"] == 1.0
    assert "voice_ignored" in result["applied"]
    assert "speed_ignored" in result["applied"]
    assert base64.b64decode(result["audio_base64"]) == _wav()
    url, kwargs = http.requests[0]
    assert url.endswith("/accounts/account-1/ai/run/@cf/myshell-ai/melotts")
    assert kwargs["json"] == {"prompt": "Hello classroom.", "lang": "en"}


def test_cloudflare_failure_falls_through_to_groq_with_named_voice():
    settings = _settings(groq_api_key="groq-token")
    wav = _wav()
    http = _FakeHttp(
        [
            _FakeResponse(401, text='{"error":"invalid key"}'),
            _FakeResponse(200, content=wav, headers={"content-type": "audio/wav"}),
        ]
    )
    service = SpeechService(client_factory=lambda: http)

    with patch("app.speech.service.get_settings", return_value=settings):
        result = service.synthesize("Hello classroom.", voice="austin")

    assert result["provider"] == "groq"
    assert result["voice"] == "austin"
    assert result["applied"] == {"voice": "austin", "speed": 1.0}
    assert http.requests[1][0].endswith("/audio/speech")
    assert http.requests[1][1]["json"]["voice"] == "austin"


def test_melotts_has_no_named_voices_but_groq_does():
    cloudflare = _settings(groq_api_key="groq-token")
    with patch("app.speech.service.get_settings", return_value=cloudflare):
        assert _tts_order() == ["cloudflare", "groq"]
        assert available_voices() == []

    groq_only = _settings(cloudflare_api_token="", groq_api_key="groq-token")
    with patch("app.speech.service.get_settings", return_value=groq_only):
        assert _tts_order() == ["groq"]
        voices = available_voices()
        assert "hannah" in voices
        assert "austin" in voices


def test_status_reports_the_provider_that_will_actually_speak():
    settings = _settings(groq_api_key="groq-token")
    service = SpeechService(client_factory=lambda: _FakeHttp([]))

    with patch("app.speech.service.get_settings", return_value=settings):
        status = service.status()

    assert status["tts_configured"] is True
    assert status["tts_provider"] == "cloudflare"
    assert status["tts_models"] == ["@cf/myshell-ai/melotts"]
    assert status["tts_voices"] == []


def test_no_configured_tts_provider_raises_an_honest_503():
    settings = _settings(cloudflare_api_token="", groq_api_key="")
    service = SpeechService(client_factory=lambda: _FakeHttp([]))

    with patch("app.speech.service.get_settings", return_value=settings):
        status = service.status()
        with pytest.raises(ServiceUnavailableError) as excinfo:
            service.synthesize("Hello classroom.")

    assert status["tts_configured"] is False
    assert status["tts_provider"] == ""
    assert status["tts_models"] == []
    assert excinfo.value.status_code == 503
    assert "CLOUDFLARE_API_TOKEN" in excinfo.value.message


def test_long_text_is_chunked_and_merged_for_melotts():
    settings = _settings()
    first, second = _wav(b"\x01\x00" * 4), _wav(b"\x02\x00" * 4)
    http = _FakeHttp([_cloudflare_ok(first), _cloudflare_ok(second)])
    service = SpeechService(client_factory=lambda: http)
    text = "word " * 300  # 179 words fit in one 900-character request, so two

    with patch("app.speech.service.get_settings", return_value=settings):
        result = service.synthesize(text)

    assert len(http.requests) == 2
    merged = base64.b64decode(result["audio_base64"])
    assert merged[:4] == b"RIFF"
    assert merged.count(b"data") == 1
