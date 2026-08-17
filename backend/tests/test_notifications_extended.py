import pytest
from httpx import AsyncClient

from tests.conftest import auth_header


@pytest.mark.asyncio
async def test_list_notifications(client: AsyncClient, student_user, student_token):
    response = await client.get(
        "/api/v1/notifications/", headers=auth_header(student_token)
    )
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_unread_count(client: AsyncClient, student_user, student_token):
    response = await client.get(
        "/api/v1/notifications/unread-count", headers=auth_header(student_token)
    )
    assert response.status_code == 200
    assert "count" in response.json()


@pytest.mark.asyncio
async def test_mark_all_read(client: AsyncClient, student_user, student_token):
    response = await client.post(
        "/api/v1/notifications/mark-all-read", headers=auth_header(student_token)
    )
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_create_notification_admin(
    client: AsyncClient, admin_user, admin_token, student_user
):
    response = await client.post(
        "/api/v1/notifications/",
        json={
            "user_id": student_user.id,
            "title": "Test",
            "message": "Hello",
            "notif_type": "info",
        },
        headers=auth_header(admin_token),
    )
    assert response.status_code == 201


@pytest.mark.asyncio
async def test_create_notification_non_admin(
    client: AsyncClient, student_user, student_token, lecturer_user
):
    response = await client.post(
        "/api/v1/notifications/",
        json={
            "user_id": lecturer_user.id,
            "title": "Test",
            "message": "Hello",
            "notif_type": "info",
        },
        headers=auth_header(student_token),
    )
    assert response.status_code == 403
