from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.config.settings import get_settings
from app.config.stem_latex import STEM_LATEX_INSTRUCTION
from app.core.subject_registry import get_subject_module
from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    MasteryRecord,
    STEMConcept,
    STEMDiscipline,
    STEMTopic,
)
from app.modules.chemistry.prompts import CHEMISTRY_AI_TEMPLATES
from app.modules.computer_science.prompts import CS_AI_TEMPLATES
from app.modules.mathematics.prompts import MATH_AI_TEMPLATES

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])
settings = get_settings()


class ChatMessage(BaseModel):
    role: str
    content: str


class TutorChatRequest(BaseModel):
    concept_id: int
    message: str
    mode: str
    history: list[ChatMessage] | None = None


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


SUBJECT_AI_TEMPLATES: dict[str, dict[str, str]] = {
    "mathematics": MATH_AI_TEMPLATES,
    "chemistry": CHEMISTRY_AI_TEMPLATES,
    "computer-science": CS_AI_TEMPLATES,
}


def _get_subject_template(
    subject_slug: str | None, mode: str, user_message: str
) -> str | None:
    if not subject_slug or subject_slug not in SUBJECT_AI_TEMPLATES:
        return None
    templates = SUBJECT_AI_TEMPLATES[subject_slug]
    if mode not in templates:
        return None
    return templates[mode].format(problem=user_message)


def _build_system_prompt(context: dict, mode: str, user_message: str) -> str:
    concept = context["concept"]
    subject = context["subject"]
    discipline = context["discipline"]
    subtopic = context["subtopic"]
    topic = context["topic"]

    subject_module = get_subject_module(subject.subject_slug) if subject else None

    parts = [
        "You are STEM Tutor, an expert AI tutor specializing in STEM education for Malawian students.",
        "",
    ]

    if subject_module:
        parts.append(f"Subject: {subject_module.title}")
        parts.append(f"Subject Icon: {subject_module.icon}")
        parts.append(f"Subject Features: {', '.join(subject_module.features)}")
    elif subject:
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

    subject_prompt = _get_subject_template(
        subject.subject_slug if subject else None, mode, user_message
    )
    if subject_prompt:
        parts.append(f"\nSubject-specific context:\n{subject_prompt}")

    mode_instruction = MODE_INSTRUCTIONS.get(
        mode, "Provide a helpful explanation of the concept."
    )
    parts.append(f"\nCurrent interaction mode: {mode}")
    parts.append(f"Instructions for this mode: {mode_instruction}")
    parts.append(_build_mode_footer(mode))

    parts.append(
        "\n\nRespond in a helpful, encouraging tone. Use markdown formatting where appropriate."
        + STEM_LATEX_INSTRUCTION
    )

    mastery = context.get("mastery")
    if mastery:
        pct = round(mastery.mastery_level * 100, 1)
        parts.append(
            f"\nStudent mastery of this concept: {pct}% "
            f"({mastery.attempts} attempts, {mastery.correct} correct)."
        )
        if mastery.mastery_level < 0.3:
            parts.append(
                "The student is struggling. Be extra patient, break things down, "
                "use very simple language, and provide lots of encouragement."
            )
        elif mastery.mastery_level < 0.6:
            parts.append(
                "The student has some understanding but needs reinforcement. "
                "Focus on common misconceptions and provide practice opportunities."
            )
        elif mastery.mastery_level < 0.8:
            parts.append(
                "The student is progressing well. Challenge them with slightly harder "
                "problems and deeper explanations."
            )
        else:
            parts.append(
                "The student has strong mastery. Push them toward advanced applications, "
                "connections to other topics, and challenge problems."
            )
    else:
        parts.append(
            "\nStudent has not practiced this concept yet. "
            "Start from fundamentals and be very thorough in explanations."
        )

    return "\n".join(parts)


async def _call_llm(
    system_prompt: str, message: str, history: list[dict] | None = None
) -> str:
    from app.config.ai_client import AIProviderError, call_ai_text

    messages: list[dict[str, str]] = [{"role": "system", "content": system_prompt}]
    if history:
        for h in history:
            role = h.get("role", "user")
            if role in ("user", "assistant"):
                messages.append({"role": role, "content": h.get("content", "")})
    messages.append({"role": "user", "content": message})
    try:
        return await call_ai_text(messages, max_tokens=2000, temperature=0.7)
    except AIProviderError as exc:
        import logging

        logging.getLogger(__name__).warning("AI call failed: %s", exc)
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

    mastery_result = await db.execute(
        select(MasteryRecord).where(
            MasteryRecord.user_id == user.id,
            MasteryRecord.concept_id == body.concept_id,
        )
    )
    mastery_record = mastery_result.scalar_one_or_none()
    context["mastery"] = mastery_record

    system_prompt = _build_system_prompt(context, body.mode, body.message)
    history_dicts = [m.model_dump() for m in body.history] if body.history else None
    ai_response = await _call_llm(system_prompt, body.message, history_dicts)

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
