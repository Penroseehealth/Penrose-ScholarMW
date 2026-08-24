from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    MasteryRecord,
    STEMConcept,
    STEMDiscipline,
    STEMStudyPlan,
    STEMStudyPlanItem,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class StudyPlanItemResponse(BaseModel):
    item_id: int
    concept_id: int
    title: str
    day_number: int
    priority: str
    estimated_minutes: int
    mastery_level: float
    is_completed: bool


class StudyPlanGenerateRequest(BaseModel):
    subject_slug: str
    daily_minutes: int = 60
    days_ahead: int = 14


class StudyPlanGenerateResponse(BaseModel):
    plan_id: int
    title: str
    subject_slug: str
    total_days: int
    total_concepts: int
    daily_minutes: int
    items: list[StudyPlanItemResponse]


class DailyStudyTask(BaseModel):
    item_id: int
    plan_id: int
    plan_title: str
    concept_id: int
    concept_title: str
    topic_title: str | None
    mastery_level: float
    is_completed: bool
    estimated_minutes: int
    priority: str


class StudyPlanSummaryItem(BaseModel):
    plan_id: int
    title: str
    subject_slug: str | None
    total_items: int
    completed_items: int
    progress_pct: float
    status: str
    created_at: datetime


class StudyPlanOverview(BaseModel):
    total_plans: int
    active_plans: int
    total_items: int
    completed_items: int
    overall_progress: float
    plans: list[StudyPlanSummaryItem]


@router.post(
    "/study-planner/generate",
    response_model=StudyPlanGenerateResponse,
)
async def generate_study_plan(
    req: StudyPlanGenerateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    subject_result = await db.execute(select(STEMSubject).where(STEMSubject.subject_slug == req.subject_slug))
    subject = subject_result.scalar_one_or_none()

    concept_result = await db.execute(
        select(
            STEMConcept.id.label("concept_id"),
            STEMConcept.title.label("concept_title"),
        )
        .join(STEMSubtopic, STEMSubtopic.id == STEMConcept.subtopic_id)
        .join(STEMTopic, STEMTopic.id == STEMSubtopic.topic_id)
        .join(STEMDiscipline, STEMDiscipline.id == STEMTopic.discipline_id)
        .where(STEMDiscipline.subject_id == subject.id)
    )
    all_concepts = concept_result.all()
    concept_ids = [c.concept_id for c in all_concepts]

    mastery_result = await db.execute(
        select(MasteryRecord).where(
            MasteryRecord.user_id == user.id,
            MasteryRecord.concept_id.in_(concept_ids),
        )
    )
    mastery_map = {r.concept_id: r for r in mastery_result.scalars().all()}

    PRIORITY_WEIGHTS = {"high": 3, "medium": 2, "review": 1}
    MINUTES_DEFAULT = 15
    MINUTES_HIGH = 20

    prioritized: list[dict] = []
    for c in all_concepts:
        record = mastery_map.get(c.concept_id)
        mastery = record.mastery_level if record else 0.0

        if mastery >= 0.9:
            continue
        elif mastery < 0.4:
            priority = "high"
        elif mastery < 0.7:
            priority = "medium"
        else:
            priority = "review"

        est = MINUTES_HIGH if priority == "high" else MINUTES_DEFAULT
        prioritized.append(
            {
                "concept_id": c.concept_id,
                "title": c.concept_title,
                "priority": priority,
                "weight": PRIORITY_WEIGHTS[priority],
                "mastery": mastery,
                "estimated_minutes": est,
            }
        )

    prioritized.sort(key=lambda x: (-x["weight"], x["mastery"]))

    days: list[list[dict]] = [[] for _ in range(req.days_ahead)]
    day_remaining = [req.daily_minutes] * req.days_ahead

    for item in prioritized:
        placed = False
        for d in range(req.days_ahead):
            if day_remaining[d] >= item["estimated_minutes"]:
                days[d].append(item)
                day_remaining[d] -= item["estimated_minutes"]
                placed = True
                break
        if not placed:
            for d in range(req.days_ahead):
                if days[d]:
                    days[d].append(item)
                    day_remaining[d] -= item["estimated_minutes"]
                    placed = True
                    break
        if not placed and days:
            days[0].append(item)

    now = datetime.now(timezone.utc)
    plan = STEMStudyPlan(
        user_id=user.id,
        title=f"Auto-generated {subject.title} Plan",
        subject_slug=req.subject_slug,
        target_date=now + timedelta(days=req.days_ahead),
        status="active",
    )
    db.add(plan)
    await db.flush()

    all_items: list[StudyPlanItemResponse] = []
    order = 0
    for day_idx, day_items in enumerate(days):
        for item in day_items:
            plan_item = STEMStudyPlanItem(
                plan_id=plan.id,
                concept_id=item["concept_id"],
                title=item["title"],
                order_index=day_idx,
                is_completed=False,
            )
            db.add(plan_item)
            await db.flush()
            all_items.append(
                StudyPlanItemResponse(
                    item_id=plan_item.id,
                    concept_id=item["concept_id"],
                    title=item["title"],
                    day_number=day_idx,
                    priority=item["priority"],
                    estimated_minutes=item["estimated_minutes"],
                    mastery_level=item["mastery"],
                    is_completed=False,
                )
            )
            order += 1

    total_days = max((i.day_number for i in all_items), default=0) + 1

    await db.commit()
    await db.refresh(plan)

    return StudyPlanGenerateResponse(
        plan_id=plan.id,
        title=plan.title,
        subject_slug=req.subject_slug,
        total_days=total_days,
        total_concepts=len(all_items),
        daily_minutes=req.daily_minutes,
        items=all_items,
    )


@router.get(
    "/study-planner/today",
    response_model=list[DailyStudyTask],
)
async def get_today_tasks(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plans_result = await db.execute(
        select(STEMStudyPlan).where(
            STEMStudyPlan.user_id == user.id,
            STEMStudyPlan.status == "active",
        )
    )
    active_plans = plans_result.scalars().all()

    today = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    tasks: list[DailyStudyTask] = []

    for plan in active_plans:
        plan_start = plan.created_at.replace(hour=0, minute=0, second=0, microsecond=0)
        if isinstance(plan_start, datetime) and plan_start.tzinfo:
            plan_start = plan_start.replace(tzinfo=None)
        day_offset = (today - plan_start).days

        items_result = await db.execute(
            select(STEMStudyPlanItem).where(
                STEMStudyPlanItem.plan_id == plan.id,
                STEMStudyPlanItem.order_index == day_offset,
            )
        )
        items = items_result.scalars().all()

        for item in items:
            mastery_result = await db.execute(
                select(MasteryRecord).where(
                    MasteryRecord.user_id == user.id,
                    MasteryRecord.concept_id == item.concept_id,
                )
            )
            record = mastery_result.scalar_one_or_none()
            mastery = record.mastery_level if record else 0.0

            concept_result = await db.execute(
                select(
                    STEMConcept.title.label("concept_title"),
                    STEMSubtopic.title.label("topic_title"),
                )
                .join(STEMSubtopic, STEMSubtopic.id == STEMConcept.subtopic_id)
                .where(STEMConcept.id == item.concept_id)
            )
            concept_row = concept_result.first()

            if mastery >= 0.9:
                priority = "review"
            elif mastery >= 0.7:
                priority = "medium"
            elif mastery >= 0.4:
                priority = "medium"
            else:
                priority = "high"

            est = 20 if priority == "high" else 15

            tasks.append(
                DailyStudyTask(
                    item_id=item.id,
                    plan_id=plan.id,
                    plan_title=plan.title,
                    concept_id=item.concept_id,
                    concept_title=concept_row.concept_title if concept_row else "Unknown",
                    topic_title=concept_row.topic_title if concept_row else None,
                    mastery_level=round(mastery, 4),
                    is_completed=item.is_completed,
                    estimated_minutes=est,
                    priority=priority,
                )
            )

    return tasks


@router.get(
    "/study-planner/overview",
    response_model=StudyPlanOverview,
)
async def get_overview(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plans_result = await db.execute(select(STEMStudyPlan).where(STEMStudyPlan.user_id == user.id))
    plans = plans_result.scalars().all()

    total_plans = len(plans)
    active_plans = sum(1 for p in plans if p.status == "active")

    total_items = 0
    completed_items = 0
    summary_items: list[StudyPlanSummaryItem] = []

    for plan in plans:
        counts_result = await db.execute(
            select(
                func.count(STEMStudyPlanItem.id).label("total"),
                func.count(func.nullif(STEMStudyPlanItem.is_completed, False)).label("completed"),
            ).where(STEMStudyPlanItem.plan_id == plan.id)
        )
        counts = counts_result.first()
        t = counts.total if counts else 0
        c = counts.completed if counts else 0
        progress = (c / t * 100) if t > 0 else 0.0

        total_items += t
        completed_items += c

        summary_items.append(
            StudyPlanSummaryItem(
                plan_id=plan.id,
                title=plan.title,
                subject_slug=plan.subject_slug,
                total_items=t,
                completed_items=c,
                progress_pct=round(progress, 2),
                status=plan.status,
                created_at=plan.created_at,
            )
        )

    overall_progress = (completed_items / total_items * 100) if total_items > 0 else 0.0

    return StudyPlanOverview(
        total_plans=total_plans,
        active_plans=active_plans,
        total_items=total_items,
        completed_items=completed_items,
        overall_progress=round(overall_progress, 2),
        plans=summary_items,
    )
