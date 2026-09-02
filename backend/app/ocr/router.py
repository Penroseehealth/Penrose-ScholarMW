"""OCR scan & analyse endpoints — upload a scan, extract text, analyse it."""

from __future__ import annotations

import logging
import re
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from app.config.ai_client import call_ai_text
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.schemas.ocr import (
    OcrAnalyzeRequest,
    OcrAnalyzeResponse,
    OcrLineSchema,
    OcrScanResponse,
)
from app.services.file_validation import (
    extract_docx_text,
    extract_pdf_text,
    validate_upload,
)
from app.services.ocr_service import ocr_image, ocr_pdf

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ocr", tags=["OCR"])

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
OCR_EXTENSIONS = IMAGE_EXTENSIONS | {".pdf"}


@router.post("/scan", response_model=OcrScanResponse)
async def scan_upload(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
):
    """OCR a scanned image or scanned/text PDF and return extracted text."""
    content = await file.read()
    filename = file.filename or "document"

    result = validate_upload(filename, content)
    if isinstance(result, str):
        raise HTTPException(status_code=400, detail=result)

    ext = Path(filename).suffix.lower()

    if ext not in OCR_EXTENSIONS:
        # Not an OCR target — try text extraction so analysis still works.
        text, method = await _extract_text(result.content, result.file_type, filename)
        return OcrScanResponse(
            filename=filename,
            text=text,
            method=method,
            word_count=_word_count(text),
        )

    if ext == ".pdf":
        pdf_text, method = await _extract_text(result.content, "pdf", filename)
        if _has_real_text(pdf_text):
            return OcrScanResponse(
                filename=filename,
                text=pdf_text,
                method=method,
                word_count=_word_count(pdf_text),
                page_count=_count_pdf_pages(result.content),
            )
        # Scanned PDF — rasterise + OCR it.
        ocr_result = await ocr_pdf(result.content)
        if ocr_result.error:
            raise HTTPException(status_code=500, detail=ocr_result.error)
        return _to_scan_response(filename, ocr_result)

    ocr_result = await ocr_image(result.content)
    if ocr_result.error:
        raise HTTPException(status_code=500, detail=ocr_result.error)
    return _to_scan_response(filename, ocr_result)


@router.post("/analyze", response_model=OcrAnalyzeResponse)
async def analyze_text(
    body: OcrAnalyzeRequest,
    user: User = Depends(get_current_user),
):
    """Ask the AI to analyse extracted text (summary, key points, question Q&A)."""
    q = (body.question or "").strip()
    lang_hint = body.language or "English"

    system_prompt = (
        "You are Penrose ScholarMW, an academic analysis assistant for "
        "Malawi secondary-school students. You are given text extracted from "
        "an uploaded document (scanned via OCR or a textable file). Produce a "
        "clear, well-structured analysis. Keep it concise and directly grounded "
        "in the provided text. Do not invent content not present in it.\n\n"
        f"Document file name: {body.filename}\n"
        f"Document language hint: {lang_hint}"
    )

    excerpt = body.text[:9000]
    if q:
        user_prompt = (
            f"Extracted document text:\n\n{excerpt}\n\n"
            f"The student asks: {q}\n\n"
            "Please answer the question using the text. Begin with a one-line "
            "summary of the document, then give the answer, then cite the key "
            "points (bullet list) that support it."
        )
    else:
        user_prompt = (
            f"Extracted document text:\n\n{excerpt}\n\n"
            "Please analyse this document:\n"
            "- One-line summary\n"
            "- Key points (concise bullet list\n"
            "- Any formulas, definitions or facts a student should remember\n"
            "- Suggestions on what to study next"
        )

    try:
        text = await call_ai_text(
            [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            max_tokens=2000,
            temperature=0.4,
        )
    except Exception as e:
        log.warning("OCR analysis LLM failed: %s", e)
        text = (
            "Analysis could not be generated (AI provider unavailable). "
            "Here is the extracted text for you to read:\n\n" + body.text[:2000]
        )

    return OcrAnalyzeResponse(filename=body.filename, analysis=text)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _extract_text(
    content: bytes, file_type: str, filename: str
) -> tuple[str, str]:
    if file_type == "pdf":
        text = await extract_pdf_text(content)
        return text, "text-layer" if _has_real_text(text) else "none"
    if file_type == "document":
        text = await extract_docx_text(content)
        return text, "text-layer"
    if file_type == "image":
        res = await ocr_image(content)
        return res.text, "ocr"
    text = content.decode("utf-8", errors="replace")
    return text, "text-layer"


def _has_real_text(text: str) -> bool:
    stripped = text.strip()
    if not stripped or stripped.startswith("("):
        return False
    return len(stripped.split()) >= 5


def _word_count(text: str) -> int:
    return len(re.findall(r"\S+", text))


def _count_pdf_pages(content: bytes) -> int:
    try:
        import pymupdf
    except ImportError:
        import fitz as pymupdf

    try:
        doc = pymupdf.open(stream=content, filetype="pdf")
        n = len(doc)
        doc.close()
        return n
    except Exception:
        return 1


def _to_scan_response(filename: str, res) -> OcrScanResponse:
    return OcrScanResponse(
        filename=filename,
        text=res.text,
        lines=[
            OcrLineSchema(text=ln.text, confidence=ln.confidence, box=ln.box)
            for ln in res.lines
        ],
        page_count=res.page_count,
        method=res.method,
        word_count=_word_count(res.text),
        error=res.error,
    )
