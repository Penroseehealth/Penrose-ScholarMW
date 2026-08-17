from pydantic import BaseModel


class SmartNotification(BaseModel):
    id: int
    title: str
    message: str
    category: str
    priority: str = "normal"
    action_url: str | None = None
    created_at: str


class NotificationPreferencesResponse(BaseModel):
    assignment_reminders: bool = True
    study_nudges: bool = True
    grade_notifications: bool = True
    resource_uploads: bool = True
    weekly_summary: bool = True
    ai_suggestions: bool = True
    quiet_hours_start: str | None = None
    quiet_hours_end: str | None = None

    model_config = {"from_attributes": True}


class NotificationPreferencesUpdate(BaseModel):
    assignment_reminders: bool | None = None
    study_nudges: bool | None = None
    grade_notifications: bool | None = None
    resource_uploads: bool | None = None
    weekly_summary: bool | None = None
    ai_suggestions: bool | None = None
    quiet_hours_start: str | None = None
    quiet_hours_end: str | None = None
