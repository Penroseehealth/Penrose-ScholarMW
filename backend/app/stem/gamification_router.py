from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    STEMBadge,
    STEMChallenge,
    STEMChallengeParticipant,
    STEMLeaderboardEntry,
    STEMUserBadge,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


# ── Response models ──


class BadgeResponse(BaseModel):
    id: int
    title: str
    description: str | None
    icon: str | None
    category: str
    points: int
    requirement_type: str | None
    requirement_value: int | None


class EarnedBadgeResponse(BadgeResponse):
    earned_at: datetime


class LeaderboardEntryResponse(BaseModel):
    rank: int
    user_id: int
    display_name: str
    total_points: int
    concepts_mastered: int
    challenges_completed: int
    current_streak: int


class ChallengeResponse(BaseModel):
    id: int
    title: str
    description: str | None
    challenge_type: str
    subject_slug: str | None
    points_reward: int
    difficulty: str
    is_active: bool
    expires_at: datetime | None
    participants_count: int


class ChallengeJoinResponse(BaseModel):
    id: int
    challenge_id: int
    progress_pct: float
    is_completed: bool
    created_at: datetime


class ChallengeProgressResponse(BaseModel):
    id: int
    challenge_id: int
    progress_pct: float
    is_completed: bool
    completed_at: datetime | None


class StreakResponse(BaseModel):
    current_streak: int
    longest_streak: int
    last_activity_date: datetime | None


class PointsBreakdown(BaseModel):
    concepts_mastered: int
    challenges_completed: int
    badges_earned: int


class PointsResponse(BaseModel):
    total_points: int
    breakdown: PointsBreakdown


# ── Helpers ──


def _badge_to_response(badge: STEMBadge) -> BadgeResponse:
    return BadgeResponse(
        id=badge.id,
        title=badge.title,
        description=badge.description,
        icon=badge.icon,
        category=badge.category,
        points=badge.points,
        requirement_type=badge.requirement_type,
        requirement_value=badge.requirement_value,
    )


# ── Badges ──


@router.get("/gamification/badges", response_model=list[BadgeResponse])
async def list_badges(
    category: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(STEMBadge).where(STEMBadge.is_published.is_(True))
    if category:
        stmt = stmt.where(STEMBadge.category == category)
    stmt = stmt.order_by(STEMBadge.category, STEMBadge.title)
    result = await db.execute(stmt)
    return [_badge_to_response(b) for b in result.scalars().all()]


@router.get("/gamification/badges/earned", response_model=list[EarnedBadgeResponse])
async def list_earned_badges(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMUserBadge, STEMBadge)
        .join(STEMBadge, STEMUserBadge.badge_id == STEMBadge.id)
        .where(STEMUserBadge.user_id == user.id)
        .order_by(STEMUserBadge.earned_at.desc())
    )
    return [
        EarnedBadgeResponse(
            id=badge.id,
            title=badge.title,
            description=badge.description,
            icon=badge.icon,
            category=badge.category,
            points=badge.points,
            requirement_type=badge.requirement_type,
            requirement_value=badge.requirement_value,
            earned_at=ub.earned_at,
        )
        for ub, badge in result.all()
    ]


# ── Leaderboard ──


@router.get("/gamification/leaderboard", response_model=list[LeaderboardEntryResponse])
async def global_leaderboard(
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMLeaderboardEntry, User)
        .join(User, STEMLeaderboardEntry.user_id == User.id)
        .order_by(desc(STEMLeaderboardEntry.total_points))
        .limit(20)
    )
    return [
        LeaderboardEntryResponse(
            rank=idx + 1,
            user_id=entry.user_id,
            display_name=user.full_name or f"User {entry.user_id}",
            total_points=entry.total_points,
            concepts_mastered=entry.concepts_mastered,
            challenges_completed=entry.challenges_completed,
            current_streak=entry.current_streak,
        )
        for idx, (entry, user) in enumerate(result.all())
    ]


@router.get(
    "/gamification/leaderboard/{subject_slug}",
    response_model=list[LeaderboardEntryResponse],
)
async def subject_leaderboard(
    subject_slug: str,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMLeaderboardEntry, User)
        .join(User, STEMLeaderboardEntry.user_id == User.id)
        .where(STEMLeaderboardEntry.subject_slug == subject_slug)
        .order_by(desc(STEMLeaderboardEntry.total_points))
        .limit(20)
    )
    return [
        LeaderboardEntryResponse(
            rank=idx + 1,
            user_id=entry.user_id,
            display_name=user.full_name or f"User {entry.user_id}",
            total_points=entry.total_points,
            concepts_mastered=entry.concepts_mastered,
            challenges_completed=entry.challenges_completed,
            current_streak=entry.current_streak,
        )
        for idx, (entry, user) in enumerate(result.all())
    ]


# ── Challenges ──


@router.get("/gamification/challenges", response_model=list[ChallengeResponse])
async def list_challenges(
    challenge_type: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(STEMChallenge).where(STEMChallenge.is_active.is_(True))
    if challenge_type:
        stmt = stmt.where(STEMChallenge.challenge_type == challenge_type)
    stmt = stmt.order_by(STEMChallenge.points_reward.desc())
    result = await db.execute(stmt)
    challenges = result.scalars().all()

    response: list[ChallengeResponse] = []
    for c in challenges:
        count_result = await db.execute(
            select(func.count(STEMChallengeParticipant.id)).where(STEMChallengeParticipant.challenge_id == c.id)
        )
        participants_count = count_result.scalar()
        response.append(
            ChallengeResponse(
                id=c.id,
                title=c.title,
                description=c.description,
                challenge_type=c.challenge_type,
                subject_slug=c.subject_slug,
                points_reward=c.points_reward,
                difficulty=c.difficulty,
                is_active=c.is_active,
                expires_at=c.expires_at,
                participants_count=participants_count,
            )
        )
    return response


@router.post("/gamification/challenges/{id}/join", response_model=ChallengeJoinResponse)
async def join_challenge(
    id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMChallenge).where(STEMChallenge.id == id, STEMChallenge.is_active.is_(True)))
    challenge = result.scalar_one_or_none()
    if not challenge:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Challenge not found or inactive",
        )

    existing = await db.execute(
        select(STEMChallengeParticipant).where(
            STEMChallengeParticipant.user_id == user.id,
            STEMChallengeParticipant.challenge_id == id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already joined this challenge",
        )

    participant = STEMChallengeParticipant(user_id=user.id, challenge_id=id)
    db.add(participant)
    await db.commit()
    await db.refresh(participant)

    return ChallengeJoinResponse(
        id=participant.id,
        challenge_id=participant.challenge_id,
        progress_pct=participant.progress_pct,
        is_completed=participant.is_completed,
        created_at=participant.created_at,
    )


@router.post(
    "/gamification/challenges/{id}/progress",
    response_model=ChallengeProgressResponse,
)
async def update_challenge_progress(
    id: int,
    progress_pct: float,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMChallengeParticipant).where(
            STEMChallengeParticipant.user_id == user.id,
            STEMChallengeParticipant.challenge_id == id,
        )
    )
    participant = result.scalar_one_or_none()
    if not participant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Not participating in this challenge",
        )

    participant.progress_pct = min(max(progress_pct, 0.0), 100.0)
    if participant.progress_pct >= 100.0:
        participant.is_completed = True
        participant.completed_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(participant)

    return ChallengeProgressResponse(
        id=participant.id,
        challenge_id=participant.challenge_id,
        progress_pct=participant.progress_pct,
        is_completed=participant.is_completed,
        completed_at=participant.completed_at,
    )


# ── Streak ──


@router.get("/gamification/streak", response_model=StreakResponse)
async def get_streak(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMLeaderboardEntry).where(STEMLeaderboardEntry.user_id == user.id))
    entry = result.scalar_one_or_none()

    last_activity: datetime | None = None
    if entry and entry.current_streak > 0:
        last_activity = entry.updated_at

    return StreakResponse(
        current_streak=entry.current_streak if entry else 0,
        longest_streak=entry.longest_streak if entry else 0,
        last_activity_date=last_activity,
    )


# ── Points ──


@router.get("/gamification/points", response_model=PointsResponse)
async def get_points(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    entry_result = await db.execute(select(STEMLeaderboardEntry).where(STEMLeaderboardEntry.user_id == user.id))
    entry = entry_result.scalar_one_or_none()

    badge_count_result = await db.execute(select(func.count(STEMUserBadge.id)).where(STEMUserBadge.user_id == user.id))
    badges_earned = badge_count_result.scalar()

    return PointsResponse(
        total_points=entry.total_points if entry else 0,
        breakdown=PointsBreakdown(
            concepts_mastered=entry.concepts_mastered if entry else 0,
            challenges_completed=entry.challenges_completed if entry else 0,
            badges_earned=badges_earned,
        ),
    )
