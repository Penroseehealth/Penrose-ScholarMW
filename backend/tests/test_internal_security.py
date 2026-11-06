"""Phase 2: internal endpoint security — INTERNAL_TOKEN required, never
bypassable; constant-time comparison; unauthorized events rejected."""

import pytest
from httpx import AsyncClient

from tests.conftest import auth_header


@pytest.mark.asyncio
async def test_internal_context_requires_token(client: AsyncClient):
    resp = await client.get("/api/v1/internal/presentation-sessions/whatever/context")
    assert resp.status_code in (401, 503)  # 503 when INTERNAL_TOKEN unset


@pytest.mark.asyncio
async def test_internal_context_rejects_wrong_token(client: AsyncClient, monkeypatch):
    import os

    monkeypatch.setenv("INTERNAL_TOKEN", "sekrit")
    resp = await client.get(
        "/api/v1/internal/presentation-sessions/whatever/context",
        headers={"Authorization": "Bearer wrong-token"},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_internal_events_require_token(client: AsyncClient, monkeypatch):
    monkeypatch.setenv("INTERNAL_TOKEN", "sekrit")
    resp = await client.post(
        "/api/v1/internal/presentation-sessions/some-session/events",
        json={"event_type": "transcript_final", "payload": {"text": "hi"}},
    )
    assert resp.status_code == 401
