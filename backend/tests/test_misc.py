import pytest
from httpx import AsyncClient

from tests.conftest import auth_header


@pytest.mark.asyncio
async def test_admin_dashboard(client: AsyncClient, admin_user, admin_token):
    response = await client.get(
        "/api/v1/admin/dashboard",
        headers=auth_header(admin_token),
    )
    assert response.status_code == 200
    data = response.json()
    assert "total_users" in data
    assert "total_courses" in data


@pytest.mark.asyncio
async def test_admin_dashboard_forbidden_for_student(
    client: AsyncClient, student_user, student_token
):
    response = await client.get(
        "/api/v1/admin/dashboard",
        headers=auth_header(student_token),
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_admin_list_users(client: AsyncClient, admin_user, admin_token):
    response = await client.get(
        "/api/v1/admin/users",
        headers=auth_header(admin_token),
    )
    assert response.status_code == 200
    assert isinstance(response.json(), list)


@pytest.mark.asyncio
async def test_notifications_list(client: AsyncClient, student_user, student_token):
    response = await client.get(
        "/api/v1/notifications/",
        headers=auth_header(student_token),
    )
    assert response.status_code == 200
    assert isinstance(response.json(), list)


@pytest.mark.asyncio
async def test_notifications_unread_count(
    client: AsyncClient, student_user, student_token
):
    response = await client.get(
        "/api/v1/notifications/unread-count",
        headers=auth_header(student_token),
    )
    assert response.status_code == 200
    assert "count" in response.json()


@pytest.mark.asyncio
async def test_mark_all_read(client: AsyncClient, student_user, student_token):
    response = await client.post(
        "/api/v1/notifications/mark-all-read",
        headers=auth_header(student_token),
    )
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
