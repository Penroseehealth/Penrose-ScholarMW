import csv
import io
from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload
from starlette.responses import StreamingResponse

from app.database.engine import get_db
from app.dependencies.auth import require_lecturer
from app.models.models import User
from app.models.stem import (
    MasteryRecord,
    MockExamResult,
    STEMConcept,
    STEMDiscipline,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])

CSV_MEDIATYPE = "text/csv"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _csv_response(
    rows: list[list[str]], headers: list[str], filename: str
) -> StreamingResponse:
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(headers)
    for row in rows:
        writer.writerow(row)
    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type=CSV_MEDIATYPE,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


def _fmt_dt(val: datetime | None) -> str:
    if val is None:
        return ""
    return val.isoformat()


# ---------------------------------------------------------------------------
# 1. GET /stem/export/students-progress
# ---------------------------------------------------------------------------


@router.get("/export/students-progress")
async def export_students_progress(
    fmt: str = Query("json", alias="format", pattern="^(csv|json)$"),
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_lecturer),
):
    result = await db.execute(
        select(MasteryRecord)
        .options(joinedload(MasteryRecord.concept))
        .order_by(MasteryRecord.user_id, MasteryRecord.concept_id)
    )
    records = list(result.unique().scalars().all())

    if not records:
        if fmt == "csv":
            return _csv_response(
                [],
                [
                    "student_id",
                    "student_name",
                    "email",
                    "concept_id",
                    "concept_name",
                    "mastery_level",
                    "attempts",
                    "correct",
                    "last_practiced",
                    "next_review",
                ],
                "students_progress.csv",
            )
        return {"students": []}

    user_ids = sorted({r.user_id for r in records})
    users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
    users_map = {u.id: u for u in users_result.scalars().all()}

    if fmt == "csv":
        headers = [
            "student_id",
            "student_name",
            "email",
            "concept_id",
            "concept_name",
            "mastery_level",
            "attempts",
            "correct",
            "last_practiced",
            "next_review",
        ]
        rows: list[list[str]] = []
        for r in records:
            u = users_map.get(r.user_id)
            concept_name = r.concept.title if r.concept else ""
            rows.append(
                [
                    str(r.user_id),
                    u.full_name if u else "",
                    u.email if u else "",
                    str(r.concept_id),
                    concept_name,
                    str(r.mastery_level),
                    str(r.attempts),
                    str(r.correct),
                    _fmt_dt(r.last_practiced),
                    _fmt_dt(r.next_review),
                ]
            )
        return _csv_response(rows, headers, "students_progress.csv")

    students: dict[int, dict] = {}
    for r in records:
        if r.user_id not in students:
            u = users_map.get(r.user_id)
            students[r.user_id] = {
                "id": r.user_id,
                "name": u.full_name if u else "",
                "email": u.email if u else "",
                "mastery_records": [],
            }
        students[r.user_id]["mastery_records"].append(
            {
                "concept_id": r.concept_id,
                "concept_name": r.concept.title if r.concept else "",
                "mastery_level": r.mastery_level,
                "attempts": r.attempts,
                "correct": r.correct,
                "last_practiced": _fmt_dt(r.last_practiced),
                "next_review": _fmt_dt(r.next_review),
            }
        )

    return {"students": list(students.values())}


# ---------------------------------------------------------------------------
# 2. GET /stem/export/exam-results
# ---------------------------------------------------------------------------


@router.get("/export/exam-results")
async def export_exam_results(
    fmt: str = Query("json", alias="format", pattern="^(csv|json)$"),
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_lecturer),
):
    result = await db.execute(
        select(MockExamResult).order_by(MockExamResult.created_at.desc())
    )
    exams = list(result.scalars().all())

    if not exams:
        if fmt == "csv":
            return _csv_response(
                [],
                [
                    "student_id",
                    "student_name",
                    "email",
                    "exam_id",
                    "subject_slug",
                    "score",
                    "total_questions",
                    "correct_answers",
                    "percentage",
                    "time_spent_seconds",
                    "completed_at",
                ],
                "exam_results.csv",
            )
        return {"exam_results": []}

    user_ids = sorted({e.user_id for e in exams})
    users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
    users_map = {u.id: u for u in users_result.scalars().all()}

    if fmt == "csv":
        headers = [
            "student_id",
            "student_name",
            "email",
            "exam_id",
            "subject_slug",
            "score",
            "total_questions",
            "correct_answers",
            "percentage",
            "time_spent_seconds",
            "completed_at",
        ]
        rows: list[list[str]] = []
        for e in exams:
            u = users_map.get(e.user_id)
            rows.append(
                [
                    str(e.user_id),
                    u.full_name if u else "",
                    u.email if u else "",
                    str(e.id),
                    e.subject_slug,
                    str(e.score_marks),
                    str(e.total_questions),
                    str(e.correct_count),
                    str(e.percentage),
                    str(e.time_taken_seconds),
                    _fmt_dt(e.created_at),
                ]
            )
        return _csv_response(rows, headers, "exam_results.csv")

    data = []
    for e in exams:
        u = users_map.get(e.user_id)
        data.append(
            {
                "student_id": e.user_id,
                "student_name": u.full_name if u else "",
                "email": u.email if u else "",
                "exam_id": e.id,
                "subject_slug": e.subject_slug,
                "score": e.score_marks,
                "total_questions": e.total_questions,
                "correct_answers": e.correct_count,
                "percentage": e.percentage,
                "time_spent_seconds": e.time_taken_seconds,
                "completed_at": _fmt_dt(e.created_at),
            }
        )
    return {"exam_results": data}


# ---------------------------------------------------------------------------
# 3. GET /stem/export/mastery-summary
# ---------------------------------------------------------------------------


@router.get("/export/mastery-summary")
async def export_mastery_summary(
    fmt: str = Query("json", alias="format", pattern="^(csv|json)$"),
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_lecturer),
):
    stats = await db.execute(
        select(
            MasteryRecord.concept_id,
            func.count(func.distinct(MasteryRecord.user_id)).label("total_students"),
            func.avg(MasteryRecord.mastery_level).label("avg_mastery"),
            func.min(MasteryRecord.mastery_level).label("min_mastery"),
            func.max(MasteryRecord.mastery_level).label("max_mastery"),
        ).group_by(MasteryRecord.concept_id)
    )
    concept_rows = stats.all()

    concepts_result = await db.execute(select(STEMConcept))
    concepts_map = {c.id: c for c in concepts_result.scalars().all()}

    total_students_per_concept = await db.execute(
        select(
            MasteryRecord.concept_id,
            func.count(func.distinct(MasteryRecord.user_id)),
        ).group_by(MasteryRecord.concept_id)
    )
    total_map = {row[0]: row[1] for row in total_students_per_concept.all()}

    mastered_counts = await db.execute(
        select(
            MasteryRecord.concept_id, func.count(func.distinct(MasteryRecord.user_id))
        )
        .where(MasteryRecord.mastery_level >= 0.8)
        .group_by(MasteryRecord.concept_id)
    )
    mastered_map = {row[0]: row[1] for row in mastered_counts.all()}

    in_progress_counts = await db.execute(
        select(
            MasteryRecord.concept_id, func.count(func.distinct(MasteryRecord.user_id))
        )
        .where(MasteryRecord.mastery_level > 0, MasteryRecord.mastery_level < 0.8)
        .group_by(MasteryRecord.concept_id)
    )
    in_progress_map = {row[0]: row[1] for row in in_progress_counts.all()}

    if fmt == "csv":
        headers = [
            "concept_id",
            "concept_name",
            "total_students",
            "avg_mastery",
            "min_mastery",
            "max_mastery",
            "students_mastered",
            "students_in_progress",
            "students_not_started",
        ]
        rows: list[list[str]] = []
        for row in concept_rows:
            concept = concepts_map.get(row.concept_id)
            concept_name = concept.title if concept else ""
            total = total_map.get(row.concept_id, 0)
            mastered = mastered_map.get(row.concept_id, 0)
            in_prog = in_progress_map.get(row.concept_id, 0)
            not_started = max(total - mastered - in_prog, 0)
            rows.append(
                [
                    str(row.concept_id),
                    concept_name,
                    str(total),
                    f"{float(row.avg_mastery):.2f}",
                    f"{float(row.min_mastery):.2f}",
                    f"{float(row.max_mastery):.2f}",
                    str(mastered),
                    str(in_prog),
                    str(not_started),
                ]
            )
        return _csv_response(rows, headers, "mastery_summary.csv")

    data = []
    for row in concept_rows:
        concept = concepts_map.get(row.concept_id)
        total = total_map.get(row.concept_id, 0)
        mastered = mastered_map.get(row.concept_id, 0)
        in_prog = in_progress_map.get(row.concept_id, 0)
        not_started = max(total - mastered - in_prog, 0)
        data.append(
            {
                "concept_id": row.concept_id,
                "concept_name": concept.title if concept else "",
                "total_students": total,
                "avg_mastery": round(float(row.avg_mastery), 2),
                "min_mastery": round(float(row.min_mastery), 2),
                "max_mastery": round(float(row.max_mastery), 2),
                "students_mastered": mastered,
                "students_in_progress": in_prog,
                "students_not_started": not_started,
            }
        )
    return {"mastery_summary": data}


# ---------------------------------------------------------------------------
# 4. GET /stem/export/subject-overview
# ---------------------------------------------------------------------------


@router.get("/export/subject-overview")
async def export_subject_overview(
    fmt: str = Query("json", alias="format", pattern="^(csv|json)$"),
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_lecturer),
):
    subjects_result = await db.execute(select(STEMSubject).order_by(STEMSubject.id))
    subjects = list(subjects_result.scalars().all())

    if not subjects:
        if fmt == "csv":
            return _csv_response(
                [],
                [
                    "subject_id",
                    "subject_name",
                    "total_concepts",
                    "avg_mastery",
                    "total_students",
                    "active_students",
                    "total_exams_taken",
                    "avg_exam_score",
                ],
                "subject_overview.csv",
            )
        return {"subject_overview": []}

    subtopics_result = await db.execute(select(STEMSubtopic))
    subtopics_map: dict[int, int] = {}
    for st in subtopics_result.scalars().all():
        subtopics_map[st.id] = st.topic_id

    topics_result = await db.execute(select(STEMTopic))
    topics_map: dict[int, int] = {}
    for t in topics_result.scalars().all():
        topics_map[t.id] = t.discipline_id

    disciplines_result = await db.execute(select(STEMDiscipline))
    disc_map: dict[int, int] = {}
    for d in disciplines_result.scalars().all():
        disc_map[d.id] = d.subject_id

    concept_result = await db.execute(select(STEMConcept))
    concept_subject_map: dict[int, int] = {}
    for c in concept_result.scalars().all():
        topic_id = subtopics_map.get(c.subtopic_id)
        if topic_id is not None:
            disc_id = topics_map.get(topic_id)
            if disc_id is not None:
                subj_id = disc_map.get(disc_id)
                if subj_id is not None:
                    concept_subject_map[c.id] = subj_id

    mastery_agg = await db.execute(
        select(
            MasteryRecord.concept_id,
            func.count(func.distinct(MasteryRecord.user_id)).label("student_count"),
            func.avg(MasteryRecord.mastery_level).label("avg_mastery"),
        ).group_by(MasteryRecord.concept_id)
    )
    concept_mastery_map: dict[int, tuple[int, float]] = {}
    for row in mastery_agg.all():
        concept_mastery_map[row.concept_id] = (
            row.student_count,
            float(row.avg_mastery),
        )

    exam_agg = await db.execute(
        select(
            MockExamResult.subject_slug,
            func.count(MockExamResult.id).label("total_exams"),
            func.avg(MockExamResult.percentage).label("avg_score"),
        ).group_by(MockExamResult.subject_slug)
    )
    exam_map: dict[str, tuple[int, float]] = {}
    for row in exam_agg.all():
        exam_map[row.subject_slug] = (
            row.total_exams,
            float(row.avg_score) if row.avg_score else 0.0,
        )

    data_rows: list[dict] = []
    for subj in subjects:
        concept_ids = [
            cid for cid, sid in concept_subject_map.items() if sid == subj.id
        ]
        total_concepts = len(concept_ids)

        all_students: set[int] = set()
        total_mastery_sum = 0.0
        mastery_count = 0
        for cid in concept_ids:
            info = concept_mastery_map.get(cid)
            if info:
                all_students.add(info[0])
                total_mastery_sum += info[1]
                mastery_count += 1

        total_students_count = 0
        for cid in concept_ids:
            info = concept_mastery_map.get(cid)
            if info:
                total_students_count += info[0]

        unique_active = set()
        for cid in concept_ids:
            info = concept_mastery_map.get(cid)
            if info:
                unique_active.add(info[0])

        avg_mastery = total_mastery_sum / mastery_count if mastery_count > 0 else 0.0

        exam_info = exam_map.get(subj.subject_slug, (0, 0.0))

        data_rows.append(
            {
                "subject_id": subj.id,
                "subject_name": subj.title,
                "total_concepts": total_concepts,
                "avg_mastery": round(avg_mastery, 2),
                "total_students": total_students_count,
                "active_students": total_students_count,
                "total_exams_taken": exam_info[0],
                "avg_exam_score": round(exam_info[1], 2),
            }
        )

    if fmt == "csv":
        headers = [
            "subject_id",
            "subject_name",
            "total_concepts",
            "avg_mastery",
            "total_students",
            "active_students",
            "total_exams_taken",
            "avg_exam_score",
        ]
        rows: list[list[str]] = []
        for d in data_rows:
            rows.append(
                [
                    str(d["subject_id"]),
                    d["subject_name"],
                    str(d["total_concepts"]),
                    str(d["avg_mastery"]),
                    str(d["total_students"]),
                    str(d["active_students"]),
                    str(d["total_exams_taken"]),
                    str(d["avg_exam_score"]),
                ]
            )
        return _csv_response(rows, headers, "subject_overview.csv")

    return {"subject_overview": data_rows}


# ---------------------------------------------------------------------------
# 5. GET /stem/export/student/{student_id}
# ---------------------------------------------------------------------------


@router.get("/export/student/{student_id}")
async def export_student_data(
    student_id: int,
    fmt: str = Query("json", alias="format", pattern="^(csv|json)$"),
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_lecturer),
):
    user_result = await db.execute(select(User).where(User.id == student_id))
    student = user_result.scalar_one_or_none()
    if student is None:
        return {"error": "Student not found"}

    mastery_result = await db.execute(
        select(MasteryRecord)
        .options(joinedload(MasteryRecord.concept))
        .where(MasteryRecord.user_id == student_id)
        .order_by(MasteryRecord.concept_id)
    )
    mastery_records = list(mastery_result.unique().scalars().all())

    exams_result = await db.execute(
        select(MockExamResult)
        .where(MockExamResult.user_id == student_id)
        .order_by(MockExamResult.created_at.desc())
    )
    exams = list(exams_result.scalars().all())

    if fmt == "csv":
        headers = [
            "type",
            "concept_id",
            "concept_name",
            "mastery_level",
            "attempts",
            "correct",
            "last_practiced",
            "next_review",
            "exam_id",
            "subject_slug",
            "score",
            "total_questions",
            "correct_answers",
            "percentage",
            "time_spent_seconds",
            "completed_at",
        ]
        rows: list[list[str]] = []
        for r in mastery_records:
            rows.append(
                [
                    "mastery",
                    str(r.concept_id),
                    r.concept.title if r.concept else "",
                    str(r.mastery_level),
                    str(r.attempts),
                    str(r.correct),
                    _fmt_dt(r.last_practiced),
                    _fmt_dt(r.next_review),
                    "",
                    "",
                    "",
                    "",
                    "",
                    "",
                    "",
                    "",
                ]
            )
        for e in exams:
            rows.append(
                [
                    "exam",
                    "",
                    "",
                    "",
                    "",
                    "",
                    "",
                    "",
                    str(e.id),
                    e.subject_slug,
                    str(e.score_marks),
                    str(e.total_questions),
                    str(e.correct_count),
                    str(e.percentage),
                    str(e.time_taken_seconds),
                    _fmt_dt(e.created_at),
                ]
            )
        return _csv_response(rows, headers, f"student_{student_id}_data.csv")

    return {
        "student": {
            "id": student.id,
            "name": student.full_name,
            "email": student.email,
        },
        "mastery_records": [
            {
                "concept_id": r.concept_id,
                "concept_name": r.concept.title if r.concept else "",
                "mastery_level": r.mastery_level,
                "attempts": r.attempts,
                "correct": r.correct,
                "last_practiced": _fmt_dt(r.last_practiced),
                "next_review": _fmt_dt(r.next_review),
            }
            for r in mastery_records
        ],
        "exam_results": [
            {
                "exam_id": e.id,
                "subject_slug": e.subject_slug,
                "score": e.score_marks,
                "total_questions": e.total_questions,
                "correct_answers": e.correct_count,
                "percentage": e.percentage,
                "time_spent_seconds": e.time_taken_seconds,
                "completed_at": _fmt_dt(e.created_at),
            }
            for e in exams
        ],
    }


# ---------------------------------------------------------------------------
# 6. GET /stem/export/summary
# ---------------------------------------------------------------------------


@router.get("/export/summary")
async def export_summary(
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_lecturer),
):
    total_students = (
        await db.execute(select(func.count(func.distinct(User.id))))
    ).scalar() or 0

    total_concepts = (
        await db.execute(select(func.count(STEMConcept.id)))
    ).scalar() or 0

    avg_mastery_result = await db.execute(select(func.avg(MasteryRecord.mastery_level)))
    avg_mastery = avg_mastery_result.scalar()
    avg_mastery_val = round(float(avg_mastery), 2) if avg_mastery is not None else 0.0

    total_exams = (
        await db.execute(select(func.count(MockExamResult.id)))
    ).scalar() or 0

    avg_exam_score_result = await db.execute(
        select(func.avg(MockExamResult.percentage))
    )
    avg_exam_score = avg_exam_score_result.scalar()
    avg_exam_score_val = (
        round(float(avg_exam_score), 2) if avg_exam_score is not None else 0.0
    )

    subjects_result = await db.execute(
        select(STEMSubject.id, STEMSubject.title, STEMSubject.subject_slug)
    )
    subjects = subjects_result.all()

    subtopics_result = await db.execute(select(STEMSubtopic))
    subtopics_map = {st.id: st.topic_id for st in subtopics_result.scalars().all()}

    topics_result = await db.execute(select(STEMTopic))
    topics_map = {t.id: t.discipline_id for t in topics_result.scalars().all()}

    disciplines_result = await db.execute(select(STEMDiscipline))
    disc_map = {d.id: d.subject_id for d in disciplines_result.scalars().all()}

    concept_result = await db.execute(select(STEMConcept))
    concept_subject_map: dict[int, int] = {}
    for c in concept_result.scalars().all():
        topic_id = subtopics_map.get(c.subtopic_id)
        if topic_id is not None:
            disc_id = topics_map.get(topic_id)
            if disc_id is not None:
                subj_id = disc_map.get(disc_id)
                if subj_id is not None:
                    concept_subject_map[c.id] = subj_id

    exam_agg = await db.execute(
        select(
            MockExamResult.subject_slug,
            func.count(MockExamResult.id).label("count"),
            func.avg(MockExamResult.percentage).label("avg_pct"),
        ).group_by(MockExamResult.subject_slug)
    )
    exam_by_subject = {
        row.subject_slug: (row.count, float(row.avg_pct) if row.avg_pct else 0.0)
        for row in exam_agg.all()
    }

    mastery_agg = await db.execute(
        select(
            MasteryRecord.concept_id,
            func.avg(MasteryRecord.mastery_level).label("avg"),
        ).group_by(MasteryRecord.concept_id)
    )
    concept_mastery_avg: dict[int, float] = {
        row.concept_id: float(row.avg) for row in mastery_agg.all()
    }

    top_subjects = []
    for subj in subjects:
        concept_ids = [
            cid for cid, sid in concept_subject_map.items() if sid == subj.id
        ]
        if not concept_ids:
            continue
        m_values = [
            concept_mastery_avg[cid]
            for cid in concept_ids
            if cid in concept_mastery_avg
        ]
        subj_avg = sum(m_values) / len(m_values) if m_values else 0.0
        exam_info = exam_by_subject.get(subj.subject_slug, (0, 0.0))
        top_subjects.append(
            {
                "subject_id": subj.id,
                "subject_name": subj.title,
                "subject_slug": subj.subject_slug,
                "avg_mastery": round(subj_avg, 2),
                "exams_taken": exam_info[0],
                "avg_exam_score": round(exam_info[1], 2),
            }
        )

    top_subjects.sort(key=lambda x: x["avg_mastery"], reverse=True)

    recent_exams_result = await db.execute(
        select(MockExamResult).order_by(MockExamResult.created_at.desc()).limit(10)
    )
    recent_exams = recent_exams_result.scalars().all()
    recent_user_ids = {e.user_id for e in recent_exams}
    recent_users_result = await db.execute(
        select(User).where(User.id.in_(recent_user_ids))
    )
    recent_users_map = {u.id: u for u in recent_users_result.scalars().all()}

    recent_activity = [
        {
            "student_id": e.user_id,
            "student_name": recent_users_map[e.user_id].full_name
            if e.user_id in recent_users_map
            else "",
            "subject_slug": e.subject_slug,
            "score": e.score_marks,
            "total_questions": e.total_questions,
            "percentage": e.percentage,
            "completed_at": _fmt_dt(e.created_at),
        }
        for e in recent_exams
    ]

    return {
        "total_students": total_students,
        "total_concepts": total_concepts,
        "avg_mastery": avg_mastery_val,
        "total_exams": total_exams,
        "avg_exam_score": avg_exam_score_val,
        "top_performing_subjects": top_subjects,
        "recent_activity": recent_activity,
    }
