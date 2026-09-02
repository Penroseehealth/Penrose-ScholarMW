"""Pydantic schemas for the AI Lecture Presentation Builder."""

from __future__ import annotations

from pydantic import BaseModel, Field


class SlideSectionConfig(BaseModel):
    """A slide building block the lecturer can enable/disable."""

    key: str
    enabled: bool = True


class UploadedSource(BaseModel):
    """An uploaded source document (client sends raw bytes via multipart)."""

    filename: str
    kind: str = "notes"  # notes | syllabus | textbook | reference | image
    text: str = ""
    file_size: int = 0


class BuilderConfig(BaseModel):
    """Step 1 (content) configuration + design + density + citations."""

    course: str = ""
    course_code: str = ""
    topic: str = ""
    subtopic: str = ""
    academic_level: str = ""
    programme: str = ""
    institution: str = ""
    lecturer: str = ""
    semester: str = ""
    academic_year: str = ""

    # Learning objectives typed by the lecturer (optional — else derived).
    learning_objectives: list[str] = Field(default_factory=list)

    # Source material
    uploaded_text: str = ""  # merged extracted text from uploaded files
    vault_doc_ids: list[int] = Field(default_factory=list)

    slide_count: int = 10
    auto_slide_count: bool = False

    presentation_type: str = "Lecture Presentation"

    # Design
    template: str = "Minimal Academic"
    body_font: str = "Calibri"
    heading_font: str = "Calibri"
    heading_size: int = 34
    body_size: int = 24
    max_lines_per_slide: int = 6
    max_bullets: int = 5
    max_words_per_slide: int = 80
    columns: int = 1

    accent_hex: str = "#1F4E79"
    background_hex: str = "#FFFFFF"
    text_hex: str = "#1A1A1A"

    citation_style: str = "APA 7"
    web_research: bool = False

    # Slide sections enabled/disabled
    sections: list[SlideSectionConfig] = Field(default_factory=list)


class OutlineRequest(BaseModel):
    config: BuilderConfig


class OutlineItem(BaseModel):
    id: str
    title: str
    purpose: str = ""
    learning_objective: str = ""


class OutlineResponse(BaseModel):
    slides: list[OutlineItem] = Field(default_factory=list)
    syllabus_coverage: dict = Field(default_factory=dict)
    warnings: list[str] = Field(default_factory=list)


class SlideData(BaseModel):
    """A single generated slide (internal representation, not yet a shape)."""

    id: str
    title: str
    slide_type: str
    bullets: list[str] = Field(default_factory=list)
    body: str = ""
    speaker_notes: str = ""
    citation: str = ""
    learning_objective: str = ""
    source: str = ""
    layout: str = "title_and_content"


class GenerateRequest(BaseModel):
    config: BuilderConfig
    outline: list[OutlineItem] = Field(default_factory=list)
    regenerate_slide_ids: list[str] = Field(default_factory=list)
    slides: list[SlideData] | None = None


class GenerateResponse(BaseModel):
    presentation_id: str
    title: str
    slides: list[SlideData] = Field(default_factory=list)


class QualityReport(BaseModel):
    id: str
    syllabus_coverage_pct: int = 0
    citation_coverage_pct: int = 0
    accessibility_pct: int = 0
    content_density_pct: int = 0
    visual_quality_pct: int = 0
    checks: list[dict] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)


class RegenerateSlideRequest(BaseModel):
    presentation_id: str
    slide_id: str
    focus: str = ""


class RegenerateNotesRequest(BaseModel):
    presentation_id: str
    slide_id: str
    prompt: str = ""


class PptxFromDataRequest(BaseModel):
    config: BuilderConfig
    slides: list[SlideData] = Field(default_factory=list)
