"""Request/response models for system-audio recording."""

from __future__ import annotations

from pydantic import BaseModel, Field


class StartRecordingRequest(BaseModel):
    label: str | None = Field(default=None, max_length=120)
    sample_rate: int = Field(default=48000, ge=8000, le=96000)
    channels: int = Field(default=2, ge=1, le=2)


class StartRecordingResult(BaseModel):
    recording_id: str
    label: str
    status: str
    started_at: str
    sample_rate: int
    channels: int
    device: str
    max_seconds: int


class RecordingStatus(BaseModel):
    active: bool
    recording_id: str | None = None
    label: str | None = None
    status: str | None = None
    device: str | None = None
    started_at: str | None = None
    elapsed_seconds: float = 0.0
    level: float = 0.0
    sample_rate: int | None = None
    channels: int | None = None
    max_seconds: int
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
    wav_bytes: int = 0
    mp3_bytes: int = 0
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
