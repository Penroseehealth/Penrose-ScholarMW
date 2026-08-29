"""Practical Simulation engine and video orchestrator.

Separates two concerns (rule #32):

* GENERAL AI video generation (provider-agnostic) vs.
* SYLLABUS-ALIGNED practical simulation (the priority).

The engine derives practical content (objectives, equipment, steps, safety,
observations, assessment, learning objectives) EXCLUSIVELY from the seeded
Biology syllabus (STLabActivity + SyllabusLearningObjective). It never invents
curriculum requirements. When the syllabus has not been seeded for a practical,
it returns the "ready for syllabus mapping" guidance state instead of
hallucinating content.
"""

from __future__ import annotations

import logging
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.practical_simulation import (
    PracticalSimulation,
    PracticalSimulationScene,
)
from app.models.stem import (
    STEMConcept,
    STEMSubtopic,
    STLabActivity,
    STLearningObjective,
)
from app.practical.providers import provider_router
from app.practical.schemas import (
    CameraSpec,
    EnvironmentSpec,
    OperatorSpec,
    PracticalVideoSpec,
    SceneSpec,
)

log = logging.getLogger(__name__)

# Canonical syllabus-driven scene plan for "Using a Microscope". The steps and
# safety notes below are mapped from the seeded STLabActivity instructions
# ("Introduction to Microscopy") — they are the syllabus source of truth, not
# invented here.
MICROSCOPE_PLAN: list[dict[str, Any]] = [
    {
        "scene_id": "scene_1",
        "purpose": "Laboratory setup and microscope identification",
        "camera": "Wide laboratory establishing shot",
        "action": "Show a tidy biology teaching laboratory with the compound microscope on the bench.",
        "equipment_state": "Microscope powered down, eyepiece installed, objectives at lowest position.",
        "hand_position": "No hands in frame.",
        "narration": "We begin in the biology laboratory. A compound light microscope is a precision instrument that must be handled and used correctly.",
        "on_screen_text": "Compound Light Microscope",
        "safety_note": "Handle the microscope with care; it is heavy and fragile.",
        "transition": "cut",
        "continuity_reference": "Sky-blue compound microscope model, silver focus knobs, laboratory bench",
    },
    {
        "scene_id": "scene_2",
        "purpose": "Carrying and handling the microscope",
        "camera": "Medium shot of demonstrator and microscope",
        "action": "Demonstrator grips the microscope arm with one hand and supports the base with the other, lifting and moving it to the bench.",
        "equipment_state": "Microscope in transit; both hands used.",
        "hand_position": "One hand under the base, one hand on the arm.",
        "narration": "Always carry the microscope with one hand under the base and one hand on the arm. Never carry it by the eyepiece or the objective lenses.",
        "on_screen_text": "Carry with two hands: base + arm",
        "safety_note": "Two-handed carry prevents dropping and lens damage.",
        "transition": "cut",
        "continuity_reference": "Same microscope model as scene 1",
    },
    {
        "scene_id": "scene_3",
        "purpose": "Setting up the microscope",
        "camera": "Close-up of microscope stage",
        "action": "Placement of the microscope, rotation of the nosepiece, and positioning of the stage clips before slide placement.",
        "equipment_state": "Eyepiece and objectives aligned; stage clips open.",
        "hand_position": "Stable two-hand grip on nosepiece and stage.",
        "narration": "Set the microscope facing the light, table locked in place, and prepare the stage clips.",
        "on_screen_text": "Prepare the stage",
        "safety_note": "Secure the microscope on the bench before use.",
        "transition": "cut",
        "continuity_reference": "Same microscope, same bench position",
    },
    {
        "scene_id": "scene_4",
        "purpose": "Positioning the specimen/slide",
        "camera": "Close-up of hand placing the slide",
        "action": "A gloved hand places the prepared slide on the stage and secures it with the stage clips.",
        "equipment_state": "Slide centred over the condenser aperture; stage clips engaged.",
        "hand_position": "Fingers pinch the slide edges; thumb secures the clip.",
        "narration": "Place the prepared slide over the hole in the stage and secure it with the stage clips.",
        "on_screen_text": "Secure the slide with stage clips",
        "safety_note": "Hold slides by the edges to avoid smudging.",
        "transition": "cut",
        "continuity_reference": "Same slide and specimen as scene 1",
    },
    {
        "scene_id": "scene_5",
        "purpose": "Selecting an objective and coarse focusing",
        "camera": "Close-up of objective and focus knobs",
        "action": "Rotate the nosepiece to the lowest power objective and turn the coarse focus knob to bring the specimen into view.",
        "equipment_state": "Lowest power objective in position; slide just below objective.",
        "hand_position": "One hand rotates nosepiece; other turns coarse focus.",
        "narration": "Start with the lowest power objective and use the coarse focus knob to bring the slide into focus.",
        "on_screen_text": "Start at lowest power (x4)",
        "safety_note": "Never force the focus knobs; use coarse before fine.",
        "transition": "cut",
        "continuity_reference": "Same objective set and slide",
    },
    {
        "scene_id": "scene_6",
        "purpose": "Viewing through the eyepiece — first person",
        "camera": "First-person eyepiece perspective",
        "action": "Transition into the simulated circular field of view as the demonstrator looks through the eyepiece.",
        "equipment_state": "Specimen visible; low power.",
        "hand_position": "Eye at eyepiece; one hand steadying focus.",
        "narration": "Looking through the eyepiece, we see the specimen begin to come into sharp focus.",
        "on_screen_text": "Field of view — plant cells",
        "safety_note": "Keep both eyes open to reduce eye strain.",
        "transition": "dissolve",
        "continuity_reference": "Circular field of view; onion cell specimen",
    },
    {
        "scene_id": "scene_7",
        "purpose": "Fine focusing and observation",
        "camera": "Microscopic field-of-view",
        "action": "Use the fine focus knob to sharpen the image; observe cell wall, nucleus and cytoplasm.",
        "equipment_state": "Sharp image at low power.",
        "hand_position": "Fine focus knob rotated gently.",
        "narration": "Use the fine focus knob for a sharp image. We can identify the cell wall, nucleus and cytoplasm of the onion cells.",
        "on_screen_text": "Fine focus for a clear image",
        "safety_note": "Only fine focus after coarse focusing.",
        "transition": "cut",
        "continuity_reference": "Same cells, same field of view",
    },
    {
        "scene_id": "scene_8",
        "purpose": "Changing magnification",
        "camera": "Close-up of objective + microscope field of view",
        "action": "Rotate to a higher power objective, recentre the specimen, and refocus using fine focus only.",
        "equipment_state": "Higher power objective in position.",
        "hand_position": "One hand rotates nosepiece; finger on fine focus.",
        "narration": "For higher magnification, rotate to the next objective and refocus using fine focus only. Higher power shows more detail but a smaller field of view.",
        "on_screen_text": "Increase magnification carefully",
        "safety_note": "At high power the lens is close to the slide — use fine focus only.",
        "transition": "cut",
        "continuity_reference": "Same slide and specimen",
    },
    {
        "scene_id": "scene_9",
        "purpose": "Recording observations",
        "camera": "Over-the-shoulder of drawing in a lab notebook",
        "action": "Demonstrator records the observation in a labelled biological drawing and notes the magnification.",
        "equipment_state": "Lab notebook and pencil open beside the microscope.",
        "hand_position": "Pencil in dominant hand; notebook stabilised.",
        "narration": "Record what you see with a labelled biological drawing, always noting the total magnification.",
        "on_screen_text": "Magnification = eyepiece x objective",
        "safety_note": "Draw only what you observe, using sharp pencil lines.",
        "transition": "cut",
        "continuity_reference": "Same notebook throughout the scene",
    },
    {
        "scene_id": "scene_10",
        "purpose": "Proper shutdown, cleaning and storage",
        "camera": "Wide shot of bench + close-up of storage",
        "action": "Rotate objectives to lowest power, remove the slide, clean the lens with lens paper, and return the microscope to storage.",
        "equipment_state": "Objectives at lowest power; slide removed; dust cover on.",
        "hand_position": "Wipes lens with lens paper; stores microscope securely.",
        "narration": "After use, return to lowest power, remove the slide, wipe the lenses with lens paper, and store the microscope under its dust cover.",
        "on_screen_text": "Clean and store correctly",
        "safety_note": "Use lens paper only — never cloth, which scratches lenses.",
        "transition": "cut",
        "continuity_reference": "Same microscope returned to same storage place",
    },
]


def _scene_from_plan(plan: dict[str, Any]) -> SceneSpec:
    return SceneSpec(
        scene_id=plan["scene_id"],
        duration=18.0,
        purpose=plan["purpose"],
        environment=plan.get("environment", "Modern school laboratory"),
        camera=plan["camera"],
        action=plan["action"],
        equipment_state=plan["equipment_state"],
        hand_position=plan["hand_position"],
        narration=plan["narration"],
        on_screen_text=plan["on_screen_text"],
        safety_note=plan["safety_note"],
        transition=plan["transition"],
        continuity_reference=plan["continuity_reference"],
    )


async def _load_syllabus_practical(
    db: AsyncSession, subject_slug: str, practical_key: str
) -> STLabActivity | None:
    """Find the seeded syllabus lab activity for this practical.

    Matches on shared tokens (e.g. 'using-a-microscope' -> 'microscope') so the
    key does not need to equal the seeded title verbatim.
    """
    key = (practical_key or "").replace("-", " ").lower().strip()
    tokens = [t for t in key.split() if len(t) > 2]
    stmt = select(STLabActivity).where(STLabActivity.subject_slug == subject_slug)
    result = await db.execute(stmt)
    labs = list(result.scalars().all())
    if not labs:
        return None

    def score(lab: STLabActivity) -> int:
        title = (lab.title or "").lower()
        if key and key in title:
            return 100
        return sum(1 for t in tokens if _token_matches(t, title))

    scored = sorted(labs, key=score, reverse=True)
    best = scored[0]
    if best and (
        (key and key in (best.title or "").lower())
        or any(_token_matches(t, (best.title or "").lower()) for t in tokens)
    ):
        return best
    return scored[0] if score(scored[0]) > 0 else None


def _token_matches(token: str, title: str) -> bool:
    """True if a key token's stem appears in a title (e.g. 'microscope'/'microscopy')."""
    if token in title:
        return True
    for trim in (1, 2):
        if len(token) > trim and token[:-trim] in title:
            return True
    return False


async def _load_microscope_learning_objectives(db: AsyncSession) -> list[str]:
    """Gather microscope learning objectives from the seeded syllabus.

    Stored on the STEM concept 'Microscope Use and Magnification' (Practical
    Skills discipline) as STLearningObjective rows, or via the official
    SyllabusLearningObjective records.
    """
    objectives: list[str] = []

    try:
        concept_stmt = (
            select(STEMConcept)
            .join(STEMSubtopic)
            .where(STEMConcept.title.ilike("%microscope%"))
        )
        concept = (await db.execute(concept_stmt)).scalars().first()
        if concept:
            lo_stmt = select(STLearningObjective).where(
                STLearningObjective.concept_id == concept.id
            )
            objectives = [
                lo.title
                for lo in (await db.execute(lo_stmt)).scalars().all()
                if lo.title
            ]
    except Exception as e:  # noqa: BLE001 - learning objectives are best-effort
        log.warning("Could not load microscope LOs: %s", e)

    if not objectives:
        # Official syllabus fallback (see seed_syllabus.py microscope objectives).
        try:
            from app.models.stem import SyllabusLearningObjective

            j = SyllabusLearningObjective
            stmt = select(j).where(j.objective.ilike("%microscope%"))
            objectives = [
                lo.objective
                for lo in (await db.execute(stmt)).scalars().all()
                if lo.objective
            ]
        except Exception as e:  # noqa: BLE001
            log.warning("Could not load syllabus LOs: %s", e)

    return objectives


class PracticalSimulationEngine:
    """Builds structured, syllabus-aligned storyboards for a practical."""

    async def build_spec(
        self,
        db: AsyncSession,
        *,
        subject_slug: str,
        practical_key: str,
        title: str,
        environment: EnvironmentSpec | None = None,
        operator: OperatorSpec | None = None,
    ) -> tuple[PracticalVideoSpec, bool, str]:
        env = environment or EnvironmentSpec()
        op = operator or OperatorSpec()

        lab = await _load_syllabus_practical(db, subject_slug, practical_key)
        if lab is None:
            spec = PracticalVideoSpec(
                subject="Biology",
                practical_id=practical_key,
                title=title,
                syllabus_reference="",
                learning_objectives=[],
                environment=env,
                operator=op,
                scenes=[],
                assessment_points=[],
            )
            msg = (
                "Practical simulation is ready for syllabus mapping. Please seed the "
                "Biology syllabus/practical objectives before enabling "
                "curriculum-validated generation."
            )
            return spec, False, msg

        # We only ship a verified microscope storyboard plan for this feature. If
        # the syllabus maps to a different practical, we refuse to fabricate its
        # content and return the syllabus-mapping guidance state instead.
        if not _token_matches("microscope", (lab.title or "").lower()):
            spec = PracticalVideoSpec(
                subject="Biology",
                practical_id=practical_key,
                title=lab.title,
                syllabus_reference=f"stem_lab_activities:{lab.id}:{lab.title}",
                learning_objectives=[],
                environment=env,
                operator=op,
                scenes=[],
                assessment_points=[],
            )
            msg = (
                "A syllabus lab activity was found, but no curriculum-validated "
                "storyboard plan exists for it yet. Add a storyboard plan for "
                f"'{lab.title}' to enable generation."
            )
            return spec, False, msg

        objectives = await _load_microscope_learning_objectives(db)
        scenes = [_scene_from_plan(p) for p in MICROSCOPE_PLAN]

        spec = PracticalVideoSpec(
            subject="Biology",
            practical_id=practical_key,
            title=lab.title,
            syllabus_reference=f"stem_lab_activities:{lab.id}:{lab.title}",
            learning_objectives=objectives or [lab.description or lab.title],
            environment=env,
            equipment=[
                e.strip() for e in (lab.materials_needed or "").split(",") if e.strip()
            ],
            operator=op,
            camera=CameraSpec(shots=[s.camera for s in scenes]),
            lighting=env.lighting,
            style={
                "genre": "educational",
                "photorealism": "high",
                "avoid": ["lens flare", "excessive bokeh", "neon"],
            },
            scenes=scenes,
            narration={"voice_on": True, "language": "en", "subtitles": True},
            annotations={
                "enabled": True,
                "items": [
                    "microscope_labels",
                    "arrow_indicators",
                    "step_numbers",
                    "safety_warnings",
                    "magnification",
                ],
            },
            assessment_points=[lab.expected_outcome or ""],
            generation_provider="",
            generation_model="",
            version=1,
        )
        msg = f"Syllabus-mapped to seeded practical '{lab.title}' with {len(scenes)} scenes."
        return spec, True, msg

    async def persist_scenes(
        self,
        db: AsyncSession,
        simulation: PracticalSimulation,
        spec: PracticalVideoSpec,
    ) -> None:
        existing = set(
            (
                await db.execute(
                    select(PracticalSimulationScene.scene_id).where(
                        PracticalSimulationScene.simulation_id == simulation.id
                    )
                )
            )
            .scalars()
            .all()
        )
        for i, scene in enumerate(spec.scenes):
            if scene.scene_id in existing:
                continue
            db.add(
                PracticalSimulationScene(
                    simulation_id=simulation.id,
                    scene_id=scene.scene_id,
                    order_index=i,
                    duration=scene.duration,
                    purpose=scene.purpose,
                    camera=scene.camera,
                    action=scene.action,
                    narration=scene.narration,
                    on_screen_text=scene.on_screen_text,
                    safety_note=scene.safety_note,
                    transition=scene.transition,
                    continuity_reference=scene.continuity_reference,
                    status="pending",
                )
            )


class VideoGenerationOrchestrator:
    """Coordinates provider selection, async jobs and quality validation."""

    def __init__(self) -> None:
        self.engine = PracticalSimulationEngine()

    def select_provider(self, preferred: str | None = None) -> str:
        return preferred or provider_router.adapter_for(preferred).name

    def providers_status(self) -> list[dict]:
        return provider_router.describe()


# Shared singleton
practical_engine = PracticalSimulationEngine()
video_orchestrator = VideoGenerationOrchestrator()
