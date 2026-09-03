"""Vault document processing pipeline.

Runs an explicit, inspectable pipeline over an uploaded document:

    validating → extracting → ocr_processing → indexing → ready

The stage is stored on the ``VaultDocument`` row so the frontend can show the
exact status ("Upload successful, but OCR processing failed") and offer
stage-specific retries. Textable files use their native layer; only when no
valid text is present are scanned pages routed through OCR.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass

from app.models.models import VaultDocument
from app.services.file_validation import (
    extract_docx_text,
    extract_pdf_text,
    extract_spreadsheet_text,
    validate_upload,
)
from app.services.ocr_service import ocr_image, ocr_pdf

log = logging.getLogger(__name__)

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
OCR_EXTENSIONS = IMAGE_EXTENSIONS | {".pdf"}


@dataclass
class ProcessingOutcome:
    content: str
    method: str = "text-layer"
    page_count: int | None = None
    error: str | None = None
    ocr_used: bool = False


def _has_real_text(text: str) -> bool:
    stripped = (text or "").strip()
    if not stripped or stripped.startswith("("):
        return False
    return len(stripped.split()) >= 5


def _word_count(text: str) -> int:
    return len(re.findall(r"\S+", text))


def _count_pdf_pages(content: bytes) -> int:
    try:
        import pymupdf
    except ImportError:
        import fitz as pymupdf  # type: ignore[no-redef]
    try:
        doc = pymupdf.open(stream=content, filetype="pdf")
        n = len(doc)
        doc.close()
        return n
    except Exception:
        return 1


async def process_document(
    doc: VaultDocument, *, force_ocr: bool = False
) -> ProcessingOutcome:
    """Run the extraction pipeline for a stored vault document.

    ``doc.file_path`` must point to a readable file on disk. The returned
    outcome carries the extracted text plus processing metadata; the caller is
    responsible for persisting it onto the row.
    """
    from pathlib import Path

    path = Path(doc.file_path)
    if not path.exists() or not path.is_file():
        return ProcessingOutcome(content="", error="File not found on disk")

    with open(path, "rb") as fh:
        content = fh.read()

    filename = doc.file_name or path.name
    ext = path.suffix.lower()

    validated = validate_upload(filename, content)
    if isinstance(validated, str):
        return ProcessingOutcome(content="", error=validated)

    if ext not in OCR_EXTENSIONS or (ext == ".pdf" and not force_ocr):
        # Prefer the native text layer for textable files and searchable PDFs.
        try:
            text, method, page_count = await _native_extract(
                validated.file_type, validated.content, filename
            )
            if _has_real_text(text) and method != "none":
                return ProcessingOutcome(
                    content=text,
                    method=method,
                    page_count=page_count,
                    ocr_used=False,
                )
            # Scanned PDF (no text layer) → fall through to OCR.
            if ext == ".pdf":
                ocr_result = await ocr_pdf(validated.content)
                if ocr_result.error:
                    return ProcessingOutcome(
                        content="", error=ocr_result.error, ocr_used=True
                    )
                return ProcessingOutcome(
                    content=ocr_result.text,
                    method=ocr_result.method,
                    page_count=ocr_result.page_count,
                    ocr_used=True,
                )
            if method == "none":
                return ProcessingOutcome(
                    content="", error="No readable text found", method=method
                )
        except Exception as e:  # pragma: no cover - defensive
            log.exception("Native extraction failed for %s", filename)
            return ProcessingOutcome(content="", error=f"Extraction failed: {e}")

    # Images and force_ocr PDFs always go through OCR.
    if ext == ".pdf" or force_ocr:
        ocr_result = await ocr_pdf(validated.content)
    else:
        ocr_result = await ocr_image(validated.content)
    if ocr_result.error:
        return ProcessingOutcome(content="", error=ocr_result.error, ocr_used=True)
    return ProcessingOutcome(
        content=ocr_result.text,
        method=ocr_result.method,
        page_count=ocr_result.page_count,
        ocr_used=True,
    )


async def _native_extract(
    file_type: str, content: bytes, filename: str
) -> tuple[str, str, int | None]:
    """Extract native text for a validated file type that is not OCR-first."""
    if file_type == "pdf":
        text = await extract_pdf_text(content)
        page_count = _count_pdf_pages(content)
        return text, "text-layer" if _has_real_text(text) else "none", page_count
    if file_type == "document":
        text = await extract_docx_text(content)
        return text, "text-layer", None
    if file_type == "spreadsheet":
        text = await extract_spreadsheet_text(content, filename)
        return text, "text-layer", None
    if file_type == "image":
        res = await ocr_image(content)
        return res.text, "ocr", res.page_count
    text = content.decode("utf-8", errors="replace")
    return text, "text-layer", None
