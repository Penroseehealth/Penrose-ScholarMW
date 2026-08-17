from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import (
    Assessment,
    Enrollment,
    NotificationPreference,
    StudentPerformance,
    User,
    VaultDocument,
)

router = APIRouter(prefix="/smart-notifications", tags=["Smart Notifications"])


class NotificationPreferenceUpdate(BaseModel):
    assessment_reminders: bool | None = None
    study_nudges: bool | None = None
    resource_alerts: bool | None = None
    weekly_summary: bool | None = None
    ai_insights: bool | None = None
    quiet_hours_start: str | None = None
    quiet_hours_end: str | None = None


class GenerateRequest(BaseModel):
    context: str = "recent_activity"


async def _get_or_create_prefs(
    user_id: int, db: AsyncSession
) -> NotificationPreference:
    result = await db.execute(
        select(NotificationPreference).where(NotificationPreference.user_id == user_id)
    )
    prefs = result.scalar_one_or_none()
    if not prefs:
        prefs = NotificationPreference(user_id=user_id)
        db.add(prefs)
        await db.commit()
        await db.refresh(prefs)
    return prefs


async def _generate_dynamic_notifications(user: User, db: AsyncSession) -> list[dict]:
    notifications = []
    now = datetime.now(timezone.utc)

    enroll_result = await db.execute(
        select(Enrollment).where(
            Enrollment.student_id == user.id, Enrollment.is_active == True
        )
    )
    enrollments = enroll_result.scalars().all()
    enrolled_course_ids = [e.course_id for e in enrollments]

    if enrolled_course_ids:
        assessment_result = await db.execute(
            select(Assessment).where(
                Assessment.course_id.in_(enrolled_course_ids),
                Assessment.due_at != None,
                Assessment.due_at > now,
                Assessment.due_at < now + timedelta(hours=48),
            )
        )
        upcoming = assessment_result.scalars().all()
        for a in upcoming:
            hours_left = (a.due_at - now).total_seconds() / 3600
            notifications.append(
                {
                    "type": "assessment_reminder",
                    "title": f"Assessment Due Soon: {a.title}",
                    "message": f"Due in {int(hours_left)} hours. Don't forget to submit!",
                    "priority": "high" if hours_left < 12 else "medium",
                    "link": f"/assessments/{a.id}",
                }
            )

        perf_result = await db.execute(
            select(StudentPerformance).where(
                StudentPerformance.student_id == user.id,
                StudentPerformance.course_id.in_(enrolled_course_ids),
            )
        )
        for perf in perf_result.scalars().all():
            if perf.trend == "declining":
                notifications.append(
                    {
                        "type": "study_nudge",
                        "title": "Performance Alert",
                        "message": "Your performance is declining. Consider reviewing the material.",
                        "priority": "high",
                        "link": f"/analytics/student/{user.id}",
                    }
                )

    if enrolled_course_ids:
        vault_result = await db.execute(
            select(VaultDocument)
            .where(VaultDocument.course_id.in_(enrolled_course_ids))
            .order_by(VaultDocument.created_at.desc())
            .limit(5)
        )
        recent_docs = vault_result.scalars().all()
        if recent_docs:
            notifications.append(
                {
                    "type": "resource_alert",
                    "title": "New Course Materials Available",
                    "message": f"{len(recent_docs)} new document(s) uploaded to your courses.",
                    "priority": "low",
                    "link": "/vault",
                }
            )

    notifications.append(
        {
            "type": "weekly_summary",
            "title": "Weekly Progress Summary",
            "message": "Check your weekly learning progress and achievements.",
            "priority": "low",
            "link": "/analytics/weekly",
        }
    )

    return notifications


@router.get("/")
async def list_notifications(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    prefs = await _get_or_create_prefs(user.id, db)
    all_notifications = await _generate_dynamic_notifications(user, db)

    filtered = []
    for n in all_notifications:
        if n["type"] == "assessment_reminder" and prefs.assessment_reminders:
            filtered.append(n)
        elif n["type"] == "study_nudge" and prefs.study_nudges:
            filtered.append(n)
        elif n["type"] == "resource_alert" and prefs.resource_alerts:
            filtered.append(n)
        elif n["type"] == "weekly_summary" and prefs.weekly_summary:
            filtered.append(n)
        elif n["type"] == "ai_insight" and prefs.ai_insights:
            filtered.append(n)

    return {"notifications": filtered, "total": len(filtered)}


@router.get("/preferences")
async def get_preferences(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    prefs = await _get_or_create_prefs(user.id, db)
    return {
        "assessment_reminders": prefs.assessment_reminders,
        "study_nudges": prefs.study_nudges,
        "resource_alerts": prefs.resource_alerts,
        "weekly_summary": prefs.weekly_summary,
        "ai_insights": prefs.ai_insights,
        "quiet_hours_start": prefs.quiet_hours_start,
        "quiet_hours_end": prefs.quiet_hours_end,
    }


@router.put("/preferences")
async def update_preferences(
    body: NotificationPreferenceUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    prefs = await _get_or_create_prefs(user.id, db)
    update_data = body.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(prefs, key, value)
    await db.commit()
    await db.refresh(prefs)

    return {
        "assessment_reminders": prefs.assessment_reminders,
        "study_nudges": prefs.study_nudges,
        "resource_alerts": prefs.resource_alerts,
        "weekly_summary": prefs.weekly_summary,
        "ai_insights": prefs.ai_insights,
        "quiet_hours_start": prefs.quiet_hours_start,
        "quiet_hours_end": prefs.quiet_hours_end,
    }


@router.post("/generate")
async def generate_ai_notifications(
    body: GenerateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    enroll_result = await db.execute(
        select(Enrollment).where(
            Enrollment.student_id == user.id, Enrollment.is_active == True
        )
    )
    enrollments = enroll_result.scalars().all()
    course_ids = [e.course_id for e in enrollments]

    perf_result = await db.execute(
        select(StudentPerformance).where(StudentPerformance.student_id == user.id)
    )
    performances = perf_result.scalars().all()

    insights = []
    if performances:
        avg_score = sum(p.overall_score for p in performances) / len(performances)
        declining = [p for p in performances if p.trend == "declining"]
        if avg_score < 50:
            insights.append(
                {
                    "type": "performance_warning",
                    "message": f"Your average score is {avg_score:.0f}%. Consider seeking tutoring support.",
                }
            )
        if declining:
            insights.append(
                {
                    "type": "trend_alert",
                    "message": f"{len(declining)} course(s) show declining performance. Focus review on weak areas.",
                }
            )

    if enrollments:
        avg_progress = sum(e.progress_pct for e in enrollments) / len(enrollments)
        if avg_progress < 30:
            insights.append(
                {
                    "type": "progress_nudge",
                    "message": f"Your average course progress is {avg_progress:.0f}%. Try to keep up with materials.",
                }
            )

    if not insights:
        insights.append(
            {
                "type": "positive",
                "message": "You're doing well! Keep up the consistent effort.",
            }
        )

    return {"insights": insights, "course_count": len(course_ids)}
