from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import (
    InstitutionKnowledge,
    KnowledgeDocument,
    KnowledgeLayer,
    User,
)
from app.schemas.malawi_context import (
    ContextQueryRequest,
    ContextQueryResponse,
    InstitutionKnowledgeCreate,
    InstitutionKnowledgeResponse,
    KnowledgeDocumentCreate,
    KnowledgeDocumentResponse,
    KnowledgeLayerCreate,
    KnowledgeLayerResponse,
)

router = APIRouter(prefix="/malawi-context", tags=["Malawi Academic Context"])


# ─── Knowledge Layers ────────────────────────────────────────────


@router.post("/layers", response_model=KnowledgeLayerResponse)
async def create_knowledge_layer(
    payload: KnowledgeLayerCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    layer = KnowledgeLayer(
        name=payload.name,
        layer_type=payload.layer_type,
        institution_id=payload.institution_id,
        faculty=payload.faculty,
        department=payload.department,
        course_id=payload.course_id,
        description=payload.description,
        priority=payload.priority,
        owner_id=user.id,
    )
    db.add(layer)
    await db.commit()
    await db.refresh(layer)
    return KnowledgeLayerResponse.model_validate(layer)


@router.get("/layers", response_model=list[KnowledgeLayerResponse])
async def list_knowledge_layers(
    layer_type: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    stmt = select(KnowledgeLayer).order_by(KnowledgeLayer.priority.desc())
    if layer_type:
        stmt = stmt.where(KnowledgeLayer.layer_type == layer_type)
    result = await db.execute(stmt)
    return [KnowledgeLayerResponse.model_validate(rec) for rec in result.scalars().all()]


@router.get("/layers/{layer_id}", response_model=KnowledgeLayerResponse)
async def get_knowledge_layer(
    layer_id: int,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(KnowledgeLayer).where(KnowledgeLayer.id == layer_id))
    layer = result.scalar_one_or_none()
    if not layer:
        raise HTTPException(status_code=404, detail="Knowledge layer not found")
    return KnowledgeLayerResponse.model_validate(layer)


# ─── Knowledge Documents ─────────────────────────────────────────


@router.post("/layers/{layer_id}/documents", response_model=KnowledgeDocumentResponse)
async def create_knowledge_document(
    layer_id: int,
    payload: KnowledgeDocumentCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(KnowledgeLayer).where(KnowledgeLayer.id == layer_id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Knowledge layer not found")

    doc = KnowledgeDocument(
        layer_id=layer_id,
        title=payload.title,
        content=payload.content,
        doc_type=payload.doc_type,
        tags=payload.tags,
        uploaded_by=user.id,
    )
    db.add(doc)
    await db.commit()
    await db.refresh(doc)
    return KnowledgeDocumentResponse.model_validate(doc)


@router.get("/layers/{layer_id}/documents", response_model=list[KnowledgeDocumentResponse])
async def list_knowledge_documents(
    layer_id: int,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(KnowledgeDocument)
        .where(KnowledgeDocument.layer_id == layer_id)
        .order_by(KnowledgeDocument.created_at.desc())
    )
    return [KnowledgeDocumentResponse.model_validate(d) for d in result.scalars().all()]


# ─── Institutional Knowledge ─────────────────────────────────────


@router.post("/institutional", response_model=InstitutionKnowledgeResponse)
async def create_institutional_knowledge(
    payload: InstitutionKnowledgeCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ik = InstitutionKnowledge(
        course_id=payload.course_id,
        title=payload.title,
        content=payload.content,
        doc_type=payload.doc_type,
        access_level=payload.access_level,
        is_ai_exclusive=payload.is_ai_exclusive,
        uploaded_by=user.id,
    )
    db.add(ik)
    await db.commit()
    await db.refresh(ik)
    return InstitutionKnowledgeResponse.model_validate(ik)


@router.get("/institutional", response_model=list[InstitutionKnowledgeResponse])
async def list_institutional_knowledge(
    course_id: int | None = None,
    db: AsyncSession = Depends(get_db),
):
    stmt = select(InstitutionKnowledge).order_by(InstitutionKnowledge.created_at.desc())
    if course_id is not None:
        stmt = stmt.where(InstitutionKnowledge.course_id == course_id)
    result = await db.execute(stmt)
    return [InstitutionKnowledgeResponse.model_validate(ik) for ik in result.scalars().all()]


# ─── Context Query ───────────────────────────────────────────────


@router.post("/query", response_model=ContextQueryResponse)
async def query_knowledge_layers(
    payload: ContextQueryRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    keywords = [w.strip().lower() for w in payload.question.split() if len(w.strip()) > 2]

    layers_used: list[str] = []
    sources: list[str] = []
    matched_contents: list[str] = []

    layer_stmt = select(KnowledgeLayer).where(KnowledgeLayer.is_active == True)  # noqa: E712
    if payload.layer_type:
        layer_stmt = layer_stmt.where(KnowledgeLayer.layer_type == payload.layer_type)
    if payload.course_id is not None:
        layer_stmt = layer_stmt.where(KnowledgeLayer.course_id == payload.course_id)

    layer_result = await db.execute(layer_stmt)
    layers = layer_result.scalars().all()

    for layer in layers:
        doc_stmt = select(KnowledgeDocument).where(KnowledgeDocument.layer_id == layer.id)
        doc_result = await db.execute(doc_stmt)
        docs = doc_result.scalars().all()

        for doc in docs:
            searchable = f"{doc.title} {doc.content or ''} {doc.tags or ''}".lower()
            if any(kw in searchable for kw in keywords):
                layers_used.append(layer.name)
                sources.append(doc.title)
                if doc.content:
                    matched_contents.append(doc.content)

    if payload.use_institutional:
        inst_stmt = select(InstitutionKnowledge)
        if payload.course_id is not None:
            inst_stmt = inst_stmt.where(InstitutionKnowledge.course_id == payload.course_id)
        inst_result = await db.execute(inst_stmt)
        for ik in inst_result.scalars().all():
            searchable = f"{ik.title} {ik.content} {ik.doc_type}".lower()
            if any(kw in searchable for kw in keywords):
                layers_used.append(f"institutional:{ik.doc_type}")
                sources.append(ik.title)
                matched_contents.append(ik.content)

    unique_layers = list(dict.fromkeys(layers_used))
    unique_sources = list(dict.fromkeys(sources))

    answer = "\n\n".join(matched_contents) if matched_contents else "No matching knowledge found for the given query."

    return ContextQueryResponse(
        answer=answer,
        sources=unique_sources,
        layers_used=unique_layers,
    )
