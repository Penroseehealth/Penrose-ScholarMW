from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user, require_lecturer
from app.models.models import (
    Course,
    CourseModule,
    Enrollment,
    Lesson,
    ScheduleItem,
    User,
    UserRole,
)
from app.schemas.course import (
    CourseCreate,
    CourseDetailResponse,
    CourseResponse,
    EnrollmentResponse,
    ScheduleItemCreate,
    ScheduleItemResponse,
)


class ModuleCreate(BaseModel):
    title: str
    description: str | None = None
    order: int = 0


class ModuleResponse(BaseModel):
    id: int
    course_id: int
    title: str
    description: str | None
    order: int
    is_published: bool


class LessonCreate(BaseModel):
    title: str
    content_type: str = "text"
    content: str | None = None
    duration_minutes: int = 0
    order: int = 0


class LessonResponse(BaseModel):
    id: int
    module_id: int
    title: str
    content_type: str
    content: str | None
    duration_minutes: int
    order: int
    is_published: bool


router = APIRouter(prefix="/courses", tags=["Courses"])


@router.get("/", response_model=list[CourseResponse])
async def list_courses(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if user.role == UserRole.LECTURER:
        result = await db.execute(select(Course).where(Course.lecturer_id == user.id))
    elif user.role == UserRole.STUDENT:
        result = await db.execute(
            select(Course).join(Enrollment).where(Enrollment.student_id == user.id, Enrollment.is_active == True)
        )
    else:
        result = await db.execute(select(Course))
    return [CourseResponse.model_validate(c) for c in result.scalars().all()]


@router.post("/", response_model=CourseResponse, status_code=status.HTTP_201_CREATED)
async def create_course(
    body: CourseCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    course = Course(**body.model_dump(), lecturer_id=user.id)
    db.add(course)
    await db.commit()
    await db.refresh(course)
    return CourseResponse.model_validate(course)


@router.get("/{course_id}", response_model=CourseDetailResponse)
async def get_course(course_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Course).where(Course.id == course_id))
    course = result.scalar_one_or_none()
    if not course:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found")

    enroll_result = await db.execute(
        select(Enrollment).where(Enrollment.course_id == course_id, Enrollment.is_active == True)
    )
    enrollments = enroll_result.scalars().all()
    count = len(enrollments)
    avg_progress = sum(e.progress_pct for e in enrollments) / count if count else 0.0

    resp = CourseDetailResponse.model_validate(course)
    resp.enrolled_count = count
    resp.progress_pct = avg_progress
    return resp


@router.post("/{course_id}/enroll", response_model=EnrollmentResponse)
async def enroll_in_course(
    course_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(Enrollment).where(
            Enrollment.student_id == user.id,
            Enrollment.course_id == course_id,
            Enrollment.is_active == True,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already enrolled")

    enrollment = Enrollment(student_id=user.id, course_id=course_id)
    db.add(enrollment)
    await db.commit()
    await db.refresh(enrollment)
    return EnrollmentResponse.model_validate(enrollment)


@router.get("/{course_id}/schedule", response_model=list[ScheduleItemResponse])
async def get_schedule(course_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(ScheduleItem).where(ScheduleItem.course_id == course_id))
    return [ScheduleItemResponse.model_validate(s) for s in result.scalars().all()]


@router.post(
    "/{course_id}/schedule",
    response_model=ScheduleItemResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_schedule_item(
    course_id: int,
    body: ScheduleItemCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    item = ScheduleItem(course_id=course_id, **body.model_dump())
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return ScheduleItemResponse.model_validate(item)


@router.get("/{course_id}/modules", response_model=list[ModuleResponse])
async def list_modules(
    course_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(CourseModule).where(CourseModule.course_id == course_id).order_by(CourseModule.order)
    )
    return [ModuleResponse.model_validate(m) for m in result.scalars().all()]


@router.post(
    "/{course_id}/modules",
    response_model=ModuleResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_module(
    course_id: int,
    body: ModuleCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    module = CourseModule(course_id=course_id, **body.model_dump())
    db.add(module)
    await db.commit()
    await db.refresh(module)
    return ModuleResponse.model_validate(module)


@router.put("/modules/{module_id}", response_model=ModuleResponse)
async def update_module(
    module_id: int,
    body: ModuleCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(CourseModule).where(CourseModule.id == module_id))
    module = result.scalar_one_or_none()
    if not module:
        raise HTTPException(status_code=404, detail="Module not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(module, field, value)
    await db.commit()
    await db.refresh(module)
    return ModuleResponse.model_validate(module)


@router.delete("/modules/{module_id}")
async def delete_module(
    module_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(CourseModule).where(CourseModule.id == module_id))
    module = result.scalar_one_or_none()
    if not module:
        raise HTTPException(status_code=404, detail="Module not found")
    await db.delete(module)
    await db.commit()
    return {"detail": "Module deleted"}


@router.get("/modules/{module_id}/lessons", response_model=list[LessonResponse])
async def list_lessons(
    module_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    result = await db.execute(select(Lesson).where(Lesson.module_id == module_id).order_by(Lesson.order))
    return [LessonResponse.model_validate(lesson) for lesson in result.scalars().all()]


@router.post(
    "/modules/{module_id}/lessons",
    response_model=LessonResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_lesson(
    module_id: int,
    body: LessonCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    lesson = Lesson(module_id=module_id, **body.model_dump())
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)
    return LessonResponse.model_validate(lesson)


@router.put("/lessons/{lesson_id}", response_model=LessonResponse)
async def update_lesson(
    lesson_id: int,
    body: LessonCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Lesson).where(Lesson.id == lesson_id))
    lesson = result.scalar_one_or_none()
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(lesson, field, value)
    await db.commit()
    await db.refresh(lesson)
    return LessonResponse.model_validate(lesson)


@router.delete("/lessons/{lesson_id}")
async def delete_lesson(
    lesson_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Lesson).where(Lesson.id == lesson_id))
    lesson = result.scalar_one_or_none()
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")
    await db.delete(lesson)
    await db.commit()
    return {"detail": "Lesson deleted"}
