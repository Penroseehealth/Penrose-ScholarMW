import pytest
from httpx import AsyncClient

from tests.conftest import auth_header


@pytest.mark.asyncio
async def test_admin_dashboard_admin(client: AsyncClient, admin_user, admin_token):
    response = await client.get(
        "/api/v1/admin/dashboard", headers=auth_header(admin_token)
    )
    assert response.status_code == 200
    data = response.json()
    assert "total_users" in data
    assert "total_students" in data
    assert "total_lecturers" in data
    assert "total_courses" in data
    assert "total_enrollments" in data
    assert "total_submissions" in data


@pytest.mark.asyncio
async def test_admin_dashboard_non_admin(
    client: AsyncClient, student_user, student_token
):
    response = await client.get(
        "/api/v1/admin/dashboard", headers=auth_header(student_token)
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_admin_dashboard_unauthenticated(client: AsyncClient):
    # No credentials at all: FastAPI's HTTPBearer rejects before any route
    # dependency runs, the same 403 test_get_me_no_token documents.
    response = await client.get("/api/v1/admin/dashboard")
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_admin_list_users(client: AsyncClient, admin_user, admin_token):
    response = await client.get("/api/v1/admin/users", headers=auth_header(admin_token))
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    user_emails = [u["email"] for u in data]
    assert "admin@test.com" in user_emails


@pytest.mark.asyncio
async def test_admin_list_users_non_admin(
    client: AsyncClient, student_user, student_token
):
    response = await client.get(
        "/api/v1/admin/users", headers=auth_header(student_token)
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_admin_toggle_user_active(
    client: AsyncClient, admin_user, admin_token, student_user
):
    response = await client.put(
        f"/api/v1/admin/users/{student_user.id}/toggle-active",
        headers=auth_header(admin_token),
    )
    assert response.status_code == 200
    assert "deactivated" in response.json()["detail"]


@pytest.mark.asyncio
async def test_admin_toggle_user_active_non_admin(
    client: AsyncClient, student_user, student_token
):
    response = await client.put(
        f"/api/v1/admin/users/{student_user.id}/toggle-active",
        headers=auth_header(student_token),
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_admin_toggle_user_active_not_found(client: AsyncClient, admin_token):
    response = await client.put(
        "/api/v1/admin/users/99999/toggle-active",
        headers=auth_header(admin_token),
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_admin_change_user_role(
    client: AsyncClient, admin_user, admin_token, student_user
):
    response = await client.put(
        f"/api/v1/admin/users/{student_user.id}/role",
        json={"role": "lecturer"},
        headers=auth_header(admin_token),
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "lecturer"


@pytest.mark.asyncio
async def test_admin_change_user_role_invalid(
    client: AsyncClient, admin_user, admin_token, student_user
):
    response = await client.put(
        f"/api/v1/admin/users/{student_user.id}/role",
        json={"role": "superadmin"},
        headers=auth_header(admin_token),
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_admin_change_user_role_not_found(client: AsyncClient, admin_token):
    response = await client.put(
        "/api/v1/admin/users/99999/role",
        json={"role": "lecturer"},
        headers=auth_header(admin_token),
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_admin_list_courses(
    client: AsyncClient, admin_user, admin_token, lecturer_user, lecturer_token
):
    await client.post(
        "/api/v1/courses/",
        json={"code": "ADM101", "title": "Admin Test Course"},
        headers=auth_header(lecturer_token),
    )
    response = await client.get(
        "/api/v1/admin/courses", headers=auth_header(admin_token)
    )
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert any(c["code"] == "ADM101" for c in data)


@pytest.mark.asyncio
async def test_admin_toggle_course_active(
    client: AsyncClient, admin_user, admin_token, lecturer_user, lecturer_token
):
    create_resp = await client.post(
        "/api/v1/courses/",
        json={"code": "TOG101", "title": "Toggle Test"},
        headers=auth_header(lecturer_token),
    )
    course_id = create_resp.json()["id"]

    response = await client.put(
        f"/api/v1/admin/courses/{course_id}/toggle-active",
        headers=auth_header(admin_token),
    )
    assert response.status_code == 200
    data = response.json()
    assert data["is_active"] is False


@pytest.mark.asyncio
async def test_admin_toggle_course_active_not_found(client: AsyncClient, admin_token):
    response = await client.put(
        "/api/v1/admin/courses/99999/toggle-active",
        headers=auth_header(admin_token),
    )
    assert response.status_code == 404
