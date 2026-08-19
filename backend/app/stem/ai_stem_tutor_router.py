from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.config.settings import get_settings
from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    STEMConcept,
    STEMDiscipline,
    STEMTopic,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])
settings = get_settings()


class TutorChatRequest(BaseModel):
    concept_id: int
    message: str
    mode: str


class TutorChatResponse(BaseModel):
    response: str
    concept_id: int
    mode: str


class TutorMode(BaseModel):
    mode: str
    description: str


TUTOR_MODES: list[dict[str, str]] = [
    {"mode": "explain", "description": "Get a clear explanation of the concept"},
    {"mode": "teach", "description": "Structured lesson-style teaching of the concept"},
    {"mode": "example", "description": "See worked examples illustrating the concept"},
    {
        "mode": "diagram",
        "description": "Get a text-based diagram or visual representation",
    },
    {"mode": "solve", "description": "Walk through solving a problem step by step"},
    {"mode": "hint", "description": "Get a hint without the full answer"},
    {
        "mode": "quiz",
        "description": "Test your understanding with quick quiz questions",
    },
    {"mode": "practice", "description": "Practice problems with guided steps"},
    {
        "mode": "challenge",
        "description": "Advanced challenge problems to push your limits",
    },
    {
        "mode": "simplify",
        "description": "Get a simplified, beginner-friendly explanation",
    },
    {
        "mode": "deepen",
        "description": "Go deeper into the theory and underlying principles",
    },
]

VALID_MODES = {m["mode"] for m in TUTOR_MODES}

NO_ANSWER_DIRECTLY_MODES = {"hint", "quiz", "practice", "challenge"}

MODE_INSTRUCTIONS = {
    "explain": "Provide a clear, concise explanation of the concept.",
    "teach": "Act as a structured lesson. Break the concept into parts, build progressively.",
    "example": "Provide one or more concrete worked examples showing the concept in action.",
    "diagram": "Create a text-based diagram, flowchart, or visual layout to illustrate the concept.",
    "solve": "Walk through solving a relevant problem step by step, explaining each step.",
    "hint": "Do NOT give the answer directly. Provide a guiding hint that helps the student think toward the solution.",
    "quiz": "Do NOT give the answer directly. Ask quiz questions and let the student answer. Provide feedback after they respond.",
    "practice": "Do NOT give the answer directly. Present practice problems and guide the student through the approach.",
    "challenge": "Do NOT give the answer directly. Present an advanced challenge problem and give minimal hints.",
    "simplify": "Rewrite the explanation at the simplest possible level, as if teaching a complete beginner.",
    "deepen": "Go beyond the basics. Cover underlying theory, proofs, connections to other areas, and advanced nuances.",
}


def _build_mode_footer(mode: str) -> str:
    if mode in NO_ANSWER_DIRECTLY_MODES:
        return (
            f"\n\nIMPORTANT: In {mode} mode, you must NOT give the final answer directly. "
            "Guide the student to discover the answer themselves. "
            "Only reveal the answer if the student explicitly asks after attempting."
        )
    return ""


async def _get_concept_context(concept_id: int, db: AsyncSession) -> dict:
    concept_result = await db.execute(
        select(STEMConcept)
        .options(
            joinedload(STEMConcept.subtopic)
            .joinedload(STEMTopic.discipline)
            .joinedload(STEMDiscipline.subject)
        )
        .where(STEMConcept.id == concept_id)
    )
    concept = concept_result.unique().scalar_one_or_none()
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Concept not found"
        )

    subtopic = concept.subtopic
    topic = subtopic.topic if subtopic else None
    discipline = topic.discipline if topic else None
    subject = discipline.subject if discipline else None

    return {
        "concept": concept,
        "subtopic": subtopic,
        "topic": topic,
        "discipline": discipline,
        "subject": subject,
    }


def _build_system_prompt(context: dict, mode: str) -> str:
    concept = context["concept"]
    subject = context["subject"]
    discipline = context["discipline"]
    subtopic = context["subtopic"]
    topic = context["topic"]

    parts = [
        "You are STEM Tutor, an expert AI tutor specializing in STEM education for university students.",
        "",
    ]

    if subject:
        parts.append(f"Subject: {subject.title}")
    if discipline:
        parts.append(f"Discipline: {discipline.title}")
    if topic:
        parts.append(f"Topic: {topic.title}")
    if subtopic:
        parts.append(f"Subtopic: {subtopic.title}")

    parts.append(f"\nConcept: {concept.title}")
    if concept.description:
        parts.append(f"Description: {concept.description}")
    if concept.learning_objectives_text:
        parts.append(f"Learning Objectives: {concept.learning_objectives_text}")
    if concept.prerequisites_text:
        parts.append(f"Prerequisites: {concept.prerequisites_text}")
    if concept.difficulty_level:
        parts.append(f"Difficulty Level: {concept.difficulty_level}")

    mode_instruction = MODE_INSTRUCTIONS.get(
        mode, "Provide a helpful explanation of the concept."
    )
    parts.append(f"\nCurrent interaction mode: {mode}")
    parts.append(f"Instructions for this mode: {mode_instruction}")
    parts.append(_build_mode_footer(mode))

    parts.append(
        "\n\nRespond in a helpful, encouraging tone. Use markdown formatting where appropriate."
    )

    return "\n".join(parts)


async def _call_llm(system_prompt: str, message: str) -> str:
    try:
        from openai import AsyncOpenAI

        client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
        response = await client.chat.completions.create(
            model=settings.OPENAI_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": message},
            ],
            temperature=0.7,
            max_tokens=2000,
        )
        return response.choices[0].message.content or "I could not generate a response."
    except Exception:
        return "The STEM Tutor is currently unavailable. Please try again later."


@router.post("/tutor/chat", response_model=TutorChatResponse)
async def tutor_chat(
    body: TutorChatRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.mode not in VALID_MODES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid mode '{body.mode}'. Must be one of: {', '.join(sorted(VALID_MODES))}",
        )

    context = await _get_concept_context(body.concept_id, db)
    system_prompt = _build_system_prompt(context, body.mode)
    ai_response = await _call_llm(system_prompt, body.message)

    return TutorChatResponse(
        response=ai_response,
        concept_id=body.concept_id,
        mode=body.mode,
    )


@router.get("/tutor/modes", response_model=list[TutorMode])
async def get_tutor_modes():
    return [
        TutorMode(mode=m["mode"], description=m["description"]) for m in TUTOR_MODES
    ]
