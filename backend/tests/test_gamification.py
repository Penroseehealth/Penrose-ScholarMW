import pytest
from httpx import AsyncClient

from tests.conftest import auth_header


@pytest.mark.asyncio
async def test_get_points(client: AsyncClient, student_user, student_token):
    response = await client.get(
        "/api/v1/gamification/points", headers=auth_header(student_token)
    )
    assert response.status_code == 200
    data = response.json()
    assert "total_earned" in data
    assert "level" in data


@pytest.mark.asyncio
async def test_get_points_unauthenticated(client: AsyncClient):
    response = await client.get("/api/v1/gamification/points")
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_award_valid_action(client: AsyncClient, student_user, student_token):
    response = await client.post(
        "/api/v1/gamification/award",
        json={"action": "complete_quiz"},
        headers=auth_header(student_token),
    )
    assert response.status_code == 200
    data = response.json()
    assert data["awarded"] == 10


@pytest.mark.asyncio
async def test_award_invalid_action(client: AsyncClient, student_user, student_token):
    response = await client.post(
        "/api/v1/gamification/award",
        json={"action": "invalid_action"},
        headers=auth_header(student_token),
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_list_achievements(client: AsyncClient, student_user, student_token):
    response = await client.get(
        "/api/v1/gamification/achievements", headers=auth_header(student_token)
    )
    assert response.status_code == 200
    assert isinstance(response.json(), list)


@pytest.mark.asyncio
async def test_leaderboard(client: AsyncClient, student_user, student_token):
    response = await client.get(
        "/api/v1/gamification/leaderboard", headers=auth_header(student_token)
    )
    assert response.status_code == 200
    assert isinstance(response.json(), list)


@pytest.mark.asyncio
async def test_check_achievements(client: AsyncClient, student_user, student_token):
    response = await client.post(
        "/api/v1/gamification/check-achievements",
        headers=auth_header(student_token),
    )
    assert response.status_code == 200
    assert "newly_earned" in response.json()
