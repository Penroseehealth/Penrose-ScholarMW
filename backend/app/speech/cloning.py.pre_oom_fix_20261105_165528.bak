"""Voice cloning providers.

A clone is only real if some engine will synthesize *new* text with the user's
speaker identity. Groq's Orpheus cannot do that â€” it serves a fixed list of 12
voice personas and exposes no cloning or fine-tuning endpoint â€” so the clone
pipeline talks to a provider that mints its own voice ids instead.

`VoiceCloneProvider` is that seam. Everything above it (the training flow, the
MY VOICES rows, the conversation layer) is written against this interface, so
adding a second provider is a new class here rather than a second voice system.

ElevenLabs is the implemented provider:

* ``POST /voices/add`` mints a ``voice_id`` from a short sample â€” instant
  cloning, seconds of audio, no training job.
* ``POST /text-to-speech/{voice_id}/stream`` synthesizes arbitrary new text in
  that voice, and genuinely honours speed and style, which the Orpheus engine
  silently ignores.

Two things this module refuses to do:

* Claim identity. The provider reports its own similarity estimate; it is
  carried through as a band ("High"/"Medium"/"Low") and never as a claim of an
  exact match (Â§6).
* Hide an unavailable voice. A provider that has dropped a clone raises
  `VoiceUnavailableError` so the caller can ask the user rather than quietly
  speaking in someone else's voice.
"""

from __future__ import annotations

import base64
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from typing import Protocol

import httpx

from app.speech.config import get_settings
from app.speech.exceptions import (
    ServiceUnavailableError,
    ValidationError,
    VoiceUnavailableError,
)

# Only formats the clone endpoint reliably accepts, and that the browser
# recorder actually produces.
_CLONE_MIME_EXT = {
    "audio/wav": "wav",
    "audio/x-wav": "wav",
    "audio/wave": "wav",
    "audio/mpeg": "mp3",
    "audio/mp4": "m4a",
    "audio/webm": "webm",
    "audio/ogg": "ogg",
    "audio/flac": "flac",
}

# Instant cloning is documented as useful from roughly ten seconds of speech.
# Below this the resulting model is unusable, so the sample is refused before it
# reaches the provider rather than becoming a permanent broken voice.
_MIN_SAMPLE_MS = 8_000
# Above roughly three minutes extra audio stops improving the model and can
# destabilise it, so it is trimmed by rejecting rather than by silently sending
# a sample the user did not intend to upload.
_MAX_SAMPLE_MS = 5 * 60 * 1000

# `speed` is only accepted on the non-turbo models, and `style` is not offered on
# turbo at all. Sending them anyway is a provider error, so they are filtered per
# model instead of being silently dropped after the fact.
_STYLE_UNSUPPORTED = ("eleven_turbo", "eleven_flash", "eleven_multilingual_tts")

_SPEAKING_STYLES = (
    "conversational",
    "formal",
    "academic",
    "calm",
    "enthusiastic",
)


@dataclass(frozen=True)
class CloneRequest:
    """One training run's worth of input."""

    display_name: str
    sample: bytes
    mime_type: str
    duration_ms: int = 0
    description: str = ""
    remove_background_noise: bool = False


@dataclass(frozen=True)
class CloneResult:
    """What the provider gave back after minting a speaker model."""

    provider: str
    provider_voice_id: str
    model_version: str = ""
    requires_verification: bool = False
    similarity_score: float = 0.0
    labels: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class CloneSynthesis:
    audio: bytes
    mime: str
    provider: str
    model: str
    provider_voice_id: str
    # Only the controls the provider actually honoured. Reporting the full
    # request here would claim a speed change that never reached the engine.
    applied: dict[str, object] = field(default_factory=dict)


class VoiceCloneProvider(Protocol):
    """What the training flow needs from whatever engine mints cloned voices."""

    name: str

    def available(self) -> bool: ...

    def create_clone(self, request: CloneRequest) -> CloneResult: ...

    def delete_clone(self, provider_voice_id: str) -> None: ...

    def voice_exists(self, provider_voice_id: str) -> bool: ...

    def synthesize(
        self,
        *,
        text: str,
        provider_voice_id: str,
        speed: float | None = None,
        style: str | None = None,
        language: str | None = None,
    ) -> CloneSynthesis: ...


def cloning_available() -> bool:
    """True when a provider that can actually clone a voice is configured.

    Deliberately derived from configuration rather than cached, so a deploy that
    adds the key starts reporting availability without a code change.
    """
    return _configured_provider_name() is not None


def provider_sample_formats(name: str | None) -> frozenset[str]:
    """Sample containers each provider can actually train from.

    ElevenLabs decodes compressed uploads itself. OpenVoice does not: it loads
    the sample through a plain PCM/WAV reader, so a browser WebM/Opus recording
    reaches it undecodable and it fails with no usable detail. Advertising the
    difference lets the service reject an unusable sample up front with a
    message that says what to do, instead of a bare provider 500.
    """
    if name == "elevenlabs":
        return frozenset(_CLONE_MIME_EXT.values())
    if name == "openvoice":
        return frozenset({"wav", "flac"})
    return frozenset(_CLONE_MIME_EXT.values())


def provider_status() -> dict:
    """What the UI needs to decide whether to offer training at all."""
    name = _configured_provider_name()
    is_openvoice = name == "openvoice"
    # One probe answers both questions the client asks about OpenVoice â€” is it
    # up, and which accents can it really speak. Probing twice would double the
    # cost of every status call and let the two answers disagree with each
    # other if the sidecar restarted in between.
    health = _openvoice_health() if is_openvoice else None
    return {
        "clone_available": name is not None,
        "clone_provider": name or "",
        # Configuration and reachability are separate questions. A provider can
        # be fully configured and still unable to answer â€” the local sidecar may
        # be stopped, or some other process may have bound its port â€” and
        # reporting configuration alone makes the UI offer training that is
        # certain to fail, only after the user has recorded a sample and waited
        # for it. Reporting this alongside `clone_available` lets the client say
        # what to start, up front.
        #
        # ElevenLabs is a cloud API and is reported on the same terms as the
        # rest of this endpoint: configuration rather than a live round trip.
        # Probing it would spend a request on every page load and can fail for
        # reasons that have nothing to do with whether training works.
        "clone_reachable": (health is not None) if is_openvoice else name is not None,
        "clone_models": _tts_models(name) if name else [],
        # OpenVoice supplies the accent through its base speaker and has no
        # style dial, so advertising ElevenLabs' styles would be offering a
        # control that silently does nothing.
        "speaking_styles": [] if is_openvoice else list(_SPEAKING_STYLES),
        "min_sample_ms": _MIN_SAMPLE_MS,
        "max_sample_ms": _MAX_SAMPLE_MS,
        # Lets the UI explain the wait instead of appearing to hang.
        "synthesis_is_slow": is_openvoice,
        # Which containers this provider can train from, so a client can convert
        # a capture up front rather than discovering the limit as a 500.
        "clone_sample_formats": sorted(provider_sample_formats(name)),
        # The accents that have their own reference embedding, as opposed to the
        # full set `/synthesize` accepts. Offering a picker containing only these
        # is the difference between a real choice and a control that quietly
        # speaks with a different accent than the one shown.
        "base_speakers_available": _base_speakers_from(health) if is_openvoice else [],
    }


def _openvoice_health() -> dict | None:
    """One health probe of the sidecar, or None if it did not answer as one.

    The budget is `openvoice_health_timeout_s`, not the synthesis one: this is a
    status check, and a sidecar that is down must not hold the request open for
    the minutes a CPU voice conversion is allowed to take â€” on a single-instance
    host, borrowing that budget would take the status endpoint down with it.

    None covers every way the answer can be untrustworthy: nothing listening,
    a non-200, a body that is not JSON, and a body from a different service that
    happens to own the port. The API serves its own `/health` on 200 as well,
    and the two sit on adjacent ports, so status alone cannot tell them apart;
    the responder has to identify itself or it is treated as absent.
    """
    try:
        with httpx.Client(timeout=get_settings().openvoice_health_timeout_s) as http:
            response = http.get(_openvoice_url("health"))
    except httpx.HTTPError:
        return None
    if response.status_code != 200:
        return None
    try:
        payload = response.json()
    except ValueError:
        return None
    return (
        payload if isinstance(payload, dict) and _looks_like_sidecar(payload) else None
    )


def _base_speakers_from(health: dict | None) -> list[str]:
    """Base speakers the sidecar can actually speak, or all of them if unknown.

    Falls back to the full list when the sidecar cannot be reached, because a
    status endpoint that reports "no accents" while the service is merely down
    would hide training entirely. The substitution is still reported per render,
    so nothing is silently misrepresented.
    """
    if health is not None:
        available = health.get("base_speakers_available")
        if isinstance(available, list) and available:
            return [str(item) for item in available]
    return list(_OPENVOICE_SPEAKERS)


def get_clone_provider(
    client_factory: Callable[[], httpx.Client] | None = None,
) -> VoiceCloneProvider:
    name = _configured_provider_name()
    if name is None:
        raise ServiceUnavailableError(
            "Voice cloning is not configured. Set CLONE_PROVIDER to "
            "'openvoice' and start the sidecar, or set ELEVENLABS_API_KEY.",
            details=provider_status(),
        )
    if name == "elevenlabs":
        return ElevenLabsProvider(client_factory=client_factory)
    if name == "openvoice":
        return OpenVoiceProvider(client_factory=client_factory)
    raise ServiceUnavailableError(f"Unsupported clone provider '{name}'")


def _configured_provider_name() -> str | None:
    settings = get_settings()
    name = (settings.clone_provider or "").strip().lower()
    if not name:
        return None
    if name == "elevenlabs" and settings.elevenlabs_api_key:
        return "elevenlabs"
    if name == "openvoice" and settings.openvoice_sidecar_url:
        return "openvoice"
    return None


# The base speakers MeloTTS ships. These are the accent variants the product
# needs and they are real model weights, not labels applied after the fact.
_OPENVOICE_SPEAKERS = ("EN-US", "EN_INDIA", "EN-AU", "EN-BR", "EN-Default")


def _tts_models(provider: str | None = None) -> list[str]:
    """Provider-specific offerings.

    OpenVoice has no model catalogue to choose between and no speaking-style
    control, so it reports its base speakers and an empty style list instead of
    borrowing ElevenLabs' vocabulary.
    """
    if provider == "openvoice":
        return list(_OPENVOICE_SPEAKERS)
    return ["eleven_multilingual_v2", "eleven_turbo_v2"]


def validate_style(style: str | None) -> str:
    """Reject an unknown style instead of quietly speaking without it.

    A style the engine does not know is a bug in the request, and answering in a
    different delivery than the one that was asked for is exactly the kind of
    silent substitution the voice layer is supposed to avoid.
    """
    if style is None or not style.strip():
        return ""
    normalized = style.strip().lower()
    if normalized not in _SPEAKING_STYLES:
        raise ValidationError(
            f"'{style}' is not a speaking style Penrose offers",
            details={"available": list(_SPEAKING_STYLES)},
        )
    return normalized


def validate_sample(
    sample: bytes,
    mime_type: str,
    duration_ms: int,
    *,
    supported_exts: frozenset[str] | None = None,
) -> str:
    """Check a training sample before it is uploaded anywhere.

    Returns the extension the provider should be given. A sample we cannot
    measure a duration for (a compressed browser recording, say) is accepted
    rather than rejected on a guess â€” `quality.py` reports the measurements it
    could actually take instead of inventing the rest.

    `supported_exts` is the provider's real capability. A container the provider
    cannot decode is refused here with a message naming the format, because
    passing it on only produces an opaque failure from deep inside the trainer.
    """
    if not sample:
        raise ValidationError("The voice sample is empty.")
    ext = _CLONE_MIME_EXT.get((mime_type or "").split(";")[0].strip().lower())
    if not ext:
        raise ValidationError(
            f"Unsupported voice sample type '{mime_type}'. Use wav, mp3, m4a, webm, ogg or flac."
        )
    if supported_exts is not None and ext not in supported_exts:
        raise ValidationError(
            f"This voice trainer cannot read a '{ext}' recording. Record or "
            f"convert the clip to {_join_names(sorted(supported_exts))} and try again.",
            details={"format": ext, "supported_formats": sorted(supported_exts)},
        )
    if duration_ms and duration_ms < _MIN_SAMPLE_MS:
        raise ValidationError(
            f"That sample is only {duration_ms / 1000:.1f}s long. Record a clip of "
            f"at least {_MIN_SAMPLE_MS // 1000} seconds so there is enough to "
            "learn your voice from.",
            details={"min_sample_ms": _MIN_SAMPLE_MS, "duration_ms": duration_ms},
        )
    if duration_ms and duration_ms > _MAX_SAMPLE_MS:
        raise ValidationError(
            f"That sample is {duration_ms / 60000:.1f} minutes long. Keep it under "
            f"{_MAX_SAMPLE_MS // 60000} minutes â€” extra audio stops improving the "
            "model and can make it less stable.",
            details={"max_sample_ms": _MAX_SAMPLE_MS, "duration_ms": duration_ms},
        )
    return ext


def _join_names(names: Sequence[str]) -> str:
    """Format a short list the way a person would say it aloud."""
    if len(names) == 1:
        return names[0]
    if len(names) == 2:
        return f"{names[0]} or {names[1]}"
    return f"{', '.join(names[:-1])} or {names[-1]}"


class ElevenLabsProvider:
    """Instant/professional voice cloning over the ElevenLabs REST API."""

    name = "elevenlabs"

    def __init__(
        self, client_factory: Callable[[], httpx.Client] | None = None
    ) -> None:
        # Injectable for the same reason SpeechService takes one: tests swap the
        # transport instead of calling out over the network.
        self._client_factory = client_factory or (lambda: httpx.Client(timeout=120.0))

    def available(self) -> bool:
        return bool(get_settings().elevenlabs_api_key)

    def create_clone(self, request: CloneRequest) -> CloneResult:
        settings = get_settings()
        ext = validate_sample(request.sample, request.mime_type, request.duration_ms)
        url = f"{_base_url().rstrip('/')}/voices/add"
        files = [("files", (f"sample.{ext}", request.sample, request.mime_type))]
        data: dict[str, str] = {"name": request.display_name}
        if request.description:
            data["description"] = request.description
        if request.remove_background_noise:
            data["remove_background_noise"] = "true"
        with self._client_factory() as http:
            response = http.post(
                url,
                headers={"xi-api-key": settings.elevenlabs_api_key},
                files=files,
                data=data,
            )
        if response.status_code != 200:
            raise _provider_error("create clone", response)
        payload = _json(response)
        voice_id = str(payload.get("voice_id") or "").strip()
        if not voice_id:
            # No id means nothing can ever be synthesized with this model, so it
            # must not be stored as ready.
            raise ServiceUnavailableError(
                "The cloning provider accepted the sample but returned no voice "
                "id, so there is nothing to speak with.",
                code="clone_provider_error",
            )
        return CloneResult(
            provider=self.name,
            provider_voice_id=voice_id,
            model_version=str(payload.get("model_version") or ""),
            requires_verification=bool(payload.get("requires_verification")),
            similarity_score=_similarity_score(payload),
            labels={
                str(k): str(v)
                for k, v in (payload.get("labels") or {}).items()
                if isinstance(v, (str, int, float))
            },
        )

    def delete_clone(self, provider_voice_id: str) -> None:
        if not provider_voice_id:
            return
        settings = get_settings()
        url = f"{_base_url().rstrip('/')}/voices/{provider_voice_id}"
        with self._client_factory() as http:
            response = http.delete(
                url, headers={"xi-api-key": settings.elevenlabs_api_key}
            )
        # 404 means it is already gone, which is the state the caller wanted.
        if response.status_code not in (200, 204, 404):
            raise _provider_error("delete clone", response)

    def voice_exists(self, provider_voice_id: str) -> bool:
        """Ask the provider whether the voice is still synthesizable.

        Used before a reply is spoken so a dropped clone surfaces as an honest
        "your voice is unavailable" instead of a different narrator taking over.
        """
        if not provider_voice_id:
            return False
        settings = get_settings()
        url = f"{_base_url().rstrip('/')}/voices/{provider_voice_id}"
        try:
            with self._client_factory() as http:
                response = http.get(
                    url, headers={"xi-api-key": settings.elevenlabs_api_key}
                )
        except httpx.HTTPError as exc:
            raise ServiceUnavailableError(
                f"Could not confirm your voice is available ({exc}).",
                code="clone_provider_unreachable",
            ) from exc
        if response.status_code == 404:
            return False
        if response.status_code != 200:
            raise _provider_error("read voice", response)
        return True

    def synthesize(
        self,
        *,
        text: str,
        provider_voice_id: str,
        speed: float | None = None,
        style: str | None = None,
        language: str | None = None,
    ) -> CloneSynthesis:
        if not provider_voice_id:
            raise VoiceUnavailableError("No cloned voice was selected.")
        settings = get_settings()
        model = settings.elevenlabs_tts_model
        url = (
            f"{_base_url().rstrip('/')}/text-to-speech/{provider_voice_id}/stream"
            "?output_format=mp3_44100_128"
        )
        voice_settings: dict[str, object] = {
            "use_speaker_boost": True,
            # Stability is pinned mid-range: low values drift from the recorded
            # speaker, high values flatten the prosody the user recorded.
            "stability": 0.5,
            "similarity_boost": 0.75,
        }
        applied: dict[str, object] = {}
        if speed is not None:
            voice_settings["speed"] = speed
            applied["speed"] = speed
        if style and not _model_supports_style(model):
            # Not sent, and not reported as applied.
            applied["style_ignored"] = (
                f"the {model} model does not support speaking styles"
            )
        elif style:
            voice_settings["style"] = _STYLE_VALUE.get(style, 0.0)
            applied["style"] = style
        body: dict[str, object] = {
            "text": text,
            "model_id": model,
            "voice_settings": voice_settings,
        }
        if language and _model_supports_language(model):
            body["language_code"] = language
            applied["language"] = language
        with self._client_factory() as http:
            response = http.post(
                url,
                headers={
                    "xi-api-key": settings.elevenlabs_api_key,
                    "Accept": "audio/mpeg",
                },
                json=body,
            )
        if response.status_code == 404:
            raise VoiceUnavailableError(
                "Your selected voice is temporarily unavailable.",
                details={"provider_voice_id": provider_voice_id},
            )
        if response.status_code == 422 and _is_invalid_voice(response):
            raise VoiceUnavailableError(
                "Your selected voice is temporarily unavailable.",
                details={"provider_voice_id": provider_voice_id},
            )
        if response.status_code != 200:
            raise _provider_error("synthesize", response)
        return CloneSynthesis(
            audio=response.content,
            mime=response.headers.get("content-type", "audio/mpeg"),
            provider=self.name,
            model=model,
            provider_voice_id=provider_voice_id,
            applied=applied,
        )

    def synthesize_base64(self, **kwargs) -> dict:
        """The same call in the envelope `/speech/synthesize` returns."""
        return render(self.synthesize(**kwargs))


class OpenVoiceProvider:
    """Local OpenVoice v2 cloning through a sidecar process.

    OpenVoice is the free, MIT-licensed alternative to a paid cloning API, and it
    needs no key and no card. It is also not an HTTP SaaS: MeloTTS and the tone
    converter are ~700MB of local weights that must be resident in memory. They
    live in a separate process (see `sidecar/openvoice_sidecar`) so that the
    backend's own environment and test suite stay free of torch, and so the
    sidecar can be restarted without restarting the API.

    Two behaviours differ from ElevenLabs and are deliberate:

    * **No similarity estimate.** OpenVoice does not report one, so
      `similarity_score` stays 0.0 and the existing band logic reports
      "Unknown". Inventing a number from a technical report would be exactly the
      kind of unmeasured claim the voice layer is built to avoid (Â§6).
    * **No style control.** The base speaker supplies accent and prosody, and
      there is no style dial on top of it. A requested style is reported as
      ignored rather than applied, so `applied` never claims a delivery change
      the engine did not make.
    """

    name = "openvoice"

    def __init__(
        self, client_factory: Callable[[], httpx.Client] | None = None
    ) -> None:
        self._client_factory = client_factory or (lambda: httpx.Client(timeout=30.0))

    def available(self) -> bool:
        """True only when the sidecar answers, not merely when it is configured.

        A URL in the environment says where the sidecar should be; it does not
        say it is running, so this asks it. The timeout is per-request and short
        so an absent sidecar costs seconds rather than the client's own default.

        A bare 200 is not accepted. The API serves its own `/health` on 200 too,
        so a URL that happens to point at a port the backend is already
        listening on answered every probe successfully â€” availability reported
        True, training was offered, and the failure only appeared later as an
        unrelated transport error when `/clone` reached a service that has no
        such route. The responder is asked to identify itself so a reachable
        but wrong process cannot pass as the sidecar.
        """
        try:
            with self._client_factory() as http:
                response = http.get(
                    _openvoice_url("health"),
                    timeout=get_settings().openvoice_health_timeout_s,
                )
        except httpx.HTTPError:
            return False
        if response.status_code != 200:
            return False
        try:
            payload = response.json()
        except ValueError:
            # An HTML index or any other non-JSON page served with a 200 is not
            # a sidecar, and a probe must report that rather than throw at its
            # caller.
            return False
        return _looks_like_sidecar(payload)

    def create_clone(self, request: CloneRequest) -> CloneResult:
        settings = get_settings()
        ext = validate_sample(request.sample, request.mime_type, request.duration_ms)
        files = [("sample", (f"sample.{ext}", request.sample, request.mime_type))]
        data: dict[str, str] = {"name": request.display_name}
        if request.description:
            data["description"] = request.description
        try:
            with self._client_factory() as http:
                response = http.post(
                    _openvoice_url("clone"),
                    files=files,
                    data=data,
                    timeout=settings.openvoice_synthesize_timeout_s,
                )
        except httpx.TimeoutException as exc:
            raise ServiceUnavailableError(
                "Cloning your voice timed out. On CPU this takes a few minutes; "
                "try again with a shorter sample.",
                code="clone_provider_timeout",
            ) from exc
        except httpx.HTTPError as exc:
            raise ServiceUnavailableError(
                f"Could not reach the local voice service ({exc}). Is the "
                "OpenVoice sidecar running?",
                code="clone_provider_unreachable",
            ) from exc
        if response.status_code != 200:
            raise _openvoice_error("create clone", response)
        payload = _json(response)
        voice_id = str(payload.get("voice_id") or "").strip()
        if not voice_id:
            # Without an id nothing can ever be spoken with this model, so it
            # must not be stored as a ready voice.
            raise ServiceUnavailableError(
                "The local voice service accepted the sample but returned no "
                "voice id, so there is nothing to speak with.",
                code="clone_provider_error",
            )
        return CloneResult(
            provider=self.name,
            provider_voice_id=voice_id,
            model_version=str(payload.get("model_version") or ""),
            # OpenVoice reports no similarity estimate, so this stays False and
            # the score below stays 0.0 => the "Unknown" band.
            requires_verification=False,
            similarity_score=_similarity_score(payload),
            labels={
                str(k): str(v)
                for k, v in (payload.get("labels") or {}).items()
                if isinstance(v, (str, int, float))
            },
        )

    def delete_clone(self, provider_voice_id: str) -> None:
        if not provider_voice_id:
            return
        try:
            with self._client_factory() as http:
                response = http.delete(_openvoice_url(f"voice/{provider_voice_id}"))
        except httpx.HTTPError as exc:
            raise ServiceUnavailableError(
                f"Could not reach the local voice service to delete this voice ({exc}).",
                code="clone_provider_unreachable",
            ) from exc
        # 404 means it is already gone, which is the state the caller wanted.
        if response.status_code not in (200, 204, 404):
            raise _openvoice_error("delete clone", response)

    def voice_exists(self, provider_voice_id: str) -> bool:
        """Ask the sidecar whether this voice's embedding is still on disk.

        Checked before a reply is spoken so a deleted or lost voice surfaces as
        an honest "your voice is unavailable" rather than another narrator
        quietly taking over.
        """
        if not provider_voice_id:
            return False
        try:
            with self._client_factory() as http:
                response = http.get(
                    _openvoice_url(f"voice/{provider_voice_id}"),
                    timeout=get_settings().openvoice_health_timeout_s,
                )
        except httpx.HTTPError as exc:
            raise ServiceUnavailableError(
                f"Could not confirm your voice is available ({exc}).",
                code="clone_provider_unreachable",
            ) from exc
        if response.status_code == 404:
            return False
        if response.status_code != 200:
            raise _openvoice_error("read voice", response)
        return True

    def synthesize(
        self,
        *,
        text: str,
        provider_voice_id: str,
        speed: float | None = None,
        style: str | None = None,
        language: str | None = None,
    ) -> CloneSynthesis:
        if not provider_voice_id:
            raise VoiceUnavailableError("No cloned voice was selected.")
        settings = get_settings()
        body: dict[str, object] = {
            "text": text,
            "voice_id": provider_voice_id,
            "base_speaker": settings.openvoice_base_speaker,
        }
        applied: dict[str, object] = {"base_speaker": settings.openvoice_base_speaker}
        if speed is not None:
            body["speed"] = speed
            applied["speed"] = speed
        if style:
            # Not sent, and not reported as applied.
            applied["style_ignored"] = (
                "the OpenVoice engine has no speaking-style control"
            )
        if language:
            # The sidecar's English model is the only one loaded; saying so is
            # better than accepting a language code it would ignore.
            applied["language_ignored"] = (
                "the sidecar serves English base speakers only"
            )
        try:
            with self._client_factory() as http:
                response = http.post(
                    _openvoice_url("synthesize"),
                    json=body,
                    headers={"Accept": "audio/wav"},
                    timeout=settings.openvoice_synthesize_timeout_s,
                )
        except httpx.TimeoutException as exc:
            raise ServiceUnavailableError(
                "Speaking in your voice took too long and was stopped. On CPU "
                "this takes a few minutes for a full reply.",
                code="clone_provider_timeout",
            ) from exc
        except httpx.HTTPError as exc:
            raise ServiceUnavailableError(
                f"Could not reach the local voice service ({exc}).",
                code="clone_provider_unreachable",
            ) from exc
        if response.status_code == 404:
            raise VoiceUnavailableError(
                "Your selected voice is unavailable; its embedding is no longer on disk.",
                details={"provider_voice_id": provider_voice_id},
            )
        if response.status_code == 422:
            # The sidecar refuses text with nothing pronounceable in it, rather
            # than handing an empty utterance to the model. That is the caller's
            # problem, not the voice service's, so it must not be reported as
            # "the local voice service failed" (a 503 that tells the user to go
            # and start a process that is already running).
            raise ValidationError(
                "There are no words to speak in that text.",
                details={"provider_detail": _detail_of(response)},
            )
        if response.status_code != 200:
            raise _openvoice_error("synthesize", response)
        _record_source_embedding(applied, response, settings.openvoice_base_speaker)
        return CloneSynthesis(
            audio=response.content,
            mime=response.headers.get("content-type", "audio/wav"),
            provider=self.name,
            model=f"openvoice-v2/{settings.openvoice_base_speaker}",
            provider_voice_id=provider_voice_id,
            applied=applied,
        )

    def synthesize_base(
        self,
        *,
        text: str,
        base_speaker: str | None = None,
        speed: float | None = None,
    ) -> CloneSynthesis:
        """Speak text in a base speaker, with no cloned timbre.

        This is the local fallback for the hosted engine: when Groq's Orpheus
        hits its per-day token cap (or is otherwise unreachable), the reply can
        still be spoken here in the configured accent. There is no voice
        embedding involved, so `provider_voice_id` is empty and the applied
        controls say only what was honoured.
        """
        settings = get_settings()
        speaker = base_speaker or settings.openvoice_base_speaker
        body: dict[str, object] = {
            "text": text,
            "base_speaker": speaker,
        }
        applied: dict[str, object] = {"base_speaker": speaker}
        if speed is not None:
            body["speed"] = speed
            applied["speed"] = speed
        try:
            with self._client_factory() as http:
                response = http.post(
                    _openvoice_url("synthesize"),
                    json=body,
                    headers={"Accept": "audio/wav"},
                    timeout=settings.openvoice_synthesize_timeout_s,
                )
        except httpx.TimeoutException as exc:
            raise ServiceUnavailableError(
                "The local voice engine took too long and was stopped. On CPU "
                "this takes a few minutes for a full reply.",
                code="clone_provider_timeout",
            ) from exc
        except httpx.HTTPError as exc:
            raise ServiceUnavailableError(
                f"Could not reach the local voice service ({exc}).",
                code="clone_provider_unreachable",
            ) from exc
        if response.status_code == 422:
            raise ValidationError(
                "There are no words to speak in that text.",
                details={"provider_detail": _detail_of(response)},
            )
        if response.status_code != 200:
            raise _openvoice_error("synthesize", response)
        _record_source_embedding(applied, response, speaker)
        return CloneSynthesis(
            audio=response.content,
            mime=response.headers.get("content-type", "audio/wav"),
            provider=self.name,
            model=f"openvoice-v2/{speaker}",
            provider_voice_id="",
            applied=applied,
        )


def render(clone: CloneSynthesis) -> dict:
    """Wrap cloned audio in the envelope the API already speaks.

    One helper rather than a method on the provider, so a caller holding a
    `VoiceCloneProvider` gets the same JSON shape without a downcast and without
    paying for a second synthesis call.
    """
    return {
        "audio_base64": base64.b64encode(clone.audio).decode("ascii"),
        "mime": clone.mime,
        "provider": clone.provider,
        "model": clone.model,
        "voice": clone.provider_voice_id,
        "applied": clone.applied,
    }


# Style is a 0..1 dial on the provider, not a named preset. The mapping is a
# delivery hint (how much style emphasis to add) and deliberately leaves the
# speaker identity settings above it untouched, so changing style does not change
# who is speaking (Â§14).
_STYLE_VALUE = {
    "conversational": 0.15,
    "formal": 0.25,
    "academic": 0.2,
    "calm": 0.1,
    "enthusiastic": 0.45,
}


def _model_supports_style(model: str) -> bool:
    return not any(model.startswith(prefix) for prefix in _STYLE_UNSUPPORTED)


def _model_supports_language(model: str) -> bool:
    # Only the multilingual model takes a language code; turbo would reject it.
    return "multilingual" in model


def _base_url() -> str:
    return get_settings().elevenlabs_base_url or "https://api.elevenlabs.io/v1"


def _openvoice_url(path: str) -> str:
    base = get_settings().openvoice_sidecar_url.rstrip("/")
    return f"{base}/{path.lstrip('/')}"


def _json(response: httpx.Response) -> dict:
    try:
        payload = response.json()
    except ValueError as exc:
        raise ServiceUnavailableError(
            "The cloning provider returned a response we could not read.",
            code="clone_provider_error",
        ) from exc
    return payload if isinstance(payload, dict) else {}


def _looks_like_sidecar(payload: object) -> bool:
    """Whether a `/health` body came from the sidecar.

    The sidecar and the API both answer `/health` with 200, so status alone
    cannot tell them apart â€” and the two sit on adjacent ports, making a
    mis-pointed `OPENVOICE_SIDECAR_URL` easy to create and invisible to every
    probe that only checks the status code. The sidecar is asked to name
    itself. Its own `/health` has carried `service` since this check existed;
    an older build that has not is recognised by `engine_loaded`, which only
    the sidecar's lazy-load probe reports, so upgrading the sidecar is never a
    prerequisite for being able to talk to it.
    """
    if not isinstance(payload, dict):
        return False
    marker = payload.get("service")
    if isinstance(marker, str) and marker:
        return marker == "openvoice-sidecar"
    return "engine_loaded" in payload


def _similarity_score(payload: dict) -> float:
    """Read a similarity estimate if the provider offers one.

    Absent means absent: the caller then reports an unknown similarity band
    rather than inventing a number, because Â§6 forbids claiming more than was
    actually measured.
    """
    for key in ("similarity", "similarity_score", "score"):
        value = payload.get(key)
        if isinstance(value, (int, float)) and 0.0 <= float(value) <= 1.0:
            return float(value)
    return 0.0


def _is_invalid_voice(response: httpx.Response) -> bool:
    detail = response.text.lower()
    return "voice" in detail and any(
        word in detail for word in ("invalid", "not found", "does not exist")
    )


def _provider_error(action: str, response: httpx.Response) -> ServiceUnavailableError:
    return ServiceUnavailableError(
        f"Voice cloning provider error while trying to {action} "
        f"({response.status_code}): {response.text[:200]}",
        code="clone_provider_error",
    )


def _record_source_embedding(
    applied: dict[str, object], response: httpx.Response, requested: str
) -> None:
    """Say which accent was *actually* spoken, not the one that was asked for.

    Only `en-us` and `en-india` ship with the checkpoints, so any other accent
    the UI offers falls back to en-us inside the sidecar. The sidecar says so in
    a response header; dropping that header would leave `applied["base_speaker"]`
    claiming "EN-AU" for a clip that was spoken with an American accent, which is
    exactly the kind of success the user should never be shown.

    Reported rather than rejected: an unexpected accent is not a failure, but it
    must not be silent either.
    """
    used = (response.headers.get("x-openvoice-source-embedding") or "").strip()
    if not used:
        return
    applied["source_embedding"] = used
    fallback = used.endswith("(fallback)")
    if fallback:
        applied["base_speaker_substituted"] = (
            f"{requested} has no reference embedding, so this was spoken with "
            f"{used.removesuffix(' (fallback)')}"
        )


def _detail_of(response: httpx.Response) -> str:
    """Pull the sidecar's `detail` string out of an error body, if it sent one.

    The sidecar answers failures with `{"detail": "..."}`, and that text is the
    only place the real reason appears, so it is worth surfacing instead of
    showing the caller a raw blob of JSON. Anything unparseable falls back to
    the truncated body rather than being lost.
    """
    try:
        payload = response.json()
    except ValueError:
        return response.text[:200]
    if isinstance(payload, dict) and isinstance(payload.get("detail"), str):
        return payload["detail"]
    return response.text[:200]


def _openvoice_error(action: str, response: httpx.Response) -> ServiceUnavailableError:
    """Like `_provider_error` but names the sidecar, so the message points at
    the thing the user actually has to go and start."""
    return ServiceUnavailableError(
        f"The local voice service failed while trying to {action} "
        f"({response.status_code}): {response.text[:200]}",
        code="clone_provider_error",
    )
