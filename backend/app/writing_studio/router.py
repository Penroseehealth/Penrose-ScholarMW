import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config.settings import get_settings
from app.config.stem_latex import STEM_LATEX_INSTRUCTION, VISUAL_GENERATION_POLICY
from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import (
    Citation,
    ReferenceCollection,
    User,
    WritingProject,
    WritingSection,
)
from app.schemas.writing import (
    BibliographyGenerateRequest,
    BibliographyGenerateResponse,
    CitationCreate,
    CitationResponse,
    ReferenceCollectionCreate,
    ReferenceCollectionResponse,
    WritingAssistRequest,
    WritingAssistResponse,
    WritingProjectCreate,
    WritingProjectResponse,
    WritingSectionCreate,
    WritingSectionResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/writing", tags=["Academic Writing Studio"])
settings = get_settings()


# ── helpers ──────────────────────────────────────────────────────────────


def _format_apa(c: Citation) -> str:
    authors = c.authors or "Unknown"
    year = c.year or "n.d."
    base = f"{authors} ({year}). {c.title}."
    if c.journal:
        jp = c.journal
        if c.volume:
            jp += f", {c.volume}"
        if c.pages:
            jp += f", {c.pages}"
        base = f"{authors} ({year}). {c.title}. {jp}."
    return base


def _format_vancouver(c: Citation) -> str:
    authors = c.authors or "Unknown"
    base = f"{authors}. {c.title}."
    if c.journal:
        jp = c.journal
        if c.year:
            jp += f". {c.year}"
        if c.volume:
            jp += f";{c.volume}"
        if c.pages:
            jp += f":{c.pages}"
        base = f"{authors}. {c.title}. {jp}."
    return base


def _format_harvard(c: Citation) -> str:
    authors = c.authors or "Unknown"
    year = c.year or "n.d."
    base = f"{authors} ({year}) '{c.title}',"
    if c.journal:
        jp = c.journal
        if c.volume:
            jp += f", {c.volume}"
        if c.pages:
            jp += f", pp. {c.pages}"
        base = f"{authors} ({year}) '{c.title}', {jp}."
    return base


def _format_mla(c: Citation) -> str:
    authors = c.authors or "Unknown"
    base = f"{authors}. '{c.title}.'"
    if c.journal:
        jp = c.journal
        if c.volume:
            jp += f", vol. {c.volume}"
        if c.year:
            jp += f", {c.year}"
        if c.pages:
            jp += f", pp. {c.pages}"
        base = f"{authors}. '{c.title}.' {jp}."
    return base


FORMATTERS = {
    "apa": _format_apa,
    "vancouver": _format_vancouver,
    "harvard": _format_harvard,
    "mla": _format_mla,
}


# ── Writing Studio endpoints ─────────────────────────────────────────────


@router.post(
    "/projects",
    response_model=WritingProjectResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_project(
    body: WritingProjectCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = WritingProject(
        owner_id=current_user.id,
        title=body.title,
        project_type=body.project_type,
    )
    db.add(project)
    await db.commit()
    await db.refresh(project)
    return project


@router.get("/projects", response_model=list[WritingProjectResponse])
async def list_projects(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(WritingProject).where(WritingProject.owner_id == current_user.id)
    )
    return result.scalars().all()


@router.get("/projects/{project_id}", response_model=WritingProjectResponse)
async def get_project(
    project_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(WritingProject)
        .options(selectinload(WritingProject.sections))
        .where(WritingProject.id == project_id)
    )
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    if project.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    return project


@router.put("/projects/{project_id}", response_model=WritingProjectResponse)
async def update_project(
    project_id: int,
    body: WritingProjectCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(WritingProject).where(WritingProject.id == project_id)
    )
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    if project.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    project.title = body.title
    project.project_type = body.project_type
    await db.commit()
    await db.refresh(project)
    return project


@router.delete("/projects/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_project(
    project_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(WritingProject).where(WritingProject.id == project_id)
    )
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    if project.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    await db.delete(project)
    await db.commit()


@router.post(
    "/projects/{project_id}/sections",
    response_model=WritingSectionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_section(
    project_id: int,
    body: WritingSectionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(WritingProject).where(WritingProject.id == project_id)
    )
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    if project.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    word_count = len(body.content.split()) if body.content else 0
    section = WritingSection(
        project_id=project_id,
        title=body.title,
        section_type=body.section_type,
        content=body.content,
        order=body.order,
        word_count=word_count,
    )
    db.add(section)
    await db.commit()
    await db.refresh(section)
    return section


@router.put("/sections/{section_id}", response_model=WritingSectionResponse)
async def update_section(
    section_id: int,
    body: WritingSectionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(WritingSection)
        .join(WritingProject)
        .where(WritingSection.id == section_id)
    )
    section = result.scalar_one_or_none()
    if not section:
        raise HTTPException(status_code=404, detail="Section not found")
    if section.project.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    section.title = body.title
    section.section_type = body.section_type
    section.content = body.content
    section.order = body.order
    section.word_count = len(body.content.split()) if body.content else 0
    await db.commit()
    await db.refresh(section)
    return section


@router.delete("/sections/{section_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_section(
    section_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(WritingSection)
        .join(WritingProject)
        .where(WritingSection.id == section_id)
    )
    section = result.scalar_one_or_none()
    if not section:
        raise HTTPException(status_code=404, detail="Section not found")
    if section.project.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    await db.delete(section)
    await db.commit()


@router.post("/assist", response_model=WritingAssistResponse)
async def writing_assist(
    body: WritingAssistRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(WritingSection)
        .join(WritingProject)
        .where(WritingSection.id == body.section_id)
    )
    section = result.scalar_one_or_none()
    if not section:
        raise HTTPException(status_code=404, detail="Section not found")
    if section.project.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    content = body.content or section.content or ""

    try:
        from app.config.ai_client import AIProviderError, call_ai_text

        system_prompt = (
            "You are an academic writing assistant. "
            "Provide specific, actionable suggestions to improve academic writing. "
            "Focus on clarity, grammar, structure, and scholarly tone."
            + STEM_LATEX_INSTRUCTION
            + VISUAL_GENERATION_POLICY
        )
        user_msg = f"Action: {body.action}\n\nContent:\n{content}"
        text = await call_ai_text(
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_msg},
            ],
            temperature=0.7,
            max_tokens=1500,
        )
        suggestions = [s.strip() for s in text.split("\n") if s.strip()]
        return WritingAssistResponse(
            suggestions=suggestions[:10],
            improved_text=(
                text
                if body.action in ("improve_grammar", "improve_tone", "paraphrase")
                else None
            ),
            analysis=(
                text if body.action in ("suggest_structure", "identify_gaps") else None
            ),
        )
    except (AIProviderError, RuntimeError, TimeoutError, OSError):
        logger.exception("AI call failed for writing assist")

    placeholder_map = {
        "improve_grammar": [
            "Consider using the active voice instead of passive constructions.",
            "Ensure subject-verb agreement throughout the paragraph.",
            "Replace informal contractions with formal equivalents.",
        ],
        "improve_tone": [
            "Use more hedging language (e.g., 'suggests' instead of 'proves').",
            "Avoid first-person pronouns in favour of impersonal constructions.",
            "Ensure claims are supported by citing relevant literature.",
        ],
        "suggest_structure": [
            "Consider adding a topic sentence to introduce the paragraph's main idea.",
            "Group related ideas into cohesive paragraphs.",
            "Add transition sentences between sections for better flow.",
        ],
        "identify_gaps": [
            "The argument lacks empirical support; consider citing recent studies.",
            "Counter-arguments should be addressed to strengthen the analysis.",
            "The conclusion does not fully echo the thesis statement.",
        ],
        "paraphrase": [
            "Try restructuring sentences to convey the same meaning in different words.",
            "Use synonyms while preserving the original intent.",
            "Break long compound sentences into shorter, clearer ones.",
        ],
    }
    suggestions = placeholder_map.get(
        body.action,
        [
            "Review the text for clarity and coherence.",
            "Ensure all claims are properly cited.",
            "Check for consistent use of terminology.",
        ],
    )

    return WritingAssistResponse(
        suggestions=suggestions,
        improved_text=None,
        analysis=None,
    )


# ── Reference Manager endpoints ──────────────────────────────────────────


@router.post(
    "/references/collections",
    response_model=ReferenceCollectionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_reference_collection(
    body: ReferenceCollectionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    collection = ReferenceCollection(
        owner_id=current_user.id,
        name=body.name,
        description=body.description,
    )
    db.add(collection)
    await db.commit()
    await db.refresh(collection)
    return collection


@router.get(
    "/references/collections",
    response_model=list[ReferenceCollectionResponse],
)
async def list_reference_collections(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(ReferenceCollection).where(
            ReferenceCollection.owner_id == current_user.id
        )
    )
    return result.scalars().all()


@router.delete(
    "/references/collections/{collection_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_reference_collection(
    collection_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(ReferenceCollection).where(ReferenceCollection.id == collection_id)
    )
    collection = result.scalar_one_or_none()
    if not collection:
        raise HTTPException(status_code=404, detail="Collection not found")
    if collection.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    await db.delete(collection)
    await db.commit()


@router.post(
    "/references/citations",
    response_model=CitationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_citation(
    body: CitationCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(ReferenceCollection).where(ReferenceCollection.id == body.collection_id)
    )
    collection = result.scalar_one_or_none()
    if not collection:
        raise HTTPException(status_code=404, detail="Collection not found")
    if collection.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    citation = Citation(
        collection_id=body.collection_id,
        title=body.title,
        authors=body.authors,
        year=body.year,
        doi=body.doi,
        journal=body.journal,
        volume=body.volume,
        pages=body.pages,
        url=body.url,
        citation_style=body.citation_style,
        tags=body.tags,
        notes=body.notes,
    )
    db.add(citation)
    await db.commit()
    await db.refresh(citation)
    return citation


@router.get("/references/citations", response_model=list[CitationResponse])
async def list_citations(
    collection_id: int | None = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = (
        select(Citation)
        .join(ReferenceCollection)
        .where(ReferenceCollection.owner_id == current_user.id)
    )
    if collection_id is not None:
        stmt = stmt.where(Citation.collection_id == collection_id)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.put(
    "/references/citations/{citation_id}",
    response_model=CitationResponse,
)
async def update_citation(
    citation_id: int,
    body: CitationCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Citation).join(ReferenceCollection).where(Citation.id == citation_id)
    )
    citation = result.scalar_one_or_none()
    if not citation:
        raise HTTPException(status_code=404, detail="Citation not found")
    if citation.collection.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    citation.collection_id = body.collection_id
    citation.title = body.title
    citation.authors = body.authors
    citation.year = body.year
    citation.doi = body.doi
    citation.journal = body.journal
    citation.volume = body.volume
    citation.pages = body.pages
    citation.url = body.url
    citation.citation_style = body.citation_style
    citation.tags = body.tags
    citation.notes = body.notes
    await db.commit()
    await db.refresh(citation)
    return citation


@router.delete(
    "/references/citations/{citation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_citation(
    citation_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Citation).join(ReferenceCollection).where(Citation.id == citation_id)
    )
    citation = result.scalar_one_or_none()
    if not citation:
        raise HTTPException(status_code=404, detail="Citation not found")
    if citation.collection.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    await db.delete(citation)
    await db.commit()


@router.post(
    "/references/bibliography",
    response_model=BibliographyGenerateResponse,
)
async def generate_bibliography(
    body: BibliographyGenerateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(ReferenceCollection).where(ReferenceCollection.id == body.collection_id)
    )
    collection = result.scalar_one_or_none()
    if not collection:
        raise HTTPException(status_code=404, detail="Collection not found")
    if collection.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    stmt = select(Citation).where(Citation.collection_id == body.collection_id)
    citations_result = await db.execute(stmt)
    citations = citations_result.scalars().all()

    style = body.style.lower()
    formatter = FORMATTERS.get(style, _format_apa)
    entries = [formatter(c) for c in citations]

    return BibliographyGenerateResponse(
        entries=entries,
        style=style,
        count=len(entries),
    )
