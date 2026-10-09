"""API endpoints for the AI Lecture Presentation Builder."""

from __future__ import annotations

import logging
import re
import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import require_lecturer
from app.models.models import User, VaultDocument
from app.presentation import service as engine
from app.presentation.schemas import (
    GenerateRequest,
    GenerateResponse,
    OutlineRequest,
    OutlineResponse,
    PptxFromDataRequest,
    QualityReport,
    RegenerateNotesRequest,
    RegenerateSlideRequest,
    SlideData,
)
from app.services.file_validation import (
    extract_docx_text,
    extract_pdf_text,
    extract_spreadsheet_text,
    validate_upload,
)

log = logging.getLogger(__name__)

router = APIRouter(prefix="/presentations", tags=["Lecture Presentation Builder"])

PPTX_MEDIATYPE = (
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"
)


def _safe_filename(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("_") or "presentation"


def _pptx_response(topic: str, pptx_bytes: bytes) -> StreamingResponse:
    filename = f"{_safe_filename(topic or 'lecture')}.pptx"
    return StreamingResponse(
        iter([pptx_bytes]),
        media_type=PPTX_MEDIATYPE,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


UPLOAD_LABEL_HINTS = {
    "syllabus": "syllabus",
    "textbook": "textbook",
    "text book": "textbook",
    "reference": "reference",
    "materials": "materials",
    "material": "materials",
    "note": "notes",
    "lecture": "notes",
    "upload": "notes",
}


async def _resolve_vault_docs(
    db: AsyncSession, user: User, doc_ids: list[int]
) -> list[dict]:
    """Load vault documents the current user owns (mirrors vault scoping)."""
    docs: list[dict] = []
    for doc_id in doc_ids or []:
        result = await db.execute(
            select(VaultDocument).where(VaultDocument.id == doc_id)
        )
        doc = result.scalar_one_or_none()
        if not doc or doc.uploaded_by != user.id:
            continue
        docs.append(
            {
                "id": doc.id,
                "title": doc.title or doc.file_name or "",
                "content": doc.content or "",
            }
        )
    return docs


async def _extract_image_placeholder() -> str:
    return "(Image uploaded — OCR not applied here. Use the Scan & Analyse tool first.)"


@router.post("/upload", response_model=None)
async def upload_source(
    file: UploadFile = File(...),
    label: str = Form("notes"),
    user: User = Depends(require_lecturer),
):
    """Upload a source file and return its extracted text with a source label."""
    content = await file.read()
    result = validate_upload(file.filename or "", content)
    if isinstance(result, str):
        raise HTTPException(status_code=400, detail=result)
    if result.file_type == "pdf":
        text = await extract_pdf_text(content)
    elif result.file_type == "document":
        text = await extract_docx_text(content)
    elif result.file_type == "spreadsheet":
        text = await extract_spreadsheet_text(content, file.filename or "")
    elif result.file_type == "image":
        text = await _extract_image_placeholder()
    elif result.file_type == "text":
        text = content.decode("utf-8", errors="replace")
    else:
        text = ""

    fname = (file.filename or "").lower()
    kind = "notes"
    if label in UPLOAD_LABEL_HINTS:
        kind = UPLOAD_LABEL_HINTS[label]
    elif "syllabus" in fname:
        kind = "syllabus"
    elif "textbook" in fname:
        kind = "textbook"
    elif "reference" in fname:
        kind = "reference"

    return {
        "filename": file.filename,
        "label": kind,
        "text": text,
        "size": len(content),
    }


@router.post("/outline", response_model=OutlineResponse)
async def build_outline_endpoint(
    body: OutlineRequest,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    try:
        vault_docs = await _resolve_vault_docs(db, user, body.config.vault_doc_ids)
        result = await engine.build_outline(body.config, vault_docs, db)
        return OutlineResponse(
            slides=result["slides"],
            syllabus_coverage=result["syllabus_coverage"],
            warnings=result["warnings"],
        )
    except HTTPException:
        raise
    except Exception as e:
        log.exception("Outline build failed")
        raise HTTPException(status_code=500, detail=f"Outline generation failed: {e}")


@router.post("/generate", response_model=GenerateResponse)
async def generate_endpoint(
    body: GenerateRequest,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    """Build slide text + speaker notes from an approved outline; store for editing."""
    try:
        slides = await engine.generate_slides(body.config, body.outline, [], db)
        presentation_id = uuid.uuid4().hex[:12]
        engine._engine.put(
            presentation_id,
            {
                "config": body.config,
                "outline": [o.model_dump() for o in body.outline],
                "slides": slides,
            },
        )
        return GenerateResponse(
            presentation_id=presentation_id,
            title=body.config.topic or "Untitled Lecture",
            slides=[SlideData(**s) for s in slides],
        )
    except Exception as e:
        log.exception("Slide generation failed")
        raise HTTPException(status_code=500, detail=f"Slide generation failed: {e}")


@router.post("/quality", response_model=QualityReport)
async def quality_endpoint(
    body: GenerateRequest,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    try:
        slides = (
            [s.model_dump() for s in body.slides]
            if body.slides
            else await engine.generate_slides(body.config, body.outline, [], db)
        )
        report = engine.compute_quality_report(slides, body.config)
        return QualityReport(
            id=uuid.uuid4().hex[:8],
            syllabus_coverage_pct=report["syllabus_coverage_pct"],
            citation_coverage_pct=report["citation_coverage_pct"],
            accessibility_pct=report["accessibility_pct"],
            content_density_pct=report["content_density_pct"],
            visual_quality_pct=report["visual_quality_pct"],
            checks=report["checks"],
            warnings=report["warnings"],
        )
    except Exception as e:
        log.exception("Quality check failed")
        raise HTTPException(status_code=500, detail=f"Quality check failed: {e}")


@router.post("/pptx/from-data", response_model=None)
async def export_pptx_from_data(
    body: PptxFromDataRequest,
    user: User = Depends(require_lecturer),
):
    """Build an editable .pptx directly from captured slide data + config."""
    try:
        slides = [s.model_dump() for s in body.slides]
        pptx_bytes = engine.build_pptx(body.config, slides)
        return _pptx_response(body.config.topic, pptx_bytes)
    except Exception as e:
        log.exception("PPTX export failed")
        raise HTTPException(status_code=500, detail=f"PPTX export failed: {e}")


@router.post("/pptx", response_model=None)
async def export_pptx(
    body: GenerateRequest,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    """Generate a real, editable .pptx from the current slide data."""
    try:
        slides = (
            [s.model_dump() for s in body.slides]
            if body.slides
            else await engine.generate_slides(body.config, body.outline, [], db)
        )
        pptx_bytes = engine.build_pptx(body.config, slides)
        return _pptx_response(body.config.topic, pptx_bytes)
    except Exception as e:
        log.exception("PPTX generation failed")
        raise HTTPException(status_code=500, detail=f"PPTX generation failed: {e}")


@router.post("/regenerate-slide")
async def regenerate_slide_endpoint(
    body: RegenerateSlideRequest,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    rec = engine._engine.get(body.presentation_id)
    if not rec:
        raise HTTPException(status_code=404, detail="Presentation not found")
    try:
        new_slide = await engine.regenerate_slide(
            rec["config"], body.slide_id, body.focus, rec["slides"], db
        )
        return {"slide": new_slide}
    except Exception as e:
        log.exception("Slide regeneration failed")
        raise HTTPException(status_code=500, detail=f"Regeneration failed: {e}")


@router.post("/regenerate-notes")
async def regenerate_notes_endpoint(
    body: RegenerateNotesRequest,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    rec = engine._engine.get(body.presentation_id)
    if not rec:
        raise HTTPException(status_code=404, detail="Presentation not found")
    try:
        new_notes = await engine.regenerate_notes(
            rec["config"], body.slide_id, body.prompt, rec["slides"], db
        )
        return {"speaker_notes": new_notes}
    except Exception as e:
        log.exception("Notes regeneration failed")
        raise HTTPException(status_code=500, detail=f"Notes regeneration failed: {e}")
