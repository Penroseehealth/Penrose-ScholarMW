"""Async spec-generation job queue (in-process, mirrors practical/jobs).

Spec generation is fast and deterministic, so the job completes almost
immediately; the job abstraction keeps the API contract future-proof for
slow AI/rendering phases (per the master requirement that long tasks must not
block the HTTP request).
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from app.biology_viz.engine import build_spec
from app.biology_viz.schemas import GenerateStatus
from app.database.engine import async_session
from app.models.biology_viz import BiologyVisualization

_STAGE_PROGRESS = {
    "QUEUED": 0.05,
    "GENERATING": 0.4,
    "PERSISTING": 0.9,
    "COMPLETED": 1.0,
}


@dataclass
class GenerationTask:
    job_id: int
    status: str = "QUEUED"
    progress: float = 0.05
    visualization_id: int | None = None
    error: str | None = None
    task: "asyncio.Task[None] | None" = None


class GenerationJobStore:
    """Registry of in-flight spec-generation tasks (in-memory)."""

    def __init__(self) -> None:
        self._tasks: dict[int, GenerationTask] = {}
        self._counter = 0

    def create(self) -> GenerationTask:
        self._counter += 1
        task = GenerationTask(job_id=self._counter)
        self._tasks[task.job_id] = task
        return task

    def get(self, job_id: int) -> GenerationTask | None:
        return self._tasks.get(job_id)


job_store = GenerationJobStore()


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


async def run_spec_generation(
    job: GenerationTask,
    prompt: str,
    opts: dict[str, Any],
) -> None:
    try:
        job.status = "GENERATING"
        job.progress = _STAGE_PROGRESS["GENERATING"]
        async with async_session() as session:
            spec, detected = await build_spec(
                session,
                prompt,
                app=opts.get("app"),
                form=opts.get("form"),
                topic=opts.get("topic"),
                subtopic=opts.get("subtopic"),
                background=opts.get("background", "white"),
                labels_shown=opts.get("labels_shown"),
                quality_level=opts.get("quality_level", "standard"),
                exclude=set(opts.get("exclude") or []),
            )
            viz = BiologyVisualization(
                user_id=opts.get("user_id"),
                subject_slug="biology",
                form=spec.form,
                category=spec.category,
                topic=spec.topic,
                subtopic=spec.subtopic,
                prompt=prompt,
                diagram_type=spec.diagram_type,
                spec=spec.model_dump(),
                title=spec.title,
                thumbnail_svg=None,
                quality_level=spec.quality_level,
                background=spec.background,
                labels_shown=spec.labels_shown,
                syllabus_reference=spec.syllabus_reference,
            )
            session.add(viz)
            await session.commit()
            await session.refresh(viz)
            job.visualization_id = viz.id
        job.status = "PERSISTING"
        job.progress = _STAGE_PROGRESS["PERSISTING"]
        job.status = "COMPLETED"
        job.progress = _STAGE_PROGRESS["COMPLETED"]
    except Exception:  # pragma: no cover - defensive
        job.status = "FAILED"
        job.error = "Diagram generation failed unexpectedly."


def enqueue_spec_generation(prompt: str, opts: dict[str, Any]) -> GenerationTask:
    job = job_store.create()
    job.task = asyncio.create_task(run_spec_generation(job, prompt, opts))
    return job


def to_status(job: GenerationTask) -> GenerateStatus:
    return GenerateStatus(
        job_id=job.job_id,
        visualization_id=job.visualization_id,
        status=job.status,
        progress=round(job.progress, 2),
        error=job.error,
    )
