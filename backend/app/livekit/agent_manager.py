"""Supervises the LiveKit voice-agent worker subprocess from the FastAPI app.

The heavy ``livekit.agents`` worker must never block the web server's event loop,
so it is spawned as its own process (`python -m app.livekit.agent.worker dev`)
and terminated when the app shuts down.

Starts only when LiveKit is configured (`LIVEKIT_*` in backend/.env); disable
with ``LIVEKIT_AGENT_ENABLED=0``.  Logs go to ``backend/logs/voice_agent.log``.
"""

from __future__ import annotations

import asyncio
import logging
import os
import sys
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path

from app.config.settings import get_settings

log = logging.getLogger(__name__)

_BACKEND_DIR = Path(__file__).resolve().parent.parent.parent

_worker_pid: int | None = None
"""PID of the spawned voice-agent worker (0 when not running)."""


def worker_pid() -> int | None:
    """Current voice-agent worker PID for status endpoints."""
    return _worker_pid


@asynccontextmanager
async def voice_agent_host() -> AsyncIterator[None]:
    """Spawn the LiveKit voice-agent worker for the app's lifetime."""
    global _worker_pid

    settings = get_settings()
    enabled = os.getenv("LIVEKIT_AGENT_ENABLED", "1").lower() not in (
        "0",
        "false",
        "no",
    )
    proc: asyncio.subprocess.Process | None = None
    log_file = None

    if settings.livekit_configured and enabled:
        try:
            log_dir = _BACKEND_DIR / "logs"
            log_dir.mkdir(exist_ok=True)
            log_file = (log_dir / "voice_agent.log").open(
                "a", encoding="utf-8", buffering=1
            )

            proc = await asyncio.create_subprocess_exec(
                sys.executable,
                "-m",
                "app.livekit.agent.worker",
                "dev",
                cwd=str(_BACKEND_DIR),
                stdout=log_file,
                stderr=asyncio.subprocess.STDOUT,
            )
            _worker_pid = proc.pid
            log.info("LiveKit voice-agent worker started (pid=%s)", proc.pid)
        except Exception:  # noqa: BLE001 - must not take the API server down
            _worker_pid = None
            log.exception("Failed to start LiveKit voice-agent worker")
    else:
        log.info(
            "LiveKit voice-agent worker skipped (configured=%s, enabled=%s)",
            settings.livekit_configured,
            enabled,
        )

    try:
        yield
    finally:
        if proc is not None and proc.returncode is None:
            proc.terminate()
            try:
                await asyncio.wait_for(proc.wait(), timeout=10)
            except asyncio.TimeoutError:
                proc.kill()
            log.info("LiveKit voice-agent worker terminated (pid=%s)", proc.pid)
        if log_file is not None:
            log_file.close()
        _worker_pid = None
