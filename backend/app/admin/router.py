from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import require_admin
from app.models.models import Course, Enrollment, Submission, User, UserRole

router = APIRouter(prefix="/admin", tags=["Administration"])


@router.get("/dashboard")
async def admin_dashboard(
    user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    total_users = (await db.execute(select(func.count(User.id)))).scalar()
    total_students = (
        await db.execute(
            select(func.count(User.id)).where(User.role == UserRole.STUDENT)
        )
    ).scalar()
    total_lecturers = (
        await db.execute(
            select(func.count(User.id)).where(User.role == UserRole.LECTURER)
        )
    ).scalar()
    total_courses = (await db.execute(select(func.count(Course.id)))).scalar()
    total_enrollments = (await db.execute(select(func.count(Enrollment.id)))).scalar()
    total_submissions = (await db.execute(select(func.count(Submission.id)))).scalar()

    return {
        "total_users": total_users,
        "total_students": total_students,
        "total_lecturers": total_lecturers,
        "total_courses": total_courses,
        "total_enrollments": total_enrollments,
        "total_submissions": total_submissions,
    }


@router.get("/users")
async def list_all_users(
    user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).order_by(User.created_at.desc()))
    return [
        {
            "id": u.id,
            "email": u.email,
            "full_name": u.full_name,
            "role": u.role.value,
            "is_active": u.is_active,
            "created_at": u.created_at,
        }
        for u in result.scalars().all()
    ]


@router.put("/users/{user_id}/toggle-active")
async def toggle_user_active(
    user_id: int,
    user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    target = result.scalar_one_or_none()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    target.is_active = not target.is_active
    await db.commit()
    return {"detail": f"User {'activated' if target.is_active else 'deactivated'}"}


@router.get("/lecturer-performance")
async def lecturer_performance(
    user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.role == UserRole.LECTURER))
    lecturers = result.scalars().all()
    perf = []
    for lec in lecturers:
        courses = (
            await db.execute(
                select(func.count(Course.id)).where(Course.lecturer_id == lec.id)
            )
        ).scalar()
        perf.append(
            {
                "id": lec.id,
                "name": lec.full_name,
                "courses": courses,
            }
        )
    return perf


@router.put("/users/{user_id}/role")
async def change_user_role(
    user_id: int,
    body: dict,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    new_role = body.get("role")
    if new_role not in ["student", "lecturer", "researcher", "admin"]:
        raise HTTPException(status_code=400, detail="Invalid role")
    user.role = new_role
    await db.commit()
    return {"id": user.id, "role": user.role.value}


@router.get("/courses")
async def admin_list_courses(
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Course))
    courses = result.scalars().all()
    return [
        {
            "id": c.id,
            "code": c.code,
            "title": c.title,
            "is_active": c.is_active,
        }
        for c in courses
    ]


@router.put("/courses/{course_id}/toggle-active")
async def toggle_course_active(
    course_id: int,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Course).where(Course.id == course_id))
    course = result.scalar_one_or_none()
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")
    course.is_active = not course.is_active
    await db.commit()
    return {"id": course.id, "is_active": course.is_active}
