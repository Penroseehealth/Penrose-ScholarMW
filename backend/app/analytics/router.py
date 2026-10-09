from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import (
    Assessment,
    Course,
    Enrollment,
    LearningPlan,
    LearningPlanItem,
    StudentPerformance,
    Submission,
    User,
)
from app.schemas.analytics import (
    LearningPlanCreate,
    LearningPlanItemCreate,
    LearningPlanItemResponse,
    LearningPlanResponse,
    LecturerAnalyticsResponse,
    StudentDashboardResponse,
    StudentPerformanceResponse,
)

router = APIRouter(prefix="/analytics", tags=["Learning Analytics"])


# ─── Student Dashboard & Performance ────────────────────────────────────────


@router.get("/student/dashboard", response_model=StudentDashboardResponse)
async def get_student_dashboard(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    enrollments_result = await db.execute(
        select(Enrollment).where(Enrollment.student_id == current_user.id)
    )
    enrollments = enrollments_result.scalars().all()

    overall_progress = 0.0
    if enrollments:
        progress_values = [e.progress_pct for e in enrollments]
        if progress_values:
            overall_progress = sum(progress_values) / len(progress_values)

    perf_result = await db.execute(
        select(StudentPerformance).where(
            StudentPerformance.student_id == current_user.id
        )
    )
    performances = perf_result.scalars().all()

    course_performances = []
    weak_areas: list[str] = []
    for p in performances:
        course_performances.append(
            {
                "course_id": p.course_id,
                "score": p.overall_score,
                "trend": p.trend,
            }
        )
        if p.weak_areas:
            weak_areas.append(p.weak_areas)

    now = datetime.now(timezone.utc)
    assessment_result = await db.execute(
        select(Assessment).where(
            Assessment.due_at > now, Assessment.is_published == True
        )
    )
    upcoming_raw = assessment_result.scalars().all()
    upcoming_assessments = [
        {
            "id": a.id,
            "title": a.title,
            "due_at": str(a.due_at),
            "course_id": a.course_id,
        }
        for a in upcoming_raw
    ]

    if overall_progress < 50:
        recommended_action = "You're making progress but have room to catch up. Try to complete more module activities this week."
    elif overall_progress >= 80:
        recommended_action = "Great performance across courses. Consider tackling advanced topics to deepen your understanding."
    else:
        recommended_action = "Keep up the consistent work. Review weak areas regularly and stay on schedule with your study plan."

    return StudentDashboardResponse(
        overall_progress=round(overall_progress, 2),
        course_performances=course_performances,
        weak_areas=weak_areas,
        recommended_action=recommended_action,
        upcoming_assessments=upcoming_assessments,
        weekly_plan=[],
    )


@router.get("/student/performance", response_model=List[StudentPerformanceResponse])
async def get_student_performance(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(StudentPerformance).where(
            StudentPerformance.student_id == current_user.id
        )
    )
    return [
        StudentPerformanceResponse.model_validate(p) for p in result.scalars().all()
    ]


@router.get(
    "/student/performance/{course_id}", response_model=StudentPerformanceResponse
)
async def get_student_performance_by_course(
    course_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(StudentPerformance).where(
            StudentPerformance.student_id == current_user.id,
            StudentPerformance.course_id == course_id,
        )
    )
    performance = result.scalars().first()
    if not performance:
        raise HTTPException(status_code=404, detail="No performance record found")
    return StudentPerformanceResponse.model_validate(performance)


# ─── Learning Plan (Personal AI Learning Coach) ────────────────────────────


@router.post("/learning-plan", response_model=LearningPlanResponse, status_code=201)
async def create_learning_plan(
    plan_data: LearningPlanCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plan = LearningPlan(
        student_id=current_user.id,
        title=plan_data.title,
        plan_type=plan_data.plan_type,
        start_date=datetime.fromisoformat(plan_data.start_date)
        if isinstance(plan_data.start_date, str)
        else plan_data.start_date,
        end_date=datetime.fromisoformat(plan_data.end_date)
        if isinstance(plan_data.end_date, str)
        else plan_data.end_date,
        ai_generated=False,
    )
    db.add(plan)
    await db.commit()
    await db.refresh(plan)
    return LearningPlanResponse.model_validate(plan)


@router.get("/learning-plans", response_model=List[LearningPlanResponse])
async def list_learning_plans(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(LearningPlan).where(
            LearningPlan.student_id == current_user.id,
            LearningPlan.is_active == True,
        )
    )
    return [LearningPlanResponse.model_validate(p) for p in result.scalars().all()]


@router.get("/learning-plans/{plan_id}", response_model=LearningPlanResponse)
async def get_learning_plan(
    plan_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(LearningPlan).where(
            LearningPlan.id == plan_id,
            LearningPlan.student_id == current_user.id,
        )
    )
    plan = result.scalars().first()
    if not plan:
        raise HTTPException(status_code=404, detail="Learning plan not found")

    items_result = await db.execute(
        select(LearningPlanItem).where(LearningPlanItem.plan_id == plan.id)
    )
    items = items_result.scalars().all()

    plan_response = LearningPlanResponse.model_validate(plan)
    plan_response.items = [LearningPlanItemResponse.model_validate(i) for i in items]
    return plan_response


@router.post(
    "/learning-plans/{plan_id}/items",
    response_model=LearningPlanItemResponse,
    status_code=201,
)
async def add_learning_plan_item(
    plan_id: int,
    item_data: LearningPlanItemCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plan_result = await db.execute(
        select(LearningPlan).where(
            LearningPlan.id == plan_id,
            LearningPlan.student_id == current_user.id,
        )
    )
    plan = plan_result.scalars().first()
    if not plan:
        raise HTTPException(status_code=404, detail="Learning plan not found")

    item = LearningPlanItem(
        plan_id=plan.id,
        day_of_week=item_data.day_of_week,
        course_id=item_data.course_id,
        topic=item_data.topic,
        activity_type=item_data.activity_type,
        duration_minutes=item_data.duration_minutes,
        order=item_data.order,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return LearningPlanItemResponse.model_validate(item)


@router.put("/learning-plans/{plan_id}/items/{item_id}/complete")
async def complete_learning_plan_item(
    plan_id: int,
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plan_result = await db.execute(
        select(LearningPlan).where(
            LearningPlan.id == plan_id,
            LearningPlan.student_id == current_user.id,
        )
    )
    plan = plan_result.scalars().first()
    if not plan:
        raise HTTPException(status_code=404, detail="Learning plan not found")

    item_result = await db.execute(
        select(LearningPlanItem).where(
            LearningPlanItem.id == item_id,
            LearningPlanItem.plan_id == plan_id,
        )
    )
    item = item_result.scalars().first()
    if not item:
        raise HTTPException(status_code=404, detail="Plan item not found")

    item.is_completed = True
    await db.commit()
    return {"detail": "Item marked as completed"}


class GeneratePlanRequest(BaseModel):
    course_id: int | None = None
    exam_date: str
    hours_per_day: float = 2.0


@router.post(
    "/learning-plans/generate", response_model=LearningPlanResponse, status_code=201
)
async def generate_study_plan(
    body: GeneratePlanRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    enrollments_result = await db.execute(
        select(Enrollment).where(
            Enrollment.student_id == current_user.id, Enrollment.is_active == True
        )
    )
    enrollments = enrollments_result.scalars().all()

    if not enrollments:
        raise HTTPException(status_code=400, detail="No enrolled courses found")

    exam_date = datetime.fromisoformat(body.exam_date)
    days_until_exam = (exam_date.date() - datetime.now(timezone.utc).date()).days
    if days_until_exam < 1:
        raise HTTPException(status_code=400, detail="Exam date must be in the future")

    plan = LearningPlan(
        student_id=current_user.id,
        title=f"Study Plan - Exam Prep ({exam_date.strftime('%b %d, %Y')})",
        plan_type="exam_prep",
        start_date=datetime.now(timezone.utc),
        end_date=min(exam_date, datetime.now(timezone.utc) + timedelta(days=7)),
        ai_generated=True,
    )
    db.add(plan)
    await db.flush()

    session_days = min(days_until_exam, 7)
    daily_minutes = int(body.hours_per_day * 60)
    courses_per_session = max(1, len(enrollments))
    minutes_per_course = daily_minutes // courses_per_session

    day_names = [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday",
    ]
    start_weekday = datetime.now(timezone.utc).weekday()

    items_created = []
    for day_offset in range(session_days):
        day_name = day_names[(start_weekday + day_offset) % 7]

        for enrollment in enrollments:
            course_result = await db.execute(
                select(Course).where(Course.id == enrollment.course_id)
            )
            course = course_result.scalars().first()
            course_title = course.title if course else f"Course {enrollment.course_id}"

            item = LearningPlanItem(
                plan_id=plan.id,
                day_of_week=day_name,
                course_id=enrollment.course_id,
                topic=course_title,
                activity_type="study",
                duration_minutes=minutes_per_course,
                order=day_offset * courses_per_session,
            )
            db.add(item)
            items_created.append(item)

    await db.commit()
    await db.refresh(plan)

    plan_response = LearningPlanResponse.model_validate(plan)
    plan_response.items = [
        LearningPlanItemResponse.model_validate(i) for i in items_created
    ]
    return plan_response


# ─── Lecturer Analytics ─────────────────────────────────────────────────────


@router.get("/lecturer/course/{course_id}", response_model=LecturerAnalyticsResponse)
async def get_lecturer_course_analytics(
    course_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    course_result = await db.execute(select(Course).where(Course.id == course_id))
    course = course_result.scalars().first()
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")

    enrolled_result = await db.execute(
        select(Enrollment).where(Enrollment.course_id == course_id)
    )
    enrollments = enrolled_result.scalars().all()
    total_students = len(enrollments)

    submission_result = await db.execute(
        select(Submission).join(Assessment).where(Assessment.course_id == course_id)
    )
    submissions = submission_result.scalars().all()

    class_average = 0.0
    students_at_risk_list: list[dict] = []
    difficult_topics: list[str] = []

    if submissions:
        scores = [s.final_marks for s in submissions if s.final_marks is not None]
        if scores:
            class_average = round(sum(scores) / len(scores), 2)
            risk_threshold = class_average * 0.6
            for s in submissions:
                if s.final_marks is not None and s.final_marks < risk_threshold:
                    students_at_risk_list.append(
                        {
                            "student_id": s.student_id,
                            "score": s.final_marks,
                        }
                    )

        assessment_result = await db.execute(
            select(Assessment).where(Assessment.course_id == course_id)
        )
        assessments = assessment_result.scalars().all()

        for assessment in assessments:
            a_subs = [s for s in submissions if s.assessment_id == assessment.id]
            if a_subs:
                a_scores = [s.final_marks for s in a_subs if s.final_marks is not None]
                if (
                    a_scores
                    and (sum(a_scores) / len(a_scores)) < (class_average or 50) * 0.75
                ):
                    if assessment.title:
                        difficult_topics.append(assessment.title)

    if total_students == 0:
        ai_insights = "No enrollment data available yet. Encourage students to enroll."
    elif not submissions:
        ai_insights = f"{total_students} student(s) enrolled but no submissions yet."
    elif class_average >= 70:
        ai_insights = (
            f"Class performance is strong (avg: {class_average}%). "
            f"{len(students_at_risk_list)} student(s) may need support."
        )
    else:
        ai_insights = (
            f"Class average is {class_average}%, below target. "
            f"{len(students_at_risk_list)} student(s) at risk. "
            f"Review: {', '.join(difficult_topics[:3]) if difficult_topics else 'general material'}."
        )

    return LecturerAnalyticsResponse(
        course_id=course_id,
        class_average=class_average,
        attendance_pct=0.0,
        assignment_completion=0.0,
        difficult_topics=difficult_topics,
        engagement_trend=None,
        ai_insights=ai_insights,
        students_at_risk=students_at_risk_list,
    )


@router.get("/lecturer/overview", response_model=List[LecturerAnalyticsResponse])
async def get_lecturer_overview(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    courses_result = await db.execute(
        select(Course).where(Course.lecturer_id == current_user.id)
    )
    courses = courses_result.scalars().all()
    if not courses:
        return []

    overviews: list[LecturerAnalyticsResponse] = []
    for course in courses:
        enrolled_result = await db.execute(
            select(Enrollment).where(Enrollment.course_id == course.id)
        )
        total_students = len(enrolled_result.scalars().all())

        submission_result = await db.execute(
            select(Submission).join(Assessment).where(Assessment.course_id == course.id)
        )
        submissions = submission_result.scalars().all()

        class_average = 0.0
        students_at_risk_list: list[dict] = []
        difficult_topics: list[str] = []

        if submissions:
            scores = [s.final_marks for s in submissions if s.final_marks is not None]
            if scores:
                class_average = round(sum(scores) / len(scores), 2)

        if not submissions:
            ai_insights = f"No submissions yet for '{course.title}'. {total_students} student(s) enrolled."
        elif class_average >= 70:
            ai_insights = f"Strong average of {class_average}%."
        else:
            ai_insights = f"Below-target average of {class_average}%."

        overviews.append(
            LecturerAnalyticsResponse(
                course_id=course.id,
                class_average=class_average,
                attendance_pct=0.0,
                assignment_completion=0.0,
                difficult_topics=difficult_topics,
                engagement_trend=None,
                ai_insights=ai_insights,
                students_at_risk=students_at_risk_list,
            )
        )

    return overviews
