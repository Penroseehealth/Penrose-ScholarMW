import base64
import binascii
import json
import struct
import uuid
import zlib
from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException

from ..core.database import connection
from ..schemas.maps import MapConfig, MapCreate, MapRecord, MapSummary


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _record(row: Any) -> MapRecord:
    return MapRecord(
        id=row["id"],
        name=row["name"],
        config=json.loads(row["config_json"]),
        annotations=json.loads(row["annotations_json"]),
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def create_map(payload: MapCreate) -> MapRecord:
    map_id = str(uuid.uuid4())
    now = _now()
    with connection() as db:
        db.execute(
            """INSERT INTO maps(id, name, config_json, annotations_json, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (
                map_id,
                payload.name.strip(),
                payload.config.model_dump_json(),
                json.dumps(payload.annotations),
                now,
                now,
            ),
        )
        row = db.execute("SELECT * FROM maps WHERE id = ?", (map_id,)).fetchone()
    return _record(row)


def list_maps() -> list[MapSummary]:
    with connection() as db:
        rows = db.execute("SELECT * FROM maps ORDER BY updated_at DESC").fetchall()
    return [
        MapSummary(
            id=row["id"],
            name=row["name"],
            config=json.loads(row["config_json"]),
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )
        for row in rows
    ]


def get_map(map_id: str) -> MapRecord:
    with connection() as db:
        row = db.execute("SELECT * FROM maps WHERE id = ?", (map_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Map not found")
    return _record(row)


def update_map(map_id: str, payload: MapCreate) -> MapRecord:
    now = _now()
    with connection() as db:
        result = db.execute(
            """UPDATE maps SET name = ?, config_json = ?, annotations_json = ?, updated_at = ?
               WHERE id = ?""",
            (
                payload.name.strip(),
                payload.config.model_dump_json(),
                json.dumps(payload.annotations),
                now,
                map_id,
            ),
        )
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="Map not found")
        row = db.execute("SELECT * FROM maps WHERE id = ?", (map_id,)).fetchone()
    return _record(row)


def delete_map(map_id: str) -> None:
    with connection() as db:
        result = db.execute("DELETE FROM maps WHERE id = ?", (map_id,))
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="Map not found")


def save_png(map_id: str, data_url: str) -> dict[str, str]:
    get_map(map_id)
    prefix = "data:image/png;base64,"
    if not data_url.startswith(prefix):
        raise HTTPException(status_code=422, detail="Expected a PNG data URL")
    try:
        content = base64.b64decode(data_url[len(prefix):], validate=True)
    except (binascii.Error, ValueError) as error:
        raise HTTPException(status_code=422, detail="Invalid PNG base64 data") from error
    _validate_png(content)
    export_id = str(uuid.uuid4())
    created_at = _now()
    with connection() as db:
        db.execute(
            """INSERT INTO exports(id, map_id, kind, media_type, content, created_at)
               VALUES (?, ?, 'png', 'image/png', ?, ?)""",
            (export_id, map_id, content, created_at),
        )
    return {"id": export_id, "created_at": created_at}


def _validate_png(content: bytes) -> None:
    signature = b"\x89PNG\r\n\x1a\n"
    if not content.startswith(signature):
        raise HTTPException(status_code=422, detail="Export data is not a PNG image")
    offset = len(signature)
    first_chunk = True
    ended = False
    while offset + 12 <= len(content):
        length = struct.unpack(">I", content[offset : offset + 4])[0]
        end = offset + length + 12
        if end > len(content):
            break
        chunk_type = content[offset + 4 : offset + 8]
        chunk_data = content[offset + 8 : offset + 8 + length]
        crc = struct.unpack(">I", content[offset + 8 + length : end])[0]
        if zlib.crc32(chunk_type + chunk_data) & 0xFFFFFFFF != crc:
            break
        if first_chunk:
            if chunk_type != b"IHDR" or length != 13:
                break
            width, height = struct.unpack(">II", chunk_data[:8])
            if width < 1 or height < 1 or width * height > 40_000_000:
                raise HTTPException(status_code=422, detail="PNG dimensions are invalid or too large")
            first_chunk = False
        if chunk_type == b"IEND":
            ended = length == 0 and end == len(content)
            break
        offset = end
    if first_chunk or not ended:
        raise HTTPException(status_code=422, detail="PNG image data is incomplete or invalid")


def get_png(export_id: str) -> tuple[bytes, str]:
    with connection() as db:
        row = db.execute(
            """SELECT content, media_type FROM exports
               WHERE id = ? AND kind = 'png'""",
            (export_id,),
        ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="PNG export not found")
    return bytes(row["content"]), row["media_type"]


def normalize_generation(config: MapConfig) -> MapConfig:
    return config
