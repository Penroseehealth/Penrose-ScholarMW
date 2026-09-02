"""Pydantic schemas for the OCR scan & analyse feature."""

from __future__ import annotations

from pydantic import BaseModel, Field


class OcrLineSchema(BaseModel):
    text: str
    confidence: float = 1.0
    box: list[list[float]] = Field(default_factory=list)


class OcrScanRequest(BaseModel):
    """Text extracted for analysis (either from OCR or a textable document)."""

    filename: str = Field(default="document")
    text: str = Field(min_length=1)
    language: str | None = Field(
        default=None, description="ISO language hint (e.g. zh, en)"
    )


class OcrAnalyzeRequest(BaseModel):
    """Ask the AI to analyse extracted text."""

    filename: str = Field(default="document")
    text: str = Field(min_length=1)
    question: str | None = Field(
        default=None, description="Optional user question about the text"
    )
    language: str | None = Field(default=None)


class OcrAnalyzeResponse(BaseModel):
    filename: str
    analysis: str
    summary: str | None = None
    key_points: list[str] = Field(default_factory=list)
    provider: str | None = None


class OcrScanResponse(BaseModel):
    filename: str
    text: str
    lines: list[OcrLineSchema] = Field(default_factory=list)
    page_count: int = 1
    method: str = "ocr"
    word_count: int = 0
    error: str | None = None
