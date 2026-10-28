import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.stem import (
    STEMConcept,
    STEMDiscipline,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
    STEMUserCertificate,
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
async def test_log_proctor_event(client: AsyncClient, student_token: str):
    resp = await client.post(
        "/api/v1/stem/proctor/event",
        json={
            "exam_type": "mock",
            "exam_id": 1,
            "event_type": "tab_switch",
            "event_data": "User switched tab",
        },
        headers=auth_header(student_token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["exam_type"] == "mock"
    assert data["event_type"] == "tab_switch"


@pytest.mark.asyncio
async def test_get_proctor_events(client: AsyncClient, student_token: str):
    await client.post(
        "/api/v1/stem/proctor/event",
        json={"exam_type": "mock", "exam_id": 1, "event_type": "focus_lost"},
        headers=auth_header(student_token),
    )
    resp = await client.get(
        "/api/v1/stem/proctor/events/mock/1",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["event_type"] == "focus_lost"


@pytest.mark.asyncio
async def test_get_proctor_summary(client: AsyncClient, student_token: str):
    await client.post(
        "/api/v1/stem/proctor/event",
        json={"exam_type": "mock", "exam_id": 2, "event_type": "tab_switch"},
        headers=auth_header(student_token),
    )
    await client.post(
        "/api/v1/stem/proctor/event",
        json={"exam_type": "mock", "exam_id": 2, "event_type": "tab_switch"},
        headers=auth_header(student_token),
    )
    resp = await client.get(
        "/api/v1/stem/proctor/summary/mock/2",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["total_events"] == 2
    assert data["events_by_type"]["tab_switch"] == 2
    assert data["risk_score"] == 10
    assert data["risk_level"] == "low"


@pytest.mark.asyncio
async def test_proctor_risk_levels(client: AsyncClient, student_token: str):
    for _ in range(5):
        await client.post(
            "/api/v1/stem/proctor/event",
            json={"exam_type": "mock", "exam_id": 3, "event_type": "copy"},
            headers=auth_header(student_token),
        )
    resp = await client.get(
        "/api/v1/stem/proctor/summary/mock/3",
        headers=auth_header(student_token),
    )
    data = resp.json()
    assert data["risk_score"] == 50
    assert data["risk_level"] == "high"


@pytest.mark.asyncio
async def test_generate_certificate_invalid_type(
    client: AsyncClient, student_token: str
):
    resp = await client.post(
        "/api/v1/stem/certificates/generate",
        json={"certificate_type": "invalid_type"},
        headers=auth_header(student_token),
    )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_generate_subject_mastery_cert_no_mastery(
    client: AsyncClient, student_token: str, stem_concept
):
    # stem_concept seeds the Mathematics subject the handler resolves; with a
    # subject but zero mastery records the request must answer 400 (no mastery).
    resp = await client.post(
        "/api/v1/stem/certificates/generate",
        json={"certificate_type": "subject_mastery", "subject_slug": "mathematics"},
        headers=auth_header(student_token),
    )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_list_certificates_empty(client: AsyncClient, student_token: str):
    resp = await client.get(
        "/api/v1/stem/certificates",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) == 0


@pytest.mark.asyncio
async def test_generate_and_get_certificate(
    client: AsyncClient, student_token: str, student_user, stem_concept, db_session
):
    cert = STEMUserCertificate(
        user_id=student_user.id,
        certificate_type="subject_mastery",
        title="Subject Mastery: Mathematics",
        description="Mastered all concepts.",
        subject_slug="mathematics",
        score=95.0,
        certificate_data='{"subject": "Mathematics"}',
    )
    db_session.add(cert)
    await db_session.commit()
    await db_session.refresh(cert)
    cert_id = cert.id

    resp = await client.get(
        f"/api/v1/stem/certificates/{cert_id}",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["certificate_type"] == "subject_mastery"
    assert data["score"] == 95.0


@pytest.mark.asyncio
async def test_share_certificate(
    client: AsyncClient, student_token: str, student_user, db_session
):
    cert = STEMUserCertificate(
        user_id=student_user.id,
        certificate_type="subject_mastery",
        title="Subject Mastery: Mathematics",
        subject_slug="mathematics",
        score=92.5,
        certificate_data='{"subject": "Mathematics", "concepts_mastered": 10}',
    )
    db_session.add(cert)
    await db_session.commit()
    await db_session.refresh(cert)

    resp = await client.get(
        f"/api/v1/stem/certificates/{cert.id}/share",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["certificate_data"] is not None
    assert data["certificate_data"]["platform"] == "Penrose ScholarMW"


@pytest.mark.asyncio
async def test_get_certificate_not_found(client: AsyncClient, student_token: str):
    resp = await client.get(
        "/api/v1/stem/certificates/99999",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 404
