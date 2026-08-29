"""Practical Simulation Video data models.

Syllabus-aligned practical simulation video engine for Biology (and other
STEM subjects). Everything is keyed to the seeded syllabus / lab records so no
curriculum content is invented in the application code.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.engine import Base


class PracticalSimulation(Base):
    """A syllabus-linked practical simulation (e.g. 'Using a Microscope')."""

    __tablename__ = "practical_simulations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    subject_slug: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    practical_key: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Link to the seeded syllabus source (STLabActivity or SyllabusLearningObjective).
    syllabus_reference: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_type: Mapped[str] = mapped_column(String(50), default="lab_activity")
    source_id: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Full structured video spec (PracticalVideoSpec) serialized as JSON.
    spec: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)

    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    is_saved: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    versions: Mapped[list["PracticalSimulationVersion"]] = relationship(
        back_populates="simulation", cascade="all, delete-orphan"
    )
    scenes: Mapped[list["PracticalSimulationScene"]] = relationship(
        back_populates="simulation", cascade="all, delete-orphan"
    )
    generations: Mapped[list["PracticalSimulationGeneration"]] = relationship(
        back_populates="simulation", cascade="all, delete-orphan"
    )


class PracticalSimulationVersion(Base):
    """A saved version of a simulation. Regeneration never destroys old ones."""

    __tablename__ = "practical_simulation_versions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    simulation_id: Mapped[int] = mapped_column(
        ForeignKey("practical_simulations.id"), nullable=False, index=True
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    is_current: Mapped[bool] = mapped_column(Boolean, default=True)
    # ID of the generation job whose output this version represents.
    generation_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    video_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    thumbnail_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    settings: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    simulation: Mapped[PracticalSimulation] = relationship(back_populates="versions")


class PracticalSimulationScene(Base):
    """A single storyboard scene with continuity reference."""

    __tablename__ = "practical_simulation_scenes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    simulation_id: Mapped[int] = mapped_column(
        ForeignKey("practical_simulations.id"), nullable=False, index=True
    )
    scene_id: Mapped[str] = mapped_column(String(100), nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    duration: Mapped[float] = mapped_column(Float, default=0)
    purpose: Mapped[str | None] = mapped_column(Text, nullable=True)
    camera: Mapped[str | None] = mapped_column(String(255), nullable=True)
    action: Mapped[str | None] = mapped_column(Text, nullable=True)
    narration: Mapped[str | None] = mapped_column(Text, nullable=True)
    on_screen_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    safety_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    transition: Mapped[str | None] = mapped_column(String(100), nullable=True)
    continuity_reference: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # Per-scene generation status (for scene-level regenerate).
    status: Mapped[str] = mapped_column(String(30), default="pending")
    asset_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    simulation: Mapped[PracticalSimulation] = relationship(back_populates="scenes")


class PracticalSimulationGeneration(Base):
    """An async video generation job."""

    __tablename__ = "practical_simulation_generations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    simulation_id: Mapped[int] = mapped_column(
        ForeignKey("practical_simulations.id"), nullable=False, index=True
    )
    status: Mapped[str] = mapped_column(String(30), default="QUEUED", index=True)
    qc_status: Mapped[str | None] = mapped_column(String(30), nullable=True)
    provider: Mapped[str | None] = mapped_column(String(100), nullable=True)
    model: Mapped[str | None] = mapped_column(String(255), nullable=True)
    provider_job_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    quality: Mapped[str] = mapped_column(String(20), default="standard")
    estimated_credits: Mapped[float | None] = mapped_column(Float, nullable=True)
    progress: Mapped[float] = mapped_column(Float, default=0.0)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    result: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    simulation: Mapped[PracticalSimulation] = relationship(back_populates="generations")
