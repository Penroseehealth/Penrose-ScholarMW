from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.context_engine.context_manager import context_manager
from app.context_engine.intent_classifier import IntentClassifier
from app.context_engine.models import (
    ResponseMode,
    WorkspaceState,
)
from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User

router = APIRouter(prefix="/context", tags=["Live Context Engine"])


# ---------------------------------------------------------------------------
# Request / response schemas
# ---------------------------------------------------------------------------


class WorkspaceUpdateRequest(BaseModel):
    session_id: int
    workspace: WorkspaceState


class VisualSelectionRequest(BaseModel):
    session_id: int
    visual_id: str
    visual_type: str = ""
    selected_element: str = ""
    element_label: str = ""
    element_description: str = ""


class TextSelectionRequest(BaseModel):
    session_id: int
    selected_text: str


class IntentRequest(BaseModel):
    message: str
    session_id: int


class IntentResponse(BaseModel):
    action: str
    target: str
    response_mode: str
    is_followup: bool
    is_visual_request: bool
    is_audio_request: bool
    is_quiz_request: bool
    is_teaching_mode: bool
    is_interrupt: bool
    confidence: float


class ContextSnapshotResponse(BaseModel):
    session_id: int
    subject: str
    syllabus: str
    topic: str
    subtopic: str
    current_objective: str
    active_lesson: str
    current_question: str
    selected_text: str
    active_visual_id: str
    active_visual_type: str
    active_visual_element: str
    preferred_response_mode: str
    conversation_turns: int
    mastery_pct: float
    difficulty_level: str
    struggling_concepts: list[str]
    referenced_topics: list[str]


class SetResponseModeRequest(BaseModel):
    session_id: int
    mode: str


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("/workspace", status_code=status.HTTP_204_NO_CONTENT)
async def update_workspace(
    body: WorkspaceUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Called by the Flutter client whenever the student navigates or the
    active screen content changes. Keeps the context engine in sync."""
    await context_manager.build_context(
        user_id=user.id,
        session_id=body.session_id,
        workspace=body.workspace,
        db=db,
    )


@router.post("/visual-selection", status_code=status.HTTP_204_NO_CONTENT)
async def set_visual_selection(
    body: VisualSelectionRequest,
    user: User = Depends(get_current_user),
):
    """Called when the student taps/clicks on part of a diagram, chart,
    equation, or other visual element."""
    context_manager.set_visual_selection(
        user_id=user.id,
        session_id=body.session_id,
        visual_id=body.visual_id,
        visual_type=body.visual_type,
        element=body.selected_element,
        element_label=body.element_label,
        element_description=body.element_description,
    )


@router.post("/text-selection", status_code=status.HTTP_204_NO_CONTENT)
async def set_text_selection(
    body: TextSelectionRequest,
    user: User = Depends(get_current_user),
):
    """Called when the student highlights/selects text on screen."""
    context_manager.set_selected_text(
        user_id=user.id,
        session_id=body.session_id,
        text=body.selected_text,
    )


@router.post("/intent", response_model=IntentResponse)
async def classify_intent(
    body: IntentRequest,
    user: User = Depends(get_current_user),
):
    """Classify the user's message intent and return the detected response
    mode. Useful for the frontend to pre-configure UI before sending."""
    intent = IntentClassifier.classify(body.message)
    return IntentResponse(
        action=intent.action,
        target=intent.target,
        response_mode=intent.response_mode,
        is_followup=intent.is_followup,
        is_visual_request=intent.is_visual_request,
        is_audio_request=intent.is_audio_request,
        is_quiz_request=intent.is_quiz_request,
        is_teaching_mode=intent.is_teaching_mode,
        is_interrupt=intent.is_interrupt,
        confidence=intent.confidence,
    )


@router.get("/snapshot/{session_id}", response_model=ContextSnapshotResponse)
async def get_context_snapshot(
    session_id: int,
    user: User = Depends(get_current_user),
):
    """Return the current live context for a session (for debugging /
    context-aware UI rendering)."""
    ctx = context_manager.get(user.id, session_id)
    if not ctx:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active context for this session",
        )
    return ContextSnapshotResponse(
        session_id=ctx.session_id,
        subject=ctx.subject,
        syllabus=ctx.syllabus,
        topic=ctx.topic,
        subtopic=ctx.subtopic,
        current_objective=ctx.current_objective,
        active_lesson=ctx.active_lesson,
        current_question=ctx.current_question,
        selected_text=ctx.selected_text,
        active_visual_id=ctx.current_visual.visual_id,
        active_visual_type=ctx.current_visual.visual_type,
        active_visual_element=ctx.current_visual.selected_element,
        preferred_response_mode=ctx.preferred_response_mode.value,
        conversation_turns=ctx.conversation_turns,
        mastery_pct=ctx.learning_state.current_mastery_pct,
        difficulty_level=ctx.learning_state.difficulty_level,
        struggling_concepts=ctx.learning_state.struggling_concepts,
        referenced_topics=ctx.referenced_topics,
    )


@router.post("/response-mode", status_code=status.HTTP_204_NO_CONTENT)
async def set_response_mode(
    body: SetResponseModeRequest,
    user: User = Depends(get_current_user),
):
    """Explicitly set the preferred response mode (text, audio, visual,
    combined, interactive) for the session."""
    try:
        mode = ResponseMode(body.mode)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid mode '{body.mode}'. Use: text, audio, visual, combined, interactive",
        )
    context_manager.set_response_mode(user.id, body.session_id, mode)


@router.delete("/session/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def clear_session_context(
    session_id: int,
    user: User = Depends(get_current_user),
):
    """Clear the in-memory context for a session (e.g. on session end)."""
    context_manager.remove(user.id, session_id)
