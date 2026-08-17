from datetime import datetime

from pydantic import BaseModel


class CourseCreate(BaseModel):
    code: str
    title: str
    description: str | None = None
    level: str | None = None
    credits: int = 3
    semester: str | None = None
    year: int | None = None


class CourseResponse(BaseModel):
    id: int
    code: str
    title: str
    description: str | None = None
    level: str | None = None
    credits: int
    semester: str | None = None
    year: int | None = None
    lecturer_id: int
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class CourseDetailResponse(CourseResponse):
    enrolled_count: int = 0
    progress_pct: float = 0.0


class EnrollmentResponse(BaseModel):
    id: int
    student_id: int
    course_id: int
    enrolled_at: datetime
    progress_pct: float
    grade: str | None = None

    model_config = {"from_attributes": True}


class ScheduleItemCreate(BaseModel):
    title: str
    item_type: str
    starts_at: datetime
    ends_at: datetime | None = None
    location: str | None = None
    recurrence: str | None = None


class ScheduleItemResponse(BaseModel):
    id: int
    course_id: int
    title: str
    item_type: str
    starts_at: datetime
    ends_at: datetime | None = None
    location: str | None = None

    model_config = {"from_attributes": True}
