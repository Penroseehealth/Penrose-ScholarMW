import pytest
from httpx import AsyncClient

from tests.conftest import auth_header


@pytest.mark.asyncio
async def test_create_assessment(client: AsyncClient, lecturer_user, lecturer_token):
    course_resp = await client.post(
        "/api/v1/courses/",
        json={"code": "MED501", "title": "Pathology"},
        headers=auth_header(lecturer_token),
    )
    course_id = course_resp.json()["id"]

    response = await client.post(
        "/api/v1/assessments/",
        json={
            "course_id": course_id,
            "title": "Midterm Exam",
            "assessment_type": "exam",
            "total_marks": 100,
            "weight_pct": 30,
        },
        headers=auth_header(lecturer_token),
    )
    assert response.status_code == 201
    assert response.json()["title"] == "Midterm Exam"


@pytest.mark.asyncio
async def test_create_assessment_as_student_forbidden(
    client: AsyncClient, student_user, student_token
):
    response = await client.post(
        "/api/v1/assessments/",
        json={"course_id": 1, "title": "Test", "assessment_type": "quiz"},
        headers=auth_header(student_token),
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_add_question(client: AsyncClient, lecturer_user, lecturer_token):
    course_resp = await client.post(
        "/api/v1/courses/",
        json={"code": "BIO301", "title": "Biology Advanced"},
        headers=auth_header(lecturer_token),
    )
    course_id = course_resp.json()["id"]

    assess_resp = await client.post(
        "/api/v1/assessments/",
        json={"course_id": course_id, "title": "Quiz 1", "assessment_type": "quiz"},
        headers=auth_header(lecturer_token),
    )
    assessment_id = assess_resp.json()["id"]

    response = await client.post(
        f"/api/v1/assessments/{assessment_id}/questions",
        json={
            "question_text": "What is the powerhouse of the cell?",
            "question_type": "mcq",
            "marks": 2,
            "options": "A) Nucleus B) Mitochondria C) Ribosome D) Golgi",
            "correct_answer": "B) Mitochondria",
            "difficulty": "easy",
        },
        headers=auth_header(lecturer_token),
    )
    assert response.status_code == 201
    assert response.json()["question_type"] == "mcq"


@pytest.mark.asyncio
async def test_list_questions(client: AsyncClient, lecturer_user, lecturer_token):
    course_resp = await client.post(
        "/api/v1/courses/",
        json={"code": "PHY201", "title": "Physics 2"},
        headers=auth_header(lecturer_token),
    )
    course_id = course_resp.json()["id"]

    assess_resp = await client.post(
        "/api/v1/assessments/",
        json={"course_id": course_id, "title": "Final", "assessment_type": "exam"},
        headers=auth_header(lecturer_token),
    )
    assessment_id = assess_resp.json()["id"]

    await client.post(
        f"/api/v1/assessments/{assessment_id}/questions",
        json={"question_text": "Q1", "question_type": "short_answer", "marks": 5},
        headers=auth_header(lecturer_token),
    )

    response = await client.get(
        f"/api/v1/assessments/{assessment_id}/questions",
        headers=auth_header(lecturer_token),
    )
    assert response.status_code == 200
    assert len(response.json()) == 1


@pytest.mark.asyncio
async def test_submit_assessment(
    client: AsyncClient, student_user, lecturer_user, lecturer_token, student_token
):
    course_resp = await client.post(
        "/api/v1/courses/",
        json={"code": "CS102", "title": "CS Basics"},
        headers=auth_header(lecturer_token),
    )
    course_id = course_resp.json()["id"]

    assess_resp = await client.post(
        "/api/v1/assessments/",
        json={"course_id": course_id, "title": "HW1", "assessment_type": "homework"},
        headers=auth_header(lecturer_token),
    )
    assessment_id = assess_resp.json()["id"]

    response = await client.post(
        "/api/v1/assessments/submit",
        json={"assessment_id": assessment_id, "answers": "Answer 1; Answer 2"},
        headers=auth_header(student_token),
    )
    assert response.status_code == 201
    assert response.json()["status"] == "submitted"


@pytest.mark.asyncio
async def test_publish_assessment(client: AsyncClient, lecturer_user, lecturer_token):
    course_resp = await client.post(
        "/api/v1/courses/",
        json={"code": "ENG101", "title": "English"},
        headers=auth_header(lecturer_token),
    )
    course_id = course_resp.json()["id"]

    assess_resp = await client.post(
        "/api/v1/assessments/",
        json={"course_id": course_id, "title": "Essay", "assessment_type": "essay"},
        headers=auth_header(lecturer_token),
    )
    assessment_id = assess_resp.json()["id"]

    response = await client.post(
        f"/api/v1/assessments/{assessment_id}/publish",
        headers=auth_header(lecturer_token),
    )
    assert response.status_code == 200
