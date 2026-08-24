from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import Achievement, ScholarPoints, User, UserAchievement

router = APIRouter(prefix="/gamification", tags=["Gamification"])


class AwardRequest(BaseModel):
    action: str


ACTION_POINTS = {
    "complete_quiz": 10,
    "complete_course": 50,
    "study_streak": 5,
    "read_resource": 3,
    "submit_assignment": 15,
}


async def _get_or_create_points(user_id: int, db: AsyncSession) -> ScholarPoints:
    result = await db.execute(select(ScholarPoints).where(ScholarPoints.user_id == user_id))
    points = result.scalar_one_or_none()
    if not points:
        points = ScholarPoints(user_id=user_id)
        db.add(points)
        await db.commit()
        await db.refresh(points)
    return points


@router.get("/points")
async def get_points(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    points = await _get_or_create_points(user.id, db)
    return {
        "user_id": points.user_id,
        "total_earned": points.total_earned,
        "level": points.level,
        "streak_days": points.streak_days,
        "last_activity_date": (points.last_activity_date.isoformat() if points.last_activity_date else None),
    }


@router.post("/award")
async def award_points(
    body: AwardRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.action not in ACTION_POINTS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unknown action: {body.action}. Valid: {list(ACTION_POINTS.keys())}",
        )

    points = await _get_or_create_points(user.id, db)
    now = datetime.now(timezone.utc)
    amount = ACTION_POINTS[body.action]

    points.total_earned += amount
    points.level = (points.total_earned // 100) + 1

    if points.last_activity_date:
        last_date = points.last_activity_date.replace(hour=0, minute=0, second=0, microsecond=0)
        today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        delta = (today - last_date).days
        if delta == 1:
            points.streak_days += 1
        elif delta > 1:
            points.streak_days = 1
    else:
        points.streak_days = 1

    points.last_activity_date = now
    await db.commit()
    await db.refresh(points)

    return {
        "total_earned": points.total_earned,
        "level": points.level,
        "streak_days": points.streak_days,
        "awarded": amount,
        "action": body.action,
    }


@router.get("/achievements")
async def list_achievements(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Achievement))
    all_achievements = result.scalars().all()

    earned_result = await db.execute(select(UserAchievement).where(UserAchievement.user_id == user.id))
    earned_map = {ua.achievement_id: ua.earned_at for ua in earned_result.scalars().all()}

    return [
        {
            "id": a.id,
            "name": a.name,
            "description": a.description,
            "icon": a.icon,
            "category": a.category,
            "points_required": a.points_required,
            "earned": a.id in earned_map,
            "earned_at": earned_map[a.id].isoformat() if a.id in earned_map else None,
        }
        for a in all_achievements
    ]


@router.get("/leaderboard")
async def leaderboard(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ScholarPoints, User)
        .join(User, ScholarPoints.user_id == User.id)
        .order_by(desc(ScholarPoints.total_earned))
        .limit(20)
    )
    rows = result.all()

    return [
        {
            "rank": idx + 1,
            "user_id": sp.user_id,
            "display_name": u.full_name or f"User {sp.user_id}",
            "total_earned": sp.total_earned,
            "level": sp.level,
            "streak_days": sp.streak_days,
        }
        for idx, (sp, u) in enumerate(rows)
    ]


@router.post("/check-achievements")
async def check_achievements(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    points = await _get_or_create_points(user.id, db)

    earned_result = await db.execute(select(UserAchievement.achievement_id).where(UserAchievement.user_id == user.id))
    earned_ids = set(earned_result.scalars().all())

    all_achievements_result = await db.execute(select(Achievement))
    all_achievements = all_achievements_result.scalars().all()

    newly_earned = []
    for achievement in all_achievements:
        if achievement.id in earned_ids:
            continue
        if points.total_earned >= achievement.points_required:
            ua = UserAchievement(user_id=user.id, achievement_id=achievement.id)
            db.add(ua)
            newly_earned.append({"id": achievement.id, "name": achievement.name})

    if newly_earned:
        await db.commit()

    return {
        "newly_earned": newly_earned,
        "total_achievements_earned": len(earned_ids) + len(newly_earned),
    }
