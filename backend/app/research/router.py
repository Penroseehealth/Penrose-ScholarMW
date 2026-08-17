from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import ResearchNote, ResearchProject, User
from app.schemas.research import (
    LiteratureSearchRequest,
    ResearchNoteCreate,
    ResearchNoteResponse,
    ResearchProjectCreate,
    ResearchProjectResponse,
)

router = APIRouter(prefix="/research", tags=["Research Intelligence Lab"])


@router.get("/projects", response_model=list[ResearchProjectResponse])
async def list_projects(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ResearchProject).where(ResearchProject.owner_id == user.id)
    )
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
        select(ResearchProject).where(
            ResearchProject.id == project_id, ResearchProject.owner_id == user.id
        )
    )
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Project not found"
        )
    return ResearchProjectResponse.model_validate(project)


@router.get("/projects/{project_id}/notes", response_model=list[ResearchNoteResponse])
async def list_notes(
    project_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ResearchNote).where(ResearchNote.project_id == project_id)
    )
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
                            a.get("author", {}).get("display_name", "")
                            for a in work.get("authorships", [])[:5]
                        ),
                        "abstract": work.get("abstract_inverted_index", {})
                        if isinstance(work.get("abstract_inverted_index"), str)
                        else "",
                        "year": work.get("publication_year", 0),
                        "doi": work.get("doi"),
                        "source": work.get("primary_location", {})
                        .get("source", {})
                        .get("display_name", "")
                        if work.get("primary_location")
                        else "",
                        "relevance_score": work.get("relevance_score", 0.0),
                    }
                )
            return results
    except Exception:
        return []
