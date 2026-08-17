import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import Notification
from tests.conftest import auth_header


async def _seed_notification(
    db_session: AsyncSession, user_id: int, title: str = "Test", is_read: bool = False
) -> Notification:
    n = Notification(
        user_id=user_id,
        title=title,
        message="Test message",
        notif_type="info",
        is_read=is_read,
    )
    db_session.add(n)
    await db_session.commit()
    await db_session.refresh(n)
    return n


@pytest.mark.asyncio
async def test_list_notifications_authenticated(
    client: AsyncClient, student_user, student_token, db_session
):
    await _seed_notification(db_session, student_user.id, "Notif1")
    response = await client.get(
        "/api/v1/notifications/", headers=auth_header(student_token)
    )
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["title"] == "Notif1"


@pytest.mark.asyncio
async def test_list_notifications_unauthenticated(client: AsyncClient):
    response = await client.get("/api/v1/notifications/")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_unread_count(
    client: AsyncClient, student_user, student_token, db_session
):
    await _seed_notification(db_session, student_user.id, "Unread1", is_read=False)
    await _seed_notification(db_session, student_user.id, "Unread2", is_read=False)
    await _seed_notification(db_session, student_user.id, "Read1", is_read=True)

    response = await client.get(
        "/api/v1/notifications/unread-count", headers=auth_header(student_token)
    )
    assert response.status_code == 200
    data = response.json()
    assert data["count"] == 2


@pytest.mark.asyncio
async def test_unread_count_zero(
    client: AsyncClient, student_user, student_token, db_session
):
    await _seed_notification(db_session, student_user.id, "Read1", is_read=True)
    response = await client.get(
        "/api/v1/notifications/unread-count", headers=auth_header(student_token)
    )
    assert response.status_code == 200
    assert response.json()["count"] == 0


@pytest.mark.asyncio
async def test_mark_all_read(
    client: AsyncClient, student_user, student_token, db_session
):
    await _seed_notification(db_session, student_user.id, "Unread1")
    await _seed_notification(db_session, student_user.id, "Unread2")

    response = await client.post(
        "/api/v1/notifications/mark-all-read", headers=auth_header(student_token)
    )
    assert response.status_code == 200

    count_resp = await client.get(
        "/api/v1/notifications/unread-count", headers=auth_header(student_token)
    )
    assert count_resp.json()["count"] == 0


@pytest.mark.asyncio
async def test_mark_single_read(
    client: AsyncClient, student_user, student_token, db_session
):
    n = await _seed_notification(db_session, student_user.id, "ToRead")

    response = await client.put(
        f"/api/v1/notifications/{n.id}/read", headers=auth_header(student_token)
    )
    assert response.status_code == 200

    count_resp = await client.get(
        "/api/v1/notifications/unread-count", headers=auth_header(student_token)
    )
    assert count_resp.json()["count"] == 0


@pytest.mark.asyncio
async def test_mark_single_read_not_found(
    client: AsyncClient, student_user, student_token
):
    response = await client.put(
        "/api/v1/notifications/99999/read", headers=auth_header(student_token)
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_create_notification_as_admin(
    client: AsyncClient, admin_user, admin_token, student_user
):
    response = await client.post(
        "/api/v1/notifications/",
        json={
            "user_id": student_user.id,
            "title": "Admin Alert",
            "message": "Your account has been reviewed.",
            "notif_type": "alert",
        },
        headers=auth_header(admin_token),
    )
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "Admin Alert"


@pytest.mark.asyncio
async def test_create_notification_as_non_admin(
    client: AsyncClient, student_user, student_token, lecturer_user
):
    response = await client.post(
        "/api/v1/notifications/",
        json={
            "user_id": lecturer_user.id,
            "title": "Sneaky",
            "message": "This should fail",
            "notif_type": "info",
        },
        headers=auth_header(student_token),
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_create_notification_unauthenticated(client: AsyncClient):
    response = await client.post(
        "/api/v1/notifications/",
        json={
            "user_id": 1,
            "title": "X",
            "message": "Y",
            "notif_type": "info",
        },
    )
    assert response.status_code == 401
