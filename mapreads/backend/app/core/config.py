import os
from pathlib import Path


APP_NAME = "MapReads API"


def database_path() -> Path:
    configured = os.environ.get("MAPREADS_DB_PATH")
    if configured:
        return Path(configured).expanduser()
    return Path(__file__).resolve().parents[2] / "data" / "maps.sqlite3"


def allowed_origins() -> list[str]:
    configured = os.environ.get("MAPREADS_CORS_ORIGINS", "*")
    return [origin.strip() for origin in configured.split(",") if origin.strip()]
