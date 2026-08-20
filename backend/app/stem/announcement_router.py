from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User, UserRole
from app.models.stem import STEMAnnouncement

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class AnnouncementCreate(BaseModel):
    title: str
    body: str
    subject_slug: str | None = None
    priority: str = "normal"
    is_pinned: bool = False
    target_audience: str = "all"


class AnnouncementResponse(BaseModel):
    id: int
    author_id: int
    title: str
    body: str
    subject_slug: str | None = None
    priority: str
    is_pinned: bool
    target_audience: str
    created_at: datetime

    model_config = {"from_attributes": True}


class AnnouncementDetailResponse(AnnouncementResponse):
    author_name: str = ""


@router.post(
    "/announcements",
    response_model=AnnouncementResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_announcement(
    body: AnnouncementCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if user.role not in (UserRole.LECTURER, UserRole.ADMIN):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only lecturers and admins can create announcements",
        )

    announcement = STEMAnnouncement(
        author_id=user.id,
        title=body.title,
        body=body.body,
        subject_slug=body.subject_slug,
        priority=body.priority,
        is_pinned=body.is_pinned,
        target_audience=body.target_audience,
    )
    db.add(announcement)
    await db.commit()
    await db.refresh(announcement)
    return AnnouncementResponse.model_validate(announcement)


@router.get("/announcements", response_model=list[AnnouncementResponse])
async def list_announcements(
    subject_slug: str | None = Query(None),
    priority: str | None = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(STEMAnnouncement)

    if subject_slug:
        query = query.where(STEMAnnouncement.subject_slug == subject_slug)
    if priority:
        query = query.where(STEMAnnouncement.priority == priority)

    if user.role == UserRole.STUDENT:
        query = query.where(STEMAnnouncement.target_audience.in_(["all", "students"]))
    elif user.role == UserRole.LECTURER:
        query = query.where(STEMAnnouncement.target_audience.in_(["all", "lecturers"]))

    query = query.order_by(
        STEMAnnouncement.is_pinned.desc(),
        STEMAnnouncement.created_at.desc(),
    )
    query = query.offset(skip).limit(limit)

    result = await db.execute(query)
    announcements = result.scalars().all()
    return [AnnouncementResponse.model_validate(a) for a in announcements]


@router.get(
    "/announcements/{announcement_id}",
    response_model=AnnouncementDetailResponse,
)
async def get_announcement(
    announcement_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMAnnouncement).where(STEMAnnouncement.id == announcement_id)
    )
    announcement = result.scalar_one_or_none()
    if not announcement:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Announcement not found"
        )

    author_result = await db.execute(
        select(User).where(User.id == announcement.author_id)
    )
    author = author_result.scalar_one_or_none()

    return AnnouncementDetailResponse(
        id=announcement.id,
        author_id=announcement.author_id,
        title=announcement.title,
        body=announcement.body,
        subject_slug=announcement.subject_slug,
        priority=announcement.priority,
        is_pinned=announcement.is_pinned,
        target_audience=announcement.target_audience,
        created_at=announcement.created_at,
        author_name=author.full_name if author else "",
    )


@router.delete("/announcements/{announcement_id}")
async def delete_announcement(
    announcement_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMAnnouncement).where(STEMAnnouncement.id == announcement_id)
    )
    announcement = result.scalar_one_or_none()
    if not announcement:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Announcement not found"
        )
    if announcement.author_id != user.id and user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the author or an admin can delete this announcement",
        )

    await db.delete(announcement)
    await db.commit()
    return {"detail": "Announcement deleted"}
