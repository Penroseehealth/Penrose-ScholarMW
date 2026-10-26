"""Pydantic schemas for the Asymptote diagram service.

Inputs are strictly typed per diagram kind; anything that ends up inside
Asymptote source as text is constrained to a safe character set, and function
expressions are additionally AST-whitelisted in the service layer.
"""

from __future__ import annotations

import re
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator

_SAFE_TEXT = re.compile(r"^[A-Za-z0-9 .,\-()+/°]*$")


class RightTriangleParams(BaseModel):
    a: float = Field(3.0, ge=0.1, le=1000.0, description="length of the horizontal leg")
    b: float = Field(4.0, ge=0.1, le=1000.0, description="length of the vertical leg")
    unit: str = Field("", max_length=12, description="optional unit suffix (e.g. cm)")

    @field_validator("unit")
    @classmethod
    def _unit_safe(cls, v: str) -> str:
        if v and not _SAFE_TEXT.match(v):
            raise ValueError("unit must be short alphanumeric text")
        return v


class CircleParams(BaseModel):
    radius: float = Field(2.5, gt=0.0, le=1000.0)
    show_axes: bool = True


class FunctionPlotParams(BaseModel):
    fn: str = Field("x^2 - 2", max_length=120, description="expression in x")
    xmin: float = Field(-3.0, ge=-1000.0, le=1000.0)
    xmax: float = Field(3.0, ge=-1000.0, le=1000.0)
    samples: int = Field(240, ge=20, le=600)

    @field_validator("xmax")
    @classmethod
    def _range(cls, v: float, info) -> float:
        if "xmin" in info.data and v <= info.data["xmin"]:
            raise ValueError("xmax must be greater than xmin")
        return v


class VectorParams(BaseModel):
    u: tuple[float, float] = Field((3.0, 2.0))
    v: tuple[float, float] | None = Field(
        (1.0, 3.0), description="optional second vector"
    )

    @field_validator("u", "v")
    @classmethod
    def _bounded(cls, value):
        if value is None:
            return value
        for c in value:
            if abs(c) > 1000:
                raise ValueError("vector components must be within ±1000")
        return value


class EnergyProfileParams(BaseModel):
    dh_kj: float = Field(
        -85.0, ge=-500.0, le=500.0, description="enthalpy change, kJ/mol"
    )
    exothermic: bool = True
    title: str = Field("Energy profile", max_length=48)

    @field_validator("title")
    @classmethod
    def _title_safe(cls, v: str) -> str:
        if not _SAFE_TEXT.match(v):
            raise ValueError("title must be short printable text")
        return v


DiagramParams = (
    RightTriangleParams
    | CircleParams
    | FunctionPlotParams
    | VectorParams
    | EnergyProfileParams
)

KindName = Literal[
    "right_triangle", "circle", "function_plot", "vectors", "energy_profile"
]


class DiagramRenderRequest(BaseModel):
    kind: KindName
    params: dict[str, Any] = Field(default_factory=dict)
    timeout_s: float | None = Field(None, ge=1.0, le=60.0)


class DiagramRenderResponse(BaseModel):
    ok: bool
    kind: str
    params: dict[str, Any] = Field(default_factory=dict)
    svg_url: str | None = None
    sha256: str | None = None
    cached: bool = False
    duration_ms: int = 0
    exit_code: int | None = None
    stdout: str = ""
    stderr: str = ""
    asy_executable: str | None = None
    asy_version: str | None = None
    source_path: str | None = None
    error: str | None = None
    detail: str | None = None


class DiagramHealthResponse(BaseModel):
    ok: bool
    asy_executable: str | None = None
    asy_version: str | None = None
    label_capable: bool = False
    smoke_sha256: str | None = None
    smoke_error: str | None = None
    cache_dir: str | None = None


class LessonPlanAssets(BaseModel):
    """What a lesson needs: a diagram, a 3D scene, both, or neither."""

    decision: Literal["diagram", "three", "both", "neither"]
    diagram_kind: str | None = None
    three_scene: str | None = None
    reason: str = ""
    params: dict[str, Any] = Field(default_factory=dict)


class ThreeWorkflow(BaseModel):
    scene: str
    launch_url: str
    sync_params: dict[str, Any] = Field(default_factory=dict)
    workflow: str = ""


class FallbackNote(BaseModel):
    used: bool
    reason: str
    recorded_as_asy_success: bool = False


class LessonAssetsRequest(BaseModel):
    question: str = Field(..., min_length=2, max_length=600)
    params: dict[str, Any] | None = Field(
        default=None, description="optional parameter overrides for the diagram"
    )


class LessonAssetsResponse(BaseModel):
    plan: LessonPlanAssets
    diagram: DiagramRenderResponse | None = None
    three: ThreeWorkflow | None = None
    fallback: FallbackNote | None = None
    asy_executed: bool = False
