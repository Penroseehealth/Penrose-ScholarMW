import pytest
from httpx import AsyncClient

from tests.conftest import auth_header


@pytest.mark.asyncio
async def test_create_conversation(client: AsyncClient, student_user, student_token):
    response = await client.post(
        "/api/v1/messaging/conversations",
        json={"member_ids": [], "title": "Test Chat"},
        headers=auth_header(student_token),
    )
    assert response.status_code in (200, 201)


@pytest.mark.asyncio
async def test_list_conversations(client: AsyncClient, student_user, student_token):
    response = await client.get(
        "/api/v1/messaging/conversations", headers=auth_header(student_token)
    )
    assert response.status_code == 200
    assert isinstance(response.json(), list)


@pytest.mark.asyncio
async def test_list_conversations_unauthenticated(client: AsyncClient):
    response = await client.get("/api/v1/messaging/conversations")
    assert response.status_code == 403
