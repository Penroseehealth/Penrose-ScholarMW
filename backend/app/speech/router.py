"""HTTP layer for speech support."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import asdict
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, Query, Response, UploadFile

from app.speech.clone_service import CONSENT_TEXT, VoiceCloneService
from app.speech.cloning import cloning_available, provider_status
from app.speech.dependencies import DbSessionDep, require_module_enabled
from app.speech.repository import VoiceModelRepository, VoiceProfileRepository
from app.speech.schemas import (
    CloneStatusView,
    CloneTrainResult,
    SpeechStatusView,
    SynthesisRequest,
    SynthesisResult,
    TranscriptionResult,
    VoiceComparisonResult,
    VoiceModelRename,
    VoiceModelUpdate,
    VoiceModelView,
    VoicePreviewResult,
    VoiceProfileCreate,
    VoiceProfileUpdate,
    VoiceProfileView,
)
from app.speech.service import SpeechService
from app.speech.voice_library import (
    VoiceLibraryService,
    effective_default_voice,
)

# Override hook so tests (and future callers) can inject a bespoke service.
# FastAPI captures the `_service` callable at decoration time, so module-level
# monkeypatching of `_service` itself would be ignored; the override is read
# dynamically at request time instead.
_service_override: Callable[[], SpeechService] | None = None
# Same hook for the clone pipeline, so tests drive training with a fake provider
# instead of uploading anyone's voice to ElevenLabs.
_clones_override: Callable[[], VoiceCloneService] | None = None


def _service() -> SpeechService:
    if _service_override is not None:
        return _service_override()
    return SpeechService()


def _clones(db: DbSessionDep) -> VoiceCloneService:
    if _clones_override is not None:
        return _clones_override()
    return VoiceCloneService(VoiceModelRepository(db))


ServiceDep = Annotated[SpeechService, Depends(_service)]


def _library(db: DbSessionDep) -> VoiceLibraryService:
    return VoiceLibraryService(VoiceProfileRepository(db))


LibraryDep = Annotated[VoiceLibraryService, Depends(_library)]

ClonesDep = Annotated[VoiceCloneService, Depends(_clones)]

router = APIRouter(
    prefix="/speech",
    tags=["speech"],
    dependencies=[Depends(require_module_enabled("speech"))],
)


@router.get("/status", response_model=SpeechStatusView)
def status(db: DbSessionDep, service: ServiceDep, clones: ClonesDep) -> dict:
    # The engine proxy stays clone-agnostic; cloning availability is grafted on
    # here so the client can enable or explain training from the one status call
    # it already makes.
    payload = service.status(
        default_voice=effective_default_voice(VoiceProfileRepository(db))
    )
    default_clone = clones.resolve_default()
    payload.update(
        clone_available=cloning_available(),
        clone_provider=provider_status()["clone_provider"],
        default_clone_voice_id=default_clone.id if default_clone else None,
    )
    return payload


@router.post("/transcribe", response_model=TranscriptionResult)
def transcribe(file: UploadFile = File(...), service: ServiceDep = None) -> dict:  # type: ignore[assignment]
    return service.transcribe(file.file.read(), file.content_type or "")


@router.post("/synthesize", response_model=SynthesisResult)
def synthesize(
    data: SynthesisRequest,
    db: DbSessionDep,
    service: ServiceDep = None,  # type: ignore[assignment]
    clones: ClonesDep = None,  # type: ignore[assignment]
) -> dict:
    # A cloned voice takes precedence, because it is the only thing the user
    # actually trained. When the engine is used instead, a request that omits
    # `voice` speaks with the library default, so selecting a voice in MY VOICES
    # reaches every existing TTS caller (voice chat, the training centre,
    # document narration) without a second engine or a second code path.
    if data.voice_id is not None:
        return clones.synthesize(
            data.voice_id,
            data.text,
            speed=data.speed,
            style=data.style,
            language=data.language,
        )
    # Nothing was chosen explicitly. If the user marked a trained voice as
    # default, it is what they expect to hear, so it reaches callers that never
    # pick a voice (the chat replies) without each one threading a voice through.
    # An explicit `voice` still wins, so picking an engine voice in the selector
    # is never overridden by a default clone.
    if data.voice is None:
        default_clone = clones.resolve_default()
        if default_clone is not None:
            return clones.synthesize(
                default_clone.id,
                data.text,
                speed=data.speed,
                style=data.style,
                language=data.language,
            )
    voice = data.voice or effective_default_voice(VoiceProfileRepository(db))
    result = service.synthesize(data.text, voice=voice, speed=data.speed)
    if data.style:
        # The engine has no speaking styles. Saying so is the point: the caller
        # learns the style was not applied instead of assuming it was.
        result.setdefault("applied", {})["style_ignored"] = (
            "the built-in engine has no speaking styles"
        )
    return result


# --- MY VOICES library -------------------------------------------------------
# One entry per real engine voice. There is no clone/train endpoint because the
# configured provider has none; the Voice Training Center remains the place
# where audio is captured and analysed.


@router.get("/voices", response_model=list[VoiceProfileView])
def list_voices(
    library: LibraryDep,
    include_archived: bool = Query(default=False),
) -> list[dict]:
    return library.list(include_archived=include_archived)


@router.post("/voices", response_model=VoiceProfileView, status_code=201)
def add_voice(payload: VoiceProfileCreate, library: LibraryDep) -> dict:
    return library.add(
        payload.voice_key,
        display_name=payload.display_name,
        accent_label=payload.accent_label,
        style_note=payload.style_note,
        language=payload.language,
        make_default=payload.make_default,
    )


@router.patch("/voices/{profile_id}", response_model=VoiceProfileView)
def update_voice(
    profile_id: int, payload: VoiceProfileUpdate, library: LibraryDep
) -> dict:
    changes = payload.model_dump(exclude_unset=True)
    return library.update(
        profile_id,
        display_name=changes.get("display_name"),
        accent_label=changes.get("accent_label"),
        style_note=changes.get("style_note"),
        language=changes.get("language"),
        is_default=changes.get("is_default"),
        is_archived=changes.get("is_archived"),
    )


@router.delete("/voices/{profile_id}", status_code=204)
def delete_voice(profile_id: int, library: LibraryDep) -> Response:
    library.delete(profile_id)
    return Response(status_code=204)


@router.post("/voices/{profile_id}/preview", response_model=VoicePreviewResult)
def preview_voice(
    profile_id: int, library: LibraryDep, service: ServiceDep = None
) -> dict:  # type: ignore[assignment]
    """Render a short sample in a library voice so MY VOICES can preview it."""
    entry = library.get(profile_id)
    return service.synthesize(_preview_text(entry), voice=entry["voice_key"])


def _preview_text(entry: dict) -> str:
    """Prefer the user's own style note so a preview sounds like their entry."""
    note = (entry.get("style_note") or "").strip()
    if note:
        return note
    name = (entry.get("display_name") or "this voice").strip()
    return f"{name}. This is how I will read your research aloud."


# --- cloned voices -----------------------------------------------------------
# The training pipeline: a recording becomes a speaker model the engine can
# synthesize with, and MY VOICES gains a row the user can select. Kept under the
# same `/speech` prefix and module gate as everything else so there is one voice
# system, not two.


@router.get("/clone/status", response_model=CloneStatusView)
def clone_status(clones: ClonesDep) -> dict:
    """Whether training is offered, the consent wording, and the current default.

    The training centre asks this before it renders anything, so it also carries
    the default clone id: with no explicit choice a new session should speak in
    the voice the user last made default, not fall back to an engine narrator.
    """
    default_clone = clones.resolve_default()
    return {
        **provider_status(),
        "consent_text": CONSENT_TEXT,
        "default_clone_voice_id": default_clone.id if default_clone else None,
    }


@router.get("/clones", response_model=list[VoiceModelView])
def list_clones(
    clones: ClonesDep,
    include_archived: bool = Query(default=False),
) -> list[dict]:
    return clones.list(include_archived=include_archived)


@router.post("/clones", response_model=CloneTrainResult, status_code=201)
def train_clone(
    clones: ClonesDep,
    file: UploadFile = File(...),
    display_name: str = Form(..., min_length=1, max_length=120),
    consent: bool = Form(...),
    duration_ms: int = Form(default=0, ge=0),
    language: str = Form(default="", max_length=40),
    accent_label: str = Form(default="", max_length=80),
    make_default: bool = Form(default=False),
) -> dict:
    """Train a new voice from a recording.

    The sample is sent with its real content type and a caller-declared
    duration. The duration is only advisory: a sample whose container cannot be
    decoded locally is still measured by `quality.py`'s own analysis, and the
    declared value is used solely to refuse a clip that is obviously too short
    before anything is uploaded.
    """
    outcome = clones.train(
        display_name=display_name,
        sample=file.file.read(),
        mime_type=file.content_type or "",
        consent=consent,
        duration_ms=duration_ms,
        language=language,
        accent_label=accent_label,
        make_default=make_default,
    )
    return asdict(outcome)


@router.get("/clones/{voice_id}", response_model=VoiceModelView)
def get_clone(voice_id: int, clones: ClonesDep) -> dict:
    return clones.get(voice_id)


@router.patch("/clones/{voice_id}", response_model=VoiceModelView)
def update_clone(voice_id: int, payload: VoiceModelRename, clones: ClonesDep) -> dict:
    """Rename a voice or correct the labels the user gave it."""
    return clones.update(
        voice_id,
        display_name=payload.display_name,
        language=payload.language,
        accent_label=payload.accent_label,
    )


@router.patch("/clones/{voice_id}/selection", response_model=VoiceModelView)
def select_clone(voice_id: int, payload: VoiceModelUpdate, clones: ClonesDep) -> dict:
    """Use this voice for Penrose, or archive it out of the way."""
    if payload.is_archived is not None:
        clones.set_archived(voice_id, payload.is_archived)
    if payload.is_default:
        return clones.set_default(voice_id)
    return clones.get(voice_id)


@router.post("/clones/{voice_id}/retrain", response_model=CloneTrainResult)
def retrain_clone(
    voice_id: int,
    clones: ClonesDep,
    file: UploadFile = File(...),
    consent: bool = Form(...),
    duration_ms: int = Form(default=0, ge=0),
    language: str = Form(default="", max_length=40),
    accent_label: str = Form(default="", max_length=80),
) -> dict:
    """Train a new version, keeping the one that was working (Â§17)."""
    return asdict(
        clones.retrain(
            voice_id,
            sample=file.file.read(),
            mime_type=file.content_type or "",
            consent=consent,
            duration_ms=duration_ms,
            language=language,
            accent_label=accent_label,
        )
    )


@router.post(
    "/clones/{voice_id}/versions/{version_id}/promote", response_model=VoiceModelView
)
def promote_clone_version(voice_id: int, version_id: int, clones: ClonesDep) -> dict:
    return clones.promote_version(voice_id, version_id)


@router.post("/clones/{voice_id}/preview", response_model=SynthesisResult)
def preview_clone(voice_id: int, clones: ClonesDep) -> dict:
    """Â§9: synthesize a fresh sentence, proving the clone is actually wired up."""
    return clones.preview(voice_id)


@router.post("/clones/{voice_id}/test", response_model=VoiceComparisonResult)
def test_clone(voice_id: int, clones: ClonesDep) -> dict:
    """Â§18: the same paragraph in the cloned voice and an engine voice."""
    return clones.test_voice(voice_id)


@router.delete("/clones/{voice_id}", status_code=204)
def delete_clone(voice_id: int, clones: ClonesDep) -> Response:
    """Remove the voice and every provider-side model trained from it."""
    clones.delete(voice_id)
    return Response(status_code=204)
