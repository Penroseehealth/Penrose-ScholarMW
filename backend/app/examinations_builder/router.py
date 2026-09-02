"""API endpoints for the AI Examination Builder."""

from __future__ import annotations

import logging
import re
import uuid

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import require_lecturer
from app.examinations_builder import service as engine
from app.examinations_builder.schemas import (
    AddQuestionRequest,
    ExamBuilderConfig,
    ExportRequest,
    GenerateRequest,
    GenerateResponse,
    QualityReport,
    QuestionItem,
    RegenerateQuestionRequest,
)
from app.models.models import User

log = logging.getLogger(__name__)

router = APIRouter(prefix="/examinations-builder", tags=["AI Examination Builder"])

DOCX_MEDIATYPE = (
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
)
PDF_MEDIATYPE = "application/pdf"


def _safe_filename(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("_") or "examination"


def _store_response(
    exam_id: str, config: ExamBuilderConfig, questions: list[dict]
) -> GenerateResponse:
    return GenerateResponse(
        exam_id=exam_id,
        title=config.title or f"{config.subject or 'Subject'} Examination",
        questions=[QuestionItem(**q) for q in questions],
        total_marks=sum(_parse_int(q["marks"]) for q in questions),
    )


def _parse_int(value, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


@router.post("/generate", response_model=GenerateResponse)
async def generate_exam(
    body: GenerateRequest,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    try:
        questions = await engine.generate_questions(body.config, db)
    except Exception as e:
        log.exception("Exam generation failed")
        raise HTTPException(status_code=500, detail=f"Question generation failed: {e}")

    exam_id = uuid.uuid4().hex[:12]
    engine._engine.put(
        exam_id,
        {
            "config": body.config,
            "questions": questions,
        },
    )
    return _store_response(exam_id, body.config, questions)


@router.get("/{exam_id}", response_model=GenerateResponse)
async def get_exam(
    exam_id: str,
    user: User = Depends(require_lecturer),
):
    rec = engine._engine.get(exam_id)
    if not rec:
        raise HTTPException(status_code=404, detail="Examination not found")
    return _store_response(exam_id, rec["config"], rec["questions"])


@router.post("/{exam_id}/quality", response_model=QualityReport)
async def quality_check(
    exam_id: str,
    user: User = Depends(require_lecturer),
):
    rec = engine._engine.get(exam_id)
    if not rec:
        raise HTTPException(status_code=404, detail="Examination not found")
    report = engine.compute_quality_report(rec["config"], rec["questions"])
    return QualityReport(id=uuid.uuid4().hex[:8], **report)


@router.post("/{exam_id}/regenerate-question")
async def regenerate_question(
    exam_id: str,
    body: RegenerateQuestionRequest,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    rec = engine._engine.get(exam_id)
    if not rec:
        raise HTTPException(status_code=404, detail="Examination not found")
    if body.question_id not in [q["id"] for q in rec["questions"]]:
        raise HTTPException(status_code=404, detail="Question not found")
    try:
        new_question = await engine.regenerate_question(
            rec["config"], body.question_id, body.focus, rec["questions"], db
        )
        for i, q in enumerate(rec["questions"]):
            if q["id"] == body.question_id:
                rec["questions"][i] = new_question
                break
        return {"question": QuestionItem(**new_question)}
    except Exception as e:
        log.exception("Question regeneration failed")
        raise HTTPException(status_code=500, detail=f"Regeneration failed: {e}")


@router.post("/{exam_id}/questions", status_code=201, response_model=QuestionItem)
async def add_question(
    exam_id: str,
    body: AddQuestionRequest,
    user: User = Depends(require_lecturer),
):
    rec = engine._engine.get(exam_id)
    if not rec:
        raise HTTPException(status_code=404, detail="Examination not found")
    question = engine._normalise_ai_question(body.model_dump())
    rec["questions"].append(question)
    return QuestionItem(**question)


@router.delete("/{exam_id}/questions/{question_id}")
async def remove_question(
    exam_id: str,
    question_id: str,
    user: User = Depends(require_lecturer),
):
    rec = engine._engine.get(exam_id)
    if not rec:
        raise HTTPException(status_code=404, detail="Examination not found")
    rec["questions"] = [q for q in rec["questions"] if q["id"] != question_id]
    return {"ok": True}


@router.post("/{exam_id}/export", response_model=None)
async def export_exam(
    exam_id: str,
    body: ExportRequest,
    user: User = Depends(require_lecturer),
):
    rec = engine._engine.get(exam_id)
    if not rec:
        raise HTTPException(status_code=404, detail="Examination not found")
    base_name = _safe_filename(
        rec["config"].title or f"{rec['config'].subject or 'Subject'}_examination"
    )
    try:
        if body.format == "pdf":
            buf = engine.build_pdf(
                rec["config"], rec["questions"], body.include_answers
            )
            filename = f"{base_name}.pdf"
            media_type = PDF_MEDIATYPE
        else:
            buf = engine.build_docx(
                rec["config"], rec["questions"], body.include_answers
            )
            filename = f"{base_name}.docx"
            media_type = DOCX_MEDIATYPE
    except Exception as e:
        log.exception("Export failed")
        raise HTTPException(status_code=500, detail=f"Export failed: {e}")

    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type=media_type,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
