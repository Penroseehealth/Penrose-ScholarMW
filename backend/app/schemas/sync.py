from pydantic import BaseModel


class SyncRecordCreate(BaseModel):
    entity_type: str
    entity_id: str
    action: str
    payload: str | None = None
    local_timestamp: str


class SyncPushRequest(BaseModel):
    records: list[SyncRecordCreate]


class SyncRecordResponse(BaseModel):
    id: int
    entity_type: str
    entity_id: str
    action: str
    status: str
    conflict_resolution: str | None = None
    synced_at: str | None = None

    model_config = {"from_attributes": True}


class SyncStatusResponse(BaseModel):
    pending: int
    synced: int
    conflicts: int


class ConflictResolveRequest(BaseModel):
    record_id: int
    resolution: str
    merged_payload: str | None = None
