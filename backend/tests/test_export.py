import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.stem import (
    MasteryRecord,
    MockExamResult,
    STEMConcept,
    STEMDiscipline,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
)
from tests.conftest import auth_header


@pytest.fixture
async def export_setup(db_session: AsyncSession, student_user):
    subj = STEMSubject(title="Mathematics", subject_slug="mathematics")
    db_session.add(subj)
    await db_session.flush()

    disc = STEMDiscipline(
        title="Algebra", discipline_slug="algebra", subject_id=subj.id
    )
    db_session.add(disc)
    await db_session.flush()

    topic = STEMTopic(
        title="Linear Equations", discipline_id=disc.id, difficulty_level="intermediate"
    )
    db_session.add(topic)
    await db_session.flush()

    sub = STEMSubtopic(
        title="Systems of Equations", topic_id=topic.id, difficulty_level="intermediate"
    )
    db_session.add(sub)
    await db_session.flush()

    con = STEMConcept(
        title="Solving Systems", subtopic_id=sub.id, difficulty_level="intermediate"
    )
    db_session.add(con)
    await db_session.flush()

    mastery = MasteryRecord(
        user_id=student_user.id,
        concept_id=con.id,
        mastery_level=0.85,
        attempts=5,
        correct=4,
    )
    db_session.add(mastery)

    exam = MockExamResult(
        user_id=student_user.id,
        subject_slug="mathematics",
        total_questions=50,
        correct_count=45,
        total_marks=50,
        score_marks=45,
        percentage=90.0,
        time_taken_seconds=3600,
    )
    db_session.add(exam)
    await db_session.commit()

    return {"subject_id": subj.id, "concept_id": con.id}


@pytest.mark.asyncio
async def test_export_summary(client: AsyncClient, lecturer_token: str):
    resp = await client.get(
        "/api/v1/stem/export/summary",
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "total_students" in data
    assert "total_concepts" in data
    assert "avg_mastery" in data


@pytest.mark.asyncio
async def test_export_students_progress_json(
    client: AsyncClient, lecturer_token: str, export_setup
):
    resp = await client.get(
        "/api/v1/stem/export/students-progress?format=json",
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "students" in data
    assert len(data["students"]) >= 1


@pytest.mark.asyncio
async def test_export_students_progress_csv(
    client: AsyncClient, lecturer_token: str, export_setup
):
    resp = await client.get(
        "/api/v1/stem/export/students-progress?format=csv",
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "text/csv; charset=utf-8"
    content = resp.text
    assert "student_id" in content
    assert "concept_name" in content


@pytest.mark.asyncio
async def test_export_exam_results_csv(
    client: AsyncClient, lecturer_token: str, export_setup
):
    resp = await client.get(
        "/api/v1/stem/export/exam-results?format=csv",
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 200
    content = resp.text
    assert "student_id" in content
    assert "percentage" in content


@pytest.mark.asyncio
async def test_export_exam_results_json(
    client: AsyncClient, lecturer_token: str, export_setup
):
    resp = await client.get(
        "/api/v1/stem/export/exam-results?format=json",
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "exam_results" in data
    assert len(data["exam_results"]) >= 1


@pytest.mark.asyncio
async def test_export_mastery_summary(
    client: AsyncClient, lecturer_token: str, export_setup
):
    resp = await client.get(
        "/api/v1/stem/export/mastery-summary?format=json",
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "mastery_summary" in data
    assert len(data["mastery_summary"]) >= 1
    entry = data["mastery_summary"][0]
    assert "concept_name" in entry
    assert "avg_mastery" in entry


@pytest.mark.asyncio
async def test_export_mastery_summary_csv(
    client: AsyncClient, lecturer_token: str, export_setup
):
    resp = await client.get(
        "/api/v1/stem/export/mastery-summary?format=csv",
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 200
    content = resp.text
    assert "concept_id" in content
    assert "avg_mastery" in content


@pytest.mark.asyncio
async def test_student_cannot_export(client: AsyncClient, student_token: str):
    resp = await client.get(
        "/api/v1/stem/export/summary",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_student_cannot_export_progress(client: AsyncClient, student_token: str):
    resp = await client.get(
        "/api/v1/stem/export/students-progress",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_unauthenticated_cannot_export(client: AsyncClient):
    resp = await client.get("/api/v1/stem/export/summary")
    assert resp.status_code == 403
