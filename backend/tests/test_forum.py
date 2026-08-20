import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.stem import (
    STEMConcept,
    STEMDiscipline,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
)
from tests.conftest import auth_header


@pytest.fixture
async def stem_concept(db_session: AsyncSession):
    subj = STEMSubject(title="Mathematics", subject_slug="mathematics")
    db_session.add(subj)
    await db_session.flush()

    disc = STEMDiscipline(
        title="Algebra", discipline_slug="algebra", subject_id=subj.id
    )
    db_session.add(disc)
    await db_session.flush()

    topic = STEMTopic(
        title="Linear Equations",
        discipline_id=disc.id,
        difficulty_level="intermediate",
    )
    db_session.add(topic)
    await db_session.flush()

    sub = STEMSubtopic(
        title="Systems of Equations", topic_id=topic.id, difficulty_level="intermediate"
    )
    db_session.add(sub)
    await db_session.flush()

    con = STEMConcept(
        title="Solving Systems",
        subtopic_id=sub.id,
        difficulty_level="intermediate",
    )
    db_session.add(con)
    await db_session.commit()
    await db_session.refresh(con)
    return con


@pytest.mark.asyncio
async def test_create_forum_post(
    client: AsyncClient, student_token: str, stem_concept: STEMConcept
):
    resp = await client.post(
        "/api/v1/stem/forum/posts",
        json={
            "title": "How to solve systems?",
            "body": "I need help with elimination method.",
            "concept_id": stem_concept.id,
            "subject_slug": "mathematics",
        },
        headers=auth_header(student_token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "How to solve systems?"
    assert data["concept_id"] == stem_concept.id
    assert data["is_resolved"] is False


@pytest.mark.asyncio
async def test_list_forum_posts(
    client: AsyncClient, student_token: str, stem_concept: STEMConcept
):
    await client.post(
        "/api/v1/stem/forum/posts",
        json={"title": "Q1", "body": "body1", "concept_id": stem_concept.id},
        headers=auth_header(student_token),
    )
    resp = await client.get(
        "/api/v1/stem/forum/posts",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


@pytest.mark.asyncio
async def test_get_single_forum_post(
    client: AsyncClient, student_token: str, stem_concept: STEMConcept
):
    create_resp = await client.post(
        "/api/v1/stem/forum/posts",
        json={"title": "Single", "body": "content", "concept_id": stem_concept.id},
        headers=auth_header(student_token),
    )
    post_id = create_resp.json()["id"]

    resp = await client.get(
        f"/api/v1/stem/forum/posts/{post_id}",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == post_id
    assert data["view_count"] >= 1


@pytest.mark.asyncio
async def test_answer_forum_post(
    client: AsyncClient, student_token: str, stem_concept: STEMConcept
):
    create_resp = await client.post(
        "/api/v1/stem/forum/posts",
        json={"title": "Q2", "body": "body2", "concept_id": stem_concept.id},
        headers=auth_header(student_token),
    )
    post_id = create_resp.json()["id"]

    resp = await client.post(
        f"/api/v1/stem/forum/posts/{post_id}/answers",
        json={"body": "Use substitution."},
        headers=auth_header(student_token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["body"] == "Use substitution."
    assert data["post_id"] == post_id


@pytest.mark.asyncio
async def test_vote_on_post(
    client: AsyncClient, student_token: str, stem_concept: STEMConcept
):
    create_resp = await client.post(
        "/api/v1/stem/forum/posts",
        json={"title": "VoteTest", "body": "body", "concept_id": stem_concept.id},
        headers=auth_header(student_token),
    )
    post_id = create_resp.json()["id"]

    resp = await client.post(
        f"/api/v1/stem/forum/posts/{post_id}/vote",
        json={"value": 1},
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    assert resp.json()["upvotes"] == 1


@pytest.mark.asyncio
async def test_vote_on_answer(
    client: AsyncClient, student_token: str, stem_concept: STEMConcept
):
    post_resp = await client.post(
        "/api/v1/stem/forum/posts",
        json={"title": "QVote", "body": "b"},
        headers=auth_header(student_token),
    )
    post_id = post_resp.json()["id"]

    ans_resp = await client.post(
        f"/api/v1/stem/forum/posts/{post_id}/answers",
        json={"body": "Answer"},
        headers=auth_header(student_token),
    )
    answer_id = ans_resp.json()["id"]

    resp = await client.post(
        f"/api/v1/stem/forum/answers/{answer_id}/vote",
        json={"value": 1},
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    assert resp.json()["upvotes"] == 1


@pytest.mark.asyncio
async def test_accept_answer(
    client: AsyncClient, student_token: str, stem_concept: STEMConcept
):
    post_resp = await client.post(
        "/api/v1/stem/forum/posts",
        json={"title": "AcceptTest", "body": "b"},
        headers=auth_header(student_token),
    )
    post_id = post_resp.json()["id"]

    ans_resp = await client.post(
        f"/api/v1/stem/forum/posts/{post_id}/answers",
        json={"body": "Accepted answer"},
        headers=auth_header(student_token),
    )
    answer_id = ans_resp.json()["id"]

    resp = await client.post(
        f"/api/v1/stem/forum/answers/{answer_id}/accept",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_resolve_post(
    client: AsyncClient, student_token: str, stem_concept: STEMConcept
):
    post_resp = await client.post(
        "/api/v1/stem/forum/posts",
        json={"title": "ResolveTest", "body": "b"},
        headers=auth_header(student_token),
    )
    post_id = post_resp.json()["id"]

    resp = await client.post(
        f"/api/v1/stem/forum/posts/{post_id}/resolve",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200

    detail = await client.get(
        f"/api/v1/stem/forum/posts/{post_id}",
        headers=auth_header(student_token),
    )
    assert detail.json()["is_resolved"] is True


@pytest.mark.asyncio
async def test_forum_stats(
    client: AsyncClient, student_token: str, stem_concept: STEMConcept
):
    resp = await client.get(
        "/api/v1/stem/forum/stats",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "total_posts" in data
    assert "total_answers" in data


@pytest.mark.asyncio
async def test_create_announcement_as_lecturer(
    client: AsyncClient, lecturer_token: str
):
    resp = await client.post(
        "/api/v1/stem/announcements",
        json={
            "title": "Midterm Reminder",
            "body": "Midterm is next Monday.",
            "priority": "high",
        },
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "Midterm Reminder"
    assert data["priority"] == "high"


@pytest.mark.asyncio
async def test_student_cannot_create_announcement(
    client: AsyncClient, student_token: str
):
    resp = await client.post(
        "/api/v1/stem/announcements",
        json={"title": "X", "body": "Y"},
        headers=auth_header(student_token),
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_list_announcements_as_student(
    client: AsyncClient, lecturer_token: str, student_token: str
):
    await client.post(
        "/api/v1/stem/announcements",
        json={"title": "Ann1", "body": "Body1", "target_audience": "all"},
        headers=auth_header(lecturer_token),
    )
    resp = await client.get(
        "/api/v1/stem/announcements",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


@pytest.mark.asyncio
async def test_get_single_announcement(
    client: AsyncClient, lecturer_token: str, student_token: str
):
    create_resp = await client.post(
        "/api/v1/stem/announcements",
        json={"title": "Single", "body": "Body"},
        headers=auth_header(lecturer_token),
    )
    ann_id = create_resp.json()["id"]

    resp = await client.get(
        f"/api/v1/stem/announcements/{ann_id}",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    assert resp.json()["id"] == ann_id


@pytest.mark.asyncio
async def test_create_content_report(client: AsyncClient, student_token: str):
    resp = await client.post(
        "/api/v1/stem/reports",
        json={
            "content_type": "post",
            "content_id": 1,
            "reason": "spam",
            "description": "Looks like spam content.",
        },
        headers=auth_header(student_token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["content_type"] == "post"
    assert data["status"] == "pending"


@pytest.mark.asyncio
async def test_list_reports_as_admin(
    client: AsyncClient, student_token: str, admin_token: str
):
    await client.post(
        "/api/v1/stem/reports",
        json={"content_type": "post", "content_id": 1, "reason": "spam"},
        headers=auth_header(student_token),
    )
    resp = await client.get(
        "/api/v1/stem/reports",
        headers=auth_header(admin_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


@pytest.mark.asyncio
async def test_student_cannot_list_reports(client: AsyncClient, student_token: str):
    resp = await client.get(
        "/api/v1/stem/reports",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_review_report_as_admin(
    client: AsyncClient, student_token: str, admin_token: str
):
    create_resp = await client.post(
        "/api/v1/stem/reports",
        json={"content_type": "post", "content_id": 2, "reason": "inappropriate"},
        headers=auth_header(student_token),
    )
    report_id = create_resp.json()["id"]

    resp = await client.put(
        f"/api/v1/stem/reports/{report_id}/review",
        json={"status": "resolved", "note": "Content removed."},
        headers=auth_header(admin_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "resolved"
    assert data["reviewed_by"] is not None


@pytest.mark.asyncio
async def test_report_stats_as_admin(
    client: AsyncClient, student_token: str, admin_token: str
):
    await client.post(
        "/api/v1/stem/reports",
        json={"content_type": "post", "content_id": 10, "reason": "spam"},
        headers=auth_header(student_token),
    )
    resp = await client.get(
        "/api/v1/stem/reports/stats",
        headers=auth_header(admin_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "pending_count" in data
    assert "by_type" in data


@pytest.mark.asyncio
async def test_invalid_report_content_type(client: AsyncClient, student_token: str):
    resp = await client.post(
        "/api/v1/stem/reports",
        json={"content_type": "invalid_type", "content_id": 1, "reason": "spam"},
        headers=auth_header(student_token),
    )
    assert resp.status_code == 400
