import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.stem_latex import STEM_LATEX_INSTRUCTION
from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import (
    ChatMessage,
    ChatSession,
    InstitutionKnowledge,
    KnowledgeDocument,
    KnowledgeLayer,
    User,
    VaultDocument,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/knowledge", tags=["AI Knowledge Retrieval"])


# ---------------------------------------------------------------------------
# Request / Response schemas
# ---------------------------------------------------------------------------


class RAGQueryRequest(BaseModel):
    question: str
    course_id: Optional[int] = None
    max_sources: int = 5


class RAGQueryResponse(BaseModel):
    answer: str
    sources: list[dict]
    confidence: str


class VoiceTranscribeRequest(BaseModel):
    audio_text: str
    session_id: Optional[int] = None
    agent_type: str = "tutor"


class VoiceTranscribeResponse(BaseModel):
    answer: str
    session_id: int


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _extract_keywords(question: str, max_keywords: int = 8) -> list[str]:
    """Return a list of meaningful keywords from the question string."""
    stopwords = {
        "the",
        "a",
        "an",
        "is",
        "are",
        "was",
        "were",
        "be",
        "been",
        "being",
        "have",
        "has",
        "had",
        "do",
        "does",
        "did",
        "will",
        "would",
        "could",
        "should",
        "may",
        "might",
        "shall",
        "can",
        "to",
        "of",
        "in",
        "for",
        "on",
        "with",
        "at",
        "by",
        "from",
        "as",
        "into",
        "about",
        "this",
        "that",
        "these",
        "those",
        "i",
        "you",
        "he",
        "she",
        "it",
        "we",
        "they",
        "me",
        "him",
        "her",
        "us",
        "them",
        "my",
        "your",
        "his",
        "its",
        "our",
        "their",
        "what",
        "which",
        "who",
        "whom",
        "how",
        "when",
        "where",
        "why",
        "and",
        "but",
        "or",
        "not",
        "so",
        "if",
        "then",
        "than",
        "too",
        "very",
        "just",
        "also",
        "no",
        "yes",
    }
    words = question.lower().split()
    keywords = [w.strip(".,!?;:()[]{}\"'") for w in words]
    keywords = [w for w in keywords if w and w not in stopwords and len(w) > 1]
    return keywords[:max_keywords]


def _ilike_conditions(column, keywords: list[str]):
    """Build an OR-chain of ILIKE conditions for keyword matching."""
    return or_(*[column.ilike(f"%{kw}%") for kw in keywords])


def _confidence_from_sources(sources: list[dict]) -> str:
    if len(sources) >= 3:
        return "high"
    if len(sources) >= 1:
        return "medium"
    return "low"


# ---------------------------------------------------------------------------
# POST /rag-query
# ---------------------------------------------------------------------------


@router.post("/rag-query", response_model=RAGQueryResponse)
async def rag_query(
    payload: RAGQueryRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    keywords = _extract_keywords(payload.question)
    if not keywords:
        raise HTTPException(
            status_code=400,
            detail="Could not extract meaningful keywords from the question.",
        )

    sources: list[dict] = []

    # --- VaultDocument search ------------------------------------------------
    vault_query = select(VaultDocument).where(_ilike_conditions(VaultDocument.title, keywords))
    if payload.course_id is not None:
        vault_query = vault_query.where(VaultDocument.course_id == payload.course_id)
    vault_query = vault_query.limit(payload.max_sources)
    vault_result = await db.execute(vault_query)
    for doc in vault_result.scalars().all():
        sources.append(
            {
                "id": doc.id,
                "title": doc.title,
                "doc_type": "vault",
                "source": "VaultDocument",
                "content": getattr(doc, "content", "") or getattr(doc, "description", "") or "",
            }
        )

    # --- KnowledgeDocument search -------------------------------------------
    kd_query = (
        select(KnowledgeDocument)
        .join(KnowledgeLayer, KnowledgeDocument.layer_id == KnowledgeLayer.id)
        .where(_ilike_conditions(KnowledgeDocument.title, keywords))
    )
    if payload.course_id is not None:
        kd_query = kd_query.where(KnowledgeLayer.course_id == payload.course_id)
    kd_query = kd_query.limit(payload.max_sources)
    kd_result = await db.execute(kd_query)
    for doc in kd_result.scalars().all():
        sources.append(
            {
                "id": doc.id,
                "title": doc.title,
                "doc_type": "knowledge",
                "source": "KnowledgeDocument",
                "content": getattr(doc, "content", "") or getattr(doc, "description", "") or "",
            }
        )

    # --- InstitutionKnowledge search ----------------------------------------
    ik_query = select(InstitutionKnowledge).where(_ilike_conditions(InstitutionKnowledge.title, keywords))
    if payload.course_id is not None:
        ik_query = ik_query.where(InstitutionKnowledge.course_id == payload.course_id)
    ik_query = ik_query.limit(payload.max_sources)
    ik_result = await db.execute(ik_query)
    for doc in ik_result.scalars().all():
        sources.append(
            {
                "id": doc.id,
                "title": doc.title,
                "doc_type": "institution",
                "source": "InstitutionKnowledge",
                "content": getattr(doc, "content", "") or getattr(doc, "description", "") or "",
            }
        )

    # Truncate to max_sources
    sources = sources[: payload.max_sources]
    confidence = _confidence_from_sources(sources)

    # --- LLM grounded answer -------------------------------------------------
    try:
        from app.config.ai_client import AIProviderError, call_ai_text

        context_block = "\n\n".join(
            f"[Source {i + 1}: {s['title']} ({s['source']})]\n{s['content']}" for i, s in enumerate(sources)
        )
        if not context_block:
            context_block = "No relevant documents were found in the knowledge base."

        system_prompt = (
            "You are ScholarAI, an academic assistant for Malawian universities. "
            "Use ONLY the provided context to answer the question. "
            "If the context doesn't contain enough information, say so." + STEM_LATEX_INSTRUCTION
        )
        user_message = f"Context:\n{context_block}\n\nQuestion: {payload.question}"

        answer = await call_ai_text(
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message},
            ],
            temperature=0.3,
            max_tokens=1024,
        )
    except (AIProviderError, RuntimeError, TimeoutError, OSError) as exc:
        logger.error("AI call failed: %s", exc)
        answer = (
            "I found some potentially relevant sources but could not generate "
            "an AI answer at this time. Please review the sources below."
        )

    return RAGQueryResponse(answer=answer, sources=sources, confidence=confidence)


# ---------------------------------------------------------------------------
# POST /voice-transcribe
# ---------------------------------------------------------------------------


@router.post("/voice-transcribe", response_model=VoiceTranscribeResponse)
async def voice_transcribe(
    payload: VoiceTranscribeRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # --- Retrieve or create chat session ------------------------------------
    if payload.session_id:
        session_result = await db.execute(select(ChatSession).where(ChatSession.id == payload.session_id))
        session = session_result.scalar_one_or_none()
        if not session or session.user_id != current_user.id:
            raise HTTPException(status_code=404, detail="Chat session not found.")
    else:
        session = ChatSession(
            user_id=current_user.id,
            agent_type=payload.agent_type,
            title=payload.audio_text[:80],
        )
        db.add(session)
        await db.commit()
        await db.refresh(session)

    # --- Persist the user message -------------------------------------------
    user_msg = ChatMessage(
        session_id=session.id,
        role="user",
        content=payload.audio_text,
    )
    db.add(user_msg)
    await db.commit()

    # --- Generate assistant response ----------------------------------------
    assistant_text: str

    try:
        from app.config.ai_client import AIProviderError, call_ai_text

        history_result = await db.execute(
            select(ChatMessage).where(ChatMessage.session_id == session.id).order_by(ChatMessage.id)
        )
        history = history_result.scalars().all()

        system_prompt = (
            "You are ScholarAI, an academic assistant and voice tutor for "
            "Malawian university students. Provide clear, helpful, and "
            "educational responses. Keep answers concise since they will be "
            "read aloud via text-to-speech." + STEM_LATEX_INSTRUCTION
        )

        messages = [{"role": "system", "content": system_prompt}]
        for msg in history:
            messages.append({"role": msg.role, "content": msg.content})

        assistant_text = await call_ai_text(messages, temperature=0.4, max_tokens=512)
    except (AIProviderError, RuntimeError, TimeoutError, OSError) as exc:
        logger.error("AI call failed for voice transcribe: %s", exc)
        assistant_text = "I'm sorry, I encountered an error processing your voice message. Please try again."

    # --- Persist assistant response -----------------------------------------
    assistant_msg = ChatMessage(
        session_id=session.id,
        role="assistant",
        content=assistant_text,
    )
    db.add(assistant_msg)
    await db.commit()

    return VoiceTranscribeResponse(answer=assistant_text, session_id=session.id)
