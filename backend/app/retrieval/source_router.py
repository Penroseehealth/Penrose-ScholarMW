"""Per-message source routing.

Decides *which* knowledge sources are appropriate for a user message before the
tutor answers, and retrieves from the ones that apply. It reuses existing
machinery rather than introducing a second retrieval system:

  * internal course materials  -> keyword search over the same three tables the
    ``/knowledge/rag-query`` endpoint already queries
    (:mod:`app.knowledge_retrieval.router`);
  * uploaded documents         -> handled by the caller (the ephemeral file
    store), surfaced here only as a routing signal;
  * web / academic sources     -> :func:`app.retrieval.orchestrator.search`;
  * the model's own knowledge  -> the default when nothing else applies.

The router is intentionally conservative and *honest*: it never claims a source
that is not present, and when a source the question clearly needs is missing it
returns a short limitation note for the prompt instead of inventing content.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field

log = logging.getLogger(__name__)


# Cues that a question is about the student's own course/institution material.
_COURSE_CUES = (
    r"\b(course|syllabus|module|assignment|lecture|handout|notes|tutorial|"
    r"past paper|exam paper|marking scheme|our (class|course|module|college)|"
    r"my (class|course|module|notes|material|lecturer|teacher))\b",
)

# Cues that a question wants current / external / verifiable information.
_EXTERNAL_CUES = (
    r"\b(latest|recent|current|today|this year|20\d{2}|news|update|"
    r"recently|as of|newest|study shows|research says|according to)\b",
)


@dataclass
class SourcePlan:
    """Which sources apply to a message, and why."""

    use_model_knowledge: bool = True
    use_internal_docs: bool = False
    use_web: bool = False
    has_uploaded_files: bool = False
    reasons: list[str] = field(default_factory=list)

    def describe(self) -> str:
        return ", ".join(self.reasons) if self.reasons else "model knowledge"


def _matches(patterns: tuple[str, ...], text: str) -> bool:
    return any(re.search(p, text) for p in patterns)


def plan_sources(message: str, *, has_uploaded_files: bool = False) -> SourcePlan:
    """Classify a message into the sources that should be consulted.

    Conservative by design: external lookup is only requested when the wording
    asks for time-sensitive or external material, so ordinary conceptual
    questions keep answering from the model without a needless network call.
    """
    low = (message or "").lower()
    plan = SourcePlan(has_uploaded_files=has_uploaded_files)
    plan.reasons.append("model knowledge")

    if has_uploaded_files:
        plan.reasons.append("uploaded documents")

    if _matches(_COURSE_CUES, low):
        plan.use_internal_docs = True
        plan.reasons.append("internal course materials")

    if _matches(_EXTERNAL_CUES, low):
        plan.use_web = True
        plan.reasons.append("web / academic sources")

    return plan


# --- Internal course-material retrieval ------------------------------------


async def search_internal(
    question: str, *, course_id: int | None = None, db, max_sources: int = 5
) -> list[dict]:
    """Keyword-search the institution's own materials (reuses the RAG tables).

    Mirrors :func:`app.knowledge_retrieval.router.rag_query`'s keyword approach
    so there is a single notion of "internal document" in the codebase. Returns
    ``[]`` on any failure; internal lookup must never break chat.
    """
    try:
        from sqlalchemy import select

        from app.knowledge_retrieval.router import (
            _extract_keywords,
            _ilike_conditions,
        )
        from app.models.models import (
            InstitutionKnowledge,
            KnowledgeDocument,
            KnowledgeLayer,
            VaultDocument,
        )

        keywords = _extract_keywords(question)
        if not keywords:
            return []

        sources: list[dict] = []

        vault_q = select(VaultDocument).where(
            _ilike_conditions(VaultDocument.title, keywords)
        )
        if course_id is not None:
            vault_q = vault_q.where(VaultDocument.course_id == course_id)
        for doc in (await db.execute(vault_q.limit(max_sources))).scalars().all():
            sources.append(
                {
                    "title": doc.title,
                    "source": "VaultDocument",
                    "content": getattr(doc, "content", "")
                    or getattr(doc, "description", "")
                    or "",
                }
            )

        kd_q = (
            select(KnowledgeDocument)
            .join(KnowledgeLayer, KnowledgeDocument.layer_id == KnowledgeLayer.id)
            .where(_ilike_conditions(KnowledgeDocument.title, keywords))
        )
        if course_id is not None:
            kd_q = kd_q.where(KnowledgeLayer.course_id == course_id)
        for doc in (await db.execute(kd_q.limit(max_sources))).scalars().all():
            sources.append(
                {
                    "title": doc.title,
                    "source": "KnowledgeDocument",
                    "content": getattr(doc, "content", "")
                    or getattr(doc, "description", "")
                    or "",
                }
            )

        ik_q = select(InstitutionKnowledge).where(
            _ilike_conditions(InstitutionKnowledge.title, keywords)
        )
        if course_id is not None:
            ik_q = ik_q.where(InstitutionKnowledge.course_id == course_id)
        for doc in (await db.execute(ik_q.limit(max_sources))).scalars().all():
            sources.append(
                {
                    "title": doc.title,
                    "source": "InstitutionKnowledge",
                    "content": getattr(doc, "content", "")
                    or getattr(doc, "description", "")
                    or "",
                }
            )

        return sources[:max_sources]
    except Exception as exc:  # noqa: BLE001 - internal lookup must never break chat
        log.info("Internal source lookup skipped: %s", exc)
        return []


def internal_prompt_block(sources: list[dict]) -> str:
    """Prompt block for internal course materials, numbered for citation."""
    if not sources:
        return ""
    blocks = []
    for i, s in enumerate(sources, 1):
        content = (s.get("content") or "").strip()
        if len(content) > 1200:
            content = content[:1200].rstrip() + " …"
        blocks.append(
            f"[{i}] {s.get('title', 'Untitled')} ({s.get('source', '')})\n{content}"
        )
    joined = "\n\n".join(blocks)
    return (
        "\n\n--- INTERNAL COURSE MATERIALS (prefer these for course-specific "
        "questions) ---\n"
        "The following excerpts come from the institution's own materials. When "
        "they cover the question, treat them as the primary source and cite them "
        "inline like [1]. If they do not cover it, say so and continue.\n\n"
        f"{joined}\n"
        "--- END INTERNAL COURSE MATERIALS ---\n"
    )


def limitation_note(plan: SourcePlan, *, internal_found: bool, web_found: bool) -> str:
    """Short, honest note when a source the question needs produced nothing.

    Empty when nothing is missing, so ordinary answers carry no disclaimer.
    """
    missing: list[str] = []
    if plan.use_internal_docs and not internal_found:
        missing.append("the institution's course materials")
    if plan.use_web and not web_found:
        missing.append("current external sources")
    if not missing:
        return ""
    joined = " and ".join(missing)
    return (
        f"\n\nNOTE: The question appears to need {joined}, but none were found "
        "for it. Answer only to the extent your own knowledge supports, and "
        "briefly tell the student that material was unavailable rather than "
        "guessing or inventing a source."
    )
