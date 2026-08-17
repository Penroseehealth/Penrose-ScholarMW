import pytest
from httpx import AsyncClient

from tests.conftest import auth_header


@pytest.mark.asyncio
async def test_create_research_project(
    client: AsyncClient, student_user, student_token
):
    response = await client.post(
        "/api/v1/research/projects",
        json={
            "title": "Malaria in Malawi",
            "description": "Epidemiological study",
            "research_question": "What is the prevalence of malaria in rural Malawi?",
        },
        headers=auth_header(student_token),
    )
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "Malaria in Malawi"
    assert data["status"] == "draft"


@pytest.mark.asyncio
async def test_list_research_projects(client: AsyncClient, student_user, student_token):
    await client.post(
        "/api/v1/research/projects",
        json={"title": "Project 1"},
        headers=auth_header(student_token),
    )
    response = await client.get(
        "/api/v1/research/projects",
        headers=auth_header(student_token),
    )
    assert response.status_code == 200
    assert len(response.json()) >= 1


@pytest.mark.asyncio
async def test_create_research_note(client: AsyncClient, student_user, student_token):
    proj_resp = await client.post(
        "/api/v1/research/projects",
        json={"title": "Note Test Project"},
        headers=auth_header(student_token),
    )
    project_id = proj_resp.json()["id"]

    response = await client.post(
        f"/api/v1/research/projects/{project_id}/notes",
        json={
            "title": "Literature review notes",
            "content": "Key findings from WHO 2024 report...",
            "note_type": "literature",
        },
        headers=auth_header(student_token),
    )
    assert response.status_code == 201
    assert response.json()["note_type"] == "literature"


@pytest.mark.asyncio
async def test_list_research_notes(client: AsyncClient, student_user, student_token):
    proj_resp = await client.post(
        "/api/v1/research/projects",
        json={"title": "Notes Project"},
        headers=auth_header(student_token),
    )
    project_id = proj_resp.json()["id"]

    await client.post(
        f"/api/v1/research/projects/{project_id}/notes",
        json={"title": "Note 1", "content": "Content 1"},
        headers=auth_header(student_token),
    )

    response = await client.get(
        f"/api/v1/research/projects/{project_id}/notes",
        headers=auth_header(student_token),
    )
    assert response.status_code == 200
    assert len(response.json()) == 1


@pytest.mark.asyncio
async def test_literature_search(client: AsyncClient, student_user, student_token):
    response = await client.post(
        "/api/v1/research/literature-search",
        json={"query": "malaria Malawi", "max_results": 3},
        headers=auth_header(student_token),
    )
    assert response.status_code == 200
    assert isinstance(response.json(), list)


@pytest.mark.asyncio
async def test_get_research_project_not_found(
    client: AsyncClient, student_user, student_token
):
    response = await client.get(
        "/api/v1/research/projects/9999",
        headers=auth_header(student_token),
    )
    assert response.status_code == 404
