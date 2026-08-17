import json

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config.settings import get_settings
from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import ChatMessage, ChatSession, User
from app.schemas.ai import (
    AssessmentGenerateRequest,
    ChatMessageResponse,
    ChatRequest,
    ChatSessionDetail,
    ChatSessionResponse,
    LessonPlanRequest,
    LessonPlanResponse,
    StudyPlanRequest,
    StudyPlanResponse,
)

router = APIRouter(prefix="/ai", tags=["ScholarAI"])
settings = get_settings()


def _build_system_prompt(agent_type: str) -> str:
    prompts = {
        "tutor": (
            "You are ScholarAI Tutor, an expert academic tutor for Malawian university students. "
            "Explain concepts clearly, use analogies, provide examples, and use Socratic questioning. "
            "Adapt explanation level to the student's year of study."
        ),
        "study_coach": (
            "You are ScholarAI Study Coach. Create personalized study plans, identify weak areas, "
            "track progress, and recommend resources tailored to Malawian university curricula."
        ),
        "writer": (
            "You are ScholarAI Academic Writer. Help structure assignments, improve academic language, "
            "generate outlines, provide citation guidance, and detect unsupported claims."
        ),
        "research": (
            "You are ScholarAI Research Assistant. Search literature, summarize papers, extract "
            "methodologies, compare studies, and build evidence tables for academic research."
        ),
        "assessment": (
            "You are ScholarAI Assessment Generator. Create questions of various types, generate "
            "marking schemes, map questions to learning outcomes, and adjust difficulty levels."
        ),
        "lesson_builder": (
            "You are ScholarAI Lesson Builder. Generate comprehensive lesson plans with objectives, "
            "structure, activities, case studies, discussion questions, quizzes, and references."
        ),
    }
    return prompts.get(agent_type, prompts["tutor"])


async def _call_llm(system_prompt: str, messages: list[dict]) -> str:
    try:
        from openai import AsyncOpenAI

        client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
        response = await client.chat.completions.create(
            model=settings.OPENAI_MODEL,
            messages=[{"role": "system", "content": system_prompt}] + messages,
            temperature=0.7,
            max_tokens=2000,
        )
        return response.choices[0].message.content or "I could not generate a response."
    except Exception:
        return (
            "ScholarAI is currently unavailable. Please try again later. "
            "If this persists, contact your administrator."
        )


@router.post("/chat", response_model=ChatMessageResponse)
async def chat(
    body: ChatRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    session_id = body.session_id
    if not session_id:
        session = ChatSession(
            user_id=user.id,
            agent_type=body.agent_type,
            context_course_id=body.context_course_id,
            title=body.message[:80],
        )
        db.add(session)
        await db.commit()
        await db.refresh(session)
        session_id = session.id
    else:
        result = await db.execute(
            select(ChatSession).where(ChatSession.id == session_id)
        )
        session = result.scalar_one_or_none()
        if not session or session.user_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Session not found"
            )

    user_msg = ChatMessage(session_id=session_id, role="user", content=body.message)
    db.add(user_msg)
    await db.commit()

    history_result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.id)
    )
    history = [
        {"role": m.role, "content": m.content} for m in history_result.scalars().all()
    ]

    system_prompt = _build_system_prompt(body.agent_type)
    ai_response = await _call_llm(system_prompt, history)

    ai_msg = ChatMessage(session_id=session_id, role="assistant", content=ai_response)
    db.add(ai_msg)
    await db.commit()
    await db.refresh(ai_msg)

    return ChatMessageResponse.model_validate(ai_msg)


@router.get("/sessions", response_model=list[ChatSessionResponse])
async def list_sessions(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ChatSession)
        .where(ChatSession.user_id == user.id)
        .order_by(ChatSession.updated_at.desc())
    )
    return [ChatSessionResponse.model_validate(s) for s in result.scalars().all()]


@router.get("/sessions/{session_id}", response_model=ChatSessionDetail)
async def get_session(
    session_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ChatSession)
        .options(selectinload(ChatSession.messages))
        .where(ChatSession.id == session_id, ChatSession.user_id == user.id)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Session not found"
        )
    return ChatSessionDetail.model_validate(session)


@router.post("/lesson-plan", response_model=LessonPlanResponse)
async def generate_lesson_plan(
    body: LessonPlanRequest,
    user: User = Depends(get_current_user),
):
    system = _build_system_prompt("lesson_builder")
    prompt = (
        f"Generate a {body.duration_minutes}-minute lesson plan for:\n"
        f"Topic: {body.topic}\nLevel: {body.level}\n\n"
        "Return JSON with keys: objectives, introduction, structure (list of dicts with "
        "time_minutes, activity, description), activities, case_study, discussion_questions, "
        "quiz (list of dicts with question, options, answer), homework, references."
    )
    response = await _call_llm(system, [{"role": "user", "content": prompt}])
    try:
        data = json.loads(response)
        return LessonPlanResponse(**data)
    except (json.JSONDecodeError, Exception):
        return LessonPlanResponse(
            objectives=["Understand " + body.topic],
            introduction=f"Introduction to {body.topic}",
            structure=[
                {
                    "time_minutes": body.duration_minutes,
                    "activity": "Lecture",
                    "description": body.topic,
                }
            ],
            activities=["Class discussion"],
            discussion_questions=[f"What are the key concepts in {body.topic}?"],
            quiz=[],
        )


@router.post("/generate-assessment")
async def generate_assessment(
    body: AssessmentGenerateRequest,
    user: User = Depends(get_current_user),
):
    system = _build_system_prompt("assessment")
    prompt = (
        f"Generate {body.num_questions} {body.difficulty}-difficulty questions for topic: "
        f"{body.topic}. Types: {', '.join(body.question_types)}. "
        "Return JSON with keys: questions (list with question_text, question_type, marks, "
        "options, correct_answer, learning_outcome, difficulty), marking_scheme."
    )
    response = await _call_llm(system, [{"role": "user", "content": prompt}])
    try:
        return json.loads(response)
    except json.JSONDecodeError:
        return {"questions": [], "marking_scheme": []}


@router.post("/study-plan", response_model=StudyPlanResponse)
async def generate_study_plan(
    body: StudyPlanRequest,
    user: User = Depends(get_current_user),
):
    system = _build_system_prompt("study_coach")
    prompt = (
        f"Create a study plan for course ID {body.course_id}. "
        f"Exam date: {body.exam_date or 'not set'}. Hours/day: {body.hours_per_day}. "
        "Return JSON with keys: schedule (list of dicts with date, topic, hours, activity), "
        "weak_topics, recommended_resources."
    )
    response = await _call_llm(system, [{"role": "user", "content": prompt}])
    try:
        data = json.loads(response)
        return StudyPlanResponse(**data)
    except (json.JSONDecodeError, Exception):
        return StudyPlanResponse(schedule=[], weak_topics=[], recommended_resources=[])
