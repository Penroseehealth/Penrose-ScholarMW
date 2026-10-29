"""HTTP API for recording this computer's audio and turning it into notes."""

from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, Query
from fastapi.responses import FileResponse

from app.system_audio.schemas import (
    DeliverRequest,
    DeliverResult,
    MicrophoneToggleRequest,
    ProcessRecordingRequest,
    RecordingStatus,
    RecordingView,
    StartRecordingRequest,
    StartRecordingResult,
    SummarizeRecordingRequest,
    TranscribeRecordingRequest,
)
from app.system_audio.service import get_manager

router = APIRouter(prefix="/system-audio", tags=["system-audio"])


@router.post("/start", response_model=StartRecordingResult)
def start(data: StartRecordingRequest | None = None) -> dict:
    payload = data or StartRecordingRequest()
    return get_manager().start(
        label=payload.label,
        sample_rate=payload.sample_rate,
        channels=payload.channels,
        source=payload.source,
        segment_seconds=payload.segment_seconds,
    )


@router.get("/status", response_model=RecordingStatus)
def status() -> dict:
    return get_manager().status()


@router.post("/stop", response_model=RecordingView)
def stop() -> dict:
    return get_manager().stop()


@router.get("/default-folder")
def default_folder() -> dict:
    """A sensible destination for saved recordings on this machine."""
    return {"folder": str(Path.home() / "Penrose Recordings")}


@router.post("/microphone", response_model=RecordingStatus)
def microphone(data: MicrophoneToggleRequest) -> dict:
    """Turn the microphone on or off without interrupting system recording."""
    return get_manager().set_microphone(data.enabled)


@router.get("/recordings", response_model=list[RecordingView])
def recordings() -> list[dict]:
    return get_manager().list_recordings()


@router.get("/recordings/{recording_id}", response_model=RecordingView)
def recording(recording_id: str) -> dict:
    return get_manager().get(recording_id)


@router.get("/recordings/{recording_id}/audio")
def audio(recording_id: str, format: str = Query(default="wav", pattern="^(wav|mp3)$")):
    path = get_manager().path_for(recording_id, format)
    media = "audio/wav" if format == "wav" else "audio/mpeg"
    label = get_manager().get(recording_id).get("label") or recording_id
    safe = "".join(ch if ch.isalnum() or ch in " -_" else "_" for ch in label).strip()
    return FileResponse(
        path, media_type=media, filename=f"{safe or recording_id}.{format}"
    )


@router.get("/recordings/{recording_id}/segments/{index}/audio")
def segment_audio(
    recording_id: str,
    index: int,
    format: str = Query(default="mp3", pattern="^(wav|mp3)$"),
) -> FileResponse:
    manager = get_manager()
    path = manager.path_for_segment(recording_id, index, format)
    media = "audio/wav" if format == "wav" else "audio/mpeg"
    return FileResponse(path, media_type=media, filename=path.name)


@router.post("/recordings/{recording_id}/deliver", response_model=DeliverResult)
def deliver(recording_id: str, data: DeliverRequest) -> dict:
    return get_manager().deliver(recording_id, **data.model_dump())


@router.post("/recordings/{recording_id}/transcribe", response_model=RecordingView)
def transcribe(
    recording_id: str, data: TranscribeRecordingRequest | None = None
) -> dict:
    payload = data or TranscribeRecordingRequest()
    return get_manager().transcribe(recording_id, language=payload.language)


@router.post("/recordings/{recording_id}/summarize", response_model=RecordingView)
async def summarize(
    recording_id: str, data: SummarizeRecordingRequest | None = None
) -> dict:
    payload = data or SummarizeRecordingRequest()
    return await get_manager().summarize(
        recording_id, style=payload.style, language=payload.language
    )


@router.post("/recordings/{recording_id}/process", response_model=RecordingView)
async def process(
    recording_id: str, data: ProcessRecordingRequest | None = None
) -> dict:
    payload = data or ProcessRecordingRequest()
    get_manager().transcribe(recording_id, language=payload.language)
    return await get_manager().summarize(
        recording_id, style=payload.style, language=payload.language
    )


@router.delete("/recordings/{recording_id}")
def delete(recording_id: str) -> dict:
    get_manager().delete(recording_id)
    return {"deleted": True, "recording_id": recording_id}
