from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user, require_admin
from app.models.models import Course, Enrollment, Institution, User

router = APIRouter(prefix="/institutions", tags=["Institutions"])


class InstitutionCreate(BaseModel):
    name: str
    code: str
    description: str | None = None
    website: str | None = None
    logo_url: str | None = None
    country: str = "Malawi"
    city: str | None = None


class InstitutionUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    website: str | None = None
    logo_url: str | None = None
    country: str | None = None
    city: str | None = None
    is_active: bool | None = None


@router.get("/")
async def list_institutions(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Institution).order_by(Institution.name))
    institutions = result.scalars().all()
    return [
        {
            "id": inst.id,
            "name": inst.name,
            "code": inst.code,
            "description": inst.description,
            "website": inst.website,
            "logo_url": inst.logo_url,
            "country": inst.country,
            "city": inst.city,
            "is_active": inst.is_active,
        }
        for inst in institutions
    ]


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_institution(
    body: InstitutionCreate,
    user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(select(Institution).where(Institution.code == body.code))
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Institution with this code already exists",
        )

    institution = Institution(**body.model_dump())
    db.add(institution)
    await db.commit()
    await db.refresh(institution)

    return {
        "id": institution.id,
        "name": institution.name,
        "code": institution.code,
        "description": institution.description,
        "website": institution.website,
        "country": institution.country,
        "city": institution.city,
        "is_active": institution.is_active,
    }


@router.get("/{institution_id}")
async def get_institution(
    institution_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Institution).where(Institution.id == institution_id))
    institution = result.scalar_one_or_none()
    if not institution:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Institution not found")

    return {
        "id": institution.id,
        "name": institution.name,
        "code": institution.code,
        "description": institution.description,
        "website": institution.website,
        "logo_url": institution.logo_url,
        "country": institution.country,
        "city": institution.city,
        "is_active": institution.is_active,
        "created_at": institution.created_at.isoformat(),
    }


@router.put("/{institution_id}")
async def update_institution(
    institution_id: int,
    body: InstitutionUpdate,
    user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Institution).where(Institution.id == institution_id))
    institution = result.scalar_one_or_none()
    if not institution:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Institution not found")

    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(institution, key, value)

    await db.commit()
    await db.refresh(institution)

    return {
        "id": institution.id,
        "name": institution.name,
        "code": institution.code,
        "description": institution.description,
        "website": institution.website,
        "country": institution.country,
        "city": institution.city,
        "is_active": institution.is_active,
    }


@router.get("/{institution_id}/stats")
async def institution_stats(
    institution_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Institution).where(Institution.id == institution_id))
    institution = result.scalar_one_or_none()
    if not institution:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Institution not found")

    user_count_result = await db.execute(select(func.count(User.id)).where(User.institution == institution.name))
    user_count = user_count_result.scalar() or 0

    course_count_result = await db.execute(select(func.count(Course.id)))
    course_count = course_count_result.scalar() or 0

    active_students_result = await db.execute(select(func.count(Enrollment.id)).where(Enrollment.is_active == True))
    active_students = active_students_result.scalar() or 0

    return {
        "institution_id": institution.id,
        "name": institution.name,
        "user_count": user_count,
        "course_count": course_count,
        "active_students": active_students,
    }
