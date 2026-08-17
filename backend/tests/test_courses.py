import pytest
from httpx import AsyncClient

from tests.conftest import auth_header


@pytest.mark.asyncio
async def test_create_course_as_lecturer(
    client: AsyncClient, lecturer_user, lecturer_token
):
    response = await client.post(
        "/api/v1/courses/",
        json={
            "code": "MED301",
            "title": "Medical Microbiology",
            "description": "Study of pathogenic microorganisms",
            "level": "Year 3",
            "credits": 4,
        },
        headers=auth_header(lecturer_token),
    )
    assert response.status_code == 201
    data = response.json()
    assert data["code"] == "MED301"
    assert data["title"] == "Medical Microbiology"
    assert data["lecturer_id"] == lecturer_user.id


@pytest.mark.asyncio
async def test_create_course_as_student_forbidden(
    client: AsyncClient, student_user, student_token
):
    response = await client.post(
        "/api/v1/courses/",
        json={"code": "CS101", "title": "Test Course"},
        headers=auth_header(student_token),
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_list_courses_student(client: AsyncClient, student_user, student_token):
    response = await client.get("/api/v1/courses/", headers=auth_header(student_token))
    assert response.status_code == 200
    assert isinstance(response.json(), list)


@pytest.mark.asyncio
async def test_enroll_in_course(
    client: AsyncClient, student_user, lecturer_user, lecturer_token, student_token
):
    create_resp = await client.post(
        "/api/v1/courses/",
        json={"code": "BIO201", "title": "Biology"},
        headers=auth_header(lecturer_token),
    )
    course_id = create_resp.json()["id"]

    response = await client.post(
        f"/api/v1/courses/{course_id}/enroll",
        headers=auth_header(student_token),
    )
    assert response.status_code in (200, 201)


@pytest.mark.asyncio
async def test_enroll_duplicate(
    client: AsyncClient, student_user, lecturer_user, lecturer_token, student_token
):
    create_resp = await client.post(
        "/api/v1/courses/",
        json={"code": "PHY101", "title": "Physics"},
        headers=auth_header(lecturer_token),
    )
    course_id = create_resp.json()["id"]

    await client.post(
        f"/api/v1/courses/{course_id}/enroll",
        headers=auth_header(student_token),
    )
    response = await client.post(
        f"/api/v1/courses/{course_id}/enroll",
        headers=auth_header(student_token),
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_get_course_detail(client: AsyncClient, lecturer_user, lecturer_token):
    create_resp = await client.post(
        "/api/v1/courses/",
        json={"code": "CHEM101", "title": "Chemistry"},
        headers=auth_header(lecturer_token),
    )
    course_id = create_resp.json()["id"]

    response = await client.get(
        f"/api/v1/courses/{course_id}", headers=auth_header(lecturer_token)
    )
    assert response.status_code == 200
    assert response.json()["code"] == "CHEM101"


@pytest.mark.asyncio
async def test_get_course_not_found(client: AsyncClient, student_token):
    response = await client.get(
        "/api/v1/courses/9999", headers=auth_header(student_token)
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_create_schedule_item(client: AsyncClient, lecturer_user, lecturer_token):
    create_resp = await client.post(
        "/api/v1/courses/",
        json={"code": "MED401", "title": "Advanced Med"},
        headers=auth_header(lecturer_token),
    )
    course_id = create_resp.json()["id"]

    response = await client.post(
        f"/api/v1/courses/{course_id}/schedule",
        json={
            "title": "Lecture 1",
            "item_type": "lecture",
            "starts_at": "2026-09-01T10:00:00Z",
            "ends_at": "2026-09-01T11:00:00Z",
            "location": "Room 101",
        },
        headers=auth_header(lecturer_token),
    )
    assert response.status_code == 201
    assert response.json()["title"] == "Lecture 1"
