"""Multimodal router for ScholarAI — file uploads, voice, TTS, STEM notation speech."""

from __future__ import annotations

import logging
import uuid
from typing import Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.dependencies.auth import get_current_user
from app.models.models import User
from app.schemas.multimodal import (
    TTSRequest,
    TTSResponse,
    VoiceCloneRequest,
    VoiceCloneResponse,
    VoiceListItem,
    VoiceSettings,
)
from app.services.file_validation import (
    extract_file_content,
    validate_upload,
)
from app.services.stem_notation import latex_to_speech
from app.services.voice_service import (
    create_voice_clone,
    delete_voice_clone,
    get_user_voice_clones,
    get_voice,
    get_voice_library,
)
from app.speech.dependencies import DbSessionDep
from app.voice.clone_narration import (
    clone_applied_controls,
    clone_audio_metadata,
    synthesize_default_clone,
)
from app.voice.tts_service import tts_service
from app.voice.voice_catalog import resolve_default_voice_id

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai/multimodal", tags=["ScholarAI Multimodal"])

# In-memory file store (would use object storage in production)
_file_store: dict[str, dict[str, Any]] = {}


@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
):
    content = await file.read()
    filename = file.filename or "unknown"

    result = validate_upload(filename, content)
    if isinstance(result, str):
        raise HTTPException(status_code=400, detail=result)

    file_id = f"file-{user.id}-{uuid.uuid4().hex[:12]}"
    extracted_text = await extract_file_content(result)

    _file_store[file_id] = {
        "file_id": file_id,
        "user_id": user.id,
        "filename": filename,
        "file_type": result.file_type,
        "mime_type": result.mime_type,
        "size_bytes": result.size_bytes,
        "content": result.content,
        "extracted_text": extracted_text,
        "status": "ready",
    }

    log.info(
        "File uploaded: %s (%s, %d bytes) by user %d",
        filename,
        result.file_type,
        result.size_bytes,
        user.id,
    )

    return {
        "file_id": file_id,
        "filename": filename,
        "file_type": result.file_type,
        "size_bytes": result.size_bytes,
        "status": "ready",
        "extracted_text_preview": extracted_text[:500] if extracted_text else None,
    }


@router.get("/files/{file_id}")
async def get_file(file_id: str, user: User = Depends(get_current_user)):
    f = _file_store.get(file_id)
    if not f or f["user_id"] != user.id:
        raise HTTPException(status_code=404, detail="File not found")
    return {
        "file_id": f["file_id"],
        "filename": f["filename"],
        "file_type": f["file_type"],
        "size_bytes": f["size_bytes"],
        "status": f["status"],
    }


@router.delete("/files/{file_id}")
async def delete_file(file_id: str, user: User = Depends(get_current_user)):
    f = _file_store.get(file_id)
    if not f or f["user_id"] != user.id:
        raise HTTPException(status_code=404, detail="File not found")
    del _file_store[file_id]
    return {"status": "deleted"}


@router.get("/voices")
async def list_voices(
    language: str | None = None,
    user: User = Depends(get_current_user),
):
    voices = get_voice_library(language)
    user_clones = get_user_voice_clones(user.id)
    all_voices = [
        VoiceListItem(
            voice_id=v["voice_id"],
            name=v["name"],
            language=v["language"],
            gender=v.get("gender"),
            description=v.get("description"),
            is_default=v["voice_id"] == "en-us-academic-female-1",
        )
        for v in voices
    ]
    for c in user_clones:
        all_voices.append(
            VoiceListItem(
                voice_id=c["clone_id"],
                name=f"[Clone] {c['voice_name']}",
                language="en",
                gender=None,
                description="Your custom cloned voice",
                is_default=False,
            )
        )
    return all_voices


@router.post("/voices/settings")
async def update_voice_settings(
    body: VoiceSettings,
    user: User = Depends(get_current_user),
):
    voice = get_voice(body.default_voice_id)
    if not voice:
        raise HTTPException(
            status_code=400, detail=f"Voice '{body.default_voice_id}' not found"
        )
    return {"status": "updated", "settings": body.model_dump()}


@router.post("/voices/clone")
async def clone_voice(
    body: VoiceCloneRequest,
    user: User = Depends(get_current_user),
):
    result = await create_voice_clone(
        user_id=user.id,
        voice_name=body.voice_name,
        consent_confirmed=body.consent_confirmed,
    )
    if result["status"] == "error":
        raise HTTPException(status_code=400, detail=result["message"])
    return VoiceCloneResponse(
        clone_id=result["clone_id"],
        voice_name=result["voice_name"],
        status=result["status"],
        created_at="2026-01-01T00:00:00Z",
        message="Voice clone created. Use this voice in your TTS settings.",
    )


@router.post("/voices/clone/upload")
async def upload_voice_sample(
    file: UploadFile = File(...),
    voice_name: str = Form("My Voice"),
    consent_confirmed: bool = Form(False),
    user: User = Depends(get_current_user),
):
    content = await file.read()
    if not consent_confirmed:
        raise HTTPException(
            status_code=400,
            detail="Consent must be confirmed before creating a voice clone",
        )

    result = await create_voice_clone(
        user_id=user.id,
        voice_name=voice_name,
        audio_content=content,
        consent_confirmed=True,
    )
    if result["status"] == "error":
        raise HTTPException(status_code=400, detail=result["message"])
    return result


@router.delete("/voices/clone/{clone_id}")
async def remove_voice_clone(clone_id: str, user: User = Depends(get_current_user)):
    deleted = delete_voice_clone(clone_id, user.id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Clone not found")
    return {"status": "deleted"}


@router.post("/tts/synthesize")
async def synthesize_tts(
    body: TTSRequest,
    db: DbSessionDep,
    user: User = Depends(get_current_user),
):
    requested_voice_id = body.voice_id.strip()

    # Same precedence as the chat TTS route: the user's trained voice narrates
    # unless they asked for a specific catalog voice.
    clone = await synthesize_default_clone(
        db,
        text=body.text,
        voice_id=requested_voice_id,
        speed=body.speed,
        language=body.language,
    )
    if clone is not None:
        duration_ms, _ = clone_audio_metadata(clone)
        return TTSResponse(
            audio_url=None,
            duration_seconds=duration_ms / 1000,
            voice_id=str(clone.get("voice_id", "")),
            audio_base64=clone["audio_base64"],
            provider=clone.get("provider", "openvoice"),
            applied_controls=clone_applied_controls(clone),
        )

    voice_id = (
        resolve_default_voice_id()
        if requested_voice_id.lower() in {"", "default"}
        else requested_voice_id
    )
    result = await tts_service.synthesize(
        body.text,
        speed=body.speed,
        language=body.language,
        voice_id=voice_id,
        scenario=body.scenario,
        delivery_style=body.delivery_style,
        mode=body.mode,
    )
    if not result["audio_base64"]:
        raise HTTPException(
            status_code=503,
            detail="No server-side speech provider is available for this request.",
        )
    return TTSResponse(
        audio_url=None,
        duration_seconds=result["duration_ms"] / 1000,
        voice_id=voice_id,
        audio_base64=result["audio_base64"],
        provider=result["provider"],
        applied_controls=result.get("applied_controls", {}),
    )


@router.post("/stem-to-speech")
async def stem_to_speech(
    body: TTSRequest,
    user: User = Depends(get_current_user),
):
    speech_text = latex_to_speech(body.text, body.language)
    return {
        "original": body.text,
        "speech_text": speech_text,
        "language": body.language,
    }
