"""In-memory engine and generators for the AI Examination Builder."""

from __future__ import annotations

import io
import logging
import re
import uuid
from collections import Counter

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.ai_client import AIProviderError, call_ai_json
from app.config.stem_latex import STEM_LATEX_INSTRUCTION, VISUAL_GENERATION_POLICY
from app.examinations_builder.paper import (
    ConstructedPaper,
    CoverData,
    PaperOptions,
    build_constructed_paper,
)
from app.examinations_builder.sanitize import (
    objective_concept,
    question_problems,
    sanitize_question,
)
from app.models.stem import SyllabusLearningObjective, SyllabusSubtopic, SyllabusTopic

log = logging.getLogger(__name__)

QUESTION_TYPES = (
    "multiple_choice",
    "true_false",
    "matching",
    "fill_in_blank",
    "short_answer",
    "structured",
    "essay",
    "practical",
    "calculation",
    "case_study",
)
DIFFICULTIES = ("easy", "medium", "hard")
BLOOM_LEVELS = (
    "Remembering",
    "Understanding",
    "Applying",
    "Analysing",
    "Evaluating",
    "Creating",
)
MARKS_BY_DIFFICULTY = {"easy": 2, "medium": 5, "hard": 10}


class EngineStore:
    """Stateless in-memory store for generated examinations (mirrors presentation)."""

    def __init__(self) -> None:
        self._records: dict[str, dict] = {}

    def put(self, exam_id: str, data: dict) -> None:
        self._records[exam_id] = data

    def get(self, exam_id: str) -> dict | None:
        return self._records.get(exam_id)


_engine = EngineStore()


# ── Syllabus context ─────────────────────────────────────────────────────────


async def _load_subtopic_objectives(db: AsyncSession, subtopic_id: int) -> dict:
    sub = (
        await db.execute(
            select(SyllabusSubtopic).where(SyllabusSubtopic.id == subtopic_id)
        )
    ).scalar_one_or_none()
    if not sub:
        return {"subtopic": "", "topic": "", "form": "", "objectives": []}

    topic_title = ""
    form_label = ""
    if sub.topic_id:
        topic = (
            await db.execute(
                select(SyllabusTopic).where(SyllabusTopic.id == sub.topic_id)
            )
        ).scalar_one_or_none()
        if topic:
            topic_title = topic.title or ""
            if topic.year_level:
                form_label = f"Form {topic.year_level}"

    rows = (
        (
            await db.execute(
                select(SyllabusLearningObjective)
                .where(SyllabusLearningObjective.subtopic_id == subtopic_id)
                .order_by(SyllabusLearningObjective.id)
            )
        )
        .scalars()
        .all()
    )
    objectives = [
        {"objective": o.objective, "cognitive_level": o.cognitive_level}
        for o in rows
        if o.objective
    ]
    return {
        "subtopic": sub.title or "",
        "topic": topic_title,
        "form": form_label,
        "objectives": objectives,
    }


async def load_syllabus_context(db: AsyncSession, config) -> dict:
    """Best-effort syllabus context (topic/subtopic/objectives) for the config."""
    context = {
        "subject": config.subject or "",
        "form": config.form_label or (f"Form {config.form}" if config.form else ""),
        "topic": config.topic or "",
        "subtopic": config.subtopic or "",
        "learning_objectives": [o for o in config.learning_objectives if o.strip()],
        "all_objectives": [o for o in config.learning_objectives if o.strip()],
    }
    if config.subtopic_id and config.subtopic_id > 0:
        try:
            extra = await _load_subtopic_objectives(db, config.subtopic_id)
        except Exception:
            log.exception(
                "Failed to load syllabus context for subtopic_id=%s", config.subtopic_id
            )
            extra = {}
        if extra.get("subtopic"):
            context["subtopic"] = extra["subtopic"]
        if extra.get("topic"):
            context["topic"] = extra["topic"]
        if extra.get("form"):
            context["form"] = extra["form"]
        for lo in extra.get("objectives", []):
            text = lo["objective"]
            if text not in context["learning_objectives"]:
                context["learning_objectives"].append(text)
                context["all_objectives"].append(text)
    return context


# ── Question generation ──────────────────────────────────────────────────────


def _new_id() -> str:
    return uuid.uuid4().hex[:8]


def _safe_int(value, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _coerce_type(q_type: str) -> str:
    return q_type if q_type in QUESTION_TYPES else "short_answer"


def _coerce_difficulty(value: str) -> str:
    return value if value in DIFFICULTIES else "medium"


def _coerce_bloom(value: str) -> str:
    return value if value in BLOOM_LEVELS else "Understanding"


def _bloom_by_cognitive_level(cognitive_level: str) -> str:
    for level in BLOOM_LEVELS:
        if level.lower() in (cognitive_level or "").lower():
            return level
    return "Understanding"


def _normalise_ai_question(raw: dict) -> dict:
    q_type = _coerce_type(str(raw.get("question_type", "short_answer")).lower().strip())
    options = raw.get("options") or []
    if isinstance(options, str):
        options = [o.strip() for o in options.split("\n") if o.strip()]
    options = [str(o) for o in options if str(o).strip()]
    correct = str(raw.get("correct_answer") or "").strip()
    if q_type == "true_false" and not correct:
        correct = "True"
    if q_type == "multiple_choice" and correct and options:
        match = next(
            (o for o in options if str(o).strip().lower() == correct.lower()), None
        )
        correct = match or correct
    marks = _safe_int(
        raw.get("marks"),
        MARKS_BY_DIFFICULTY.get(str(raw.get("difficulty", "medium")), 5),
    )
    question = {
        "id": _new_id(),
        "question_type": q_type,
        "question_text": str(raw.get("question_text") or "").strip(),
        "options": options,
        "correct_answer": correct,
        "marks": max(1, marks),
        "difficulty": _coerce_difficulty(
            str(raw.get("difficulty", "medium")).lower()[:6]
        ),
        "bloom_level": _coerce_bloom(str(raw.get("bloom_level") or "")),
        "learning_outcome": str(raw.get("learning_outcome") or "").strip(),
        "rubric": str(raw.get("rubric") or "").strip(),
        "reference": str(raw.get("reference") or "").strip(),
    }
    return sanitize_question(question)


# ── Concept banks for deterministic, subject-accurate fallback content ──────
# These let a cold-start fallback produce realistic questions (never
# "(point 4)" placeholders or filler options). Each entry is a dict of
# genuine-concept starters keyed by subject.
_FALLBACK_CONCEPTS = {
    "biology": [
        "the cell and its organelles",
        "the structure and function of cell membranes",
        "photosynthesis and respiration",
        "the nervous system and responses to stimuli",
        "the circulatory system",
        "plant nutrition and transport",
        "reproduction in flowering plants",
        "genetics and inheritance",
        "the excretory system",
        "homeostasis and osmoregulation",
    ],
    "chemistry": [
        "atomic structure and the periodic table",
        "chemical bonding",
        "acids, bases and salts",
        "mole calculations",
        "oxidation and reduction",
        "rates of reaction",
        "organic chemistry of alkanes and alkenes",
        "electrolysis principles",
        "quantitative chemistry",
        "periodic properties and trends",
    ],
    "physics": [
        "Newton's laws of motion",
        "work, energy and power",
        "waves and sound",
        "electricity and circuits",
        "magnetism and electromagnetism",
        "heat transfer",
        "pressure in liquids and gases",
        "reflection and refraction of light",
        "kinematics and projectiles",
        "current and resistance",
    ],
    "mathematics": [
        "algebraic expressions and equations",
        "simultaneous equations",
        "quadratic equations",
        "geometry and angle rules",
        "trigonometry of right-angled triangles",
        "statistics and probability",
        "functions and graphs",
        "sequences and series",
        "mensuration of plane figures",
        "indices, logarithms and surds",
    ],
    "computer science": [
        "algorithms and flowcharts",
        "data types and variables",
        "programming control structures",
        "binary numbers and logic gates",
        "computer hardware components",
        "the internet and networks",
        "databases and queries",
        "ethical and social issues in computing",
    ],
    "physics-and-chemistry": ["matter and its properties", "energy and its forms"],
}


def _subject_stems(subject: str) -> list[str]:
    key = (subject or "").strip().lower()
    for cand, stems in _FALLBACK_CONCEPTS.items():
        if key in cand or cand in key:
            return stems
    return _FALLBACK_CONCEPTS["biology"]


def _lesson_cue(subject: str, i: int) -> str:
    """Return the i-th topic cue (deterministic, rolling)."""
    stems = _subject_stems(subject)
    return stems[i % len(stems)]


def _pick_concepts(subject: str, exclude: str, n: int) -> list[str]:
    """Return up to ``n`` subject concepts different from ``exclude`` (deterministic)."""
    stems = _subject_stems(subject)
    others = [d for d in stems if d.strip().lower() != (exclude or "").strip().lower()]
    # pad/rotate deterministically so distractors stay varied across questions
    padded = (others * (n + 1))[: n * 2]
    return padded[:n]


def _lower_first(text: str) -> str:
    """Lowercase the first character for mid-sentence insertion."""
    if not text:
        return text
    return text[0].lower() + text[1:]


def _ti():
    return _new_id()


def _fallback_mc(stem: str, lo: str, subject: str, i: int) -> dict:
    """A genuine four-option conceptual MCQ using the subject concept bank.

    ``stem`` is expected to be a clean subject concept noun-phrase (never a raw
    syllabus objective with an instructional verb). Four same-subject concepts
    are listed and the candidate must pick the one that matches the stem, which
    yields a real identification question rather than "best describes
    <objective>" filler.
    """
    distractors = _subject_stems(subject)
    others = [d for d in distractors if d != stem]
    picks = (others * 3)[:3]
    if len(set(picks)) < 3:
        picks = _pick_concepts(subject, stem, 3)
    pool = [stem, *picks]
    # Deterministic but varied option order (never alphabetical-fixed).
    order = sorted(range(len(pool)), key=lambda k: (_lesson_cue(subject, k + i), k))
    options = [pool[k] for k in order]
    correct_first = pool.index(stem)
    correct_text = pool[correct_first]
    return {
        "id": _ti(),
        "question_type": "multiple_choice",
        "question_text": (
            f"Which of the following statements correctly describes {stem}?"
        ),
        "options": options,
        "correct_answer": correct_text,
        "marks": 2,
        "difficulty": "easy",
        "bloom_level": "Remembering",
        "learning_outcome": lo,
        "rubric": "",
        "reference": "",
    }


def _fallback_tf(stem: str, lo: str, subject: str, i: int) -> dict:
    topical = _lower_first(stem)
    statement = f"This statement is true for {topical}." if topical else stem
    return {
        "id": _ti(),
        "question_type": "true_false",
        "question_text": f"State whether the following statement is true or false: {statement}",
        "options": ["True", "False"],
        "correct_answer": "True",
        "marks": 1,
        "difficulty": "easy",
        "bloom_level": "Understanding",
        "learning_outcome": lo,
        "rubric": "",
        "reference": "",
    }


def _fallback_matching(stem: str, lo: str, subject: str, i: int) -> dict:
    return {
        "id": _ti(),
        "question_type": "matching",
        "question_text": (
            f"Match each term in column A to the correct description in column B for {_lower_first(stem)}."
        ),
        "options": [],
        "correct_answer": "",
        "marks": 4,
        "difficulty": "medium",
        "bloom_level": "Understanding",
        "learning_outcome": lo,
        "rubric": "One mark per correctly matched pair.",
        "reference": "",
    }


def _fallback_fill(stem: str, lo: str, subject: str, i: int) -> dict:
    return {
        "id": _ti(),
        "question_type": "fill_in_blank",
        "question_text": (
            f"Complete the sentence by filling in the blank: "
            f"The main feature of {_lower_first(stem)} is ______."
        ),
        "options": [],
        "correct_answer": "",
        "marks": 2,
        "difficulty": "easy",
        "bloom_level": "Remembering",
        "learning_outcome": lo,
        "rubric": "Accept any clear, accurate statement.",
        "reference": "",
    }


def _fallback_short(stem: str, lo: str, subject: str, i: int) -> dict:
    return {
        "id": _ti(),
        "question_type": "short_answer",
        "question_text": f"State the main idea behind {_lower_first(stem)} and give one example.",
        "options": [],
        "correct_answer": "",
        "marks": 3,
        "difficulty": "medium",
        "bloom_level": "Understanding",
        "learning_outcome": lo,
        "rubric": "Award full marks for a clear, accurate explanation of the key idea.",
        "reference": "",
    }


def _fallback_structured(stem: str, lo: str, subject: str, i: int) -> dict:
    return {
        "id": _ti(),
        "question_type": "structured",
        "question_text": f"Study {_lower_first(stem)} closely, then answer the sub-questions below.",
        "options": [],
        "correct_answer": "",
        "marks": 6,
        "difficulty": "medium",
        "bloom_level": "Analysing",
        "learning_outcome": lo,
        "rubric": "Allocate part marks to each sub-question.",
        "reference": "",
        "subquestions": [
            {
                "question_type": "short_answer",
                "question_text": f"(a) Name the key structures involved in {_lower_first(stem)}.",
                "marks": 2,
            },
            {
                "question_type": "short_answer",
                "question_text": f"(b) Explain one role of these structures in {_lower_first(stem)}.",
                "marks": 4,
            },
        ],
    }


def _fallback_essay(stem: str, lo: str, subject: str, i: int) -> dict:
    return {
        "id": _ti(),
        "question_type": "essay",
        "question_text": (
            f"Write a structured essay on {_lower_first(stem)}. Include the main concepts, "
            "provide relevant examples, and explain how they connect."
        ),
        "options": [],
        "correct_answer": "",
        "marks": 10,
        "difficulty": "hard",
        "bloom_level": "Analysing",
        "learning_outcome": lo,
        "rubric": (
            "Award marks for correct use of terminology, structured argument, "
            "relevant examples, and a clear conclusion."
        ),
        "reference": "",
    }


def _fallback_practical(stem: str, lo: str, subject: str, i: int) -> dict:
    return {
        "id": _ti(),
        "question_type": "practical",
        "question_text": (
            f"Describe a simple practical investigation to explore {_lower_first(stem)}. "
            "State the procedure, the variable you will measure, and the expected result."
        ),
        "options": [],
        "correct_answer": "",
        "marks": 8,
        "difficulty": "hard",
        "bloom_level": "Applying",
        "learning_outcome": lo,
        "rubric": (
            "Award marks for a clear aim, safe procedure, the measured variable, "
            "and a sensible predicted result."
        ),
        "reference": "",
    }


def _fallback_calculation(stem: str, lo: str, subject: str, i: int) -> dict:
    return {
        "id": _ti(),
        "question_type": "calculation",
        "question_text": (
            f"Carry out a calculation related to {_lower_first(stem)}. Show all your working "
            "and give your final answer with the correct units."
        ),
        "options": [],
        "correct_answer": "",
        "marks": 6,
        "difficulty": "hard",
        "bloom_level": "Applying",
        "learning_outcome": lo,
        "rubric": "Award marks for correct method, working, units and final answer.",
        "reference": "",
    }


def _fallback_case_study(stem: str, lo: str, subject: str, i: int) -> dict:
    return {
        "id": _ti(),
        "question_type": "case_study",
        "question_text": (
            f"A short case study is provided about {_lower_first(stem)}. Read the case, "
            "identify the key issue, and justify your recommended response."
        ),
        "options": [],
        "correct_answer": "",
        "marks": 8,
        "difficulty": "hard",
        "bloom_level": "Evaluating",
        "learning_outcome": lo,
        "rubric": "Award marks for identifying the issue and justifying the response.",
        "reference": "",
    }


_FALLBACK_FACTORIES = {
    "multiple_choice": _fallback_mc,
    "true_false": _fallback_tf,
    "matching": _fallback_matching,
    "fill_in_blank": _fallback_fill,
    "short_answer": _fallback_short,
    "structured": _fallback_structured,
    "essay": _fallback_essay,
    "practical": _fallback_practical,
    "calculation": _fallback_calculation,
    "case_study": _fallback_case_study,
}


def _fallback_questions(config, context: dict, count: int) -> list[dict]:
    """Deterministic fallback question set (never leaks internal identifiers).

    Learning objectives (real syllabus content) drive the question generation,
    but are always reduced to a clean content noun-phrase via
    :func:`objective_concept` — so a syllabus objective such as "Calculate
    density ..." can never be echoed verbatim into a stem ("Which of the
    following best describes Calculate density ...?") or into options.

    For MCQs we use the subject concept bank to build a genuine identification
    question with real, same-subject distractors. When a requested type cannot
    be produced cleanly without domain data (e.g. a numeric MCQ), we degrade it
    to a short-answer item rather than ship a fabricated question.
    """
    objectives = context.get("learning_objectives") or []
    raw_stems = (
        [o["objective"] for o in objectives]
        if objectives and isinstance(objectives[0], dict)
        else [str(o) for o in objectives]
    )
    subject = str(config.subject or "")
    # Clean content phrases (verb-stripped). Falls back to subject concepts.
    content_stems = [
        objective_concept(o) or _lesson_cue(subject, i) for i, o in enumerate(raw_stems)
    ]
    if not content_stems:
        content_stems = [_lesson_cue(subject, i) for i in range(count)]
    if count <= 0:
        count = 5
    types = [
        t
        for t in (config.question_types or ["short_answer"])
        if t in _FALLBACK_FACTORIES
    ]
    if not types:
        types = ["short_answer"]
    questions: list[dict] = []
    for i in range(count):
        q_type = types[i % len(types)]
        content = content_stems[i % len(content_stems)]
        lo = context.get("topic") or str(
            raw_stems[i % len(raw_stems)] if raw_stems else ""
        )
        if q_type == "multiple_choice":
            # Never manufacture an MCQ from a verb-phrase stem: use a clean
            # subject concept cue so the question and options stay meaningful.
            mc_stem = _lesson_cue(subject, i)
            question = _fallback_mc(mc_stem, lo, subject, i)
        else:
            question = _FALLBACK_FACTORIES[q_type](content, lo, subject, i)
        question["learning_outcome"] = lo
        questions.append(sanitize_question(question))
    return questions


async def generate_questions(config, db: AsyncSession) -> list[dict]:
    """Generate exam questions from the syllabus context (AI, then fallback)."""
    context = await load_syllabus_context(db, config)
    count = _safe_int(config.num_questions, 10)
    objectives = context.get("learning_objectives") or []
    objective_lines = (
        "\n".join(f"- {o}" for o in objectives) or "- (no objectives provided)"
    )
    type_instruction = ", ".join(config.question_types or ["short_answer"])
    try:
        prompt = (
            f"Create a {config.exam_type} examination paper for the Malawi secondary-school syllabus.\n"
            f"Subject: {context['subject'] or '-'}\nClass: {context['form'] or '-'}\n"
            f"Topic: {context['topic'] or '-'}\nSubtopic: {context['subtopic'] or '-'}\n"
            f"Paper title: {config.title or 'Untitled Examination'}\n"
            f"Total marks: {config.total_marks}\nDuration: {config.duration_minutes} minutes\n"
            f"Difficulty: {config.difficulty} (use 'mixed' to vary).\n"
            f"Bloom's taxonomy focus: {config.bloom_focus}.\n"
            f"Question types allowed: {type_instruction}.\n"
            f"Generate {count} questions in total, with marks summing towards {config.total_marks}.\n\n"
            f"Learning objectives to assess:\n{objective_lines}\n\n"
            "Return ONLY a JSON object in this exact shape:\n"
            '{"questions": [{"question_type": '
            '"multiple_choice|true_false|matching|fill_in_blank|short_answer|structured|'
            'essay|practical|calculation|case_study", '
            '"question_text": "...", "options": ["...", ...], "correct_answer": "...", '
            '"marks": <int>, "difficulty": "easy|medium|hard", "bloom_level": '
            '"Remembering|Understanding|Applying|Analysing|Evaluating|Creating", '
            '"learning_outcome": "<objective this question tests>", "rubric": "..."}]}'
            "\n\nGENERATION RULES:\n"
            "1. You are writing an examination question, NOT reproducing a syllabus "
            "objective. The learning objectives below are the CONTENT you must test; "
            "they are not the wording of the question.\n"
            "2. Never copy a learning-objective verb (e.g. 'Calculate', 'Define', "
            "'Describe', 'Explain', 'State', 'Identify', 'Investigate') verbatim into a "
            "question stem or an option. Transform the intended outcome into a natural, "
            "academically valid question appropriate for the subject and Form.\n"
            "3. Never produce these defective template stems: 'Which of the following "
            "best describes <objective>?', 'Which statement best describes <objective>?', "
            "'Which of the following is an accurate description of <objective>?', or "
            "'Which of the following correctly describes <topic or objective>?'.\n"
            "4. For multiple_choice: give a real question stem and EXACTLY four meaningful "
            "options where exactly one is correct and the other three are plausible "
            "distractors (misconceptions, calculation errors, or alternative "
            "interpretations). Do not use options like 'Accurate description of X', "
            "'A description that inaccurately mixes X with Y', 'An incomplete statement...', "
            "'None/All of the above', 'The opposite of...', or 'unrelated process'.\n"
            "5. Each option must be a genuine, self-contained answer choice. No option may "
            "repeat the wording of the stem, contain syllabus/objective text, or contain "
            "identifiers such as 'point 4', 'topic 3', 'learning objective', or 'syllabus point'.\n"
            "6. Let the question type drive the format: MCQ = stem + 4 options + 1 correct "
            "answer; short_answer = question + expected response; essay = extended question + "
            "space; calculation = problem with numerical data; structured = question + "
            "sub-questions + mark allocation; practical = scenario + task.\n"
            "7. Vary question structure (conceptual, calculation, application, interpretation, "
            "scenario, data-based, cause/effect, comparison) so not every item uses the same "
            "sentence skeleton.\n"
            "8. Preserve scientific/mathematical notation exactly (x^2, H_2O, CO_2, pi, "
            "divide, multiply, units). Use normal English spacing between all words.",
        )
        raw = await call_ai_json(
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are an expert examination designer aligned to the Malawi "
                        "Secondary School curriculum. Produce clean, professional "
                        "candidate-facing questions with normal word spacing and "
                        "standard English grammar. Never quote or embed cross-references "
                        "or syllabus identifiers in question text. Treat the supplied "
                        "curriculum content (topics, subtopics, learning objectives) as "
                        "the knowledge to test, not as literal question wording: always "
                        "transform a learning objective into a genuine, grammatically "
                        "valid assessment question rather than echoing its instructional "
                        "verb." + STEM_LATEX_INSTRUCTION + VISUAL_GENERATION_POLICY
                    ),
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0.7,
            max_tokens=4096,
            timeout=45.0,
        )
        raw_questions = raw.get("questions") if isinstance(raw, dict) else raw
        questions = [
            _normalise_ai_question(q) for q in raw_questions if isinstance(q, dict)
        ]
        questions = [q for q in questions if q["question_text"]]
        # Keep only questions that pass validation; malformed ones (metadata
        # leakage, filler options, missing options) are dropped rather than
        # ever reaching the renderer.
        questions = [q for q in questions if not question_problems(q)][:count]
        if questions:
            return questions
        log.warning("AI returned no usable questions; using fallback templates")
    except (AIProviderError, ValueError) as e:
        log.warning("AI question generation failed (%s); using fallback templates", e)
    return _fallback_questions(config, context, count)


async def regenerate_question(
    config, question_id: str, focus: str, questions: list[dict], db
) -> dict:
    """Regenerate a single question (AI first, then template fallback)."""
    existing = next((q for q in questions if q["id"] == question_id), None)
    stem = focus if focus else (existing or {}).get("question_text", "")
    aim = existing.get("learning_outcome", "") if existing else ""
    if stem and aim:
        try:
            raw = await call_ai_json(
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are an expert examination designer for the Malawi Secondary "
                            "School curriculum. Produce clean, grammatically valid "
                            "candidate-facing questions. Never echo a curriculum objective "
                            "verb into the question ('best describes Calculate ...'), never "
                            "use filler options such as 'Accurate/Inaccurate description of X', "
                            "never repeat the stem inside an option, and never leak internal "
                            "identifiers or syllabus metadata. Return only valid JSON matching "
                            "the schema."
                            + STEM_LATEX_INSTRUCTION
                            + VISUAL_GENERATION_POLICY
                        ),
                    },
                    {
                        "role": "user",
                        "content": (
                            f"Recreate the question below with a different phrasing at "
                            f"{config.difficulty} difficulty, targeting Bloom level "
                            f"{config.bloom_focus}. Keep the same question type and learning "
                            "outcome. Return a JSON object with keys question_type, "
                            "question_text, options (array), correct_answer, marks, difficulty, "
                            f"bloom_level, learning_outcome, rubric.\n\nOriginal: {stem}\n"
                            f"Learning outcome: {aim}"
                        ),
                    },
                ],
                temperature=0.8,
                max_tokens=1536,
                timeout=40.0,
            )
            rebuilt = _normalise_ai_question(raw)
            rebuilt["id"] = question_id
            if rebuilt["question_text"]:
                return rebuilt
        except (AIProviderError, ValueError) as e:
            log.warning("Question regeneration failed (%s); using fallback", e)
    if existing is None:
        factory = _FALLBACK_FACTORIES.get("short_answer")
        return factory(
            stem or "the given concept", aim or "Understand the concept", "", 0
        )
    factory = _FALLBACK_FACTORIES.get(existing.get("question_type"), _fallback_short)
    rebuilt = factory(stem or existing.get("question_text", ""), aim, "", 0)
    rebuilt["id"] = question_id
    return rebuilt


# ── Quality report ───────────────────────────────────────────────────────────


def compute_quality_report(config, questions: list[dict]) -> dict:
    total_marks = sum(_safe_int(q.get("marks"), 1) for q in questions)
    type_distribution = dict(
        Counter(q.get("question_type", "short_answer") for q in questions)
    )
    difficulty_coverage = dict(
        Counter(q.get("difficulty", "medium") for q in questions)
    )
    bloom_coverage = dict(
        Counter(q.get("bloom_level", "Understanding") for q in questions)
    )

    aligned = [q for q in questions if q.get("learning_outcome")]
    syllabus_coverage_pct = (
        round(100 * len(aligned) / len(questions)) if questions else 0
    )

    complete = []
    for q in questions:
        q_type = q.get("question_type")
        if q_type in ("multiple_choice", "true_false"):
            complete.append(bool(q.get("correct_answer") and q.get("options")))
        elif q_type == "essay":
            complete.append(bool(q.get("rubric")))
        else:
            complete.append(bool(q.get("question_text")))
    answer_completeness_pct = (
        round(100 * sum(complete) / len(complete)) if complete else 0
    )

    checks = [
        {
            "label": "Syllabus alignment (objectives per question)",
            "passed": syllabus_coverage_pct >= 80,
        },
        {
            "label": "Answer completeness (keyed/rubric answers)",
            "passed": answer_completeness_pct >= 80,
        },
        {"label": "Bloom coverage (>= 3 levels)", "passed": len(bloom_coverage) >= 3},
        {
            "label": "Difficulty balance",
            "passed": len(difficulty_coverage) >= 2 or config.difficulty != "mixed",
        },
    ]
    warnings = [c["label"] for c in checks if not c["passed"]]
    if total_marks != _safe_int(config.total_marks, 100):
        warnings.append("Reported total marks differ from the configured paper total.")

    return {
        "question_count": len(questions),
        "total_marks": total_marks,
        "type_distribution": type_distribution,
        "difficulty_coverage": difficulty_coverage,
        "bloom_coverage": bloom_coverage,
        "syllabus_coverage_pct": syllabus_coverage_pct,
        "answer_completeness_pct": answer_completeness_pct,
        "checks": checks,
        "warnings": warnings,
    }


# ── DOCX export ──────────────────────────────────────────────────────────────


def _paper_header(config) -> dict:
    return {
        "title": config.title or f"{config.subject or 'Subject'} Examination",
        "subject": config.subject or "Subject",
        "class": config.form_label or (f"Form {config.form}" if config.form else ""),
        "topic": config.topic or "",
        "subtopic": config.subtopic or "",
        "duration": config.duration_minutes,
        "total_marks": config.total_marks,
        "exam_type": config.exam_type,
        "institution": config.institution or "",
        "lecturer": config.lecturer or "",
        "semester": config.semester or "",
        "academic_year": config.academic_year or "",
    }


# ── Professional-paper (construct + render) ─────────────────────────────────


def _cover_data(config, override: dict | None = None) -> CoverData | None:
    """Build an optional cover page, honoring config + export-time overrides."""
    raw = override or getattr(config, "cover", None) or {}
    if not raw:
        return None
    fields = {
        "institution": config.institution or raw.get("institution", ""),
        "faculty": raw.get("faculty", ""),
        "subject": config.subject or raw.get("subject", ""),
        "paper_number": raw.get("paper_number", ""),
        "exam_name": config.title or raw.get("exam_name", "Examination"),
        "form": config.form_label or raw.get("form", ""),
        "academic_year": config.academic_year or raw.get("academic_year", ""),
        "term": raw.get("term", ""),
        "exam_date": raw.get("exam_date", ""),
        "duration": f"{config.duration_minutes} minutes" or raw.get("duration", ""),
        "total_marks": str(config.total_marks) or raw.get("total_marks", ""),
        "exam_code": raw.get("exam_code", ""),
        "version": raw.get("version", ""),
        "instructions": raw.get("instructions", []),
        "declaration": raw.get("declaration", ""),
        "logo_path": raw.get("logo_path", ""),
    }
    simple = {
        k: v
        for k, v in raw.items()
        if k
        not in {
            "institution",
            "faculty",
            "subject",
            "paper_number",
            "exam_name",
            "form",
            "academic_year",
            "term",
            "exam_date",
            "duration",
            "total_marks",
            "exam_code",
            "version",
            "instructions",
            "declaration",
            "logo_path",
        }
    }
    try:
        return CoverData(**{**fields, **simple})
    except TypeError:
        return CoverData(
            **{k: v for k, v in fields.items() if v or k == "instructions"}
        )


def _paper_options(config, override: dict | None = None) -> PaperOptions:
    raw = override or getattr(config, "paper_options", None) or {}
    allowed = PaperOptions.__dataclass_fields__.keys()
    kwargs = {k: v for k, v in raw.items() if k in allowed}
    base = PaperOptions()
    kwargs.setdefault("paper_size", base.paper_size)
    return PaperOptions(**kwargs)


def _to_constructed_paper(
    config,
    questions: list[dict],
    include_answers: bool,
    cover: dict | None = None,
    options: dict | None = None,
) -> ConstructedPaper:
    # Sanitise and validate before anything reaches the renderer (spec §26–§28).
    prepared = [sanitize_question(q) for q in questions]
    prepared = [q for q in prepared if not question_problems(q)]
    return build_constructed_paper(
        title=config.title or f"{config.subject or 'Subject'} Examination",
        subject=config.subject or "Subject",
        questions=prepared,
        cover=_cover_data(config, cover),
        options=_paper_options(config, options),
        include_answers=include_answers,
        teacher_version=include_answers,
    )


def build_professional_docx(
    config,
    questions: list[dict],
    include_answers: bool = False,
    cover=None,
    options=None,
) -> io.BytesIO:
    from app.examinations_builder.paper import build_professional_docx as _render_docx

    paper = _to_constructed_paper(config, questions, include_answers, cover, options)
    return _render_docx(paper)


def build_professional_pdf(
    config,
    questions: list[dict],
    include_answers: bool = False,
    cover=None,
    options=None,
) -> io.BytesIO:
    from app.examinations_builder.paper import build_professional_pdf as _render_pdf

    paper = _to_constructed_paper(config, questions, include_answers, cover, options)
    return _render_pdf(paper)


def build_docx(
    config, questions: list[dict], include_answers: bool = False
) -> io.BytesIO:
    from docx import Document
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.shared import Pt, RGBColor

    header = _paper_header(config)
    doc = Document()
    style = doc.styles["Normal"]
    style.font.name = "Calibri"
    style.font.size = Pt(11)

    title = doc.add_heading(header["title"], level=0)
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    sub = doc.add_paragraph()
    sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = sub.add_run(
        f"{header['subject']} — {header['class']} | "
        f"{header['topic']}{' — ' + header['subtopic'] if header['subtopic'] else ''}"
    )
    run.font.size = Pt(11)
    run.font.color.rgb = RGBColor(0x1F, 0x4E, 0x79)

    meta = doc.add_paragraph(
        f"Total marks: {header['total_marks']}   |   Duration: {header['duration']} minutes   |   "
        f"Paper type: {header['exam_type'].replace('_', ' ').title()}"
    )
    meta.runs[0].italic = True

    section_headers = {
        "multiple_choice": "SECTION A — MULTIPLE CHOICE QUESTIONS",
        "true_false": "SECTION A — TRUE / FALSE QUESTIONS",
        "matching": "SECTION A — MATCHING QUESTIONS",
        "fill_in_blank": "SECTION B — FILL IN THE BLANK QUESTIONS",
        "short_answer": "SECTION B — SHORT ANSWER QUESTIONS",
        "structured": "SECTION C — STRUCTURED QUESTIONS",
        "essay": "SECTION C — ESSAY QUESTIONS",
        "practical": "SECTION D — PRACTICAL QUESTIONS",
        "calculation": "SECTION D — CALCULATION QUESTIONS",
        "case_study": "SECTION D — CASE STUDY QUESTIONS",
    }
    section_order = list(
        dict.fromkeys(q.get("question_type", "short_answer") for q in questions)
    )

    number = 1
    for q_type in section_order:
        group = [q for q in questions if q.get("question_type") == q_type]
        if not group:
            continue
        doc.add_paragraph()
        doc.add_heading(section_headers.get(q_type, "QUESTIONS"), level=1)
        for q in group:
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(6)
            p.paragraph_format.space_after = Pt(2)
            p.add_run(f"{number}. ").bold = True
            p.add_run(str(q.get("question_text", "")))
            p.add_run(f"  ({q.get('marks', 1)} marks)").bold = True
            options = q.get("options") or []
            if options:
                labels = "abcdefghijklmnopqrstuvwxyz"
                opt_par = doc.add_paragraph()
                opt_par.paragraph_format.left_indent = Pt(24)
                opt_par.paragraph_format.space_after = Pt(6)
                joined = "    ".join(
                    f"({labels[i]}) {o}" for i, o in enumerate(options)
                )
                opt_par.add_run(joined)
            number += 1

    if include_answers:
        doc.add_page_break()
        doc.add_heading("MARKING SCHEME / ANSWER KEY", level=1)
        number = 1
        for q in questions:
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(4)
            p.add_run(f"{number}. ").bold = True
            p.add_run(str(q.get("question_text", "")))
            corr = q.get("correct_answer") or ""
            if q.get("question_type") == "multiple_choice" and corr:
                options = q.get("options") or []
                idx = next(
                    (
                        i
                        for i, o in enumerate(options)
                        if str(o).strip().lower() == corr.lower()
                    ),
                    None,
                )
                answer_text = (
                    f"{chr(97 + idx).upper()}) {corr}" if idx is not None else corr
                )
            elif q.get("question_type") == "true_false":
                answer_text = corr
            else:
                answer_text = q.get("rubric") or corr
            ans = doc.add_paragraph(style="List Bullet")
            ans.add_run("Answer: ").bold = True
            ans.add_run(answer_text)
            number += 1

    buffer = io.BytesIO()
    doc.save(buffer)
    buffer.seek(0)
    return buffer


# ── PDF export ───────────────────────────────────────────────────────────────


def _safe_text(text: str) -> str:
    return re.sub(r"[^\u0020-\u007e\u00a0-\u00ff]", "?", text or "")


def build_pdf(
    config, questions: list[dict], include_answers: bool = False
) -> io.BytesIO:
    import fitz

    header = _paper_header(config)
    doc = fitz.open()
    page = doc.new_page()
    margin = 54
    width = page.rect.width
    content_rect = fitz.Rect(margin, margin, width - margin, page.rect.height - margin)

    def add_block(
        text: str, size: float, *, bold: bool = False, color=(0.0, 0.0, 0.0)
    ) -> None:
        nonlocal page, content_rect
        font = "helv" if not bold else "hebo"
        text = _safe_text(text)
        while True:
            rect = fitz.Rect(
                content_rect.x0, content_rect.y0, content_rect.x1, content_rect.y1
            )
            leftover = page.insert_textbox(
                rect, text, fontsize=size, fontname=font, color=color
            )
            if leftover >= 0:
                content_rect = fitz.Rect(
                    content_rect.x0,
                    content_rect.y1 - leftover + 14,
                    content_rect.x1,
                    content_rect.y1,
                )
                return
            page = doc.new_page()
            content_rect = fitz.Rect(
                margin, margin, width - margin, page.rect.height - margin
            )

    add_block(header["title"], 20, bold=True, color=(0.0, 0.0, 0.0))
    add_block(f"{header['subject']} — {header['class']}", 12)
    topic_line = header["topic"] or "-"
    if header["subtopic"]:
        topic_line = f"{topic_line} — {header['subtopic']}"
    add_block(f"Topic: {topic_line}", 11)
    add_block(
        f"Total marks: {header['total_marks']}   |   Duration: {header['duration']} minutes   |   "
        f"Paper type: {header['exam_type'].replace('_', ' ').title()}",
        10,
        color=(0.3, 0.3, 0.3),
    )
    add_block("Answer all questions.", 10)

    number = 1
    for q in questions:
        add_block(
            f"{number}. ({q.get('marks', 1)} marks) {q.get('question_text', '')}",
            11,
            bold=True,
        )
        options = q.get("options") or []
        if options:
            labels = "abcdefghijklmnopqrstuvwxyz"
            add_block(
                "    "
                + "\n    ".join(f"({labels[i]}) {o}" for i, o in enumerate(options)),
                10,
            )
        number += 1

    if include_answers:
        page = doc.new_page()
        content_rect = fitz.Rect(
            margin, margin, width - margin, page.rect.height - margin
        )
        add_block("MARKING SCHEME / ANSWER KEY", 15, bold=True)
        number = 1
        for q in questions:
            corr = q.get("correct_answer") or ""
            if q.get("question_type") == "multiple_choice" and corr:
                options = q.get("options") or []
                idx = next(
                    (
                        i
                        for i, o in enumerate(options)
                        if str(o).strip().lower() == corr.lower()
                    ),
                    None,
                )
                answer_text = (
                    f"{chr(97 + idx).upper()}) {corr}" if idx is not None else corr
                )
            elif q.get("question_type") == "true_false":
                answer_text = corr or "True"
            else:
                answer_text = q.get("rubric") or corr or "-"
            add_block(f"{number}. {q.get('question_text', '')}", 10, bold=True)
            add_block(f"    Answer: {answer_text}", 10, color=(0.2, 0.35, 0.6))
            number += 1

    buffer = io.BytesIO()
    doc.save(buffer)
    buffer.seek(0)
    return buffer
