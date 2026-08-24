import time

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import get_settings
from app.config.stem_latex import STEM_LATEX_INSTRUCTION
from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import ChatMessage, ChatSession, User

router = APIRouter(prefix="/ai-orchestrator", tags=["AI Orchestration"])
settings = get_settings()

AVAILABLE_MODELS = {
    "openai": {
        "name": "OpenAI GPT",
        "provider": "openai",
        "model_id": settings.OPENAI_MODEL,
        "available": bool(settings.OPENAI_API_KEY),
    },
    "local": {
        "name": "Local Model",
        "provider": "local",
        "model_id": "local-model",
        "available": False,
    },
    "institutional": {
        "name": "Institutional Model",
        "provider": "institutional",
        "model_id": "institutional-model",
        "available": False,
    },
}


async def _call_openai(system_prompt: str, messages: list[dict]) -> str:
    from app.config.ai_client import AIProviderError, call_ai_text

    full_messages = [{"role": "system", "content": system_prompt}] + messages
    try:
        return await call_ai_text(full_messages, max_tokens=2000, temperature=0.7)
    except AIProviderError as exc:
        import logging

        logging.getLogger(__name__).warning("AI call failed: %s", exc)
        return "AI model is currently unavailable. Please try again later."


def _get_system_prompt(agent_type: str) -> str:
    prompts = {
        "tutor": (
            "You are an expert academic tutor for Malawian university students. "
            "Explain concepts clearly, use analogies, provide examples."
        ),
        "research": (
            "You are a research assistant. Help with literature review, methodology, "
            "and evidence analysis for academic research."
        ),
        "writer": (
            "You are an academic writing assistant. Help structure assignments, "
            "improve academic language, and provide citation guidance."
        ),
    }
    return prompts.get(agent_type, prompts["tutor"]) + STEM_LATEX_INSTRUCTION


class ChatOrchestratorRequest(BaseModel):
    message: str
    model_preference: str = "auto"
    session_id: int | None = None
    agent_type: str = "tutor"


class TranslateContextRequest(BaseModel):
    query: str
    context_documents: list[str]


@router.post("/chat")
async def chat(
    body: ChatOrchestratorRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    start_time = time.time()

    if body.session_id:
        result = await db.execute(
            select(ChatSession).where(
                ChatSession.id == body.session_id,
                ChatSession.user_id == user.id,
            )
        )
        session = result.scalar_one_or_none()
        if not session:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    else:
        session = ChatSession(
            user_id=user.id,
            agent_type=body.agent_type,
            title=body.message[:80],
        )
        db.add(session)
        await db.commit()
        await db.refresh(session)

    user_msg = ChatMessage(session_id=session.id, role="user", content=body.message)
    db.add(user_msg)
    await db.commit()

    history_result = await db.execute(
        select(ChatMessage).where(ChatMessage.session_id == session.id).order_by(ChatMessage.id)
    )
    history = [{"role": m.role, "content": m.content} for m in history_result.scalars().all()]

    model_used = "openai"
    system_prompt = _get_system_prompt(body.agent_type)

    if body.model_preference == "auto" and settings.OPENAI_API_KEY:
        ai_response = await _call_openai(system_prompt, history)
    elif body.model_preference == "cloud" and settings.OPENAI_API_KEY:
        ai_response = await _call_openai(system_prompt, history)
    elif body.model_preference == "local":
        ai_response = "Local model is not yet configured. Please use 'auto' or 'cloud' preference."
        model_used = "local_unavailable"
    elif body.model_preference == "institutional":
        ai_response = "Institutional model is not yet configured. Please use 'auto' or 'cloud' preference."
        model_used = "institutional_unavailable"
    else:
        ai_response = await _call_openai(system_prompt, history)

    ai_msg = ChatMessage(session_id=session.id, role="assistant", content=ai_response)
    db.add(ai_msg)
    await db.commit()
    await db.refresh(ai_msg)

    response_time_ms = round((time.time() - start_time) * 1000)

    return {
        "message_id": ai_msg.id,
        "session_id": session.id,
        "content": ai_response,
        "model_used": model_used,
        "response_time_ms": response_time_ms,
        "agent_type": body.agent_type,
    }


@router.get("/models")
async def list_models(user: User = Depends(get_current_user)):
    return {
        "models": [
            {
                "id": model_id,
                "name": info["name"],
                "provider": info["provider"],
                "available": info["available"],
            }
            for model_id, info in AVAILABLE_MODELS.items()
        ]
    }


@router.post("/translate-context")
async def translate_context(
    body: TranslateContextRequest,
    user: User = Depends(get_current_user),
):
    context_block = "\n\n---\n\n".join(f"Document {i + 1}:\n{doc}" for i, doc in enumerate(body.context_documents))

    prompt = (
        f"You are an academic assistant. Use the following context documents "
        f"to answer the student's query.\n\n"
        f"## Context Documents\n\n{context_block}\n\n"
        f"## Student Query\n\n{body.query}\n\n"
        f"Provide a clear, accurate response based on the context above."
    )

    return {
        "prompt": prompt,
        "token_estimate": len(prompt.split()),
        "document_count": len(body.context_documents),
    }
