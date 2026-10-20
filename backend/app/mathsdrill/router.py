from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.models.models import MathsdrillPaperState, MathsdrillSession
from app.schemas.mathsdrill import (
    MathsdrillPaperStateIn,
    MathsdrillPaperStateOut,
    MathsdrillSessionIn,
    MathsdrillSessionOut,
    MathsdrillStudentSummary,
)

router = APIRouter(prefix="/mathsdrill", tags=["mathsdrill"])


@router.get("/students", response_model=list[MathsdrillStudentSummary])
async def list_students(db: AsyncSession = Depends(get_db)):
    """Aggregate stored drill results per student name (dev viewer)."""
    stmt = (
        select(
            MathsdrillSession.student_name,
            func.count(MathsdrillSession.id),
            func.coalesce(func.sum(MathsdrillSession.correct), 0),
            func.coalesce(func.sum(MathsdrillSession.total), 0),
            func.max(MathsdrillSession.created_at),
        )
        .group_by(MathsdrillSession.student_name)
        .order_by(func.max(MathsdrillSession.created_at).desc())
    )
    rows = (await db.execute(stmt)).all()
    return [
        MathsdrillStudentSummary(
            student_name=name,
            sessions=int(count),
            correct=int(correct),
            total=int(total),
            last_activity=last,
        )
        for name, count, correct, total, last in rows
    ]


@router.get("/sessions", response_model=list[MathsdrillSessionOut])
async def list_sessions(
    student: str | None = Query(default=None),
    limit: int = Query(default=200, ge=1, le=1000),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(MathsdrillSession)
    if student:
        stmt = stmt.where(MathsdrillSession.student_name == student)
    stmt = stmt.order_by(MathsdrillSession.created_at.desc()).limit(limit)
    return list((await db.execute(stmt)).scalars().all())


@router.get("/paper-states", response_model=list[MathsdrillPaperStateOut])
async def list_paper_states(
    student: str | None = Query(default=None),
    paper_signature: str | None = Query(default=None),
    limit: int = Query(default=200, ge=1, le=1000),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(MathsdrillPaperState)
    if student:
        stmt = stmt.where(MathsdrillPaperState.student_name == student)
    if paper_signature:
        stmt = stmt.where(MathsdrillPaperState.paper_signature == paper_signature)
    stmt = stmt.order_by(MathsdrillPaperState.updated_at.desc()).limit(limit)
    return list((await db.execute(stmt)).scalars().all())


@router.post(
    "/sessions",
    response_model=MathsdrillSessionOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_session(
    payload: MathsdrillSessionIn,
    db: AsyncSession = Depends(get_db),
):
    # Write-only mirror: no auth, name-keyed. Store as-is.
    sess = MathsdrillSession(
        student_name=payload.student_name.strip() or "Anonymous",
        topic_id=payload.topic_id,
        correct=payload.correct,
        total=payload.total,
        score_ts=payload.ts,
    )
    db.add(sess)
    await db.commit()
    await db.refresh(sess)
    return sess


@router.post(
    "/paper-states",
    response_model=MathsdrillPaperStateOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_paper_state(
    payload: MathsdrillPaperStateIn,
    db: AsyncSession = Depends(get_db),
):
    # Write-only mirror: no auth, name-keyed. Upsert-like behavior by student+signature+question
    stmt = select(MathsdrillPaperState).where(
        MathsdrillPaperState.student_name == payload.student_name,
        MathsdrillPaperState.paper_signature == payload.paper_signature,
        MathsdrillPaperState.question_id == payload.question_id,
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()

    if existing is not None:
        if payload.selected is not None:
            existing.selected = payload.selected
        if payload.viewed is not None:
            existing.viewed = payload.viewed
        if payload.solved is not None:
            existing.solved = payload.solved
        if payload.answer is not None:
            existing.answer = payload.answer
        if payload.phrase is not None:
            existing.phrase = payload.phrase
        if payload.answer_lines is not None:
            existing.answer_lines = payload.answer_lines
        if payload.strokes is not None:
            existing.strokes = payload.strokes
        if payload.updated_at_ms is not None:
            existing.updated_at_ms = payload.updated_at_ms
        await db.commit()
        await db.refresh(existing)
        return existing

    state = MathsdrillPaperState(
        student_name=payload.student_name.strip() or "Anonymous",
        paper_signature=payload.paper_signature,
        question_id=payload.question_id,
        selected=payload.selected or False,
        viewed=payload.viewed or False,
        solved=payload.solved or False,
        answer=payload.answer,
        phrase=payload.phrase,
        answer_lines=payload.answer_lines,
        strokes=payload.strokes,
        updated_at_ms=payload.updated_at_ms,
    )
    db.add(state)
    await db.commit()
    await db.refresh(state)
    return state
