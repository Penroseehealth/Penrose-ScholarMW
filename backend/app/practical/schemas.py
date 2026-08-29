"""Pydantic schemas for the Practical Simulation Video engine."""

from __future__ import annotations

from pydantic import BaseModel, Field

# ---------------------------------------------------------------------------
# Structured video specification (PracticalVideoSpec)
# ---------------------------------------------------------------------------


class EnvironmentSpec(BaseModel):
    background: str = "Modern school laboratory"
    wall: str = "White"
    bench: str = "Laboratory bench"
    lighting: str = "Laboratory fluorescent"
    time_of_day: str = "Morning"
    cleanliness: str = "Standard"
    background_objects: list[str] = Field(default_factory=list)
    custom_background_url: str | None = None
    equipment: list[str] = Field(default_factory=list)


class OperatorSpec(BaseModel):
    appearance: str = "Laboratory instructor"
    clothing: str = "Laboratory coat"
    hands: str = "Visible"
    camera_mode: str = "Mixed educational views"


class CameraSpec(BaseModel):
    shots: list[str] = Field(default_factory=list)


class SceneSpec(BaseModel):
    scene_id: str
    duration: float = 0
    purpose: str = ""
    environment: str = ""
    camera: str = ""
    action: str = ""
    equipment_state: str = ""
    hand_position: str = ""
    narration: str = ""
    on_screen_text: str = ""
    safety_note: str = ""
    transition: str = "cut"
    continuity_reference: str = ""


class PracticalVideoSpec(BaseModel):
    subject: str = "Biology"
    practical_id: str = ""
    title: str = ""
    syllabus_reference: str = ""
    learning_objectives: list[str] = Field(default_factory=list)
    environment: EnvironmentSpec = Field(default_factory=EnvironmentSpec)
    equipment: list[str] = Field(default_factory=list)
    operator: OperatorSpec = Field(default_factory=OperatorSpec)
    camera: CameraSpec = Field(default_factory=CameraSpec)
    lighting: str = ""
    style: dict = Field(default_factory=dict)
    scenes: list[SceneSpec] = Field(default_factory=list)
    narration: dict = Field(default_factory=dict)
    annotations: dict = Field(default_factory=dict)
    assessment_points: list[str] = Field(default_factory=list)
    generation_provider: str = ""
    generation_model: str = ""
    version: int = 1


# ---------------------------------------------------------------------------
# API schemas
# ---------------------------------------------------------------------------


class SimulationCreate(BaseModel):
    subject_slug: str = "biology"
    practical_key: str = "using-a-microscope"
    title: str = "Using a Microscope"
    description: str | None = None


class SimulationSummary(BaseModel):
    id: int
    subject_slug: str
    practical_key: str
    title: str
    description: str | None
    syllabus_reference: str | None
    is_saved: bool
    versions: int = 0
    latest_status: str | None = None
    latest_video_url: str | None = None


class SimulationDetail(BaseModel):
    id: int
    subject_slug: str
    practical_key: str
    title: str
    description: str | None
    syllabus_reference: str | None
    spec: PracticalVideoSpec | None
    num_scenes: int = 0


class StoryboardRequest(BaseModel):
    environment: EnvironmentSpec | None = None
    operator: OperatorSpec | None = None


class StoryboardResponse(BaseModel):
    simulation_id: int
    spec: PracticalVideoSpec
    syllabus_mapped: bool
    message: str


class GenerateRequest(BaseModel):
    quality: str = "standard"  # draft | standard | high
    provider: str | None = None
    environment: EnvironmentSpec | None = None
    operator: OperatorSpec | None = None


class GenerationStatus(BaseModel):
    job_id: int
    simulation_id: int
    status: str
    progress: float
    provider: str | None
    model: str | None
    estimated_credits: float | None
    error: str | None
    video_url: str | None
    qc: dict = Field(default_factory=dict)


class RegenerateRequest(BaseModel):
    scope: str = "entire"  # entire | scene | background | character | camera | lighting | narration | subtitles | annotations
    scene_id: str | None = None
    quality: str = "standard"


class ModifyRequest(BaseModel):
    instruction: str = ""
    scope: str = "entire"
    quality: str = "standard"


class VersionSummary(BaseModel):
    id: int
    version: int
    is_current: bool
    generation_id: int | None
    video_url: str | None
    thumbnail_url: str | None
    created_at: str | None
