from datetime import datetime

from fastapi import APIRouter, Depends, Request, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import ExamProctorEvent

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class ProctorEventRequest(BaseModel):
    exam_type: str
    exam_id: int
    event_type: str
    event_data: str | None = None


class ProctorEventResponse(BaseModel):
    id: int
    user_id: int
    exam_type: str
    exam_id: int
    event_type: str
    event_data: str | None
    ip_address: str | None
    user_agent: str | None
    created_at: datetime


class ProctorSummaryResponse(BaseModel):
    exam_type: str
    exam_id: int
    total_events: int
    events_by_type: dict[str, int]
    risk_score: int
    risk_level: str


@router.post(
    "/proctor/event",
    response_model=ProctorEventResponse,
    status_code=status.HTTP_201_CREATED,
)
async def log_proctor_event(
    body: ProctorEventRequest,
    request: Request,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ip = request.client.host if request.client else None
    ua = request.headers.get("user-agent")

    event = ExamProctorEvent(
        user_id=user.id,
        exam_type=body.exam_type,
        exam_id=body.exam_id,
        event_type=body.event_type,
        event_data=body.event_data,
        ip_address=ip,
        user_agent=ua,
    )
    db.add(event)
    await db.commit()
    await db.refresh(event)

    return ProctorEventResponse(
        id=event.id,
        user_id=event.user_id,
        exam_type=event.exam_type,
        exam_id=event.exam_id,
        event_type=event.event_type,
        event_data=event.event_data,
        ip_address=event.ip_address,
        user_agent=event.user_agent,
        created_at=event.created_at,
    )


@router.get(
    "/proctor/events/{exam_type}/{exam_id}",
    response_model=list[ProctorEventResponse],
)
async def get_proctor_events(
    exam_type: str,
    exam_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ExamProctorEvent)
        .where(
            ExamProctorEvent.exam_type == exam_type,
            ExamProctorEvent.exam_id == exam_id,
        )
        .order_by(ExamProctorEvent.created_at)
    )
    events = result.scalars().all()

    return [
        ProctorEventResponse(
            id=e.id,
            user_id=e.user_id,
            exam_type=e.exam_type,
            exam_id=e.exam_id,
            event_type=e.event_type,
            event_data=e.event_data,
            ip_address=e.ip_address,
            user_agent=e.user_agent,
            created_at=e.created_at,
        )
        for e in events
    ]


@router.get(
    "/proctor/summary/{exam_type}/{exam_id}",
    response_model=ProctorSummaryResponse,
)
async def get_proctor_summary(
    exam_type: str,
    exam_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(
            ExamProctorEvent.event_type,
            func.count(ExamProctorEvent.id),
        ).where(
            ExamProctorEvent.exam_type == exam_type,
            ExamProctorEvent.exam_id == exam_id,
        )
    )
    rows = result.all()

    events_by_type: dict[str, int] = {}
    total = 0
    for event_type, count in rows:
        events_by_type[event_type] = count
        total += count

    risk_score = (
        events_by_type.get("tab_switch", 0) * 5
        + events_by_type.get("focus_lost", 0) * 3
        + events_by_type.get("copy", 0) * 10
        + events_by_type.get("paste", 0) * 10
        + events_by_type.get("right_click", 0) * 2
        + events_by_type.get("fullscreen_exit", 0) * 8
    )

    if risk_score >= 50:
        risk_level = "high"
    elif risk_score >= 20:
        risk_level = "medium"
    else:
        risk_level = "low"

    return ProctorSummaryResponse(
        exam_type=exam_type,
        exam_id=exam_id,
        total_events=total,
        events_by_type=events_by_type,
        risk_score=risk_score,
        risk_level=risk_level,
    )
