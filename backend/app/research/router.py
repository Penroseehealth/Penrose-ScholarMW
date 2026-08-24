from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import (
    EvidenceCard,
    EvidenceMatrix,
    ResearchNote,
    ResearchProject,
    User,
)
from app.schemas.research import (
    LiteratureSearchRequest,
    ResearchNoteCreate,
    ResearchNoteResponse,
    ResearchProjectCreate,
    ResearchProjectResponse,
)


# ── Evidence Card schemas ────────────────────────────────────────────
class EvidenceCardCreate(BaseModel):
    paper_title: str
    authors: str | None = None
    year: int | None = None
    doi: str | None = None
    study_design: str | None = None
    population: str | None = None
    sample_size: str | None = None
    setting: str | None = None
    exposure: str | None = None
    outcome: str | None = None
    main_finding: str | None = None
    limitations: str | None = None
    conclusions: str | None = None
    is_verified: bool = False


class EvidenceCardUpdate(BaseModel):
    paper_title: str | None = None
    authors: str | None = None
    year: int | None = None
    doi: str | None = None
    study_design: str | None = None
    population: str | None = None
    sample_size: str | None = None
    setting: str | None = None
    exposure: str | None = None
    outcome: str | None = None
    main_finding: str | None = None
    limitations: str | None = None
    conclusions: str | None = None
    is_verified: bool | None = None


class EvidenceCardResponse(BaseModel):
    id: int
    project_id: int
    paper_title: str
    authors: str | None = None
    year: int | None = None
    doi: str | None = None
    study_design: str | None = None
    population: str | None = None
    sample_size: str | None = None
    setting: str | None = None
    exposure: str | None = None
    outcome: str | None = None
    main_finding: str | None = None
    limitations: str | None = None
    conclusions: str | None = None
    is_verified: bool
    created_at: str

    model_config = {"from_attributes": True}


# ── Evidence Matrix schemas ──────────────────────────────────────────
class EvidenceMatrixCreate(BaseModel):
    title: str
    columns_config: str | None = None


class EvidenceMatrixResponse(BaseModel):
    id: int
    project_id: int
    title: str
    columns_config: str | None = None
    created_at: str

    model_config = {"from_attributes": True}


router = APIRouter(prefix="/research", tags=["Research Intelligence Lab"])


@router.get("/projects", response_model=list[ResearchProjectResponse])
async def list_projects(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(ResearchProject).where(ResearchProject.owner_id == user.id))
    return [ResearchProjectResponse.model_validate(p) for p in result.scalars().all()]


@router.post(
    "/projects",
    response_model=ResearchProjectResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_project(
    body: ResearchProjectCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    project = ResearchProject(**body.model_dump(), owner_id=user.id)
    db.add(project)
    await db.commit()
    await db.refresh(project)
    return ResearchProjectResponse.model_validate(project)


@router.get("/projects/{project_id}", response_model=ResearchProjectResponse)
async def get_project(
    project_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ResearchProject).where(ResearchProject.id == project_id, ResearchProject.owner_id == user.id)
    )
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    return ResearchProjectResponse.model_validate(project)


@router.get("/projects/{project_id}/notes", response_model=list[ResearchNoteResponse])
async def list_notes(
    project_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(ResearchNote).where(ResearchNote.project_id == project_id))
    return [ResearchNoteResponse.model_validate(n) for n in result.scalars().all()]


@router.post(
    "/projects/{project_id}/notes",
    response_model=ResearchNoteResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_note(
    project_id: int,
    body: ResearchNoteCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    note = ResearchNote(project_id=project_id, **body.model_dump())
    db.add(note)
    await db.commit()
    await db.refresh(note)
    return ResearchNoteResponse.model_validate(note)


@router.post("/literature-search")
async def search_literature(
    body: LiteratureSearchRequest,
    user: User = Depends(get_current_user),
):
    try:
        import httpx

        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.get(
                "https://api.openalex.org/works",
                params={"search": body.query, "per_page": body.max_results},
            )
            data = resp.json()
            results = []
            for work in data.get("results", []):
                results.append(
                    {
                        "title": work.get("title", ""),
                        "authors": ", ".join(
                            a.get("author", {}).get("display_name", "") for a in work.get("authorships", [])[:5]
                        ),
                        "abstract": work.get("abstract_inverted_index", {})
                        if isinstance(work.get("abstract_inverted_index"), str)
                        else "",
                        "year": work.get("publication_year", 0),
                        "doi": work.get("doi"),
                        "source": work.get("primary_location", {}).get("source", {}).get("display_name", "")
                        if work.get("primary_location")
                        else "",
                        "relevance_score": work.get("relevance_score", 0.0),
                    }
                )
            return results
    except Exception:
        return []


# ── Evidence Cards ───────────────────────────────────────────────────


@router.get(
    "/projects/{project_id}/evidence-cards",
    response_model=list[EvidenceCardResponse],
)
async def list_evidence_cards(
    project_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ResearchProject).where(ResearchProject.id == project_id, ResearchProject.owner_id == user.id)
    )
    if result.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    cards = await db.execute(
        select(EvidenceCard).where(EvidenceCard.project_id == project_id).order_by(EvidenceCard.created_at.desc())
    )
    return [EvidenceCardResponse.model_validate(c) for c in cards.scalars().all()]


@router.post(
    "/projects/{project_id}/evidence-cards",
    response_model=EvidenceCardResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_evidence_card(
    project_id: int,
    body: EvidenceCardCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ResearchProject).where(ResearchProject.id == project_id, ResearchProject.owner_id == user.id)
    )
    if result.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    card = EvidenceCard(project_id=project_id, **body.model_dump())
    db.add(card)
    await db.commit()
    await db.refresh(card)
    return EvidenceCardResponse.model_validate(card)


@router.put("/evidence-cards/{card_id}", response_model=EvidenceCardResponse)
async def update_evidence_card(
    card_id: int,
    body: EvidenceCardUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(EvidenceCard).where(EvidenceCard.id == card_id))
    card = result.scalar_one_or_none()
    if card is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Evidence card not found")
    owner_check = await db.execute(
        select(ResearchProject).where(
            ResearchProject.id == card.project_id,
            ResearchProject.owner_id == user.id,
        )
    )
    if owner_check.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(card, field, value)
    await db.commit()
    await db.refresh(card)
    return EvidenceCardResponse.model_validate(card)


@router.delete("/evidence-cards/{card_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_evidence_card(
    card_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(EvidenceCard).where(EvidenceCard.id == card_id))
    card = result.scalar_one_or_none()
    if card is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Evidence card not found")
    owner_check = await db.execute(
        select(ResearchProject).where(
            ResearchProject.id == card.project_id,
            ResearchProject.owner_id == user.id,
        )
    )
    if owner_check.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    await db.delete(card)
    await db.commit()


# ── Evidence Matrices ────────────────────────────────────────────────


@router.get(
    "/projects/{project_id}/evidence-matrices",
    response_model=list[EvidenceMatrixResponse],
)
async def list_evidence_matrices(
    project_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ResearchProject).where(ResearchProject.id == project_id, ResearchProject.owner_id == user.id)
    )
    if result.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    matrices = await db.execute(
        select(EvidenceMatrix).where(EvidenceMatrix.project_id == project_id).order_by(EvidenceMatrix.created_at.desc())
    )
    return [EvidenceMatrixResponse.model_validate(m) for m in matrices.scalars().all()]


@router.post(
    "/projects/{project_id}/evidence-matrices",
    response_model=EvidenceMatrixResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_evidence_matrix(
    project_id: int,
    body: EvidenceMatrixCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ResearchProject).where(ResearchProject.id == project_id, ResearchProject.owner_id == user.id)
    )
    if result.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    matrix = EvidenceMatrix(project_id=project_id, **body.model_dump())
    db.add(matrix)
    await db.commit()
    await db.refresh(matrix)
    return EvidenceMatrixResponse.model_validate(matrix)


@router.delete("/evidence-matrices/{matrix_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_evidence_matrix(
    matrix_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(EvidenceMatrix).where(EvidenceMatrix.id == matrix_id))
    matrix = result.scalar_one_or_none()
    if matrix is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Evidence matrix not found")
    owner_check = await db.execute(
        select(ResearchProject).where(
            ResearchProject.id == matrix.project_id,
            ResearchProject.owner_id == user.id,
        )
    )
    if owner_check.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    await db.delete(matrix)
    await db.commit()
