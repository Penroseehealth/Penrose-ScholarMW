"""Biology Visualization engine core.

Pipeline: user prompt -> intent detection -> (form/topic) syllabus retrieval ->
structured Biological Specification -> (client renders SVG).

Phase 1 implements the Cell Biology slice with a deterministic, curated
knowledge base so the vertical slice is fully functional even without an LLM
key. LLM refinement is layered in when a provider is available.
"""

from __future__ import annotations

import json
import re

from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.biology_viz.specs import (
    CELL_APPS,
    BiologySpec,
    app_from_alias,
    build_cell_spec,
    build_process_spec,
    process_from_prompt,
)
from app.config.ai_client import call_ai_text
from app.models.stem import (
    SyllabusCoreElement,
    SyllabusSubject,
    SyllabusSubtopic,
    SyllabusTopic,
    SyllabusVersion,
)

# Keywords used for deterministic intent detection (works offline).
_APP_ALIASES: list[tuple[str, tuple[str, ...]]] = [
    ("plant_cell", ("plant", "parenchyma", "mesophyll", "epidermal")),
    ("animal_cell", ("animal", "human cell", "muscle cell", "red blood")),
    (
        "bacterial_cell",
        (
            "bacteria",
            "bacterium",
            "bacterial",
            "prokaryote",
            "prokaryotic",
            "bacillus",
            "coccus",
        ),
    ),
    ("fungal_cell", ("fungus", "fungi", "fungal", "yeast")),
]

_FORM_ALIASES: list[tuple[int, tuple[str, ...]]] = [
    (4, ("form 4", "form four", "form-4", "standard 8")),
    (3, ("form 3", "form three", "form-3", "msce")),
    (2, ("form 2", "form two", "form-2")),
    (1, ("form 1", "form one", "form-1")),
]


class DetectedRequest(BaseModel):
    """What the engine inferred from the user prompt."""

    category: str = "cell"
    app: str = "plant_cell"
    form: int = 1
    topic: str = ""
    subtopic: str = ""
    diagram_type: str = "labelled_diagram"


def _detect_app(prompt: str) -> str:
    lowered = prompt.lower()
    for app, keys in _APP_ALIASES:
        if any(k in lowered for k in keys):
            return app
    # Fallback: explicit 'X cell' mention.
    m = re.search(r"\b(plant|animal|bacterial|fungal)\s+cell\b", lowered)
    return m.group(1) + "_cell" if m else "plant_cell"


def _detect_form(prompt: str) -> int:
    lowered = prompt.lower()
    for form, keys in _FORM_ALIASES:
        if any(k in lowered for k in keys):
            return form
    return 1


def _detect_diagram_type(prompt: str) -> str:
    lowered = prompt.lower()
    if any(
        k in lowered
        for k in ("unlabel", "without labels", "no labels", "exam mode", "numbered")
    ):
        return "unlabelled_diagram"
    if any(k in lowered for k in ("label", "annotate", "numbered")):
        return "labelled_diagram"
    if any(k in lowered for k in ("compare", "comparison", "both")):
        return "comparative_diagram"
    return "labelled_diagram"


# Phrases that signal the user wants a specific organelle OMITTED (e.g. "plant
# cell without a central vacuole"). Enforced at the engine level so the spec
# (and therefore the rendered diagram) respects the request while still
# rejecting biologically impossible content.
_EXCLUDE_PATTERNS: list[tuple[str, tuple[str, ...]]] = [
    (
        "without",
        ("without ", "no ", "lacks ", "missing ", "minus ", "excluding ", "absent "),
    ),
]


def _detect_exclude(prompt: str) -> set[str]:
    """Return canonical structure ids the user asked to leave out."""
    lowered = " " + prompt.lower() + " "
    drop: set[str] = set()
    for target, markers in _EXCLUDE_PATTERNS:
        for marker in markers:
            start = 0
            while True:
                idx = lowered.find(marker, start)
                if idx < 0:
                    break
                j = idx + len(marker)
                end = j
                while end < len(lowered) and (
                    lowered[end].isalnum() or lowered[end] in " _-"
                ):
                    end += 1
                phrase = lowered[j:end].strip(" -\n\t")
                # Only treat as an organelle name if it references a cell structure.
                if phrase and _looks_like_organelle(phrase):
                    for cand in _organelle_candidates(phrase):
                        drop.add(cand)
                start = end
    return drop


def _looks_like_organelle(phrase: str) -> bool:
    return any(
        k in phrase
        for k in (
            "wall",
            "membrane",
            "nucleus",
            "nucleoid",
            "cytoplasm",
            "vacuole",
            "chloroplast",
            "mitochond",
            "ribosome",
            "endoplasmic",
            "golgi",
            "lysosome",
            "centriole",
            "capsule",
            "plasmid",
            "pili",
            "flagell",
        )
    )


def _organelle_candidates(phrase: str) -> list[str]:
    # Map an organelle phrase to one or more canonical structure ids.
    if "cell wall" in phrase:
        return ["cell_wall"]
    if "cell membrane" in phrase or "plasma membrane" in phrase:
        return ["cell_membrane", "capsule"]
    if "nucleus" in phrase:
        return ["nucleus"]
    if "nucleoid" in phrase or "dna" in phrase:
        return ["nucleoid_dna"]
    if "cytoplasm" in phrase:
        return ["cytoplasm"]
    if "vacuole" in phrase:
        return ["vacuole"]
    if "chloroplast" in phrase:
        return ["chloroplasts"]
    if "mitochond" in phrase:
        return ["mitochondria"]
    if "ribosome" in phrase:
        return ["ribosomes"]
    if "endoplasmic" in phrase or "reticulum" in phrase:
        return ["endoplasmic_reticulum"]
    if "golgi" in phrase:
        return ["golgi_apparatus"]
    if "lysosome" in phrase:
        return ["lysosomes"]
    if "centriole" in phrase:
        return ["centrioles"]
    if "capsule" in phrase:
        return ["capsule"]
    if "plasmid" in phrase:
        return ["plasmid"]
    if "pili" in phrase or "pilus" in phrase:
        return ["pili"]
    if "flagell" in phrase:
        return ["flagellum"]
    return []


def _detect_category(prompt: str) -> str:
    lowered = prompt.lower()
    if any(
        k in lowered
        for k in ("cell", "organelle", "chloroplast", "nucleus", "mitochondria")
    ):
        return "cell"
    if any(
        k in lowered
        for k in ("heart", "kidney", "lung", "digestive", "respiratory", "human")
    ):
        return "human"
    if any(k in lowered for k in ("flower", "leaf", "stem", "root", "plant", "botany")):
        return "botany"
    if any(
        k in lowered for k in ("animal", "frog", "fish", "insect", "bird", "zoology")
    ):
        return "zoology"
    if any(
        k in lowered for k in ("bacteria", "virus", "bacillus", "microbio", "microbe")
    ):
        return "microbiology"
    return "cell"


async def _resolve_syllabus(
    db: AsyncSession, form: int, prompt: str
) -> tuple[str, str, str | None]:
    """Return (topic, subtopic, syllabus_reference) grounded in the seeded Malawi syllabus."""
    try:
        subject = (
            await db.execute(
                select(SyllabusSubject).where(
                    SyllabusSubject.slug == "biology",
                    SyllabusSubject.is_active == True,  # noqa: E712
                )
            )
        ).scalar_one_or_none()
        if not subject:
            return "", "", None
        versions = (
            (
                await db.execute(
                    select(SyllabusVersion)
                    .where(SyllabusVersion.subject_id == subject.id)
                    .options(
                        joinedload(SyllabusVersion.core_elements)
                        .joinedload(SyllabusCoreElement.topics)
                        .joinedload(SyllabusTopic.subtopics)
                    )
                    .order_by(SyllabusVersion.id.desc())
                )
            )
            .scalars()
            .unique()
            .all()
        )
        lowered = prompt.lower()
        for version in versions:
            for ce in version.core_elements:
                for topic in ce.topics:
                    if topic.year_level != form:
                        continue
                    # Score topic against the prompt keywords.
                    score = _topic_score(lowered, topic.title)
                    if score > 0:
                        best_sub = _pick_subtopic(lowered, topic.subtopics)
                        ref = f"Biology Form {form} - {ce.name} - {topic.title}" + (
                            f" - {best_sub.title}" if best_sub else ""
                        )
                        return topic.title, (best_sub.title if best_sub else ""), ref
        return "", "", None
    except Exception:
        return "", "", None


def _topic_score(lowered: str, title: str) -> int:
    score = 0
    toks = [
        t
        for t in re.split(r"[\s\-/&,]+", title.lower())
        if len(t) > 2 and t not in ("and", "of", "the", "with")
    ]
    for tok in toks:
        if tok in lowered:
            score += 2
    if any(word in lowered for word in ("cell", "organelle", "microscope")):
        score += 1
    return score


def _pick_subtopic(
    lowered: str, subtopics: list[SyllabusSubtopic]
) -> SyllabusSubtopic | None:
    best = None
    best_score = 0
    for sub in subtopics:
        s = _topic_score(lowered, sub.title)
        if s > best_score:
            best_score = s
            best = sub
    return best if best_score > 0 else None


async def build_spec(
    db: AsyncSession,
    prompt: str,
    *,
    app: str | None = None,
    form: int | None = None,
    topic: str | None = None,
    subtopic: str | None = None,
    background: str = "white",
    labels_shown: bool | None = None,
    quality_level: str = "standard",
    exclude: set[str] | None = None,
) -> tuple[BiologySpec, DetectedRequest]:
    """Build a structured BiologySpec from a user prompt."""
    detected = DetectedRequest(
        category=_detect_category(prompt),
        app=app or _detect_app(prompt),
        form=form or _detect_form(prompt),
        topic=topic or "",
        subtopic=subtopic or "",
        diagram_type=_detect_diagram_type(prompt),
    )
    if labels_shown is None:
        labels_shown = detected.diagram_type != "unlabelled_diagram"

    det_app = (
        detected.app if detected.app in CELL_APPS else app_from_alias(detected.app)
    )
    res_topic, res_sub, ref = await _resolve_syllabus(db, detected.form, prompt)

    # Process / cycle diagrams (photosynthesis, respiration, carbon cycle, mitosis,
    # ...) render through ProcessDiagramRenderer, not the cell renderer. A process
    # prompt wins over any cell-app guess (e.g. "carbon cycle in a plant").
    proc_key = process_from_prompt(prompt)
    if proc_key is not None:
        spec = build_process_spec(
            proc_key,
            form=detected.form,
            topic=topic or res_topic or "",
            subtopic=subtopic or res_sub,
            background=background,
            labels_shown=labels_shown,
            quality_level=quality_level,
            syllabus_reference=ref,
        )
        return spec, detected

    org_exclude = _detect_exclude(prompt)
    if exclude:
        org_exclude |= {e.lower().replace(" ", "_") for e in exclude}

    spec = build_cell_spec(
        det_app,
        title=CELL_APPS[det_app],
        form=detected.form,
        topic=topic or res_topic or _guess_topic(det_app),
        subtopic=subtopic or res_sub,
        background=background,
        labels_shown=labels_shown,
        quality_level=quality_level,
        syllabus_reference=ref,
        exclude=org_exclude,
    )
    return spec, detected


def _guess_topic(app: str) -> str:
    return {
        "plant_cell": "Cell structure and organisation",
        "animal_cell": "Cell structure and organisation",
        "bacterial_cell": "Microorganisms",
        "fungal_cell": "Cell structure and organisation",
    }.get(app, "Cell structure and organisation")


async def refine_spec_with_ai(spec: BiologySpec) -> BiologySpec:
    """Optionally refine labels/annotations via LLM. Never required to succeed."""
    try:
        text = await call_ai_text(
            [
                {
                    "role": "system",
                    "content": (
                        "You refine a structured biology diagram spec. Return ONLY valid JSON "
                        "matching the same schema. Do not invent biology. Keep words inside strings "
                        "escaped."
                    ),
                },
                {
                    "role": "user",
                    "content": (
                        f"Refine this cell diagram spec: {json.dumps(spec.model_dump())}. "
                        "Return JSON with the same keys; you may improve annotations and ensure "
                        "labels are accurate."
                    ),
                },
            ],
            max_tokens=1200,
            temperature=0.2,
        )
        data = json.loads(text)
        return BiologySpec.model_validate(data)
    except Exception:
        return spec
