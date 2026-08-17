from pydantic import BaseModel


class StudentPerformanceResponse(BaseModel):
    id: int
    student_id: int
    course_id: int
    overall_score: float
    trend: str
    weak_areas: str | None = None
    strong_areas: str | None = None
    ai_insights: str | None = None

    model_config = {"from_attributes": True}


class CourseAnalyticsResponse(BaseModel):
    id: int
    course_id: int
    class_average: float
    attendance_pct: float
    assignment_completion: float
    difficult_topics: str | None = None
    engagement_trend: str | None = None
    ai_insights: str | None = None
    students_at_risk: str | None = None

    model_config = {"from_attributes": True}


class LearningPlanCreate(BaseModel):
    title: str
    plan_type: str = "weekly"
    start_date: str
    end_date: str


class LearningPlanItemCreate(BaseModel):
    day_of_week: str
    course_id: int | None = None
    topic: str
    activity_type: str = "study"
    duration_minutes: int = 30
    order: int = 0


class LearningPlanItemResponse(BaseModel):
    id: int
    plan_id: int
    day_of_week: str
    course_id: int | None = None
    topic: str
    activity_type: str
    duration_minutes: int
    order: int
    is_completed: bool

    model_config = {"from_attributes": True}


class LearningPlanResponse(BaseModel):
    id: int
    student_id: int
    title: str
    plan_type: str
    start_date: str
    end_date: str
    is_active: bool
    ai_generated: bool
    items: list[LearningPlanItemResponse] = []

    model_config = {"from_attributes": True}


class StudentDashboardResponse(BaseModel):
    overall_progress: float
    course_performances: list[dict]
    weak_areas: list[str]
    recommended_action: str
    upcoming_assessments: list[dict]
    weekly_plan: list[dict]


class LecturerAnalyticsResponse(BaseModel):
    course_id: int
    class_average: float
    attendance_pct: float
    assignment_completion: float
    difficult_topics: list[str]
    students_at_risk: list[dict]
    ai_insights: str
    engagement_trend: str | None = None
