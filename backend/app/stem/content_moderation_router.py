from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User, UserRole
from app.models.stem import STEMContentReport

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class ReportCreate(BaseModel):
    content_type: str
    content_id: int
    reason: str
    description: str | None = None


class ReportResponse(BaseModel):
    id: int
    reporter_id: int
    content_type: str
    content_id: int
    reason: str
    description: str | None = None
    status: str
    reviewed_by: int | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ReportReviewRequest(BaseModel):
    status: str
    note: str | None = None


class ReportStatsResponse(BaseModel):
    pending_count: int
    by_type: dict[str, int]


@router.post(
    "/reports",
    response_model=ReportResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_report(
    body: ReportCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    valid_types = {"post", "answer", "flashcard", "message"}
    if body.content_type not in valid_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid content_type. Must be one of: {', '.join(sorted(valid_types))}",
        )

    report = STEMContentReport(
        reporter_id=user.id,
        content_type=body.content_type,
        content_id=body.content_id,
        reason=body.reason,
        description=body.description,
    )
    db.add(report)
    await db.commit()
    await db.refresh(report)
    return ReportResponse.model_validate(report)


@router.get("/reports", response_model=list[ReportResponse])
async def list_reports(
    report_status: str | None = Query(None),
    content_type: str | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required"
        )

    query = select(STEMContentReport)

    if report_status:
        query = query.where(STEMContentReport.status == report_status)
    if content_type:
        query = query.where(STEMContentReport.content_type == content_type)

    query = query.order_by(STEMContentReport.created_at.desc())
    query = query.offset(skip).limit(limit)

    result = await db.execute(query)
    reports = result.scalars().all()
    return [ReportResponse.model_validate(r) for r in reports]


@router.put("/reports/{report_id}/review", response_model=ReportResponse)
async def review_report(
    report_id: int,
    body: ReportReviewRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required"
        )

    valid_statuses = {"pending", "reviewed", "resolved", "dismissed"}
    if body.status not in valid_statuses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status. Must be one of: {', '.join(sorted(valid_statuses))}",
        )

    result = await db.execute(
        select(STEMContentReport).where(STEMContentReport.id == report_id)
    )
    report = result.scalar_one_or_none()
    if not report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Report not found"
        )

    report.status = body.status
    report.reviewed_by = user.id
    await db.commit()
    await db.refresh(report)
    return ReportResponse.model_validate(report)


@router.get("/reports/stats", response_model=ReportStatsResponse)
async def get_report_stats(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required"
        )

    pending_result = await db.execute(
        select(func.count()).where(STEMContentReport.status == "pending")
    )
    pending_count = pending_result.scalar() or 0

    type_result = await db.execute(
        select(
            STEMContentReport.content_type,
            func.count(),
        )
        .where(STEMContentReport.status == "pending")
        .group_by(STEMContentReport.content_type)
    )
    by_type = {row[0]: row[1] for row in type_result.all()}

    return ReportStatsResponse(pending_count=pending_count, by_type=by_type)
