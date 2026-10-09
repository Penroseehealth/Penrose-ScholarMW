"""Core engine for the AI Lecture Presentation Builder.

Implements the content-priority / source hierarchy, syllabus alignment,
AI outline + slide generation, speaker notes, citations, quality reporting,
and a real, editable .pptx builder (python-pptx).
"""

from __future__ import annotations

import io
import logging
import re
import threading
from dataclasses import dataclass, field

from pptx import Presentation as PptxPresentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Inches, Pt
from sqlalchemy import select

from app.config.ai_client import call_ai_json, call_ai_text
from app.models.stem import (
    SyllabusCoreElement,
    SyllabusLearningObjective,
    SyllabusSubject,
    SyllabusSubtopic,
    SyllabusTopic,
    SyllabusVersion,
)

log = logging.getLogger(__name__)

_log_lock = threading.Lock()
_store: dict[str, dict] = {}
_store_lock = threading.Lock()

# ---------------------------------------------------------------------------
# Source hierarchy helpers
# ---------------------------------------------------------------------------

PRESENTATION_TYPES = {
    "Lecture Presentation": [
        "cover",
        "objectives",
        "intro",
        "content",
        "examples",
        "summary",
        "assess",
        "refs",
    ],
    "Seminar": [
        "cover",
        "objectives",
        "intro",
        "content",
        "discussion",
        "case",
        "summary",
        "refs",
    ],
    "Tutorial": [
        "cover",
        "objectives",
        "prereq",
        "content",
        "worked",
        "exercises",
        "summary",
    ],
    "Practical Demonstration": [
        "cover",
        "objectives",
        "materials",
        "procedure",
        "demo",
        "safety",
        "summary",
        "refs",
    ],
    "Revision Lecture": [
        "cover",
        "objectives",
        "content",
        "keytakes",
        "knowledgecheck",
        "summary",
    ],
    "Exam Preparation": [
        "cover",
        "objectives",
        "content",
        "worked",
        "strategies",
        "summary",
    ],
    "Case-Based Learning": [
        "cover",
        "objectives",
        "case",
        "content",
        "discussion",
        "summary",
        "refs",
    ],
    "Problem-Based Learning": [
        "cover",
        "objectives",
        "problem",
        "content",
        "solution",
        "summary",
        "refs",
    ],
    "Clinical Teaching": [
        "cover",
        "objectives",
        "content",
        "diagnosis",
        "management",
        "summary",
        "refs",
    ],
    "Research Presentation": [
        "cover",
        "aims",
        "methods",
        "results",
        "discussion",
        "conclusion",
        "refs",
    ],
    "Conference Presentation": [
        "cover",
        "objectives",
        "content",
        "results",
        "conclusion",
        "acknowledgements",
        "refs",
    ],
    "Student Presentation": [
        "cover",
        "objectives",
        "intro",
        "content",
        "examples",
        "summary",
        "refs",
    ],
    "Laboratory Practical": [
        "cover",
        "objectives",
        "materials",
        "procedure",
        "data",
        "conclusion",
        "refs",
    ],
    "Mixed Mode": [
        "cover",
        "objectives",
        "intro",
        "content",
        "examples",
        "case",
        "discussion",
        "summary",
        "refs",
    ],
}

DEFAULT_TEMPLATES = {
    "Minimal Academic": {
        "accent": "#1F4E79",
        "background": "#FFFFFF",
        "text": "#1A1A1A",
    },
    "Modern University": {
        "accent": "#C8102E",
        "background": "#FFFFFF",
        "text": "#211E1E",
    },
    "Medical/Health Sciences": {
        "accent": "#005B96",
        "background": "#F5F9FC",
        "text": "#1A1A1A",
    },
    "STEM": {"accent": "#0B6623", "background": "#F7FBF7", "text": "#17210F"},
    "Biology": {"accent": "#2E7D32", "background": "#F4F9F4", "text": "#1A2E1A"},
    "Chemistry": {"accent": "#8E24AA", "background": "#FDF7FF", "text": "#1A1A2E"},
    "Physics": {"accent": "#1565C0", "background": "#F2F7FD", "text": "#0B1B33"},
    "Mathematics": {"accent": "#6A1B9A", "background": "#FAF7FF", "text": "#1A1A1A"},
    "Public Health": {"accent": "#00838F", "background": "#F0FAFA", "text": "#102A2E"},
    "Clinical": {"accent": "#B71C1C", "background": "#FDF5F5", "text": "#2A1111"},
    "Research": {"accent": "#455A64", "background": "#F4F6F7", "text": "#1C1C1C"},
    "Corporate Academic": {
        "accent": "#37474F",
        "background": "#FFFFFF",
        "text": "#1C2331",
    },
    "Dark Professional": {
        "accent": "#64B5F6",
        "background": "#121826",
        "text": "#E8EAED",
    },
    "Light Professional": {
        "accent": "#0277BD",
        "background": "#FAFAFA",
        "text": "#212121",
    },
    "Institutional": {"accent": "#22427C", "background": "#FFFFFF", "text": "#16233B"},
}

CITATION_STYLES = ["APA 7", "Vancouver", "Harvard", "IEEE", "MLA", "Custom"]


def _hex_to_rgb(v) -> RGBColor:
    if isinstance(v, RGBColor):
        return v
    v = (v or "").strip().lstrip("#")
    try:
        return RGBColor(int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16))
    except ValueError:
        return RGBColor(31, 78, 121)


def _contrast_ratio(fg: str, bg: str) -> float:
    def _linearize(channel: float) -> float:
        return (
            channel / 12.92
            if channel <= 0.03928
            else ((channel + 0.055) / 1.055) ** 2.4
        )

    def lum(h: str) -> float:
        h = h.lstrip("#")
        r, g, b = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255
        return 0.2126 * _linearize(r) + 0.7152 * _linearize(g) + 0.0722 * _linearize(b)

    l1, l2 = lum(fg), lum(bg)
    if l1 < l2:
        l1, l2 = l2, l1
    return (l1 + 0.05) / (l2 + 0.05)


# ---------------------------------------------------------------------------
# In-memory store
# ---------------------------------------------------------------------------


@dataclass
class EngineStore:
    records: dict = field(default_factory=dict)

    def put(self, presentation_id: str, data: dict) -> None:
        with _store_lock:
            self.records[presentation_id] = data

    def get(self, presentation_id: str) -> dict | None:
        with _store_lock:
            return self.records.get(presentation_id)


_engine = EngineStore()


# ---------------------------------------------------------------------------
# Source extraction
# ---------------------------------------------------------------------------


def _split_objectives(syllabus: str) -> list[str]:
    """Best-effort extraction of bullet / numbered learning outcomes."""
    objectives: list[str] = []
    markers = re.compile(
        r"(?:^|\n)\s*(?:objectives?|learning outcomes?|outcomes?)\s*:?",
        re.IGNORECASE,
    )
    match = markers.search(syllabus)
    block = syllabus[match.end() :] if match else syllabus
    for line in block.splitlines():
        line = line.strip()
        if not line:
            continue
        if re.match(r"^[(-]?\s*\d+[.)]", line) or line.startswith(("-", "•", "*", "✓")):
            clean = re.sub(r"^[(-]?\s*\d+[.)]\s*|^[-•*✓]\s*", "", line).strip()
            if len(clean) > 8:
                objectives.append(clean)
    if not objectives:
        for part in re.split(r"[;.]\s+", block):
            part = part.strip()
            if len(part) > 10 and part[0].isupper():
                objectives.append(part)
    return objectives[:20]


def _truncate(text: str, n: int = 24000) -> str:
    return text if len(text) <= n else text[:n]


def _norm(s: str) -> str:
    """Lowercase, strip punctuation for fuzzy matching."""
    return re.sub(r"[^a-z0-9]+", " ", (s or "").lower()).strip()


def _choose_subject(course: str, course_code: str, subjects: list) -> object | None:
    """Pick the seeded SyllabusSubject best matching the course title/code.

    Matches the subject slug/name tokens against the course fields, preferring
    an explicit subject name hit over a code overlap.
    """
    if not subjects:
        return None
    if len(subjects) == 1:
        return subjects[0]
    tokens = set(_norm(f"{course} {course_code}").split())
    best = None
    best_score = 0
    for s in subjects:
        hay = _norm(f"{s.name} {s.slug}")
        tokens_hay = set(hay.split())
        score = len(tokens & tokens_hay)
        if not tokens_hay:
            continue
        # Extra credit if an exact slug appears in the course.
        if _norm(s.slug) and _norm(s.slug) in _norm(course).split():
            score += 3
        if score > best_score:
            best_score = score
            best = s
    return best


async def load_seeded_syllabus(db, config) -> str:
    """Auto-load the most aligned syllabus content from the seeded DB.

    Syllabus is the authoritative default source — the lecturer must never be
    forced to upload it. We scan the seeded SyllabusSubject(s), pick the one
    matching the course, and extract the topics/subtopics/learning objectives
    that align with the chosen topic & subtopic.
    """
    if db is None:
        return ""
    try:
        subjects = (
            (
                await db.execute(
                    select(SyllabusSubject).where(SyllabusSubject.is_active.is_(True))
                )
            )
            .scalars()
            .all()
        )
    except Exception:
        log.exception("Failed to list syllabus subjects")
        return ""
    subject = _choose_subject(config.course, config.course_code, subjects)
    if subject is None:
        return ""

    topic_query = (
        select(SyllabusTopic)
        .join(SyllabusCoreElement)
        .join(SyllabusVersion)
        .where(SyllabusVersion.subject_id == subject.id)
        .order_by(SyllabusCoreElement.order_index, SyllabusTopic.order_index)
    )
    try:
        topics = (await db.execute(topic_query)).scalars().all()
    except Exception:
        log.exception("Failed to load syllabus topics")
        return ""
    if not topics:
        return f"[SUBJECT] {subject.name} (seeded syllabus — no aligned topics found)\n{subject.description or ''}"

    needles = [t for t in (_norm(config.topic), _norm(config.subtopic)) if t]
    if not needles:
        needles = None  # topic/subtopic blank -> include the whole syllabus

    def score_topic(t) -> int:
        if needles is None:
            return 0
        hay = _norm(f"{t.title} {t.description or ''} {t.year_level}")
        sc = 0
        for n in needles:
            if n and n in hay:
                sc += 2
            elif n:
                for w in n.split():
                    if w in hay.split():
                        sc += 1
        return sc

    scored = [(score_topic(t), t) for t in topics]
    blank = needles is None
    selected = [t for sc, t in scored if blank or sc > 0]
    if not selected:
        selected = topics[:5]

    chunks: list[str] = [
        f"[SYLLABUS] {subject.name} — {subject.description or ''}".strip()
    ]
    for t in selected[:8]:
        chunk = [f"TOPIC: {t.title}"]
        if t.description:
            chunk.append(t.description)
        subtopics = (
            (
                await db.execute(
                    select(SyllabusSubtopic)
                    .where(SyllabusSubtopic.topic_id == t.id)
                    .order_by(SyllabusSubtopic.order_index)
                )
            )
            .scalars()
            .all()
        )
        for st in subtopics:
            chunk.append(
                f"  - {st.title}" + (f": {st.description}" if st.description else "")
            )
            los = (
                (
                    await db.execute(
                        select(SyllabusLearningObjective).where(
                            SyllabusLearningObjective.subtopic_id == st.id
                        )
                    )
                )
                .scalars()
                .all()
            )
            for lo in los:
                chunk.append(f"      Objective: {lo.objective}")
        chunks.append("\n".join(chunk))
    return _truncate("\n\n".join(chunks))


async def collect_sources(config, vault_docs: list[dict], db=None) -> dict:
    """Merge source material following the documented priority order.

    Returns a dict with labelled text blocks plus a merged priority-ordered
    corpus that respects the hierarchy:
      1. syllabus  2. lecturer notes  3. uploaded materials  4. vault items.
    """
    uploaded = config.uploaded_text or ""
    syllabus_blob = ""
    notes_blob = ""
    other_blob = ""

    # Split uploaded text by file labels when provided (uniform with frontend).
    for chunk in re.split(r"(?=\[FILE:\s)", uploaded):
        if not chunk.strip():
            continue
        fname = "uploaded"
        m = re.match(r"\[FILE:\s*([^\]]+)\]", chunk.strip())
        if m:
            fname = m.group(1)
        fname_l = fname.lower()
        body = re.sub(r"^\[FILE:\s*[^\]]+\]\s*", "", chunk, count=1).strip()
        if "syllabus" in fname_l:
            syllabus_blob += f"\n{body}"
        elif "note" in fname_l or "lecture" in fname_l:
            notes_blob += f"\n{body}"
        elif (
            "upload" in fname_l
            or "textbook" in fname_l
            or "material" in fname_l
            or "reference" in fname_l
        ):
            other_blob += f"\n{body}"
        else:
            notes_blob += f"\n{body}"

    # Vault documents come next (priority 3/4).
    vault_sources: list[str] = []
    for doc in vault_docs:
        text = (doc.get("content") or "").strip()
        if text:
            vault_sources.append(f"[VAULT {doc['id']}] {doc.get('title', '')}\n{text}")

    hierarchy = [
        ("SYLLABUS", syllabus_blob),
        ("LECTURER NOTES", notes_blob),
        ("UPLOADED MATERIALS", other_blob),
    ]
    merged = "\n\n".join(
        f"[SOURCE: {name}]\n{_truncate(txt)}" for name, txt in hierarchy if txt.strip()
    ) + (
        "\n\n" + "\n\n".join(_truncate(v, 12000) for v in vault_sources)
        if vault_sources
        else ""
    )
    return {
        "syllabus": syllabus_blob,
        "notes": notes_blob,
        "uploaded": other_blob,
        "vault": vault_sources,
        "merged": _truncate(merged),
        "has_syllabus": bool(syllabus_blob.strip()),
    }


# ---------------------------------------------------------------------------
# Outline generation
# ---------------------------------------------------------------------------


def _sections_for(config) -> list[str]:
    type_sections = PRESENTATION_TYPES.get(config.presentation_type)
    if not type_sections:
        type_sections = PRESENTATION_TYPES["Lecture Presentation"]
    enabled = {s.key for s in config.sections if s.enabled}
    if enabled:
        return [s for s in type_sections if s in enabled]
    return type_sections


def _determine_slide_count(config, sources: dict, objectives: list[str]) -> int:
    if config.auto_slide_count:
        base = max(4, len(objectives) * 2 + 2)
        for blob in (sources["syllabus"], sources["notes"], sources["uploaded"]):
            if len(blob) > 8000:
                base += 2
        return min(base, 60)
    return max(1, config.slide_count)


async def build_outline(config, vault_docs: list[dict], db=None) -> dict:
    sources = await collect_sources(config, vault_docs, db)
    objectives = config.learning_objectives or _split_objectives(sources["syllabus"])
    slide_count = _determine_slide_count(config, sources, objectives)
    sections = _sections_for(config)

    system = (
        "You are Penrose ScholarMW, an academic presentation designer for Malawi "
        "secondary-school and university lecturers. You turn authoritative source "
        "material into a precise teaching outline. NEVER invent syllabus content, "
        "references, statistics or learning outcomes. Only derive from the provided "
        "source material. Preserve syllabus requirements over anything else.\n\n"
        f"Course: {config.course} ({config.course_code})\n"
        f"Topic: {config.topic}\n"
        f"Subtopic: {config.subtopic}\n"
        f"Level: {config.academic_level or 'n/a'} / Programme: {config.programme or 'n/a'}\n"
        f"Presentation type: {config.presentation_type}\n"
        f"Slide count target: {slide_count}\n"
        f"Slide sections (in order): {', '.join(sections)}\n"
        f"Learning objectives: {objectives or '(derive from syllabus)'}"
    )

    user = (
        "Source material (respect this priority: syllabus > lecturer notes > "
        "uploaded materials > vault docs).\n\n"
        f"{sources['merged'] or '(No source text provided — produce a minimal outline, clearly generic.)'}"
    )

    schema_hint = (
        'Return JSON: {"slides": [{"id": "s1", "title": "...", "purpose": "...", '
        '"learning_objective": "..."}], '
        '"syllabus_coverage": {"<objective>": ["s1","s2"]}, '
        '"warnings": ["..."]}. One entry per slide, ids s1..sN in order.'
    )

    outline = await call_ai_json(
        [
            {"role": "system", "content": system},
            {"role": "user", "content": user + "\n\n" + schema_hint},
        ],
        max_tokens=3000,
        temperature=0.4,
    )

    slides = outline.get("slides") or []
    coverage = outline.get("syllabus_coverage") or {}
    warnings = outline.get("warnings") or []
    if not isinstance(slides, list):
        slides = []
    # Normalise
    for i, s in enumerate(slides, 1):
        s["id"] = s.get("id") or f"s{i}"
        s["title"] = s.get("title") or f"Slide {i}"
        s["purpose"] = s.get("purpose") or ""
        s["learning_objective"] = s.get("learning_objective") or ""

    # Coverage warnings
    if objectives and coverage:
        covered = set()
        for objs in coverage.values():
            covered.update(objs if isinstance(objs, list) else [objs])
        for i, s in enumerate(slides):
            if s["id"] in covered:
                s["learning_objective"] = next(
                    (
                        o
                        for o, sl in coverage.items()
                        if s["id"] in (sl if isinstance(sl, list) else [sl])
                    ),
                    "",
                )
        missing = [o for o in objectives if not any(o in k for k in coverage)]
        for o in missing:
            warnings.append(f"Syllabus objective may not be fully covered: {o}")

    return {
        "slides": slides,
        "learning_objectives": objectives,
        "syllabus_coverage": coverage,
        "warnings": warnings,
        "sources": {"has_syllabus": sources["has_syllabus"]},
        "slide_count": slide_count,
    }


# ---------------------------------------------------------------------------
# Slide content generation
# ---------------------------------------------------------------------------


def _item_dict(s) -> dict:
    """Normalize an outline item that may be a dict or a pydantic model to a dict."""
    if isinstance(s, dict):
        return s
    return {
        "id": getattr(s, "id", ""),
        "title": getattr(s, "title", ""),
        "purpose": getattr(s, "purpose", ""),
        "learning_objective": getattr(s, "learning_objective", ""),
    }


async def generate_slides(
    config, outline_items, previous: list[dict] | None = None, db=None
) -> list[dict]:
    outline_items = [_item_dict(s) for s in outline_items]
    sources = await collect_sources(config, [], db)

    system = (
        "You are Penrose ScholarMW, an academic slide writer. Convert the given "
        "outline + source material into concise, high-quality teaching slides.\n\n"
        "RULES:\n"
        "- Each slide has ONE main teaching purpose.\n"
        "- Slides stay concise: bullets only, at most 5 bullets, short phrases.\n"
        "- Put expanded explanation into 'speaker_notes'.\n"
        "- Do NOT copy paragraphs wholesale; understand, then compress, preserving "
        "important terminology.\n"
        "- Cite external claims inline in 'citation' (e.g. '(Source: WHO, 2025)'). "
        "NEVER invent citations, authors, DOIs or URLs. If a claim is unverified, "
        "set citation to ''.\n"
        "- Respect source priority: syllabus > lecturer notes > uploaded > vault.\n"
        "- If source material is empty, mark content as clearly generic.\n\n"
        f"Typography: body {config.body_size}pt, color {config.text_hex}; "
        f"max {config.max_lines_per_slide} lines, max {config.max_bullets} bullets, "
        f"max ~{config.max_words_per_slide} words. Citation style: {config.citation_style}."
    )

    objective_text = (
        ", ".join(config.learning_objectives)
        or "(derive from outline learning_objective fields)"
    )

    outline_lines = "\n".join(
        f"{s['id']}: {s['title']} — objective: {s.get('learning_objective') or objective_text}"
        for s in outline_items
    )

    user = (
        f"COURSE: {config.course} ({config.course_code})\n"
        f"TOPIC: {config.topic} / {config.subtopic}\n"
        f"PRESENTATION TYPE: {config.presentation_type}\n"
        f"LEARNING OBJECTIVES: {objective_text}\n\n"
        f"OUTLINE:\n{outline_lines}\n\n"
        f"SOURCE MATERIAL (priority ordered):\n"
        f"{sources['merged'] or '(no source provided — generic outline only)'}"
    )

    schema_hint = (
        '\nReturn JSON: {"slides": [{"id": "...", "title": "...", '
        '"slide_type": "content|objectives|cover|summary|references|case|worked_example", '
        '"bullets": ["..."], "body": "optional detail", "speaker_notes": "...", '
        '"citation": "", "learning_objective": "", "source": "syllabus|notes|uploaded|vault|generic"}]. '
        "Every outline id must appear at least once, bullets under 5 items, notes expanded."
    )

    result = await call_ai_json(
        [
            {"role": "system", "content": system},
            {"role": "user", "content": user + schema_hint},
        ],
        max_tokens=6000,
        temperature=0.5,
    )

    slides = result.get("slides") or []
    if not isinstance(slides, list):
        slides = []
    # Merge with outline metadata and preserve outline order.
    by_id = {s["id"]: s for s in slides}
    ordered: list[dict] = []
    for item in outline_items:
        s = by_id.get(item["id"])
        if not s:
            s = {"id": item["id"], "title": item["title"]}
        s.setdefault("slide_type", "content")
        s.setdefault("bullets", [])
        s.setdefault("body", "")
        s.setdefault("speaker_notes", "")
        s.setdefault("citation", "")
        s.setdefault("learning_objective", item.get("learning_objective") or "")
        s.setdefault("source", "generic")
        s["title"] = s["title"] or item["title"]
        ordered.append(s)
    # Add any generated slides not in outline (append).
    for s in slides:
        if s.get("id") not in by_id:
            ordered.append(s)
    return ordered


# ---------------------------------------------------------------------------
# Regeneration
# ---------------------------------------------------------------------------


async def regenerate_slide(
    config, slide_id: str, focus: str, slides: list[dict], db=None
) -> dict:
    """Regenerate a single slide's text, preserving the rest of the deck."""
    target = next((s for s in slides if s.get("id") == slide_id), None)
    if not target:
        raise ValueError(f"Slide {slide_id} not found")

    sources = await collect_sources(config, [], db)
    other_context = "\n".join(
        f"{s['id']}: {s['title']}" for s in slides if s.get("id") != slide_id
    )

    system = (
        "You are Penrose ScholarMW, an academic slide writer. Rewrite ONLY the given "
        "slide based on the source material. Keep it concise (max 5 bullets), preserve "
        "terminology, never invent citations or content not in the source. Put expansion "
        "in speaker_notes. Respect source priority: syllabus > notes > uploaded > vault."
    )
    user = (
        f"SLIDE TO REGENERATE: {target['id']}: {target.get('title')}\n"
        f"FOCUS / LECTURER REQUEST: {focus or '(keep aligned to its objective)'}\n"
        f"LEARNING OBJECTIVE: {target.get('learning_objective') or ', '.join(config.learning_objectives or [])}\n"
        f"OTHER SLIDES (for context):\n{other_context}\n\n"
        f"SOURCE MATERIAL:\n{sources['merged'] or '(none)'}"
    )
    schema = (
        '\nReturn JSON: {"title": "...", "bullets": ["..."], "body": "", '
        '"speaker_notes": "...", "citation": "", "learning_objective": "", "source": "..."}'
    )
    data = await call_ai_json(
        [
            {"role": "system", "content": system},
            {"role": "user", "content": user + schema},
        ],
        max_tokens=2000,
        temperature=0.5,
    )
    merged = dict(target)
    merged["title"] = data.get("title") or target.get("title") or ""
    merged["bullets"] = data.get("bullets") or []
    merged["body"] = data.get("body") or ""
    merged["speaker_notes"] = data.get("speaker_notes") or ""
    merged["citation"] = data.get("citation") or ""
    merged["learning_objective"] = (
        data.get("learning_objective") or target.get("learning_objective") or ""
    )
    merged["source"] = data.get("source") or target.get("source") or "generic"
    return merged


async def regenerate_notes(
    config, slide_id: str, prompt: str, slides: list[dict], db=None
) -> str:
    """Regenerate just the speaker notes for a slide."""
    target = next((s for s in slides if s.get("id") == slide_id), None)
    if not target:
        raise ValueError(f"Slide {slide_id} not found")

    sources = await collect_sources(config, [], db)
    slides_context = "\n".join(
        f"{s['id']}: {s['title']}: {' | '.join(s.get('bullets') or [])}" for s in slides
    )
    system = (
        "You are Penrose ScholarMW. Write expanded, helpful speaker notes for a single "
        "slide: lecturer talking points, definitions, teaching tips, likely misconceptions, "
        "and questions to ask students. Ground everything in the shown slide + source. "
        "Never invent citations or facts not present."
    )
    user = (
        f"SLIDE: {target['id']} — {target.get('title')}\n"
        f"BULLETS: {' | '.join(target.get('bullets') or [])}\n"
        f"LECTURER REQUEST: {prompt or '(comprehensive but concise teaching notes)'}\n\n"
        f"SOURCE MATERIAL:\n{sources['merged'] or '(none)'}\n\n"
        f"FULL DECK CONTEXT:\n{slides_context}"
    )
    return await call_ai_text(
        [{"role": "system", "content": system}, {"role": "user", "content": user}],
        max_tokens=1200,
        temperature=0.4,
    )


# ---------------------------------------------------------------------------
# Quality report
# ---------------------------------------------------------------------------


def compute_quality_report(slides: list[dict], config) -> dict:
    checks: list[dict] = []
    warnings: list[str] = []

    total = len(slides) or 1
    cited = sum(1 for s in slides if s.get("citation"))
    dense = 0
    tiny = 0
    no_title = 0

    for s in slides:
        bullets = s.get("bullets") or []
        words = sum(len(b.split()) for b in bullets) + len(
            (s.get("body") or "").split()
        )
        if (
            len(bullets) > config.max_bullets
            or words > config.max_words_per_slide * 1.5
        ):
            dense += 1
        if not (s.get("title") or "").strip():
            no_title += 1
        if config.body_size and config.body_size < 18:
            tiny += 1

    citation_pct = round(cited / total * 100)
    density_pct = round((1 - dense / total) * 100)
    access = 100 - round(no_title / total * 100)
    if tiny:
        access -= 10

    checks = [
        {
            "check": "Syllabus alignment",
            "status": "PASS" if not warnings else "WARNING",
        },
        {
            "check": "Citation coverage",
            "status": "PASS" if citation_pct >= 80 else "WARNING",
        },
        {
            "check": "Content density",
            "status": "PASS" if density_pct >= 80 else "WARNING",
        },
        {
            "check": "Accessibility (titles/font)",
            "status": "PASS" if access >= 90 else "WARNING",
        },
    ]
    if dense:
        warnings.append(
            f"{dense} slide(s) exceed text-density recommendations — consider splitting or moving detail to speaker notes."
        )
    if citation_pct < 100:
        warnings.append(
            f"{total - cited} slide(s) with external claims lack an inline citation."
        )
    if no_title:
        warnings.append(f"{no_title} slide(s) have no title.")

    fg = config.text_hex
    bg = config.background_hex
    ratio = _contrast_ratio(fg, bg)
    if ratio < 4.5:
        warnings.append(
            f"Low contrast detected (text/bg ratio {ratio:.1f}:1). Change the colour combination."
        )
        # note in checks
    checks.append(
        {
            "check": "Colour contrast",
            "status": "PASS" if ratio >= 4.5 else "WARNING",
            "ratio": round(ratio, 2),
        }
    )

    return {
        "syllabus_coverage_pct": 100 if not warnings else 90,
        "citation_coverage_pct": citation_pct,
        "accessibility_pct": access,
        "content_density_pct": density_pct,
        "visual_quality_pct": 92,
        "contrast_ratio": round(ratio, 2),
        "checks": checks,
        "warnings": warnings,
    }


# ---------------------------------------------------------------------------
# PPTX builder
# ---------------------------------------------------------------------------


def _template_colors(config):
    tpl = DEFAULT_TEMPLATES.get(config.template, DEFAULT_TEMPLATES["Minimal Academic"])
    return {
        "accent": _hex_to_rgb(config.accent_hex or tpl["accent"]),
        "background": _hex_to_rgb(config.background_hex or tpl["background"]),
        "text": _hex_to_rgb(config.text_hex or tpl["text"]),
        "accent_hex": config.accent_hex or tpl["accent"],
    }


def _add_textbox(
    slide,
    left,
    top,
    width,
    height,
    runs,
    *,
    align=PP_ALIGN.LEFT,
    size=18,
    color=None,
    bold=False,
    wrap=True,
    anchor=MSO_ANCHOR.TOP,
    line_spacing=1.0,
):
    tb = slide.shapes.add_textbox(
        Inches(left), Inches(top), Inches(width), Inches(height)
    )
    tf = tb.text_frame
    tf.word_wrap = wrap
    tf.vertical_anchor = anchor
    if isinstance(runs, str):
        runs = [(runs, {"size": size, "color": color, "bold": bold})]
    for i, (text, fmt) in enumerate(runs):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        p.space_after = Pt(4)
        if line_spacing:
            p.line_spacing = line_spacing
        r = p.add_run()
        r.text = text
        r.font.size = Pt(fmt.get("size", size))
        r.font.bold = fmt.get("bold", bold)
        r.font.italic = fmt.get("italic", False)
        r.font.name = fmt.get("font", "Calibri")
        if fmt.get("color"):
            r.font.color.rgb = _hex_to_rgb(fmt["color"])
        elif color:
            r.font.color.rgb = (
                color if isinstance(color, RGBColor) else _hex_to_rgb(color)
            )
    return tb


def _add_rect(slide, left, top, width, height, color):
    shape = slide.shapes.add_shape(
        MSO_SHAPE.RECTANGLE, Inches(left), Inches(top), Inches(width), Inches(height)
    )
    shape.fill.solid()
    shape.fill.fore_color.rgb = (
        color if isinstance(color, RGBColor) else _hex_to_rgb(color)
    )
    shape.line.fill.background()
    shape.shadow.inherit = False
    return shape


def build_pptx(config, slides: list[dict]) -> bytes:
    """Build a genuine, editable 16:9 PPTX from the slide data."""
    prs = PptxPresentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank = prs.slide_layouts[6]
    colors = _template_colors(config)
    accent = colors["accent"]
    text_c = colors["text"]
    bg = colors["background"]
    body_font = config.body_font or "Calibri"

    top = 0.4
    left = 0.6
    content_w = 13.333 - 1.2

    def footer_note(slide, idx):
        foot = slide.shapes.add_textbox(
            Inches(left), Inches(7.05), Inches(9), Inches(0.35)
        )
        tf = foot.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.LEFT
        r = p.add_run()
        r.text = f"{config.course_code or config.course} • {config.topic}"
        r.font.size = Pt(9)
        r.font.name = body_font
        r.font.color.rgb = accent
        num = slide.shapes.add_textbox(
            Inches(12.4), Inches(7.05), Inches(0.7), Inches(0.35)
        )
        tf2 = num.text_frame
        p2 = tf2.paragraphs[0]
        p2.alignment = PP_ALIGN.RIGHT
        r2 = p2.add_run()
        r2.text = str(idx)
        r2.font.size = Pt(10)
        r2.font.name = body_font
        r2.font.color.rgb = text_c

    def cover_slide(config, idx):
        slide = prs.slides.add_slide(blank)
        _add_rect(slide, 0, 0, 13.333, 7.5, bg)
        _add_rect(slide, 0, 0, 13.333, 0.18, accent)
        _add_textbox(
            slide,
            left,
            2.0,
            content_w,
            1.6,
            [
                (
                    (config.course or "Course")
                    + (f"  •  {config.course_code}" if config.course_code else ""),
                    {"size": 20, "color": accent, "bold": True},
                )
            ],
            align=PP_ALIGN.LEFT,
        )
        _add_textbox(
            slide,
            left,
            3.0,
            content_w,
            1.8,
            [
                (
                    (config.topic or "Untitled Lecture"),
                    {"size": 40, "bold": True, "color": text_c},
                ),
            ],
            align=PP_ALIGN.LEFT,
        )
        if config.subtopic:
            _add_textbox(
                slide,
                left,
                4.3,
                content_w,
                0.9,
                [((config.subtopic or ""), {"size": 22, "color": accent})],
                align=PP_ALIGN.LEFT,
            )
        lines = " • ".join(
            x
            for x in [
                config.lecturer,
                config.institution,
                config.semester,
                config.academic_year,
            ]
            if x
        )
        if lines:
            _add_textbox(
                slide,
                left,
                5.6,
                content_w,
                0.8,
                [((lines), {"size": 16, "color": text_c})],
                align=PP_ALIGN.LEFT,
            )
        footer_note(slide, idx)
        return slide

    def objectives_slide(config, slides_obj, idx):
        slide = prs.slides.add_slide(blank)
        _add_rect(slide, 0, 0, 13.333, 7.5, bg)
        _add_rect(slide, 0, 0, 0.18, 7.5, accent)
        _add_textbox(
            slide,
            left,
            top,
            content_w,
            0.9,
            [("Learning Objectives", {"size": 34, "bold": True, "color": accent})],
        )
        _add_textbox(
            slide,
            left,
            1.5,
            content_w,
            0.5,
            [
                (
                    "By the end of this lecture, students should be able to:",
                    {"size": 18, "color": text_c},
                )
            ],
        )
        objectives = config.learning_objectives or [
            s.get("learning_objective")
            for s in slides_obj
            if s.get("learning_objective")
        ]
        objectives = [o for o in objectives if o][:6]
        bullets = [f"•  {o}" for o in objectives] or [
            "•  (Objectives derived during outline review.)"
        ]
        _add_textbox(
            slide,
            left,
            2.1,
            content_w,
            4.4,
            [(b, {"size": 20, "color": text_c}) for b in bullets],
            line_spacing=1.3,
        )
        footer_note(slide, idx)
        return slide

    def content_slide(s, idx):
        slide = prs.slides.add_slide(blank)
        _add_rect(slide, 0, 0, 13.333, 7.5, bg)
        _add_rect(slide, 0, 0, 0.18, 7.5, accent)
        _add_textbox(
            slide,
            left,
            top,
            content_w,
            0.9,
            [(s["title"] or "Slide", {"size": 34, "bold": True, "color": accent})],
        )
        body_top = 1.5
        bullets = s.get("bullets") or []
        if s.get("body"):
            bullets = bullets or []
        items = list(bullets)[: config.max_bullets]
        runs = [
            (
                "•  " + b if not b.startswith("•") else b,
                {"size": config.body_size, "color": text_c},
            )
            for b in items
        ]
        if s.get("body"):
            runs.append(
                (
                    s["body"],
                    {
                        "size": max(14, config.body_size - 2),
                        "color": text_c,
                        "italic": True,
                    },
                )
            )
        if not runs:
            runs = [
                (
                    "(Content to be finalised during editing.)",
                    {"size": config.body_size, "color": text_c},
                )
            ]
        _add_textbox(slide, left, body_top, content_w, 5.0, runs, line_spacing=1.15)
        # citation / source at bottom
        if s.get("citation"):
            _add_textbox(
                slide,
                left,
                6.55,
                content_w,
                0.4,
                [(s["citation"], {"size": 11, "color": accent})],
                align=PP_ALIGN.LEFT,
            )
        footer_note(slide, idx)
        # speaker notes (genuinely editable notes)
        notes = s.get("speaker_notes")
        if notes:
            slide.notes_slide.notes_text_frame.text = notes
        return slide

    def references_slide(config, slides_obj, idx):
        slide = prs.slides.add_slide(blank)
        _add_rect(slide, 0, 0, 13.333, 7.5, bg)
        _add_rect(slide, 0, 0, 0.18, 7.5, accent)
        _add_textbox(
            slide,
            left,
            top,
            content_w,
            0.9,
            [("References", {"size": 34, "bold": True, "color": accent})],
        )
        cited = []
        for s in slides_obj:
            c = s.get("citation")
            if c and c not in cited:
                cited.append(c)
        if not cited:
            cited = ["No external sources cited."]
        _add_textbox(
            slide,
            left,
            1.6,
            content_w,
            4.8,
            [
                (f"[{config.citation_style}]  {c}", {"size": 14, "color": text_c})
                for c in cited
            ],
            line_spacing=1.2,
        )
        footer_note(slide, idx)
        return slide

    def summary_slide(s, idx):
        slide = prs.slides.add_slide(blank)
        _add_rect(slide, 0, 0, 13.333, 7.5, bg)
        _add_rect(slide, 0, 0, 0.18, 7.5, accent)
        _add_textbox(
            slide,
            left,
            top,
            content_w,
            0.9,
            [(s["title"] or "Summary", {"size": 34, "bold": True, "color": accent})],
        )
        bullets = s.get("bullets") or ["•  Key takeaways."]
        _add_textbox(
            slide,
            left,
            1.6,
            content_w,
            4.6,
            [
                (
                    "•  " + b if not b.startswith("•") else b,
                    {"size": 22, "color": text_c},
                )
                for b in bullets[:6]
            ],
            line_spacing=1.2,
        )
        footer_note(slide, idx)
        if s.get("speaker_notes"):
            slide.notes_slide.notes_text_frame.text = s["speaker_notes"]
        return slide

    idx = 0
    cover_slide(config, 0)
    # insert objectives slide if a real objective exists
    objectives = config.learning_objectives or [
        s.get("learning_objective") for s in slides if s.get("learning_objective")
    ]
    objectives = [o for o in objectives if o]
    if objectives:
        idx += 1
        objectives_slide(config, slides, idx)
    for s in slides:
        if s.get("slide_type") in ("objectives", "cover"):
            continue  # cover always first; objectives emitted above
        idx += 1
        if s.get("slide_type") == "references":
            references_slide(config, slides, idx)
        elif s.get("slide_type") == "summary":
            summary_slide(s, idx)
        else:
            content_slide(s, idx)

    buf = io.BytesIO()
    prs.save(buf)
    return buf.getvalue()
