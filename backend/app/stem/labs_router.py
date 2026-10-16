import json

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.models.stem import STLabActivity

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])

_SUBJECT_NAMES = {
    "physics": "Physics",
    "chemistry": "Chemistry",
    "biology": "Biology",
    "agriculture": "Agriculture",
    "computer-science": "Computer Science",
    "mathematics": "Mathematics",
}


def _parse_steps(steps: str | None) -> list[str] | None:
    if not steps:
        return None
    try:
        parsed = json.loads(steps)
    except (json.JSONDecodeError, TypeError):
        return [steps]
    if isinstance(parsed, list):
        return [str(item) for item in parsed]
    return [str(parsed)]


def _parse_materials(materials: str | None) -> list[str] | None:
    if not materials:
        return None
    return [part.strip() for part in materials.split(",") if part.strip()]


class LabActivityResponse(BaseModel):
    id: int
    subject_slug: str
    subject: str | None = None
    title: str
    description: str | None
    lab_type: str
    instructions: str | None
    materials_needed: str | None
    materials: list[str] | None = None
    steps: list[str] | None = None
    expected_outcome: str | None
    difficulty: str
    duration_minutes: int | None
    duration: int | None = None
    is_published: bool


def _lab_to_response(lab: STLabActivity) -> LabActivityResponse:
    return LabActivityResponse(
        id=lab.id,
        subject_slug=lab.subject_slug,
        subject=_SUBJECT_NAMES.get(
            lab.subject_slug, lab.subject_slug.replace("-", " ").title()
        ),
        title=lab.title,
        description=lab.description,
        lab_type=lab.lab_type,
        instructions=lab.instructions,
        materials_needed=lab.materials_needed,
        materials=_parse_materials(lab.materials_needed),
        steps=_parse_steps(lab.steps),
        expected_outcome=lab.expected_outcome,
        difficulty=lab.difficulty,
        duration_minutes=lab.duration_minutes,
        duration=lab.duration_minutes,
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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Lab activity not found"
        )
    return _lab_to_response(lab)
