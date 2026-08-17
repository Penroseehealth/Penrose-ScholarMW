import pytest
from httpx import AsyncClient

from tests.conftest import auth_header


@pytest.mark.asyncio
async def test_register_success(client: AsyncClient):
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "new@test.com",
            "password": "TestPass1!",
            "full_name": "New User",
            "role": "student",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert data["user"]["email"] == "new@test.com"
    assert data["user"]["role"] == "student"


@pytest.mark.asyncio
async def test_register_duplicate_email(client: AsyncClient, student_user):
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "student@test.com",
            "password": "TestPass1!",
            "full_name": "Duplicate",
            "role": "student",
        },
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_login_success(client: AsyncClient, student_user):
    response = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "student@test.com",
            "password": "TestPass1!",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["user"]["full_name"] == "Test Student"


@pytest.mark.asyncio
async def test_login_wrong_password(client: AsyncClient, student_user):
    response = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "student@test.com",
            "password": "WrongPass1!",
        },
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_login_nonexistent_email(client: AsyncClient):
    response = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "nobody@test.com",
            "password": "TestPass1!",
        },
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_get_me(client: AsyncClient, student_user, student_token):
    response = await client.get("/api/v1/auth/me", headers=auth_header(student_token))
    assert response.status_code == 200
    assert response.json()["email"] == "student@test.com"


@pytest.mark.asyncio
async def test_get_me_no_token(client: AsyncClient):
    response = await client.get("/api/v1/auth/me")
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_update_me(client: AsyncClient, student_user, student_token):
    response = await client.put(
        "/api/v1/auth/me",
        json={"full_name": "Updated Name"},
        headers=auth_header(student_token),
    )
    assert response.status_code == 200
    assert response.json()["full_name"] == "Updated Name"


@pytest.mark.asyncio
async def test_change_password(client: AsyncClient, student_user, student_token):
    response = await client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "TestPass1!", "new_password": "NewPass2!"},
        headers=auth_header(student_token),
    )
    assert response.status_code == 200

    response = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "student@test.com",
            "password": "NewPass2!",
        },
    )
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_change_password_wrong_current(
    client: AsyncClient, student_user, student_token
):
    response = await client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "WrongPass!", "new_password": "NewPass2!"},
        headers=auth_header(student_token),
    )
    assert response.status_code == 400
