from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user, require_admin
from app.models.models import Notification, User

router = APIRouter(prefix="/notifications", tags=["Notifications"])


class NotificationCreate(BaseModel):
    user_id: int
    title: str
    message: str
    notif_type: str
    link: str | None = None


@router.get("/")
async def list_notifications(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == user.id)
        .order_by(Notification.created_at.desc())
        .limit(50)
    )
    return [
        {
            "id": n.id,
            "title": n.title,
            "message": n.message,
            "notif_type": n.notif_type,
            "is_read": n.is_read,
            "link": n.link,
            "created_at": n.created_at,
        }
        for n in result.scalars().all()
    ]


@router.get("/unread-count")
async def unread_count(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import func

    result = await db.execute(
        select(func.count(Notification.id)).where(
            Notification.user_id == user.id, Notification.is_read == False
        )
    )
    return {"count": result.scalar()}


@router.post("/mark-all-read")
async def mark_all_read(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await db.execute(
        update(Notification)
        .where(Notification.user_id == user.id, Notification.is_read == False)
        .values(is_read=True)
    )
    await db.commit()
    return {"detail": "All notifications marked as read"}


@router.put("/{notification_id}/read")
async def mark_single_read(
    notification_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Notification).where(
            Notification.id == notification_id, Notification.user_id == user.id
        )
    )
    notif = result.scalar_one_or_none()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    notif.is_read = True
    await db.commit()
    return {"detail": "Marked as read"}


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_notification(
    body: NotificationCreate,
    user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    notification = Notification(
        user_id=body.user_id,
        title=body.title,
        message=body.message,
        notif_type=body.notif_type,
        link=body.link,
    )
    db.add(notification)
    await db.commit()
    await db.refresh(notification)
    return {"id": notification.id, "title": notification.title}
