from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.models.stem import STEMCareerPath

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class CareerPathResponse(BaseModel):
    id: int
    subject_slug: str
    career_title: str
    description: str | None
    required_subjects: str | None
    recommended_skills: str | None
    related_programmes: str | None
    competencies: str | None
    icon: str | None


def _career_to_response(c: STEMCareerPath) -> CareerPathResponse:
    return CareerPathResponse(
        id=c.id,
        subject_slug=c.subject_slug,
        career_title=c.career_title,
        description=c.description,
        required_subjects=c.required_subjects,
        recommended_skills=c.recommended_skills,
        related_programmes=c.related_programmes,
        competencies=c.competencies,
        icon=c.icon,
    )


@router.get("/careers", response_model=list[CareerPathResponse])
async def list_careers(
    subject_slug: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(STEMCareerPath)
    if subject_slug:
        stmt = stmt.where(STEMCareerPath.subject_slug == subject_slug)
    stmt = stmt.order_by(STEMCareerPath.career_title)
    result = await db.execute(stmt)
    return [_career_to_response(c) for c in result.scalars().all()]


@router.get("/careers/{id}", response_model=CareerPathResponse)
async def get_career(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(STEMCareerPath).where(STEMCareerPath.id == id))
    career = result.scalar_one_or_none()
    if not career:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Career path not found")
    return _career_to_response(career)


@router.get("/careers/subject/{slug}", response_model=list[CareerPathResponse])
async def get_careers_for_subject(slug: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(STEMCareerPath).where(STEMCareerPath.subject_slug == slug).order_by(STEMCareerPath.career_title)
    )
    return [_career_to_response(c) for c in result.scalars().all()]
