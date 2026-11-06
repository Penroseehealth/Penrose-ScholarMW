from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.dependencies.auth import get_current_user
from app.models.models import User
from app.speech.dependencies import DbSessionDep
from app.voice.clone_narration import (
    clone_applied_controls,
    clone_audio_metadata,
    synthesize_default_clone,
)
from app.voice.conversation_orchestrator import orchestrator
from app.voice.models import (
    TTSRequest,
    TTSResponse,
    VoiceHealthResponse,
    VoiceInterruptRequest,
    VoiceListResponse,
    VoiceOption,
    VoiceSessionRequest,
    VoiceSessionResponse,
    VoiceSessionState,
    VoiceTranscriptRequest,
    VoiceTranscriptResponse,
)
from app.voice.tts_service import tts_service
from app.voice.voice_catalog import (
    ACCENTS,
    GENDERS,
    resolve_default_voice_id,
    voice_payloads,
)

router = APIRouter(prefix="/voice", tags=["voice"])


@router.post("/session", response_model=VoiceSessionResponse)
async def create_voice_session(
    body: VoiceSessionRequest,
    user: User = Depends(get_current_user),
):
    ctx = orchestrator.create_session(
        user_id=user.id,
        agent_type=body.agent_type,
        subject=body.subject,
        topic=body.topic,
        language=body.language,
    )
    return VoiceSessionResponse(
        session_id=ctx.session_id,
        state=ctx.state,
        created_at=ctx.created_at,
    )


@router.delete("/session/{session_id}")
async def delete_voice_session(
    session_id: str,
    user: User = Depends(get_current_user),
):
    ctx = orchestrator.get_session(session_id)
    if not ctx or ctx.user_id != user.id:
        raise HTTPException(status_code=404, detail="Session not found")
    orchestrator.remove_session(session_id)
    return {"status": "deleted"}


@router.post("/transcript", response_model=VoiceTranscriptResponse)
async def process_voice_transcript(
    body: VoiceTranscriptRequest,
    user: User = Depends(get_current_user),
):
    ctx = orchestrator.get_session(body.session_id)
    if not ctx or ctx.user_id != user.id:
        raise HTTPException(status_code=404, detail="Voice session not found")

    ctx.state = VoiceSessionState.THINKING
    orchestrator.record_turn(body.session_id, "user", body.transcript)

    modality = orchestrator.classify_response_modality(body.transcript, "")
    ctx.response_modality = modality

    from app.ai_tutor.router import _build_system_prompt, _call_llm

    system_prompt = _build_system_prompt(ctx.agent_type)
    system_prompt += (
        f"\n\nVoice conversation context: Subject={ctx.subject}, Topic={ctx.topic}. "
        "Respond concisely for spoken delivery. Keep responses under 3 paragraphs "
        "unless the student asks for detail. Use natural spoken language."
    )

    ctx.state = VoiceSessionState.GENERATING
    ai_response = await _call_llm(system_prompt, ctx.history_for_ai)

    orchestrator.record_turn(
        body.session_id, "assistant", ai_response, modality=modality
    )
    ctx.state = VoiceSessionState.IDLE

    return VoiceTranscriptResponse(
        session_id=body.session_id,
        user_text=body.transcript,
        ai_text=ai_response,
        response_modality=modality,
        state=ctx.state,
    )


@router.post("/tts", response_model=TTSResponse)
async def text_to_speech(
    body: TTSRequest,
    db: DbSessionDep,
    user: User = Depends(get_current_user),
):
    requested_voice_id = body.voice_id.strip() if isinstance(body.voice_id, str) else ""

    # A trained voice is the app's narrator when the caller has not chosen a
    # specific catalog voice. An explicit voice still wins below.
    clone = await synthesize_default_clone(
        db,
        text=body.text,
        voice_id=requested_voice_id,
        speed=body.speed,
        language=body.language,
    )
    if clone is not None:
        duration_ms, sample_rate = clone_audio_metadata(clone)
        return TTSResponse(
            audio_base64=clone["audio_base64"],
            duration_ms=duration_ms,
            sample_rate=sample_rate,
            provider=clone.get("provider", "openvoice"),
            scenario=body.scenario,
            delivery_style=body.delivery_style,
            mode=body.mode,
            applied_controls=clone_applied_controls(clone),
        )

    voice_id = requested_voice_id
    if voice_id.lower() == "default" or voice_id == "":
        voice_id = resolve_default_voice_id()
    tts_service.set_speed(body.speed)
    result = await tts_service.synthesize(
        body.text,
        speed=body.speed,
        language=body.language,
        voice_id=voice_id,
        scenario=body.scenario.value,
        delivery_style=body.delivery_style.value,
        mode=body.mode.value,
    )
    return TTSResponse(
        audio_base64=result["audio_base64"],
        duration_ms=result["duration_ms"],
        sample_rate=result["sample_rate"],
        provider=result.get("provider", "browser"),
        scenario=body.scenario,
        delivery_style=body.delivery_style,
        mode=body.mode,
        applied_controls=result.get("applied_controls", {}),
    )


@router.post("/interrupt")
async def interrupt_voice(
    body: VoiceInterruptRequest,
    user: User = Depends(get_current_user),
):
    interrupted = orchestrator.interrupt(body.session_id)
    return {"interrupted": interrupted}


@router.get("/voices", response_model=VoiceListResponse)
async def list_voices():
    """Narration voices available for tutor playback (accent + gender)."""
    return VoiceListResponse(
        voices=[VoiceOption(**payload) for payload in voice_payloads()],
        accents=list(ACCENTS),
        genders=list(GENDERS),
        default_voice_id=resolve_default_voice_id(),
    )


@router.get("/health", response_model=VoiceHealthResponse)
async def voice_health():
    from app.voice.voice_catalog import resolve_default_voice_id

    return VoiceHealthResponse(
        status="ok",
        tts_available=tts_service.is_available,
        stt_available=True,
        session_count=len(orchestrator._sessions),
        default_voice_id=resolve_default_voice_id(),
        provider=tts_service.preferred_provider,
    )
