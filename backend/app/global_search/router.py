from fastapi import APIRouter, Depends
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import (
    Assessment,
    ChatSession,
    Course,
    KnowledgeDocument,
    ResearchProject,
    User,
    VaultDocument,
)

router = APIRouter(prefix="/search", tags=["Global Search"])


def _make_result(entity_type: str, entity, subtitle_field: str | None = None):
    subtitle = ""
    if subtitle_field and hasattr(entity, subtitle_field):
        val = getattr(entity, subtitle_field)
        subtitle = val[:120] if val else ""
    elif hasattr(entity, "description") and entity.description:
        subtitle = entity.description[:120]
    elif hasattr(entity, "doc_type"):
        subtitle = entity.doc_type

    url_map = {
        "course": f"/courses/{entity.id}",
        "assessment": f"/assessments/{entity.id}",
        "vault_document": f"/vault/{entity.id}",
        "research_project": f"/research/{entity.id}",
        "chat_session": f"/ai/sessions/{entity.id}",
        "knowledge_document": f"/knowledge/{entity.id}",
    }

    return {
        "type": entity_type,
        "id": entity.id,
        "title": entity.title,
        "subtitle": subtitle,
        "url_path": url_map.get(entity_type, f"/{entity_type}/{entity.id}"),
    }


@router.get("/")
async def global_search(
    q: str,
    type: str | None = None,
    limit: int = 20,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    results = []
    search_types = (
        [type] if type and type != "all" else ["course", "assessment", "vault", "research", "chat", "knowledge"]
    )

    if "course" in search_types:
        stmt = (
            select(Course)
            .where(
                or_(
                    Course.title.ilike(f"%{q}%"),
                    Course.code.ilike(f"%{q}%"),
                    Course.description.ilike(f"%{q}%"),
                )
            )
            .limit(limit)
        )
        result = await db.execute(stmt)
        for c in result.scalars().all():
            results.append(_make_result("course", c, "code"))

    if "assessment" in search_types:
        stmt = (
            select(Assessment)
            .where(
                or_(
                    Assessment.title.ilike(f"%{q}%"),
                    Assessment.description.ilike(f"%{q}%"),
                )
            )
            .limit(limit)
        )
        result = await db.execute(stmt)
        for a in result.scalars().all():
            results.append(_make_result("assessment", a, "assessment_type"))

    if "vault" in search_types:
        stmt = (
            select(VaultDocument)
            .where(
                or_(
                    VaultDocument.title.ilike(f"%{q}%"),
                    VaultDocument.tags.ilike(f"%{q}%"),
                )
            )
            .limit(limit)
        )
        result = await db.execute(stmt)
        for v in result.scalars().all():
            results.append(_make_result("vault_document", v, "doc_type"))

    if "research" in search_types:
        stmt = (
            select(ResearchProject)
            .where(
                or_(
                    ResearchProject.title.ilike(f"%{q}%"),
                    ResearchProject.description.ilike(f"%{q}%"),
                )
            )
            .limit(limit)
        )
        result = await db.execute(stmt)
        for r in result.scalars().all():
            results.append(_make_result("research_project", r, "status"))

    if "chat" in search_types:
        stmt = select(ChatSession).where(ChatSession.title.ilike(f"%{q}%")).limit(limit)
        result = await db.execute(stmt)
        for cs in result.scalars().all():
            results.append(_make_result("chat_session", cs, "agent_type"))

    if "knowledge" in search_types:
        stmt = (
            select(KnowledgeDocument)
            .where(
                or_(
                    KnowledgeDocument.title.ilike(f"%{q}%"),
                    KnowledgeDocument.content.ilike(f"%{q}%"),
                )
            )
            .limit(limit)
        )
        result = await db.execute(stmt)
        for kd in result.scalars().all():
            results.append(_make_result("knowledge_document", kd, "doc_type"))

    results.sort(key=lambda x: x["title"].lower())
    return {"results": results[:limit], "total": len(results)}
