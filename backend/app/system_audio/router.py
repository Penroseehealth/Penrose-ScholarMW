"""HTTP API for recording this computer's audio and turning it into notes."""

from __future__ import annotations

import re
from pathlib import Path

from fastapi import APIRouter, File, Form, Query, Request, UploadFile
from fastapi.responses import FileResponse, Response

from app.system_audio.schemas import (
    DeliverRequest,
    DeliverResult,
    MicrophoneToggleRequest,
    ProcessRecordingRequest,
    RecordingStatus,
    RecordingView,
    RenameRecordingRequest,
    StartRecordingRequest,
    StartRecordingResult,
    SummarizeRecordingRequest,
    TranscribeRecordingRequest,
    TranslateRecordingRequest,
)
from app.system_audio.service import get_manager

router = APIRouter(prefix="/system-audio", tags=["system-audio"])


def _safe_filename(label: str | None, fallback: str) -> str:
    safe = "".join(ch if ch.isalnum() or ch in " -_" else "_" for ch in (label or ""))
    return safe.strip() or fallback


def _media_response(
    request: Request | None,
    path: Path,
    media_type: str,
    *,
    download_name: str | None = None,
) -> Response:
    """Serve a stored file with byte-range support.

    Video needs range requests for seeking; Starlette 0.38's FileResponse does
    not implement them, so a 206 partial response is built here. Text stays
    streaming-friendly because only the requested window is read.
    """
    size = path.stat().st_size
    headers = {"Accept-Ranges": "bytes", "Cache-Control": "private, max-age=0"}
    if download_name:
        quoted = download_name.replace('"', "")
        headers["Content-Disposition"] = f'attachment; filename="{quoted}"'
    raw_range = (request.headers.get("range") if request is not None else "") or ""
    match = re.fullmatch(r"bytes=(\d*)-(\d*)", raw_range.strip())
    if match and size > 0:
        start_text, end_text = match.groups()
        if start_text:
            start = int(start_text)
            end = int(end_text) if end_text else size - 1
        else:
            # Suffix range: the last N bytes.
            length = int(end_text or 0)
            start = max(size - length, 0)
            end = size - 1
        end = min(end, size - 1)
        if start <= end:
            length = end - start + 1
            with path.open("rb") as handle:
                handle.seek(start)
                chunk = handle.read(length)
            return Response(
                chunk,
                status_code=206,
                media_type=media_type,
                headers={
                    **headers,
                    "Content-Range": f"bytes {start}-{end}/{size}",
                    "Content-Length": str(len(chunk)),
                },
            )
    return FileResponse(path, media_type=media_type, headers=headers)


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


@router.post("/virtual-recordings", response_model=RecordingView)
async def upload_virtual_recording(
    file: UploadFile = File(...),
    label: str = Form(default=""),
    duration_seconds: float = Form(default=0.0),
    mime_type: str = Form(default=""),
    media_type: str = Form(default="audio"),
    sources: str = Form(default=""),
    started_at: str = Form(default=""),
    audio_file: UploadFile | None = File(default=None),
) -> dict:
    """Store a finished browser capture in the shared recordings library."""
    data = await file.read()
    reported = mime_type or file.content_type or ""
    speech_data = await audio_file.read() if audio_file is not None else None
    speech_mime = audio_file.content_type if audio_file is not None else None
    parsed_sources = [part.strip() for part in sources.split(",") if part.strip()]
    return get_manager().save_virtual(
        data=data,
        label=label or None,
        duration_seconds=duration_seconds,
        mime_type=reported,
        media_type=media_type,
        sources=parsed_sources,
        started_at=started_at or None,
        speech_data=speech_data or None,
        speech_mime=speech_mime,
    )


@router.get("/recordings/{recording_id}/media")
def media(
    recording_id: str,
    request: Request,
    download: bool = Query(default=False),
) -> Response:
    """Stream the real stored media for any recording (audio or video)."""
    manager = get_manager()
    path, media_type = manager.path_for_media(recording_id)
    meta = manager.get(recording_id)
    extension = meta.get("format") or path.suffix.lstrip(".") or "bin"
    name = _safe_filename(meta.get("label"), recording_id)
    download_name = f"{name}.{extension}" if download else None
    return _media_response(request, path, media_type, download_name=download_name)


@router.get("/recordings/{recording_id}/audio")
def audio(recording_id: str, format: str = Query(default="wav", pattern="^(wav|mp3)$")):
    manager = get_manager()
    meta = manager.get(recording_id)
    if meta.get("kind") == "virtual":
        path, media = manager.path_for_media(recording_id)
        return _media_response(None, path, media)
    path = manager.path_for(recording_id, format)
    media = "audio/wav" if format == "wav" else "audio/mpeg"
    label = manager.get(recording_id).get("label") or recording_id
    safe = "".join(ch if ch.isalnum() or ch in " -_" else "_" for ch in label).strip()
    return FileResponse(
        path, media_type=media, filename=f"{safe or recording_id}.{format}"
    )


@router.patch("/recordings/{recording_id}", response_model=RecordingView)
def rename(recording_id: str, data: RenameRecordingRequest) -> dict:
    return get_manager().rename(recording_id, data.label)


@router.post("/recordings/{recording_id}/translate", response_model=RecordingView)
async def translate(recording_id: str, data: TranslateRecordingRequest) -> dict:
    return await get_manager().translate(recording_id, data.target_language)


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
