from datetime import datetime

from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    message: str
    session_id: int | None = None
    agent_type: str = "tutor"
    context_course_id: int | None = None
    file_ids: list[str] = Field(default_factory=list)


class ChatMessageResponse(BaseModel):
    id: int
    role: str
    content: str
    sources: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ChatSessionResponse(BaseModel):
    id: int
    title: str
    agent_type: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ChatSessionDetail(ChatSessionResponse):
    messages: list[ChatMessageResponse] = []


class LessonPlanRequest(BaseModel):
    topic: str
    level: str
    duration_minutes: int = 90
    course_id: int | None = None


class LessonPlanResponse(BaseModel):
    objectives: list[str]
    introduction: str
    structure: list[dict]
    activities: list[str]
    case_study: str | None = None
    discussion_questions: list[str]
    quiz: list[dict]
    homework: str | None = None
    references: list[str]


class AssessmentGenerateRequest(BaseModel):
    course_id: int
    topic: str
    learning_objectives: list[str] = []
    difficulty: str = "medium"
    num_questions: int = 10
    question_types: list[str] = ["mcq", "short_answer"]


class AssessmentGenerateResponse(BaseModel):
    questions: list[dict]
    marking_scheme: list[dict]


class VoiceRequest(BaseModel):
    audio_data: str
    session_id: int | None = None


class StudyPlanRequest(BaseModel):
    course_id: int
    exam_date: str | None = None
    hours_per_day: float = 2.0


class StudyPlanResponse(BaseModel):
    schedule: list[dict]
    weak_topics: list[str]
    recommended_resources: list[str]
