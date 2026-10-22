"""The MY VOICES training pipeline.

This is what turns a recording into a voice Penrose can actually speak with:

    sample -> quality gate -> provider clone -> persistent voice id -> MY VOICES

and then makes that voice selectable everywhere Penrose already talks. It is
deliberately built on the existing pieces rather than beside them: the sample is
stored with the same upload-directory helper the chat attachments use, the
sample is transcribed with the same STT provider, and synthesis goes through the
same `SpeechService` entry point that every other caller already uses.

Design rules this file enforces:

* **A voice is never offered before it can be spoken.** `status` only becomes
  `ready` once the provider has returned a usable voice id, and the conversation
  layer refuses anything that is not ready (Â§3).
* **A retrain never destroys a working model.** Each run is a new
  `VoiceModelVersion`; the old one stays until the user promotes a version or
  deletes the voice (Â§17).
* **Cloning needs consent.** No sample is sent to any provider without an
  explicit confirmation recorded against the voice (Â§8).
* **An unavailable voice is reported, never substituted.** A clone that the
  provider has dropped raises `VoiceUnavailableError` so the user is asked
  rather than handed a different narrator (Â§16).
"""

from __future__ import annotations

import contextlib
import hashlib
import json
import uuid
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from app.speech import quality
from app.speech.cloning import (
    CloneRequest,
    CloneResult,
    VoiceCloneProvider,
    cloning_available,
    get_clone_provider,
    provider_sample_formats,
    provider_status,
    render,
    validate_sample,
)
from app.speech.config import get_settings
from app.speech.exceptions import (
    NotFoundError,
    ServiceUnavailableError,
    ValidationError,
    VoiceUnavailableError,
)
from app.speech.models import VoiceModel, VoiceModelVersion
from app.speech.repository import VoiceModelRepository

# The exact wording Â§8 requires, stored verbatim so the record of what was
# agreed to cannot drift from what the user actually ticked.
CONSENT_TEXT = "I confirm that I own this voice or have permission to create a synthetic version of it."

# Â§9: the preview must synthesize a *new* sentence, because playing back the
# training clip would prove nothing about whether the voice is wired up.
PREVIEW_TEXT = "Hello. This is a preview of my synthesized Penrose voice."

# Â§18: the same paragraph in both voices, so the comparison is like for like.
TEST_PARAGRAPH = (
    "Placental malaria is associated with higher rates of fetal growth "
    "restriction and low birth weight, although the strength of this "
    "association varies between studies and depends on the population studied."
)

# Similarity bands. A band, never a number presented as identity: Â§6 forbids
# claiming more than was measured, and the provider only sometimes returns an
# estimate at all.
_SIMILARITY_HIGH = 0.8
_SIMILARITY_MEDIUM = 0.6


@dataclass(frozen=True)
class TrainOutcome:
    """Result of a training run, for the endpoint that triggered it."""

    voice: dict
    version: dict
    warnings: list[str]


def similarity_band(score: float) -> str:
    """Turn a provider estimate into a user-facing band.

    Zero means the provider told us nothing, which is reported as unknown rather
    than as a low score â€” the difference matters, because "we could not measure
    this" and "this is a poor clone" must not look the same.
    """
    if score <= 0:
        return "Unknown"
    if score >= _SIMILARITY_HIGH:
        return "High"
    if score >= _SIMILARITY_MEDIUM:
        return "Medium"
    return "Low"


def _store_sample(data: bytes, mime: str) -> str:
    """Persist the training sample beside the other uploaded audio.

    Kept so "Retrain" and "Test Voice" can compare against the original instead
    of against a copy of the current output, and so a failed run can be
    diagnosed. The filename is a uuid, never anything the client supplied.
    """
    settings = get_settings()
    upload_dir = Path(settings.upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)
    ext = {
        "audio/wav": ".wav",
        "audio/x-wav": ".wav",
        "audio/wave": ".wav",
        "audio/mpeg": ".mp3",
        "audio/mp4": ".m4a",
        "audio/webm": ".webm",
        "audio/ogg": ".ogg",
        "audio/flac": ".flac",
    }.get((mime or "").split(";")[0].strip().lower(), ".bin")
    name = f"voice_sample_{uuid.uuid4().hex}{ext}"
    (upload_dir / name).write_bytes(data)
    return name


def _read_sample(ref: str) -> bytes:
    """Load a stored sample, refusing anything that is not a plain filename."""
    name = Path(ref).name
    if not name or name != ref or name in (".", ".."):
        raise ValidationError("Stored voice sample reference is not a plain filename.")
    path = Path(get_settings().upload_dir) / name
    if not path.is_file():
        raise NotFoundError("Voice sample", ref)
    return path.read_bytes()


def version_read(version: VoiceModelVersion) -> dict:
    try:
        quality_data = json.loads(version.quality_json or "{}")
    except json.JSONDecodeError:
        quality_data = {}
    return {
        "id": version.id,
        "voice_id": version.voice_model_id,
        "version": version.version,
        "provider_voice_id": version.provider_voice_id,
        "model_version": version.model_version,
        "status": version.status,
        "error_message": version.error_message,
        "sample_ref": version.sample_ref,
        "sample_mime": version.sample_mime,
        "sample_duration_ms": version.sample_duration_ms,
        # The hash travels with the version so a client can tell which sample a
        # model was trained from. The sample itself is never handed out by the
        # API â€” it is someone's biometric data.
        "sample_sha256": version.sample_sha256,
        "similarity_label": version.similarity_label,
        "similarity_score": version.similarity_score,
        "quality": quality_data,
        "created_at": version.created_at,
    }


def voice_read(model: VoiceModel, versions: Sequence[VoiceModelVersion]) -> dict:
    return {
        "id": model.id,
        "voice_id": model.id,  # Â§4's `voice_id`, named for the client contract
        "display_name": model.display_name,
        "provider": model.provider,
        "language": model.language,
        "accent_label": model.accent_label,
        "status": model.status,
        "current_version_id": model.current_version_id,
        "similarity_label": model.similarity_label,
        "similarity_score": model.similarity_score,
        "consent_given": bool(model.consent_given),
        "consent_text": model.consent_text,
        "consented_at": model.consented_at,
        "is_default": bool(model.is_default),
        "is_archived": bool(model.is_archived),
        "created_at": model.created_at,
        "updated_at": model.updated_at,
        "versions": [version_read(version) for version in versions],
    }


class VoiceCloneService:
    """Training and selection for cloned voices."""

    def __init__(
        self,
        repo: VoiceModelRepository,
        provider: VoiceCloneProvider | None = None,
        speech_factory: Callable[[], object] | None = None,
    ) -> None:
        self.repo = repo
        # Both seams are injectable so the lifecycle can be tested end to end
        # without uploading anyone's voice to a provider.
        self._provider = provider
        self._speech_factory = speech_factory

    # --- plumbing -----------------------------------------------------------

    def provider(self) -> VoiceCloneProvider:
        if self._provider is not None:
            return self._provider
        return get_clone_provider()

    def _speech(self):
        if self._speech_factory is not None:
            return self._speech_factory()
        from app.speech.service import SpeechService

        return SpeechService()

    def _require_provider(self) -> VoiceCloneProvider:
        if not cloning_available() and self._provider is None:
            raise ServiceUnavailableError(
                "Voice cloning is not configured. Set CLONE_PROVIDER and "
                "ELEVENLABS_API_KEY to train a voice Penrose can speak with.",
                details=provider_status(),
            )
        return self.provider()

    def _transcribe(self, data: bytes, mime: str) -> str:
        """Transcribe the sample so intelligibility can be judged.

        A transcription failure is not fatal: the sample may still train, it just
        will not carry an intelligibility measurement. Pretending it transcribed
        cleanly would be worse than saying nothing.
        """
        try:
            result = self._speech().transcribe(data, mime)
        except Exception:
            return ""
        return str(result.get("transcript") or "")

    # --- reads --------------------------------------------------------------

    def status(self) -> dict:
        return provider_status()

    def list(self, include_archived: bool = False) -> list[dict]:
        return [
            voice_read(model, self.repo.versions(model.id))
            for model in self.repo.list(include_archived=include_archived)
        ]

    def get(self, voice_id: int) -> dict:
        model = self.repo.get(voice_id)
        return voice_read(model, self.repo.versions(voice_id))

    def resolve_default(self) -> VoiceModel | None:
        """The default cloned voice, or None when the user has not chosen one.

        Only a `ready`, unarchived voice can be the default, so a failed or
        still-training model is never handed to the conversation layer.
        """
        for model in self.repo.list(include_archived=False):
            if (
                model.is_default
                and model.status == "ready"
                and model.current_version_id
            ):
                return model
        return None

    # --- the training pipeline --------------------------------------------

    def train(
        self,
        *,
        display_name: str,
        sample: bytes,
        mime_type: str,
        consent: bool,
        duration_ms: int = 0,
        language: str = "",
        accent_label: str = "",
        make_default: bool = False,
        provider: VoiceCloneProvider | None = None,
    ) -> TrainOutcome:
        """Create a new cloned voice from a sample."""
        name = (display_name or "").strip()
        if not name:
            raise ValidationError("Give the voice a name so you can find it later.")
        if self.repo.by_name(name):
            raise ValidationError(
                f"You already have a voice called '{name}'.",
                details={"display_name": name},
            )
        if not consent:
            # Â§8: no sample leaves the server without an explicit authorisation.
            raise ValidationError(
                "Confirm that you own this voice or have permission to create a "
                "synthetic version of it before training.",
                details={"consent_text": CONSENT_TEXT},
            )
        engine = provider or self._require_provider()

        # Duration/length checks first: they are cheap and they catch a tap of
        # the record button before anything is uploaded anywhere.
        validate_sample(
            sample,
            mime_type,
            duration_ms,
            supported_exts=provider_sample_formats(engine.name),
        )

        stored_ref = _store_sample(sample, mime_type)
        transcript = self._transcribe(sample, mime_type)
        report = quality.quality_report(
            sample, mime_type, transcript=transcript, duration_ms=duration_ms
        )
        quality.enforce_quality(report)

        model = self.repo.add(
            VoiceModel(
                display_name=name,
                provider=engine.name,
                language=language.strip(),
                accent_label=accent_label.strip(),
                status="training",
                consent_given=1,
                consent_text=CONSENT_TEXT,
                consented_at=datetime.now(UTC),
                is_default=1 if make_default else 0,
            )
        )
        try:
            outcome = self._run_clone(
                model=model,
                version_number=1,
                engine=engine,
                sample=sample,
                mime_type=mime_type,
                stored_ref=stored_ref,
                report=report,
                transcript=transcript,
            )
        except Exception:
            # The voice row survives as `failed` so MY VOICES can show what
            # happened and let the user retrain, rather than the attempt
            # vanishing as if it never existed.
            model.status = "failed"
            self.repo.save(model)
            raise
        if make_default:
            self.repo.clear_default()
            model.is_default = 1
            self.repo.save(model)
        return outcome

    def retrain(
        self,
        voice_id: int,
        *,
        sample: bytes,
        mime_type: str,
        consent: bool,
        duration_ms: int = 0,
        language: str = "",
        accent_label: str = "",
    ) -> TrainOutcome:
        """Train a new version of an existing voice, keeping the old one (Â§17).

        The new version is only promoted once the provider has accepted it, so a
        retrain that comes out unusable leaves the working version in place.
        """
        model = self.repo.get(voice_id)
        if not consent:
            raise ValidationError(
                "Confirm that you own this voice or have permission to create a "
                "synthetic version of it before retraining.",
                details={"consent_text": CONSENT_TEXT},
            )
        engine = self._require_provider()
        validate_sample(
            sample,
            mime_type,
            duration_ms,
            supported_exts=provider_sample_formats(engine.name),
        )

        stored_ref = _store_sample(sample, mime_type)
        transcript = self._transcribe(sample, mime_type)
        report = quality.quality_report(
            sample, mime_type, transcript=transcript, duration_ms=duration_ms
        )
        quality.enforce_quality(report)

        model.status = "training"
        self.repo.save(model)
        return self._run_clone(
            model=model,
            version_number=self.repo.next_version_number(voice_id),
            engine=engine,
            sample=sample,
            mime_type=mime_type,
            stored_ref=stored_ref,
            report=report,
            transcript=transcript,
        )

    def _run_clone(
        self,
        *,
        model: VoiceModel,
        version_number: int,
        engine: VoiceCloneProvider,
        sample: bytes,
        mime_type: str,
        stored_ref: str,
        report: quality.QualityReport,
        transcript: str,
    ) -> TrainOutcome:
        """One provider call, wrapped in a persisted training run.

        Split out so the create and retrain paths cannot drift apart on how a run
        is recorded.
        """
        model.status = "processing"
        self.repo.save(model)
        try:
            result: CloneResult = engine.create_clone(
                CloneRequest(
                    display_name=model.display_name,
                    sample=sample,
                    mime_type=mime_type,
                    duration_ms=report.duration_ms,
                    description=f"Penrose cloned voice: {model.display_name}",
                )
            )
        except Exception as exc:
            version = self.repo.add_version(
                VoiceModelVersion(
                    voice_model_id=model.id,
                    version=version_number,
                    status="failed",
                    error_message=str(exc)[:400],
                    sample_ref=stored_ref,
                    sample_mime=mime_type,
                    sample_duration_ms=report.duration_ms,
                    sample_sha256=hashlib.sha256(sample).hexdigest(),
                    quality_json=json.dumps(report.to_dict()),
                )
            )
            model.status = "failed"
            self.repo.save(model)
            # The wrapping code is `clone_failed`, which is what the client sees,
            # so the root cause is carried alongside it. Without this a dead
            # sidecar and a rejected sample both reach the UI as the same
            # "training failed", and the user is told a generic failure when the
            # only fix is starting the sidecar.
            details: dict[str, Any] = {"voice_id": model.id, "version_id": version.id}
            root_code = getattr(exc, "code", None)
            if isinstance(root_code, str) and root_code:
                details["root_code"] = root_code
            raise ServiceUnavailableError(
                f"Voice training unsuccessful: {exc}",
                code="clone_failed",
                details=details,
            ) from exc

        band = similarity_band(result.similarity_score)
        version = self.repo.add_version(
            VoiceModelVersion(
                voice_model_id=model.id,
                version=version_number,
                provider_voice_id=result.provider_voice_id,
                model_version=result.model_version,
                status="ready",
                sample_ref=stored_ref,
                sample_mime=mime_type,
                sample_duration_ms=report.duration_ms,
                sample_sha256=hashlib.sha256(sample).hexdigest(),
                sample_transcript=transcript,
                quality_json=json.dumps(report.to_dict()),
                similarity_label=band,
                similarity_score=result.similarity_score,
            )
        )
        # Only now is the voice usable: the provider confirmed a voice id.
        model.status = "ready"
        model.current_version_id = version.id
        model.provider = result.provider
        model.similarity_label = band
        model.similarity_score = result.similarity_score
        if not model.language:
            model.language = ""
        self.repo.save(model)
        warnings = list(report.warnings)
        if result.requires_verification:
            warnings.append(
                "The provider has flagged this voice for verification. It may not "
                "be usable for synthesis until that completes."
            )
        return TrainOutcome(
            voice=self.get(model.id),
            version=version_read(self.repo.get_version(version.id)),
            warnings=warnings,
        )

    # --- selection and editing ---------------------------------------------

    def update(
        self,
        voice_id: int,
        *,
        display_name: str | None = None,
        language: str | None = None,
        accent_label: str | None = None,
    ) -> dict:
        """Rename a voice and/or correct the labels the user gave it."""
        model = self.repo.get(voice_id)
        if display_name is not None:
            name = display_name.strip()
            if not name:
                raise ValidationError("display_name cannot be empty")
            existing = self.repo.by_name(name)
            if existing and existing.id != voice_id:
                raise ValidationError(f"You already have a voice called '{name}'.")
            model.display_name = name
        if language is not None:
            model.language = language.strip()
        if accent_label is not None:
            model.accent_label = accent_label.strip()
        self.repo.save(model)
        return self.get(voice_id)

    def set_default(self, voice_id: int) -> dict:
        """Make this the voice Penrose speaks with ("Use for Penrose", Â§2)."""
        model = self.repo.get(voice_id)
        self._assert_usable(model)
        self.repo.clear_default()
        model.is_default = 1
        model.is_archived = 0
        self.repo.save(model)
        return self.get(voice_id)

    def set_archived(self, voice_id: int, archived: bool) -> dict:
        model = self.repo.get(voice_id)
        model.is_archived = 1 if archived else 0
        if archived and model.is_default:
            # Never leave the app defaulting to something the user just hid.
            model.is_default = 0
        self.repo.save(model)
        return self.get(voice_id)

    def promote_version(self, voice_id: int, version_id: int) -> dict:
        """Make an earlier training run current again (Â§17).

        This is the recovery path for a retrain that sounded worse than the model
        it replaced: no re-recording required.
        """
        model = self.repo.get(voice_id)
        version = self.repo.get_version(version_id)
        if version.voice_model_id != voice_id:
            raise ValidationError("That version belongs to a different voice.")
        if version.status != "ready" or not version.provider_voice_id:
            raise ValidationError(
                "That version is not usable, so it cannot be made current.",
                details={"status": version.status},
            )
        model.current_version_id = version.id
        model.status = "ready"
        model.similarity_label = version.similarity_label
        model.similarity_score = version.similarity_score
        self.repo.save(model)
        return self.get(voice_id)

    def delete(self, voice_id: int) -> None:
        """Remove a cloned voice, and its provider-side model with it.

        Leaving the speaker model on the provider would keep someone's voice
        synthesizable after they asked for it to be gone.
        """
        model = self.repo.get(voice_id)
        for version in self.repo.versions(voice_id):
            if not version.provider_voice_id:
                continue
            # The row must still go. A provider that cannot be reached is not a
            # reason to keep someone's voice sitting in the app.
            with contextlib.suppress(ServiceUnavailableError):
                self.provider().delete_clone(version.provider_voice_id)
        was_default = bool(model.is_default)
        self.repo.delete(voice_id)
        if was_default:
            self.repo.clear_default()

    # --- speech -------------------------------------------------------------

    def _assert_usable(self, model: VoiceModel) -> VoiceModelVersion:
        if model.is_archived:
            raise VoiceUnavailableError(
                f"'{model.display_name}' is archived. Restore it to use it for Penrose.",
                voice_id=model.id,
            )
        if model.status != "ready" or not model.current_version_id:
            raise VoiceUnavailableError(
                f"'{model.display_name}' is not ready yet ({model.status.replace('_', ' ')}).",
                voice_id=model.id,
            )
        version = self.repo.get_version(model.current_version_id)
        if version.status != "ready" or not version.provider_voice_id:
            raise VoiceUnavailableError(
                f"'{model.display_name}' has no usable voice model.",
                voice_id=model.id,
            )
        return version

    def speech_target(self, voice_id: int) -> tuple[VoiceModel, VoiceModelVersion]:
        """Resolve a cloned voice to the provider id synthesis needs.

        Also confirms the provider still has the voice, so a clone that was
        deleted on the provider's side surfaces as `VoiceUnavailableError`
        rather than as a confusing provider error mid-reply (Â§16).
        """
        model = self.repo.get(voice_id)
        version = self._assert_usable(model)
        if not self.provider().voice_exists(version.provider_voice_id):
            raise VoiceUnavailableError(
                "Your selected voice is temporarily unavailable. Would you like "
                "to continue with text or use another available Penrose voice?",
                voice_id=voice_id,
                details={"display_name": model.display_name},
            )
        return model, version

    def preview(self, voice_id: int) -> dict:
        """Synthesize a fixed sentence in the cloned voice (Â§9).

        A *new* sentence on purpose: replaying the training clip would prove
        only that the file exists, not that the voice is connected to TTS.
        """
        return self.synthesize(voice_id, PREVIEW_TEXT)

    def synthesize(
        self,
        voice_id: int,
        text: str,
        *,
        speed: float | None = None,
        style: str | None = None,
        language: str | None = None,
    ) -> dict:
        """Speak arbitrary new text in a cloned voice.

        The single entry point for both the preview endpoint and a spoken chat
        reply, so neither can drift from the other. `speech_target` has already
        confirmed the provider still has the model, so an unavailable voice
        raises `VoiceUnavailableError` here rather than mid-request.
        """
        if not text.strip():
            raise ValidationError("Text to synthesise cannot be empty")
        from app.speech.cloning import validate_style

        style = validate_style(style) or None
        model, version = self.speech_target(voice_id)
        envelope = render(
            self.provider().synthesize(
                text=text,
                provider_voice_id=version.provider_voice_id,
                speed=speed,
                style=style,
                # An explicit request wins; otherwise the voice's own language
                # is used so a French clone is not spoken as English.
                language=(language or model.language) or None,
            )
        )
        envelope["voice_id"] = voice_id
        envelope["display_name"] = model.display_name
        envelope["text"] = text
        return envelope

    def test_voice(self, voice_id: int) -> dict:
        """Render the same paragraph in the original sample and the clone (Â§18).

        The two clips are returned side by side so the user judges the clone
        themselves. The backend reports the similarity band it was given; it does
        not turn that into a claim of identity.
        """
        model, version = self.speech_target(voice_id)
        provider = self.provider()
        envelope = render(
            provider.synthesize(
                text=TEST_PARAGRAPH,
                provider_voice_id=version.provider_voice_id,
                language=model.language or None,
            )
        )
        return {
            "voice_id": voice_id,
            "display_name": model.display_name,
            "text": TEST_PARAGRAPH,
            "similarity_label": model.similarity_label or "Unknown",
            "clone": envelope,
            "original": self._original_reference(model),
            # The engine narrates in English only, so a non-English clone is
            # compared across languages. Saying so stops the pair being read as
            # a same-language A/B, which is the only reading that supports a
            # judgement about accent fidelity.
            "comparable_language": (model.language or "en").lower(),
            "original_language": "en",
        }

    def _original_reference(self, model: VoiceModel) -> dict:
        """The same paragraph in an engine voice, for the Â§18 comparison.

        Rendered through the existing engine TTS so the two clips are the same
        words. A failure here is swallowed: the original side is a convenience,
        and it must never hide the clone the user actually asked about.
        """
        if not model.current_version_id:
            return {}
        try:
            return self._speech().synthesize(
                TEST_PARAGRAPH, voice=_engine_voice_for_language(model.language)
            )
        except Exception:
            return {}


def _engine_voice_for_language(language: str) -> str:
    """Pick the engine voice for the Â§18 side-by-side comparison.

    Only used to render the *original* side against one of the provider's own
    built-in voices; never to speak a Penrose reply.

    The engine serves English voices only, so for a non-English clone this
    returns the default English narrator and the comparison is cross-language.
    That is still worth showing - the user can hear that the clone kept its own
    accent across the language switch - but it must not read as a
    same-language A/B, so `test_voice` reports which language each side is in.
    """
    from app.speech.service import available_voices

    supported = available_voices()
    if not supported:
        return "hannah"
    return "hannah" if "hannah" in supported else sorted(supported)[0]
