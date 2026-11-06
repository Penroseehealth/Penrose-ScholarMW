"""LiveKit integration — server-side only.

Generates short-lived access tokens for authenticated clients.
The LiveKit API secret NEVER leaves the backend.
"""

from __future__ import annotations

import logging
from datetime import timedelta

import hmac

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi import Depends as _Dep
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import get_settings
from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User

log = logging.getLogger(__name__)

router = APIRouter(prefix="/livekit", tags=["livekit"])


# ---------------------------------------------------------------------------
# Request / response schemas
# ---------------------------------------------------------------------------


class LiveKitTokenRequest(BaseModel):
    room_name: str | None = None
    identity: str | None = None
    # Display name shown to other participants (e.g. "Aminiology Ma"). Only a
    # label: the stable identity above is what LiveKit uses to de-duplicate
    # participants, so this can never be used to take over someone else's seat.
    name: str | None = None
    ttl_seconds: int = 3600  # 1 hour default, max 24h


class LiveKitTokenResponse(BaseModel):
    token: str
    url: str
    room_name: str
    identity: str
    name: str | None = None
    expires_in: int


class LiveKitRoomResponse(BaseModel):
    name: str
    url: str


class SessionTokenRequest(BaseModel):
    """Role-scoped token request. NO role/identity/room fields: the server
    derives all of them from the participant record."""
    session_id: str
    participant_id: int | None = None
    guest_token: str | None = None


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


def _clean_name(name: str | None) -> str | None:
    """Normalise an optional display name.

    LiveKit caps participant names at 128 characters, so overly long names are
    trimmed rather than rejected - the client always sees a usable label.
    """
    if name is None:
        return None
    cleaned = " ".join(name.split())
    return cleaned[:128] or None


def _generate_token(
    identity: str,
    room_name: str,
    *,
    name: str | None = None,
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
                # Lets the client publish a display name and hand-raise
                # attributes (participant attributes). Nothing else.
                can_update_own_metadata=True,
            )
        )
    )

    if name:
        token = token.with_name(name)

    return token.to_jwt()


# ---------------------------------------------------------------------------
# Endpoints — all require authentication
# ---------------------------------------------------------------------------


@router.post("/session-token", response_model=LiveKitTokenResponse)
async def get_session_scoped_token(
    body: "SessionTokenRequest",
    user: User | None = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Role-scoped LiveKit token for a presentation session (Phase 2).

    The role is resolved EXCLUSIVELY from the server-side participant row —
    never from any client-supplied field. Identity is forced server-side.
    Guests authenticate with the guest_token issued at join time.
    """
    _require_livekit()
    from app.models.presentation import PresentationParticipant, PresentationSession

    # Resolve the session and its server-generated room name.
    session_row = await db.get(PresentationSession, body.session_id)
    if session_row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    session_room_name = session_row.room_name
    # Token TTL: guests and attendees get a short token (≤ 4 h) so a revoked
    # or ended session cannot be re-entered with a stale token.
    ttl = 3600  # 1 hour, clamped ≤ 4 h by design

    participant: PresentationParticipant | None = None
    if body.participant_id is not None and body.guest_token:
        row = await db.get(PresentationParticipant, body.participant_id)
        if row is not None and row.session_id == body.session_id and row.guest_token_hash:
            import hashlib
            supplied_hash = hashlib.sha256(body.guest_token.encode()).hexdigest()
            if hmac.compare_digest(supplied_hash, row.guest_token_hash) and row.left_at is None:
                participant = row
    elif user is not None:
        participant = (await db.execute(
            select(PresentationParticipant)
            .where(PresentationParticipant.session_id == body.session_id)
            .where(PresentationParticipant.user_id == user.id)
        )).scalar_one_or_none()

    if participant is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not an active participant of this session")
    if session_row.pres_state == "completed":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This session has ended")

    identity = (
        f"user_{participant.user_id}" if participant.user_id is not None
        else f"guest_{participant.id}"
    )
    # Grants by server-side role: presenter/co-presenter may publish audio +
    # data; attendees subscribe always, publish only when the session lets
    # attendees ask voice questions (Phase 0D security design).
    if participant.role in ("presenter", "co_presenter"):
        grants = VideoGrants(room=session_room_name, room_join=True, can_publish=True,
                             can_subscribe=True, can_publish_data=True,
                             can_update_own_metadata=True)
    else:
        grants = VideoGrants(room=session_room_name, room_join=True, can_publish=False,
                             can_subscribe=True, can_publish_data=False)

    settings = get_settings()
    # Room pinned to the session's server-generated room name; TTL clamped
    # short (guests ≤ 4 h) and identity/display name never client-controlled.
    token = (
        AccessToken(api_key=settings.LIVEKIT_API_KEY, api_secret=settings.LIVEKIT_API_SECRET)
        .with_identity(identity)
        .with_name(_clean_name(participant.display_name) or "Participant")
        .with_ttl(timedelta(seconds=ttl))
        .with_grants(grants)
    )
    return LiveKitTokenResponse(
        token=token.to_jwt(),
        url=settings.LIVEKIT_URL,
        room_name=session_room_name,
        identity=identity,
        name=participant.display_name,
        expires_in=ttl,
    )


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
    display_name = _clean_name(body.name) or user.full_name
    ttl = min(max(body.ttl_seconds, 60), 86400)

    try:
        token = _generate_token(
            identity=identity,
            room_name=room_name,
            name=display_name,
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
        name=display_name,
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
    from app.livekit.agent_manager import worker_pid

    return {
        "configured": configured,
        "url_set": bool(settings.LIVEKIT_URL),
        "key_set": bool(settings.LIVEKIT_API_KEY),
        "secret_set": bool(settings.LIVEKIT_API_SECRET),
        "voice_agent": worker_pid() is not None,
        "voice_agent_pid": worker_pid(),
    }
