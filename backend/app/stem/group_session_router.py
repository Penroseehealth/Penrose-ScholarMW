from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    STEMConcept,
    STEMGroupMember,
    STEMGroupSession,
    STEMGroupSessionConcept,
    STEMStudyGroup,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class SessionStartRequest(BaseModel):
    group_id: int
    title: str
    description: str | None = None
    concept_ids: list[int] | None = None


class SessionConceptResponse(BaseModel):
    concept_id: int
    concept_title: str


class GroupSessionResponse(BaseModel):
    id: int
    group_id: int
    group_name: str
    started_by: int
    started_by_name: str
    title: str
    description: str | None
    started_at: datetime
    ended_at: datetime | None
    duration_minutes: int | None
    concepts: list[SessionConceptResponse]
    member_count: int


class SessionEndRequest(BaseModel):
    concepts_studied: list[int] | None = None


class GroupStatsResponse(BaseModel):
    group_id: int
    group_name: str
    total_sessions: int
    total_duration_minutes: int
    unique_concepts: int
    active_members: int
    recent_sessions: list[GroupSessionResponse]


def _session_to_response(
    session: STEMGroupSession,
    group_name: str,
    started_by_name: str,
    concepts: list[SessionConceptResponse],
    member_count: int,
) -> GroupSessionResponse:
    duration = None
    if session.ended_at and session.started_at:
        delta = session.ended_at - session.started_at
        duration = int(delta.total_seconds() / 60)
    return GroupSessionResponse(
        id=session.id,
        group_id=session.group_id,
        group_name=group_name,
        started_by=session.started_by,
        started_by_name=started_by_name,
        title=session.title,
        description=session.description,
        started_at=session.started_at,
        ended_at=session.ended_at,
        duration_minutes=duration,
        concepts=concepts,
        member_count=member_count,
    )


async def _enrich_session(session: STEMGroupSession, db: AsyncSession) -> GroupSessionResponse:
    group_result = await db.execute(select(STEMStudyGroup).where(STEMStudyGroup.id == session.group_id))
    group = group_result.scalar_one_or_none()
    group_name = group.name if group else "Unknown"

    user_result = await db.execute(select(User).where(User.id == session.started_by))
    starter = user_result.scalar_one_or_none()
    started_by_name = starter.full_name if starter else "Unknown"

    concepts_result = await db.execute(
        select(STEMGroupSessionConcept).where(STEMGroupSessionConcept.session_id == session.id)
    )
    sc_rows = concepts_result.scalars().all()
    concepts: list[SessionConceptResponse] = []
    for sc in sc_rows:
        c_result = await db.execute(select(STEMConcept).where(STEMConcept.id == sc.concept_id))
        c = c_result.scalar_one_or_none()
        concepts.append(
            SessionConceptResponse(
                concept_id=sc.concept_id,
                concept_title=c.title if c else "Unknown",
            )
        )

    member_count_result = await db.execute(
        select(func.count(STEMGroupMember.id)).where(STEMGroupMember.group_id == session.group_id)
    )
    member_count = member_count_result.scalar() or 0

    return _session_to_response(session, group_name, started_by_name, concepts, member_count)


@router.post(
    "/group-sessions/start",
    response_model=GroupSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def start_group_session(
    body: SessionStartRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    group_result = await db.execute(select(STEMStudyGroup).where(STEMStudyGroup.id == body.group_id))
    group = group_result.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")

    member_result = await db.execute(
        select(STEMGroupMember).where(
            STEMGroupMember.group_id == body.group_id,
            STEMGroupMember.user_id == user.id,
        )
    )
    if not member_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Must be a group member to start a session",
        )

    session = STEMGroupSession(
        group_id=body.group_id,
        started_by=user.id,
        title=body.title,
        description=body.description,
    )
    db.add(session)
    await db.flush()

    if body.concept_ids:
        for cid in body.concept_ids:
            db.add(STEMGroupSessionConcept(session_id=session.id, concept_id=cid))

    await db.commit()
    await db.refresh(session)

    return await _enrich_session(session, db)


@router.post(
    "/group-sessions/{session_id}/end",
    response_model=GroupSessionResponse,
)
async def end_group_session(
    session_id: int,
    body: SessionEndRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMGroupSession).where(STEMGroupSession.id == session_id))
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    if session.ended_at:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Session already ended")

    member_result = await db.execute(
        select(STEMGroupMember).where(
            STEMGroupMember.group_id == session.group_id,
            STEMGroupMember.user_id == user.id,
        )
    )
    if not member_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Must be a group member to end a session",
        )

    session.ended_at = datetime.now(timezone.utc)

    if body.concepts_studied:
        existing_result = await db.execute(
            select(STEMGroupSessionConcept).where(STEMGroupSessionConcept.session_id == session_id)
        )
        existing_ids = {sc.concept_id for sc in existing_result.scalars().all()}
        for cid in body.concepts_studied:
            if cid not in existing_ids:
                db.add(STEMGroupSessionConcept(session_id=session_id, concept_id=cid))

    await db.commit()
    await db.refresh(session)

    return await _enrich_session(session, db)


@router.get(
    "/group-sessions/{session_id}",
    response_model=GroupSessionResponse,
)
async def get_group_session(
    session_id: int,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMGroupSession).where(STEMGroupSession.id == session_id))
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    return await _enrich_session(session, db)


@router.get(
    "/group-sessions/group/{group_id}",
    response_model=list[GroupSessionResponse],
)
async def list_group_sessions(
    group_id: int,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMGroupSession)
        .where(STEMGroupSession.group_id == group_id)
        .order_by(STEMGroupSession.started_at.desc())
    )
    sessions = result.scalars().all()
    enriched = []
    for s in sessions:
        enriched.append(await _enrich_session(s, db))
    return enriched


@router.get(
    "/group-stats/{group_id}",
    response_model=GroupStatsResponse,
)
async def get_group_stats(
    group_id: int,
    db: AsyncSession = Depends(get_db),
):
    group_result = await db.execute(select(STEMStudyGroup).where(STEMStudyGroup.id == group_id))
    group = group_result.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")

    sessions_result = await db.execute(select(STEMGroupSession).where(STEMGroupSession.group_id == group_id))
    sessions = sessions_result.scalars().all()

    total_sessions = len(sessions)
    total_minutes = 0
    concept_ids: set[int] = set()
    for s in sessions:
        if s.ended_at and s.started_at:
            total_minutes += int((s.ended_at - s.started_at).total_seconds() / 60)
        cr = await db.execute(select(STEMGroupSessionConcept).where(STEMGroupSessionConcept.session_id == s.id))
        for sc in cr.scalars().all():
            concept_ids.add(sc.concept_id)

    active_result = await db.execute(select(func.count(STEMGroupMember.id)).where(STEMGroupMember.group_id == group_id))
    active_members = active_result.scalar() or 0

    recent = sessions[:5]
    recent_enriched = [await _enrich_session(s, db) for s in recent]

    return GroupStatsResponse(
        group_id=group_id,
        group_name=group.name,
        total_sessions=total_sessions,
        total_duration_minutes=total_minutes,
        unique_concepts=len(concept_ids),
        active_members=active_members,
        recent_sessions=recent_enriched,
    )
