from __future__ import annotations

import json
import logging
from datetime import datetime
from typing import Any

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_token
from app.database.engine import async_session, get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import STEMGroupMember, STEMGroupMessage, STEMStudyGroup

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


# ── In-memory connection tracking ──
# group_id -> set of (websocket, user_id)
active_connections: dict[int, set[tuple[WebSocket, int]]] = {}


async def get_ws_user(token: str, db: AsyncSession) -> User | None:
    payload = decode_token(token)
    if payload is None or payload.get("type") != "access":
        return None
    user_id = payload.get("sub")
    if user_id is None:
        return None
    result = await db.execute(select(User).where(User.id == int(user_id)))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        return None
    return user


async def _verify_group_exists(db: AsyncSession, group_id: int) -> STEMStudyGroup | None:
    result = await db.execute(select(STEMStudyGroup).where(STEMStudyGroup.id == group_id))
    return result.scalar_one_or_none()


async def _verify_membership(db: AsyncSession, group_id: int, user_id: int) -> STEMGroupMember | None:
    result = await db.execute(
        select(STEMGroupMember).where(
            STEMGroupMember.group_id == group_id,
            STEMGroupMember.user_id == user_id,
        )
    )
    return result.scalar_one_or_none()


async def _fetch_user(db: AsyncSession, user_id: int) -> User | None:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def _broadcast(
    group_id: int,
    message: dict[str, Any],
    exclude: WebSocket | None = None,
) -> None:
    connections = active_connections.get(group_id, set())
    dead: list[tuple[WebSocket, int]] = []
    payload = json.dumps(message)
    for ws, uid in connections:
        if ws is exclude:
            continue
        try:
            await ws.send_text(payload)
        except Exception:
            dead.append((ws, uid))
    for ws, uid in dead:
        connections.discard((ws, uid))


def _get_online_user_ids(group_id: int) -> set[int]:
    return {uid for _, uid in active_connections.get(group_id, set())}


# ── WebSocket endpoint ──


@router.websocket("/ws/groups/{group_id}")
async def websocket_groups(
    websocket: WebSocket,
    group_id: int,
    token: str = Query(...),
) -> None:
    await websocket.accept()

    user: User | None = None
    db: AsyncSession | None = None

    try:
        db = async_session()

        user = await get_ws_user(token, db)
        if user is None:
            await websocket.close(code=4001, reason="Invalid or expired token")
            return

        group = await _verify_group_exists(db, group_id)
        if group is None:
            await websocket.close(code=4004, reason="Group not found")
            return

        if not group.is_active:
            await websocket.close(code=4003, reason="Group is not active")
            return

        membership = await _verify_membership(db, group_id, user.id)
        if membership is None:
            await websocket.close(code=4003, reason="Not a member of this group")
            return

        active_connections.setdefault(group_id, set()).add((websocket, user.id))

        await _broadcast(
            group_id,
            {"type": "presence", "user_id": user.id, "status": "online"},
        )

        await websocket.send_json(
            {
                "type": "connected",
                "user_id": user.id,
                "group_id": group_id,
                "online_users": list(_get_online_user_ids(group_id)),
            }
        )

        while True:
            data = await websocket.receive_text()

            try:
                payload = json.loads(data)
            except json.JSONDecodeError:
                await websocket.send_json({"type": "error", "message": "Invalid JSON"})
                continue

            msg_type = payload.get("type")

            if msg_type == "chat":
                content = payload.get("content", "").strip()
                if not content:
                    await websocket.send_json({"type": "error", "message": "Empty message"})
                    continue

                if len(content) > 5000:
                    await websocket.send_json(
                        {
                            "type": "error",
                            "message": "Message exceeds 5000 character limit",
                        }
                    )
                    continue

                message = STEMGroupMessage(
                    group_id=group_id,
                    user_id=user.id,
                    message=content,
                )
                db.add(message)
                await db.commit()
                await db.refresh(message)

                await _broadcast(
                    group_id,
                    {
                        "type": "chat",
                        "message_id": message.id,
                        "user_id": user.id,
                        "sender_name": user.full_name,
                        "content": content,
                        "created_at": message.created_at.isoformat(),
                    },
                )

            elif msg_type == "typing":
                await _broadcast(
                    group_id,
                    {
                        "type": "typing",
                        "user_id": user.id,
                        "sender_name": user.full_name,
                        "is_typing": payload.get("is_typing", True),
                    },
                    exclude=websocket,
                )

            elif msg_type == "ping":
                await websocket.send_json({"type": "pong"})

            else:
                await websocket.send_json(
                    {
                        "type": "error",
                        "message": f"Unknown message type: {msg_type}",
                    }
                )

    except WebSocketDisconnect:
        pass
    except Exception:
        logger.exception(
            "WebSocket error for group %s user %s",
            group_id,
            getattr(user, "id", "unknown"),
        )
        try:
            await websocket.close(code=1011, reason="Internal server error")
        except Exception:
            pass
    finally:
        active_connections.get(group_id, set()).discard((websocket, user.id if user else -1))
        if not active_connections.get(group_id):
            active_connections.pop(group_id, None)
        if db is not None:
            await db.close()
        if user is not None:
            await _broadcast(
                group_id,
                {"type": "presence", "user_id": user.id, "status": "offline"},
            )


# ── REST endpoints ──


class OnlineUserInfo(BaseModel):
    user_id: int
    full_name: str


class GroupOnlineInfo(BaseModel):
    group_id: int
    group_name: str
    online_count: int
    online_users: list[OnlineUserInfo]


class MessageInfo(BaseModel):
    id: int
    user_id: int
    sender_name: str
    message: str
    created_at: str


@router.get("/collaboration/presence/{group_id}", response_model=list[OnlineUserInfo])
async def get_group_presence(
    group_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[OnlineUserInfo]:
    membership = await _verify_membership(db, group_id, user.id)
    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Must be a member to view presence",
        )

    online_ids = _get_online_user_ids(group_id)
    if not online_ids:
        return []

    result = await db.execute(select(User).where(User.id.in_(online_ids)))
    users = result.scalars().all()

    return [OnlineUserInfo(user_id=u.id, full_name=u.full_name) for u in users]


@router.get("/collaboration/history/{group_id}", response_model=list[MessageInfo])
async def get_message_history(
    group_id: int,
    limit: int = Query(50, ge=1, le=200),
    before: datetime | None = Query(None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[MessageInfo]:
    membership = await _verify_membership(db, group_id, user.id)
    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Must be a member to view message history",
        )

    stmt = select(STEMGroupMessage).where(STEMGroupMessage.group_id == group_id)
    if before is not None:
        stmt = stmt.where(STEMGroupMessage.created_at < before)

    stmt = stmt.order_by(STEMGroupMessage.created_at.desc()).limit(limit)
    result = await db.execute(stmt)
    messages = result.scalars().all()

    user_ids = {m.user_id for m in messages}
    users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
    users_map = {u.id: u for u in users_result.scalars().all()}

    response: list[MessageInfo] = []
    for msg in reversed(messages):
        sender = users_map.get(msg.user_id)
        response.append(
            MessageInfo(
                id=msg.id,
                user_id=msg.user_id,
                sender_name=sender.full_name if sender else "Unknown",
                message=msg.message,
                created_at=msg.created_at.isoformat(),
            )
        )

    return response


@router.get("/collaboration/online", response_model=list[GroupOnlineInfo])
async def get_user_online_groups(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[GroupOnlineInfo]:
    stmt = (
        select(STEMStudyGroup)
        .join(STEMGroupMember, STEMGroupMember.group_id == STEMStudyGroup.id)
        .where(
            STEMGroupMember.user_id == user.id,
            STEMStudyGroup.is_active.is_(True),
        )
    )
    result = await db.execute(stmt)
    groups = result.scalars().all()

    online_groups: list[GroupOnlineInfo] = []
    for group in groups:
        online_ids = _get_online_user_ids(group.id)
        users_result = await db.execute(select(User).where(User.id.in_(online_ids)))
        users = users_result.scalars().all()
        online_groups.append(
            GroupOnlineInfo(
                group_id=group.id,
                group_name=group.name,
                online_count=len(online_ids),
                online_users=[OnlineUserInfo(user_id=u.id, full_name=u.full_name) for u in users],
            )
        )

    return online_groups
