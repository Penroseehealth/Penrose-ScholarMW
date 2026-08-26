"""LiveKit integration — server-side only.

Generates short-lived access tokens for authenticated clients.
The LiveKit API secret NEVER leaves the backend.
"""

from __future__ import annotations

import logging
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.config.settings import get_settings
from app.core.security import get_current_user
from app.models.models import User

log = logging.getLogger(__name__)

router = APIRouter(prefix="/livekit", tags=["livekit"])


# ---------------------------------------------------------------------------
# Request / response schemas
# ---------------------------------------------------------------------------


class LiveKitTokenRequest(BaseModel):
    room_name: str | None = None
    identity: str | None = None
    ttl_seconds: int = 3600  # 1 hour default, max 24h


class LiveKitTokenResponse(BaseModel):
    token: str
    url: str
    room_name: str
    identity: str
    expires_in: int


class LiveKitRoomResponse(BaseModel):
    name: str
    url: str


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _require_livekit():
    """Guard that LiveKit is configured."""
    settings = get_settings()
    if not settings.livekit_configured:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="LiveKit is not configured on this server.",
        )


def _generate_token(
    identity: str,
    room_name: str,
    *,
    ttl_seconds: int = 3600,
) -> str:
    """Generate a LiveKit access token using the server-side secret."""
    from livekit.api import AccessToken, VideoGrants

    settings = get_settings()

    ttl = min(max(ttl_seconds, 60), 86400)  # clamp 60s – 24h

    token = (
        AccessToken(
            api_key=settings.LIVEKIT_API_KEY,
            api_secret=settings.LIVEKIT_API_SECRET,
        )
        .with_identity(identity)
        .with_ttl(timedelta(seconds=ttl))
        .with_grants(
            VideoGrants(
                room=room_name,
                room_join=True,
                can_publish=True,
                can_subscribe=True,
                can_publish_data=True,
            )
        )
    )

    return token.to_jwt()


# ---------------------------------------------------------------------------
# Endpoints — all require authentication
# ---------------------------------------------------------------------------


@router.post("/token", response_model=LiveKitTokenResponse)
async def get_livekit_token(
    body: LiveKitTokenRequest,
    user: User = Depends(get_current_user),
):
    """Issue a short-lived LiveKit access token for the authenticated user.

    The API secret is NEVER sent to the client — only a JWT access token
    that grants scoped access to a specific LiveKit room.
    """
    _require_livekit()
    settings = get_settings()

    identity = body.identity or f"user_{user.id}"
    room_name = body.room_name or f"session_{user.id}"
    ttl = min(max(body.ttl_seconds, 60), 86400)

    try:
        token = _generate_token(
            identity=identity,
            room_name=room_name,
            ttl_seconds=ttl,
        )
    except Exception as e:
        log.error("Failed to generate LiveKit token: %s", type(e).__name__)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate LiveKit token.",
        )

    log.info("LiveKit token issued for user=%s room=%s", user.id, room_name)

    return LiveKitTokenResponse(
        token=token,
        url=settings.LIVEKIT_URL,
        room_name=room_name,
        identity=identity,
        expires_in=ttl,
    )


@router.get("/room/{room_name}", response_model=LiveKitRoomResponse)
async def get_livekit_room_url(
    room_name: str,
    user: User = Depends(get_current_user),
):
    """Return the LiveKit WebSocket URL for a given room.

    This is a public endpoint (no secret) — clients need only the URL
    + the token from /token to connect.
    """
    _require_livekit()
    settings = get_settings()

    return LiveKitRoomResponse(
        name=room_name,
        url=settings.LIVEKIT_URL,
    )


@router.get("/health")
async def livekit_health():
    """Quick health check — does not expose secrets."""
    settings = get_settings()
    configured = settings.livekit_configured
    return {
        "configured": configured,
        "url_set": bool(settings.LIVEKIT_URL),
        "key_set": bool(settings.LIVEKIT_API_KEY),
        "secret_set": bool(settings.LIVEKIT_API_SECRET),
    }
