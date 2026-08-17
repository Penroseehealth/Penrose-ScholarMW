from pydantic import BaseModel


class ScholarPointsResponse(BaseModel):
    id: int
    user_id: int
    points: int
    total_earned: int
    level: int
    streak_days: int
    longest_streak: int
    last_active_date: str | None = None

    model_config = {"from_attributes": True}


class AwardPointsRequest(BaseModel):
    action: str
    amount: int = 10


class AchievementResponse(BaseModel):
    id: int
    name: str
    description: str | None = None
    icon: str | None = None
    badge_color: str | None = None
    points_value: int
    category: str
    earned: bool = False
    earned_at: str | None = None
    progress: int = 0

    model_config = {"from_attributes": True}


class LeaderboardEntry(BaseModel):
    rank: int
    user_id: int
    display_name: str
    points: int
    level: int
    streak_days: int
