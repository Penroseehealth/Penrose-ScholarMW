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
async def stem_hierarchy(db_session: AsyncSession):
    subj = STEMSubject(
        title="Physics",
        subject_slug="physics",
        description="Study of matter.",
        icon="science",
        color="#3B82F6",
    )
    db_session.add(subj)
    await db_session.flush()

    disc = STEMDiscipline(
        title="Mechanics",
        discipline_slug="mechanics",
        subject_id=subj.id,
        description="Classical mechanics.",
        order_index=0,
    )
    db_session.add(disc)
    await db_session.flush()

    topic = STEMTopic(
        title="Forces",
        discipline_id=disc.id,
        difficulty_level="foundational",
        order_index=0,
        description="Newton's laws.",
    )
    db_session.add(topic)
    await db_session.flush()

    sub = STEMSubtopic(
        title="Newton's First Law",
        topic_id=topic.id,
        difficulty_level="foundational",
        order_index=0,
    )
    db_session.add(sub)
    await db_session.flush()

    con = STEMConcept(
        title="Law of Inertia",
        subtopic_id=sub.id,
        difficulty_level="foundational",
        order_index=0,
        description="An object at rest stays at rest.",
    )
    db_session.add(con)
    await db_session.commit()
    await db_session.refresh(con)

    return {
        "subject_id": subj.id,
        "discipline_id": disc.id,
        "topic_id": topic.id,
        "subtopic_id": sub.id,
        "concept_id": con.id,
    }


@pytest.mark.asyncio
async def test_list_subjects_cms(client: AsyncClient, stem_hierarchy: dict):
    resp = await client.get("/api/v1/stem/cms/subjects")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert any(s["subject_slug"] == "physics" for s in data)


@pytest.mark.asyncio
async def test_create_subject_as_lecturer(client: AsyncClient, lecturer_token: str):
    resp = await client.post(
        "/api/v1/stem/cms/subjects",
        json={"title": "Chemistry", "subject_slug": "chemistry"},
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "Chemistry"
    assert data["subject_slug"] == "chemistry"


@pytest.mark.asyncio
async def test_get_subject_by_id(client: AsyncClient, stem_hierarchy: dict):
    resp = await client.get(f"/api/v1/stem/cms/subjects/{stem_hierarchy['subject_id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "Physics"


@pytest.mark.asyncio
async def test_update_subject(
    client: AsyncClient, lecturer_token: str, stem_hierarchy: dict
):
    resp = await client.put(
        f"/api/v1/stem/cms/subjects/{stem_hierarchy['subject_id']}",
        json={"title": "Applied Physics", "description": "Updated."},
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "Applied Physics"
    assert data["description"] == "Updated."


@pytest.mark.asyncio
async def test_create_discipline(
    client: AsyncClient, lecturer_token: str, stem_hierarchy: dict
):
    resp = await client.post(
        f"/api/v1/stem/cms/subjects/{stem_hierarchy['subject_id']}/disciplines",
        json={"title": "Thermodynamics", "discipline_slug": "thermo"},
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "Thermodynamics"


@pytest.mark.asyncio
async def test_list_disciplines(client: AsyncClient, stem_hierarchy: dict):
    resp = await client.get(
        f"/api/v1/stem/cms/subjects/{stem_hierarchy['subject_id']}/disciplines"
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


@pytest.mark.asyncio
async def test_create_topic(
    client: AsyncClient, lecturer_token: str, stem_hierarchy: dict
):
    resp = await client.post(
        f"/api/v1/stem/cms/disciplines/{stem_hierarchy['discipline_id']}/topics",
        json={"title": "Dynamics", "difficulty_level": "intermediate"},
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "Dynamics"


@pytest.mark.asyncio
async def test_create_subtopic(
    client: AsyncClient, lecturer_token: str, stem_hierarchy: dict
):
    resp = await client.post(
        f"/api/v1/stem/cms/topics/{stem_hierarchy['topic_id']}/subtopics",
        json={"title": "Free Body Diagrams", "difficulty_level": "intermediate"},
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "Free Body Diagrams"


@pytest.mark.asyncio
async def test_create_concept(
    client: AsyncClient, lecturer_token: str, stem_hierarchy: dict
):
    resp = await client.post(
        f"/api/v1/stem/cms/subtopics/{stem_hierarchy['subtopic_id']}/concepts",
        json={
            "title": "Drawing FBD",
            "description": "Visualizing forces on objects.",
            "difficulty_level": "intermediate",
        },
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "Drawing FBD"


@pytest.mark.asyncio
async def test_create_material(
    client: AsyncClient, lecturer_token: str, stem_hierarchy: dict
):
    resp = await client.post(
        f"/api/v1/stem/cms/concepts/{stem_hierarchy['concept_id']}/materials",
        json={
            "title": "Inertia Guide",
            "content": "Inertia is the tendency of an object to resist changes in motion.",
            "material_type": "text",
        },
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "Inertia Guide"
    assert data["is_published"] is True


@pytest.mark.asyncio
async def test_create_practice(
    client: AsyncClient, lecturer_token: str, stem_hierarchy: dict
):
    resp = await client.post(
        f"/api/v1/stem/cms/concepts/{stem_hierarchy['concept_id']}/practices",
        json={
            "title": "Inertia MCQ",
            "question_text": "What is inertia?",
            "question_type": "mcq",
            "answer": "Resistance to change in motion",
            "difficulty": "easy",
        },
        headers=auth_header(lecturer_token),
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "Inertia MCQ"


@pytest.mark.asyncio
async def test_cms_stats(client: AsyncClient, stem_hierarchy: dict):
    resp = await client.get("/api/v1/stem/cms/stats")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total_subjects"] >= 1
    assert data["total_disciplines"] >= 1
    assert data["total_concepts"] >= 1


@pytest.mark.asyncio
async def test_student_cannot_create_subject(client: AsyncClient, student_token: str):
    resp = await client.post(
        "/api/v1/stem/cms/subjects",
        json={"title": "Biology", "subject_slug": "biology"},
        headers=auth_header(student_token),
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_student_cannot_create_material(
    client: AsyncClient, student_token: str, stem_hierarchy: dict
):
    resp = await client.post(
        f"/api/v1/stem/cms/concepts/{stem_hierarchy['concept_id']}/materials",
        json={"title": "X", "content": "Y"},
        headers=auth_header(student_token),
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_get_subject_not_found(client: AsyncClient):
    resp = await client.get("/api/v1/stem/cms/subjects/99999")
    assert resp.status_code == 404
