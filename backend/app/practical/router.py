"""Practical Simulation Video API — Biology (syllabus-driven).

Endpoints let the frontend create, storyboard, generate, regenerate, modify,
track, version, save and delete practical simulations. Generation is async and
provider-gated (no Runway/Luma key configured => structured 'no provider'
status, educational content stays fully functional).
"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.practical_simulation import (
    PracticalSimulation,
    PracticalSimulationGeneration,
    PracticalSimulationVersion,
)
from app.practical.jobs import enqueue_generation
from app.practical.orchestrator import practical_engine
from app.practical.providers import provider_router
from app.practical.schemas import (
    GenerateRequest,
    GenerationStatus,
    ModifyRequest,
    PracticalVideoSpec,
    RegenerateRequest,
    SimulationCreate,
    SimulationDetail,
    SimulationSummary,
    StoryboardRequest,
    StoryboardResponse,
    VersionSummary,
)

router = APIRouter(
    prefix="/biology/practicals/simulations", tags=["Practical Simulations"]
)


# ── Serialization helpers ────────────────────────────────────────


def _summary(
    sim: PracticalSimulation, generations: list[PracticalSimulationGeneration]
) -> SimulationSummary:
    latest_status = None
    latest_video_url = None
    if generations:
        latest = generations[-1]
        latest_status = latest.status
        if latest.result:
            latest_video_url = latest.result.get("video_url")
    return SimulationSummary(
        id=sim.id,
        subject_slug=sim.subject_slug,
        practical_key=sim.practical_key,
        title=sim.title,
        description=sim.description,
        syllabus_reference=sim.syllabus_reference,
        is_saved=sim.is_saved,
        versions=len(sim.versions),
        latest_status=latest_status,
        latest_video_url=latest_video_url,
    )


def _spec(sim: PracticalSimulation) -> PracticalVideoSpec | None:
    if not sim.spec:
        return None
    return PracticalVideoSpec.model_validate(sim.spec)


def _generation_status(gen: PracticalSimulationGeneration) -> GenerationStatus:
    video_url = gen.result.get("video_url") if gen.result else None
    return GenerationStatus(
        job_id=gen.id,
        simulation_id=gen.simulation_id,
        status=gen.status,
        progress=gen.progress,
        provider=gen.provider,
        model=gen.model,
        estimated_credits=gen.estimated_credits,
        error=gen.error,
        video_url=video_url,
        qc={"status": gen.qc_status or "unknown"},
    )


def _version_summary(v: PracticalSimulationVersion) -> VersionSummary:
    return VersionSummary(
        id=v.id,
        version=v.version,
        is_current=v.is_current,
        generation_id=v.generation_id,
        video_url=v.video_url,
        thumbnail_url=v.thumbnail_url,
        created_at=v.created_at.isoformat() if v.created_at else None,
    )


async def _load_sim(db: AsyncSession, simulation_id: int) -> PracticalSimulation:
    stmt = (
        select(PracticalSimulation)
        .options(
            selectinload(PracticalSimulation.versions),
            selectinload(PracticalSimulation.scenes),
            selectinload(PracticalSimulation.generations),
        )
        .where(PracticalSimulation.id == simulation_id)
    )
    sim = (await db.execute(stmt)).scalars().first()
    if sim is None:
        raise HTTPException(status_code=404, detail="Simulation not found")
    return sim


def _require_spec(sim: PracticalSimulation) -> dict[str, Any]:
    if not sim.spec:
        raise HTTPException(status_code=409, detail="Simulation has no storyboard yet")
    return sim.spec


# ── Endpoints ────────────────────────────────────────────────────


@router.post("", status_code=201, response_model=SimulationDetail)
async def create_simulation(
    body: SimulationCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Create a simulation record and build its syllabus storyboard."""
    existing = (
        (
            await db.execute(
                select(PracticalSimulation).where(
                    PracticalSimulation.subject_slug == body.subject_slug,
                    PracticalSimulation.practical_key == body.practical_key,
                )
            )
        )
        .scalars()
        .first()
    )
    if existing:
        raise HTTPException(status_code=409, detail="Simulation already exists")

    spec_model, mapped, _msg = await practical_engine.build_spec(
        db,
        subject_slug=body.subject_slug,
        practical_key=body.practical_key,
        title=body.title,
    )
    sim = PracticalSimulation(
        subject_slug=body.subject_slug,
        practical_key=body.practical_key,
        title=spec_model.title or body.title,
        description=body.description,
        syllabus_reference=spec_model.syllabus_reference or None,
        source_type="lab_activity",
        spec=spec_model.model_dump(),
        user_id=user.id if user else None,
        is_saved=False,
    )
    db.add(sim)
    await db.flush()
    await practical_engine.persist_scenes(db, sim, spec_model)
    await db.commit()
    sim = await _load_sim(db, sim.id)
    return SimulationDetail(
        id=sim.id,
        subject_slug=sim.subject_slug,
        practical_key=sim.practical_key,
        title=sim.title,
        description=sim.description,
        syllabus_reference=sim.syllabus_reference,
        spec=_spec(sim),
        num_scenes=len(sim.scenes),
    )


@router.get("", response_model=list[SimulationSummary])
async def list_simulations(
    subject: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    stmt = select(PracticalSimulation).options(
        selectinload(PracticalSimulation.versions),
        selectinload(PracticalSimulation.generations),
    )
    if subject:
        stmt = stmt.where(PracticalSimulation.subject_slug == subject)
    rows = (
        (await db.execute(stmt.order_by(PracticalSimulation.updated_at.desc())))
        .scalars()
        .all()
    )
    return [_summary(s, list(s.generations)) for s in rows]


@router.get("/{simulation_id}", response_model=SimulationDetail)
async def get_simulation(
    simulation_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    sim = await _load_sim(db, simulation_id)
    return SimulationDetail(
        id=sim.id,
        subject_slug=sim.subject_slug,
        practical_key=sim.practical_key,
        title=sim.title,
        description=sim.description,
        syllabus_reference=sim.syllabus_reference,
        spec=_spec(sim),
        num_scenes=len(sim.scenes),
    )


@router.post("/{simulation_id}/storyboard", response_model=StoryboardResponse)
async def build_storyboard(
    simulation_id: int,
    body: StoryboardRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    sim = await _load_sim(db, simulation_id)
    spec_model, mapped, msg = await practical_engine.build_spec(
        db,
        subject_slug=sim.subject_slug,
        practical_key=sim.practical_key,
        title=sim.title,
        environment=body.environment,
        operator=body.operator,
    )
    sim.spec = spec_model.model_dump()
    await practical_engine.persist_scenes(db, sim, spec_model)
    await db.commit()
    return StoryboardResponse(
        simulation_id=sim.id,
        spec=spec_model,
        syllabus_mapped=mapped,
        message=msg,
    )


@router.post(
    "/{simulation_id}/generate", response_model=GenerationStatus, status_code=202
)
async def generate(
    simulation_id: int,
    body: GenerateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    sim = await _load_sim(db, simulation_id)
    spec = _require_spec(sim)

    if not provider_router.configured_providers():
        raise HTTPException(
            status_code=503,
            detail="Video generation is not configured yet. Add a Runway or Luma API key on the backend to enable generation.",
        )

    provider = body.provider
    if provider and provider not in provider_router.configured_providers():
        raise HTTPException(
            status_code=400, detail=f"Provider '{provider}' is not configured"
        )

    if body.environment or body.operator:
        _env = body.environment.model_dump() if body.environment else None
        _op = body.operator.model_dump() if body.operator else None
        spec_model = PracticalVideoSpec.model_validate(spec)
        if _env:
            spec_model.environment = body.environment
        if _op:
            spec_model.operator = body.operator
        spec = spec_model.model_dump()
        sim.spec = spec
        await db.commit()

    spec["generation_provider"] = provider or ""
    gen = await enqueue_generation(sim, spec, body.quality)
    return _generation_status(gen)


@router.get("/{simulation_id}/generate/{job_id}", response_model=GenerationStatus)
async def generation_status(
    simulation_id: int,
    job_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    gen = await db.get(PracticalSimulationGeneration, job_id)
    if gen is None or gen.simulation_id != simulation_id:
        raise HTTPException(status_code=404, detail="Generation job not found")
    return _generation_status(gen)


@router.post(
    "/{simulation_id}/generate/{job_id}/cancel", response_model=GenerationStatus
)
async def cancel_generation(
    simulation_id: int,
    job_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    from app.practical.jobs import job_store

    gen = await db.get(PracticalSimulationGeneration, job_id)
    if gen is None or gen.simulation_id != simulation_id:
        raise HTTPException(status_code=404, detail="Generation job not found")
    task = job_store.get(job_id)
    if task:
        task.cancel()
    gen.status = "CANCELLED"
    await db.commit()
    return _generation_status(gen)


@router.post(
    "/{simulation_id}/regenerate", response_model=GenerationStatus, status_code=202
)
async def regenerate(
    simulation_id: int,
    body: RegenerateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    sim = await _load_sim(db, simulation_id)
    spec = _require_spec(sim)
    if not provider_router.configured_providers():
        raise HTTPException(
            status_code=503,
            detail="Video generation is not configured. Add a Runway or Luma API key to enable generation.",
        )
    if body.scope == "scene":
        if not body.scene_id:
            raise HTTPException(
                status_code=400,
                detail="scene_id is required for scene-level regenerate",
            )
        scenes = spec.get("scenes") or []
        if not any(s.get("scene_id") == body.scene_id for s in scenes):
            raise HTTPException(
                status_code=404, detail=f"Scene '{body.scene_id}' not found"
            )
    gen = await enqueue_generation(sim, spec, body.quality)
    return _generation_status(gen)


@router.post(
    "/{simulation_id}/modify", response_model=SimulationDetail, status_code=202
)
async def modify(
    simulation_id: int,
    body: ModifyRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Apply a text/scope-level modification to the storyboard (no generation)."""
    sim = await _load_sim(db, simulation_id)
    spec = _require_spec(sim)
    if body.instruction:
        spec = dict(spec)
        spec["modification_log"] = spec.get("modification_log") or []
        spec["modification_log"].append(
            {"instruction": body.instruction, "scope": body.scope}
        )
    sim.spec = spec
    await db.commit()
    return SimulationDetail(
        id=sim.id,
        subject_slug=sim.subject_slug,
        practical_key=sim.practical_key,
        title=sim.title,
        description=sim.description,
        syllabus_reference=sim.syllabus_reference,
        spec=_spec(sim),
        num_scenes=len(sim.scenes),
    )


@router.post("/{simulation_id}/save", response_model=SimulationSummary)
async def save_simulation(
    simulation_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    sim = await _load_sim(db, simulation_id)
    sim.is_saved = True
    await db.commit()
    return _summary(sim, list(sim.generations))


@router.get("/{simulation_id}/versions", response_model=list[VersionSummary])
async def list_versions(
    simulation_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    sim = await _load_sim(db, simulation_id)
    return [_version_summary(v) for v in sorted(sim.versions, key=lambda x: x.version)]


@router.delete("/{simulation_id}", status_code=204)
async def delete_simulation(
    simulation_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    sim = await _load_sim(db, simulation_id)
    await db.delete(sim)
    await db.commit()


@router.get("/providers/status")
async def providers_status(user: User = Depends(get_current_user)):
    return {
        "providers": provider_router.describe(),
        "configured": provider_router.configured_providers(),
        "generation_enabled": bool(provider_router.configured_providers()),
    }
