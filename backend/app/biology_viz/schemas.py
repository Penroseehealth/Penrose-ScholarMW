"""Biology Visualization Engine — API request/response schemas."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class GenerateRequest(BaseModel):
    prompt: str = Field(min_length=2, max_length=4000)
    form: int | None = Field(default=None, ge=1, le=4)
    app: str | None = None
    topic: str | None = None
    subtopic: str | None = None
    background: str = "white"
    labels_shown: bool | None = None
    quality_level: str = "standard"
    exclude: list[str] | None = None


class GenerateStatus(BaseModel):
    job_id: int
    visualization_id: int | None = None
    status: str
    progress: float = 0.0
    error: str | None = None


class SpecResponse(BaseModel):
    spec: dict[str, Any]
    detected: dict[str, Any]


class VisualizationSummary(BaseModel):
    id: int
    title: str
    category: str
    app: str
    form: int
    topic: str
    subtopic: str
    diagram_type: str
    thumbnail_svg: str | None = None
    version: int = 1
    created_at: str | None = None


class VisualizationDetail(BaseModel):
    id: int
    title: str
    category: str
    app: str
    form: int
    topic: str
    subtopic: str
    diagram_type: str
    prompt: str
    spec: dict[str, Any]
    background: str
    quality_level: str
    syllabus_reference: str | None = None
    versions: list[dict[str, Any]] = Field(default_factory=list)


class EditRequest(BaseModel):
    background: str | None = None
    labels_shown: bool | None = None
    title: str | None = None
    annotations: list[str] | None = None
    exclude: list[str] | None = None


class ExportRequest(BaseModel):
    fmt: str = "svg"
    width: int = 1600
    height: int = 1200
