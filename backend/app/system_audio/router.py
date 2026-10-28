"""HTTP API for recording this computer's audio and turning it into notes."""

from __future__ import annotations

from fastapi import APIRouter, Query
from fastapi.responses import FileResponse

from app.system_audio.schemas import (
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
    )


@router.get("/status", response_model=RecordingStatus)
def status() -> dict:
    return get_manager().status()


@router.post("/stop", response_model=RecordingView)
def stop() -> dict:
    return get_manager().stop()


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
