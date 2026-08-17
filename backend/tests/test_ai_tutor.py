from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

from tests.conftest import auth_header


@pytest.mark.asyncio
async def test_chat_creates_session(client: AsyncClient, student_user, student_token):
    with patch(
        "app.ai_tutor.router._call_llm",
        new_callable=AsyncMock,
        return_value="Hello! I can help you learn.",
    ):
        response = await client.post(
            "/api/v1/ai/chat",
            json={"message": "Hi ScholarAI", "agent_type": "tutor"},
            headers=auth_header(student_token),
        )
        assert response.status_code == 200
        data = response.json()
        assert data["role"] == "assistant"
        assert "Hello" in data["content"]


@pytest.mark.asyncio
async def test_chat_in_existing_session(
    client: AsyncClient, student_user, student_token
):
    with patch(
        "app.ai_tutor.router._call_llm",
        new_callable=AsyncMock,
        return_value="That's a great question.",
    ):
        resp1 = await client.post(
            "/api/v1/ai/chat",
            json={"message": "What is biology?", "agent_type": "tutor"},
            headers=auth_header(student_token),
        )
        session_id = resp1.json().get("session_id")

        resp2 = await client.post(
            "/api/v1/ai/chat",
            json={
                "message": "Tell me more",
                "session_id": session_id,
                "agent_type": "tutor",
            },
            headers=auth_header(student_token),
        )
        assert resp2.status_code == 200


@pytest.mark.asyncio
async def test_list_sessions(client: AsyncClient, student_user, student_token):
    response = await client.get(
        "/api/v1/ai/sessions", headers=auth_header(student_token)
    )
    assert response.status_code == 200
    assert isinstance(response.json(), list)


@pytest.mark.asyncio
async def test_generate_lesson_plan(client: AsyncClient, student_user, student_token):
    with patch(
        "app.ai_tutor.router._call_llm",
        new_callable=AsyncMock,
        return_value='{"objectives": ["Understand AMR"], "introduction": "AMR overview", "structure": [{"time_minutes": 30, "activity": "Lecture", "description": "Intro"}], "activities": ["Group work"], "case_study": "Hospital outbreak", "discussion_questions": ["What is AMR?"], "quiz": [{"question": "Define AMR", "options": [], "answer": "Antimicrobial resistance"}], "homework": "Read chapter 5", "references": ["WHO 2024"]}',
    ):
        response = await client.post(
            "/api/v1/ai/lesson-plan",
            json={
                "topic": "Antimicrobial Resistance",
                "level": "Year 3",
                "duration_minutes": 90,
            },
            headers=auth_header(student_token),
        )
        assert response.status_code == 200
        data = response.json()
        assert "objectives" in data
        assert "structure" in data


@pytest.mark.asyncio
async def test_generate_study_plan(client: AsyncClient, student_user, student_token):
    with patch(
        "app.ai_tutor.router._call_llm",
        new_callable=AsyncMock,
        return_value='{"schedule": [], "weak_topics": ["Microbiology"], "recommended_resources": ["WHO guidelines"]}',
    ):
        response = await client.post(
            "/api/v1/ai/study-plan",
            json={"course_id": 1, "hours_per_day": 3},
            headers=auth_header(student_token),
        )
        assert response.status_code == 200
        assert "schedule" in response.json()


@pytest.mark.asyncio
async def test_chat_unauthenticated(client: AsyncClient):
    response = await client.post(
        "/api/v1/ai/chat",
        json={"message": "Hello", "agent_type": "tutor"},
    )
    assert response.status_code == 403
