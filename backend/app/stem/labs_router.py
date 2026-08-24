from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.models.stem import STLabActivity

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class LabActivityResponse(BaseModel):
    id: int
    subject_slug: str
    title: str
    description: str | None
    lab_type: str
    instructions: str | None
    materials_needed: str | None
    steps: str | None
    expected_outcome: str | None
    difficulty: str
    duration_minutes: int | None
    is_published: bool


def _lab_to_response(lab: STLabActivity) -> LabActivityResponse:
    return LabActivityResponse(
        id=lab.id,
        subject_slug=lab.subject_slug,
        title=lab.title,
        description=lab.description,
        lab_type=lab.lab_type,
        instructions=lab.instructions,
        materials_needed=lab.materials_needed,
        steps=lab.steps,
        expected_outcome=lab.expected_outcome,
        difficulty=lab.difficulty,
        duration_minutes=lab.duration_minutes,
        is_published=lab.is_published,
    )


@router.get("/labs", response_model=list[LabActivityResponse])
async def list_labs(
    subject_slug: str | None = Query(None),
    lab_type: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(STLabActivity).where(STLabActivity.is_published.is_(True))
    if subject_slug:
        stmt = stmt.where(STLabActivity.subject_slug == subject_slug)
    if lab_type:
        stmt = stmt.where(STLabActivity.lab_type == lab_type)
    stmt = stmt.order_by(STLabActivity.title)
    result = await db.execute(stmt)
    return [_lab_to_response(activity) for activity in result.scalars().all()]


@router.get("/labs/{id}", response_model=LabActivityResponse)
async def get_lab(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(STLabActivity).where(STLabActivity.id == id))
    lab = result.scalar_one_or_none()
    if not lab:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lab activity not found")
    return _lab_to_response(lab)
