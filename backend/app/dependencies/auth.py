from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_token
from app.database.engine import get_db
from app.models.models import User, UserRole

security = HTTPBearer()

# How often an authenticated request is allowed to bump `users.last_seen_at`.
#
# This used to be written (and committed) on *every* authenticated request.
# With the app polling several endpoints per second, that turned SQLite into a
# write-bound database: each poll fsyncs a row update, and a real save (profile,
# recording, voice rename) then queues behind that traffic and appears to hang.
# Presence only needs minute-level accuracy, so writes are throttled.
LAST_SEEN_INTERVAL = timedelta(minutes=5)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    token = credentials.credentials
    payload = decode_token(token)
    if payload is None or payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )
    user_id = payload.get("sub")
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload"
        )
    result = await db.execute(select(User).where(User.id == int(user_id)))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )
    now = datetime.now(timezone.utc)
    last_seen = user.last_seen_at
    if last_seen is not None and last_seen.tzinfo is None:
        # SQLite hands datetimes back naive; treat them as UTC.
        last_seen = last_seen.replace(tzinfo=timezone.utc)
    if last_seen is None or now - last_seen >= LAST_SEEN_INTERVAL:
        user.last_seen_at = now
        await db.commit()
    return user


async def require_role(*roles: UserRole):
    def checker(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions"
            )
        return user

    return checker


async def require_lecturer(user: User = Depends(get_current_user)) -> User:
    if user.role not in (UserRole.LECTURER, UserRole.ADMIN):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Lecturer access required"
        )
    return user


async def require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required"
        )
    return user


async def require_student(user: User = Depends(get_current_user)) -> User:
    if user.role not in (UserRole.STUDENT, UserRole.ADMIN):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Student access required"
        )
    return user
