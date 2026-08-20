import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.stem import (
    STEMGroupMember,
    STEMGroupMessage,
    STEMStudyGroup,
)
from tests.conftest import auth_header


@pytest.fixture
async def collab_setup(db_session: AsyncSession, student_user, lecturer_user):
    group = STEMStudyGroup(
        name="Test Group",
        description="Collaboration test group",
        subject_slug="mathematics",
        creator_id=student_user.id,
    )
    db_session.add(group)
    await db_session.flush()

    member_student = STEMGroupMember(
        group_id=group.id,
        user_id=student_user.id,
        role="owner",
    )
    db_session.add(member_student)

    message = STEMGroupMessage(
        group_id=group.id,
        user_id=student_user.id,
        message="Hello",
    )
    db_session.add(message)
    await db_session.commit()

    return {
        "group_id": group.id,
        "message_id": message.id,
        "student_id": student_user.id,
        "lecturer_id": lecturer_user.id,
    }


@pytest.mark.asyncio
async def test_online_users_empty(client: AsyncClient, student_token: str):
    resp = await client.get(
        "/api/v1/stem/collaboration/online",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) == 0


@pytest.mark.asyncio
async def test_get_presence_for_group(
    client: AsyncClient, student_token: str, collab_setup
):
    resp = await client.get(
        f"/api/v1/stem/collaboration/presence/{collab_setup['group_id']}",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


@pytest.mark.asyncio
async def test_get_history_for_group(
    client: AsyncClient, student_token: str, collab_setup
):
    resp = await client.get(
        f"/api/v1/stem/collaboration/history/{collab_setup['group_id']}",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["message"] == "Hello"
    assert data[0]["sender_name"] == "Test Student"


@pytest.mark.asyncio
async def test_non_member_cannot_access_presence(
    client: AsyncClient, lecturer_token: str, collab_setup
):
    resp = await client.get(
        f"/api/v1/stem/collaboration/presence/{collab_setup['group_id']}",
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_non_member_cannot_access_history(
    client: AsyncClient, lecturer_token: str, collab_setup
):
    resp = await client.get(
        f"/api/v1/stem/collaboration/history/{collab_setup['group_id']}",
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_presence_requires_auth(client: AsyncClient, collab_setup):
    resp = await client.get(
        f"/api/v1/stem/collaboration/presence/{collab_setup['group_id']}"
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_history_requires_auth(client: AsyncClient, collab_setup):
    resp = await client.get(
        f"/api/v1/stem/collaboration/history/{collab_setup['group_id']}"
    )
    assert resp.status_code == 403
