"""Biology Visualization Engine data models.

Stores curriculum-grounded biology visualizations (structured diagram specs +
metadata). The actual SVG rendering is performed client-side (Flutter) from the
structured spec, but the spec + derived metadata are persisted here so saved
diagrams can be reopened, versioned, edited and exported later.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.engine import Base


class BiologyVisualization(Base):
    """A saved biology diagram: structured spec + metadata."""

    __tablename__ = "biology_visualizations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)

    # Curriculum context.
    subject_slug: Mapped[str] = mapped_column(String(50), default="biology", index=True)
    form: Mapped[int] = mapped_column(Integer, default=1, index=True)  # 1-4
    category: Mapped[str] = mapped_column(String(50), default="cell")
    topic: Mapped[str] = mapped_column(String(255), default="")
    subtopic: Mapped[str] = mapped_column(String(255), default="")

    # Generation inputs.
    prompt: Mapped[str] = mapped_column(Text, default="")
    diagram_type: Mapped[str] = mapped_column(String(50), default="labelled_diagram")

    # The structured spec (BiologySpec) serialized as JSON — client renders SVG.
    spec: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)

    # Rendered/summary metadata.
    title: Mapped[str] = mapped_column(String(255), default="Biology Diagram")
    thumbnail_svg: Mapped[str | None] = mapped_column(Text, nullable=True)
    quality_level: Mapped[str] = mapped_column(String(30), default="standard")
    background: Mapped[str] = mapped_column(String(30), default="white")
    labels_shown: Mapped[bool] = mapped_column(Boolean, default=True)
    syllabus_reference: Mapped[str | None] = mapped_column(Text, nullable=True)

    is_saved: Mapped[bool] = mapped_column(Boolean, default=True)
    is_current_version: Mapped[bool] = mapped_column(Boolean, default=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    versions: Mapped[list["BiologyVisualizationVersion"]] = relationship(
        back_populates="visualization", cascade="all, delete-orphan"
    )


class BiologyVisualizationVersion(Base):
    """A saved generation version. Regeneration never overwrites old versions."""

    __tablename__ = "biology_visualization_versions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    visualization_id: Mapped[int] = mapped_column(
        ForeignKey("biology_visualizations.id"), nullable=False, index=True
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    is_current: Mapped[bool] = mapped_column(Boolean, default=True)
    spec: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)
    thumbnail_svg: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    visualization: Mapped[BiologyVisualization] = relationship(
        back_populates="versions"
    )
