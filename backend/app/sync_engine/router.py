import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import SyncRecord, User

router = APIRouter(prefix="/sync", tags=["Offline Sync"])


class SyncRecordInput(BaseModel):
    entity_type: str
    entity_id: str
    action: str
    payload: dict | None = None
    local_timestamp: datetime


class SyncPushRequest(BaseModel):
    records: list[SyncRecordInput]


class SyncResolveRequest(BaseModel):
    record_id: int
    resolution: str
    merged_payload: dict | None = None


@router.post("/push")
async def push_changes(
    body: SyncPushRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    results = []
    for record in body.records:
        existing = await db.execute(
            select(SyncRecord).where(
                SyncRecord.user_id == user.id,
                SyncRecord.entity_type == record.entity_type,
                SyncRecord.entity_id == record.entity_id,
                SyncRecord.status == "synced",
            )
        )
        existing_record = existing.scalar_one_or_none()

        if existing_record:
            new_record = SyncRecord(
                user_id=user.id,
                entity_type=record.entity_type,
                entity_id=record.entity_id,
                action=record.action,
                payload=json.dumps(record.payload) if record.payload else None,
                status="conflict",
                local_timestamp=record.local_timestamp,
            )
        else:
            new_record = SyncRecord(
                user_id=user.id,
                entity_type=record.entity_type,
                entity_id=record.entity_id,
                action=record.action,
                payload=json.dumps(record.payload) if record.payload else None,
                status="synced",
                local_timestamp=record.local_timestamp,
                synced_at=datetime.now(timezone.utc),
            )

        db.add(new_record)
        await db.commit()
        await db.refresh(new_record)
        results.append(
            {
                "record_id": new_record.id,
                "entity_type": new_record.entity_type,
                "entity_id": new_record.entity_id,
                "status": new_record.status,
            }
        )

    return {"synced": results}


@router.get("/pull")
async def pull_changes(
    since: datetime | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(SyncRecord).where(
        SyncRecord.user_id == user.id,
        SyncRecord.status.in_(["pending", "synced"]),
    )
    if since:
        query = query.where(SyncRecord.created_at > since)
    query = query.order_by(SyncRecord.created_at.desc())

    result = await db.execute(query)
    records = result.scalars().all()

    return [
        {
            "id": r.id,
            "entity_type": r.entity_type,
            "entity_id": r.entity_id,
            "action": r.action,
            "payload": json.loads(r.payload) if r.payload else None,
            "status": r.status,
            "local_timestamp": r.local_timestamp.isoformat() if r.local_timestamp else None,
            "synced_at": r.synced_at.isoformat() if r.synced_at else None,
        }
        for r in records
    ]


@router.post("/resolve")
async def resolve_conflict(
    body: SyncResolveRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SyncRecord).where(
            SyncRecord.id == body.record_id,
            SyncRecord.user_id == user.id,
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sync record not found")
    if record.status != "conflict":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Record is not a conflict")

    record.resolution = body.resolution
    record.status = "synced"
    record.synced_at = datetime.now(timezone.utc)
    if body.merged_payload:
        record.merged_payload = json.dumps(body.merged_payload)

    await db.commit()
    await db.refresh(record)

    return {
        "id": record.id,
        "status": record.status,
        "resolution": record.resolution,
    }


@router.get("/status")
async def sync_status(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(SyncRecord.status, func.count(SyncRecord.id))
        .where(SyncRecord.user_id == user.id)
        .group_by(SyncRecord.status)
    )
    counts = {row[0]: row[1] for row in result.all()}

    return {
        "pending": counts.get("pending", 0),
        "synced": counts.get("synced", 0),
        "conflicts": counts.get("conflict", 0),
    }
