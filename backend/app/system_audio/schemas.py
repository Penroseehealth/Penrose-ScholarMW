"""Request/response models for system-audio recording."""

from __future__ import annotations

from pydantic import BaseModel, Field


class StartRecordingRequest(BaseModel):
    label: str | None = Field(default=None, max_length=120)
    sample_rate: int = Field(default=48000, ge=8000, le=96000)
    channels: int = Field(default=2, ge=1, le=2)
    # system = WASAPI loopback (what the PC plays), mic = default microphone,
    # both = the two mixed together (default, so a recording is never silent
    # just because the user spoke instead of playing something).
    source: str = Field(default="both", pattern="^(system|mic|both)$")
    # 0 keeps one file for the whole recording. The UI offers 600, 900,
    # 1200, 1500 and 1800 seconds; longer parts are still accepted.
    segment_seconds: int = Field(default=0, ge=0, le=3600)


class StartRecordingResult(BaseModel):
    recording_id: str
    label: str
    status: str
    started_at: str
    sample_rate: int
    channels: int
    device: str
    source: str = "system"
    segment_seconds: int = 0
    mic_enabled: bool = False
    mic_error: str | None = None
    max_seconds: int


class RecordingStatus(BaseModel):
    active: bool
    recording_id: str | None = None
    label: str | None = None
    status: str | None = None
    device: str | None = None
    source: str | None = None
    started_at: str | None = None
    elapsed_seconds: float = 0.0
    level: float = 0.0
    sample_rate: int | None = None
    channels: int | None = None
    max_seconds: int
    segment_seconds: int = 0
    segments_completed: int = 0
    segment_elapsed_seconds: float = 0.0
    compressing: int = 0
    mic_enabled: bool = False
    mic_error: str | None = None
    error: str | None = None


class RecordingView(BaseModel):
    id: str
    label: str
    status: str
    started_at: str
    ended_at: str | None = None
    duration_seconds: float = 0.0
    sample_rate: int = 48000
    channels: int = 2
    device: str | None = None
    source: str | None = None
    silent: bool = False
    wav_bytes: int = 0
    mp3_bytes: int = 0
    segmentation_seconds: int = 0
    segments: list[dict] = Field(default_factory=list)
    compressing: int = 0
    mic_enabled: bool = False
    mic_error: str | None = None
    transcript: str | None = None
    summary: str | None = None
    summary_style: str | None = None
    provider: str | None = None
    model: str | None = None
    error: str | None = None


class TranscribeRecordingRequest(BaseModel):
    language: str | None = Field(default=None, max_length=10)


class SummarizeRecordingRequest(BaseModel):
    style: str = Field(default="minutes", max_length=40)
    language: str | None = Field(default=None, max_length=10)


class ProcessRecordingRequest(BaseModel):
    language: str | None = Field(default=None, max_length=10)
    style: str = Field(default="minutes", max_length=40)


class MicrophoneToggleRequest(BaseModel):
    enabled: bool


class DeliverRequest(BaseModel):
    """Where a finished recording should go.

    Every destination is optional; at least one is required. A folder is copied
    on the machine running the backend. WhatsApp and email cannot carry an
    attachment from a web page, so they return a ready-to-open link and the file
    names to attach.
    """

    folder: str | None = Field(default=None, max_length=400)
    create_folder: bool = True
    whatsapp: str | None = Field(default=None, max_length=32)
    email: str | None = Field(default=None, max_length=200)
    formats: list[str] = Field(default_factory=lambda: ["mp3"])
    include_summary: bool = True
    note: str | None = Field(default=None, max_length=500)


class DeliveredFile(BaseModel):
    name: str
    bytes: int


class DeliveryResult(BaseModel):
    destination: str
    status: str
    detail: str
    folder: str | None = None
    address: str | None = None
    link: str | None = None
    files: list = Field(default_factory=list)
    failed: list = Field(default_factory=list)


class DeliverResult(BaseModel):
    recording_id: str
    label: str | None = None
    files: list[DeliveredFile] = Field(default_factory=list)
    results: list[DeliveryResult] = Field(default_factory=list)
