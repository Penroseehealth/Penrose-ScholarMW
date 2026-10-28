"""Tests for STEM API endpoints (Phases 1-5).

These tests verify the full STEM hierarchy: subjects -> disciplines ->
topics -> subtopics -> concepts -> materials/objectives/practices.

They also cover Phase 2 (knowledge graph, formulas, careers, labs,
assessment, mastery, AI tutor), Phase 3 (analytics, Malawi context,
revision), Phase 4 (gamification), and Phase 5 (study groups).
"""

from datetime import datetime, timezone

import pytest
from httpx import AsyncClient

from app.models.stem import (
    KnowledgeGraphEdge,
    MasteryRecord,
    STEMBadge,
    STEMCareerPath,
    STEMChallenge,
    STEMConcept,
    STEMCurriculumAlignment,
    STEMDiscipline,
    STEMFlashcard,
    STEMFormula,
    STEMGroupMember,
    STEMGroupMessage,
    STEMMalawiExample,
    STEMStudyGroup,
    STEMStudyPlan,
    STEMStudyPlanItem,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
    STLabActivity,
    STLearningMaterial,
    STLearningObjective,
    STPractice,
)
from tests.conftest import auth_header

# ── Fixtures that seed STEM data ──────────────────────────────────


@pytest.fixture
async def stem_setup(db_session):
    """Create a minimal STEM hierarchy for testing."""
    subj = STEMSubject(
        title="Mathematics",
        subject_slug="mathematics",
        description="Mathematical foundations.",
        icon="calculate",
        color="#8B5CF6",
    )
    db_session.add(subj)
    await db_session.flush()

    disc = STEMDiscipline(
        title="Algebra",
        discipline_slug="algebra",
        subject_id=subj.id,
        description="Study of algebraic structures.",
    )
    db_session.add(disc)
    await db_session.flush()

    topic = STEMTopic(
        title="Linear Equations",
        discipline_id=disc.id,
        difficulty_level="intermediate",
        order_index=0,
        description="Solving equations with one variable.",
    )
    db_session.add(topic)
    await db_session.flush()

    sub = STEMSubtopic(
        title="Solving Techniques",
        topic_id=topic.id,
        difficulty_level="intermediate",
        order_index=0,
    )
    db_session.add(sub)
    await db_session.flush()

    con = STEMConcept(
        title="Solving Linear Equations",
        subtopic_id=sub.id,
        description="Learn to isolate variables.",
        difficulty_level="intermediate",
        order_index=0,
    )
    db_session.add(con)
    await db_session.flush()

    mat = STLearningMaterial(
        title="Linear Equations Guide",
        content="A linear equation in one variable has exactly one solution.",
        material_type="text",
        concept_id=con.id,
    )
    db_session.add(mat)
    await db_session.flush()

    obj = STLearningObjective(
        title="Solve linear equations",
        description="Student can solve one-step and two-step equations.",
        bloom_level="apply",
        concept_id=con.id,
    )
    db_session.add(obj)
    await db_session.flush()

    prac = STPractice(
        title="Linear equation MCQ",
        question_text="What is x if 2x + 3 = 7?",
        question_type="mcq",
        options='{"options":["A) 1","B) 2","C) 3","D) 4"]}',
        answer="B",
        explanation="2x + 3 = 7 => 2x = 4 => x = 2.",
        difficulty="medium",
        marks=1,
        concept_id=con.id,
    )
    db_session.add(prac)
    await db_session.flush()

    # Second subject for traversal tests
    subj2 = STEMSubject(
        title="Physics",
        subject_slug="physics",
        description="Study of matter and energy.",
        icon="science",
        color="#3B82F6",
    )
    db_session.add(subj2)
    await db_session.flush()

    disc2 = STEMDiscipline(
        title="Mechanics",
        discipline_slug="mechanics",
        subject_id=subj2.id,
        description="Classical mechanics.",
    )
    db_session.add(disc2)
    await db_session.flush()

    await db_session.commit()
    yield {
        "subject_id": subj.id,
        "subject_slug": subj.subject_slug,
        "discipline_id": disc.id,
        "topic_id": topic.id,
        "subtopic_id": sub.id,
        "concept_id": con.id,
        "subject2_id": subj2.id,
        "subject2_slug": subj2.subject_slug,
        "discipline2_id": disc2.id,
    }


@pytest.fixture
async def stem_phase2(db_session, stem_setup):
    """Add Phase 2 data: knowledge graph edges, formulas, careers, labs."""
    cid = stem_setup["concept_id"]

    edge = KnowledgeGraphEdge(
        source_concept_id=cid,
        target_concept_id=cid,
        relationship_type="applied_in",
        weight=0.8,
        description="Related concept.",
    )
    db_session.add(edge)
    await db_session.flush()

    formula = STEMFormula(
        subject_slug="mathematics",
        title="Quadratic Formula",
        formula="x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}",
        description="Solves quadratic equations.",
        category="Algebra",
        variables='{"a":"coefficient of x^2","b":"coefficient of x","c":"constant"}',
        tags="algebra,equations",
    )
    db_session.add(formula)
    await db_session.flush()

    career = STEMCareerPath(
        subject_slug="mathematics",
        career_title="Data Scientist",
        description="Uses math and stats to analyze data.",
        required_subjects="Mathematics, Statistics",
        recommended_skills="Programming, Statistics",
        related_programmes="BSc Data Science",
        competencies="Analytical thinking",
        icon="work",
    )
    db_session.add(career)
    await db_session.flush()

    lab = STLabActivity(
        subject_slug="physics",
        title="Newton's Second Law Lab",
        description="Explore F = ma.",
        lab_type="virtual",
        instructions="Vary mass and measure acceleration.",
        materials_needed="Virtual cart, track",
        steps='["Step 1","Step 2","Step 3"]',
        expected_outcome="F is proportional to a.",
        difficulty="intermediate",
        duration_minutes=30,
    )
    db_session.add(lab)
    await db_session.flush()

    await db_session.commit()
    yield {
        "edge_id": edge.id,
        "formula_id": formula.id,
        "career_id": career.id,
        "lab_id": lab.id,
    }


@pytest.fixture
async def stem_phase3_5(db_session, stem_setup, student_user):
    """Add Phase 3-5 data: Malawi examples, badges, gamification, groups, revision."""
    cid = stem_setup["concept_id"]
    uid = student_user.id

    example = STEMMalawiExample(
        concept_id=cid,
        title="Market Trading Math",
        description="Using ratios in market calculations.",
        local_context="Lilongwe Old Market",
        region="Lilongwe",
        real_world_application="Calculate profit margins on maize sales.",
    )
    db_session.add(example)
    await db_session.flush()

    alignment = STEMCurriculumAlignment(
        concept_id=cid,
        curriculum_name="MSCE Mathematics",
        syllabus_code="MATH 402",
        form_level="Form 4",
        exam_board="MSCE",
        learning_outcome="Solve linear equations in one variable.",
    )
    db_session.add(alignment)
    await db_session.flush()

    badge = STEMBadge(
        title="Math Wizard",
        description="Master 10 math concepts.",
        icon="auto_awesome",
        category="subject",
        points=30,
    )
    db_session.add(badge)
    await db_session.flush()

    challenge = STEMChallenge(
        title="Daily Math Challenge",
        description="Solve 3 problems daily.",
        challenge_type="daily",
        points_reward=10,
        difficulty="medium",
        is_active=True,
    )
    db_session.add(challenge)
    await db_session.flush()

    group = STEMStudyGroup(
        name="Math Study Group",
        description="Study together for exams.",
        subject_slug="mathematics",
        creator_id=uid,
    )
    db_session.add(group)
    await db_session.flush()

    member = STEMGroupMember(
        group_id=group.id,
        user_id=uid,
        role="owner",
    )
    db_session.add(member)
    await db_session.flush()

    message = STEMGroupMessage(
        group_id=group.id,
        user_id=uid,
        message="Anyone studied linear equations?",
    )
    db_session.add(message)
    await db_session.flush()

    flashcard = STEMFlashcard(
        user_id=uid,
        concept_id=cid,
        front="What is a linear equation?",
        back="An equation with degree 1.",
        difficulty="medium",
        ease_factor=2.5,
        interval_days=1,
        review_count=0,
        is_active=True,
    )
    db_session.add(flashcard)
    await db_session.flush()

    plan = STEMStudyPlan(
        user_id=uid,
        title="Math Revision",
        description="Revise before exams.",
        subject_slug="mathematics",
        status="active",
        progress_pct=0.0,
    )
    db_session.add(plan)
    await db_session.flush()

    plan_item = STEMStudyPlanItem(
        plan_id=plan.id,
        concept_id=cid,
        title="Review Linear Equations",
        is_completed=False,
        order_index=0,
    )
    db_session.add(plan_item)
    await db_session.flush()

    mastery = MasteryRecord(
        user_id=uid,
        concept_id=cid,
        mastery_level=0.6,
        attempts=3,
        correct=2,
        last_practiced=datetime.now(timezone.utc),
        next_review=datetime.now(timezone.utc),
    )
    db_session.add(mastery)
    await db_session.flush()

    await db_session.commit()
    yield {
        "example_id": example.id,
        "alignment_id": alignment.id,
        "badge_id": badge.id,
        "challenge_id": challenge.id,
        "group_id": group.id,
        "member_id": member.id,
        "message_id": message.id,
        "flashcard_id": flashcard.id,
        "plan_id": plan.id,
        "plan_item_id": plan_item.id,
        "mastery_id": mastery.id,
    }


# ── Phase 1: Core STEM hierarchy ──────────────────────────────────


async def test_list_subjects(client: AsyncClient, stem_setup):
    """GET /stem/subjects returns all subjects."""
    resp = await client.get("/api/v1/stem/subjects")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert any(s["slug"] == "mathematics" for s in data)
    assert any(s["slug"] == "physics" for s in data)


async def test_get_subject_by_slug(client: AsyncClient, stem_setup):
    """GET /stem/subjects/{slug} returns a single subject."""
    resp = await client.get("/api/v1/stem/subjects/mathematics")
    assert resp.status_code == 200
    data = resp.json()
    assert data["slug"] == "mathematics"
    assert data["title"] == "Mathematics"


async def test_get_subject_not_found(client: AsyncClient):
    """GET /stem/subjects/{nonexistent} returns 404."""
    resp = await client.get("/api/v1/stem/subjects/nonexistent")
    assert resp.status_code == 404


async def test_list_disciplines_for_subject(client: AsyncClient, stem_setup):
    """GET /stem/subjects/{slug}/disciplines returns disciplines."""
    resp = await client.get("/api/v1/stem/subjects/mathematics/disciplines")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["slug"] == "algebra"


async def test_get_discipline(client: AsyncClient, stem_setup):
    """GET /stem/disciplines/{id} returns a discipline."""
    resp = await client.get(f"/api/v1/stem/disciplines/{stem_setup['discipline_id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "Algebra"


async def test_list_topics_for_discipline(client: AsyncClient, stem_setup):
    """GET /stem/disciplines/{id}/topics returns topics."""
    resp = await client.get(
        f"/api/v1/stem/disciplines/{stem_setup['discipline_id']}/topics"
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_get_topic(client: AsyncClient, stem_setup):
    """GET /stem/topics/{id} returns a topic."""
    resp = await client.get(f"/api/v1/stem/topics/{stem_setup['topic_id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "Linear Equations"


async def test_list_subtopics_for_topic(client: AsyncClient, stem_setup):
    """GET /stem/topics/{id}/subtopics returns subtopics."""
    resp = await client.get(f"/api/v1/stem/topics/{stem_setup['topic_id']}/subtopics")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_get_subtopic(client: AsyncClient, stem_setup):
    """GET /stem/subtopics/{id} returns a subtopic."""
    resp = await client.get(f"/api/v1/stem/subtopics/{stem_setup['subtopic_id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "Solving Techniques"


async def test_list_concepts_for_subtopic(client: AsyncClient, stem_setup):
    """GET /stem/subtopics/{id}/concepts returns concepts."""
    resp = await client.get(
        f"/api/v1/stem/subtopics/{stem_setup['subtopic_id']}/concepts"
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_get_concept(client: AsyncClient, stem_setup):
    """GET /stem/concepts/{id} returns a concept."""
    resp = await client.get(f"/api/v1/stem/concepts/{stem_setup['concept_id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "Solving Linear Equations"


async def test_get_concept_not_found(client: AsyncClient):
    """GET /stem/concepts/{nonexistent} returns 404."""
    resp = await client.get("/api/v1/stem/concepts/99999")
    assert resp.status_code == 404


async def test_list_objectives_for_concept(client: AsyncClient, stem_setup):
    """GET /stem/concepts/{id}/objectives returns objectives."""
    resp = await client.get(
        f"/api/v1/stem/concepts/{stem_setup['concept_id']}/objectives"
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["bloom_level"] == "apply"


async def test_list_materials_for_concept(client: AsyncClient, stem_setup):
    """GET /stem/concepts/{id}/materials returns materials."""
    resp = await client.get(
        f"/api/v1/stem/concepts/{stem_setup['concept_id']}/materials"
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_list_practices_for_concept(client: AsyncClient, stem_setup):
    """GET /stem/concepts/{id}/practices returns practices."""
    resp = await client.get(
        f"/api/v1/stem/concepts/{stem_setup['concept_id']}/practices"
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert "2x + 3 = 7" in data[0]["question_text"]


async def test_get_full_tree(client: AsyncClient, stem_setup):
    """GET /stem/tree returns full hierarchy."""
    resp = await client.get("/api/v1/stem/tree")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 2


async def test_get_subject_tree(client: AsyncClient, stem_setup):
    """GET /stem/tree/{slug} returns subject-specific tree."""
    resp = await client.get("/api/v1/stem/tree/mathematics")
    assert resp.status_code == 200
    data = resp.json()
    assert data["slug"] == "mathematics"


async def test_search(client: AsyncClient, stem_setup):
    """GET /stem/search?q=... returns matching items."""
    resp = await client.get("/api/v1/stem/search?q=Linear")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


async def test_search_empty_query(client: AsyncClient, stem_setup):
    """GET /stem/search with empty q returns empty or all."""
    resp = await client.get("/api/v1/stem/search?q=zzz_nonexistent")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


async def test_get_stats(client: AsyncClient, stem_setup, student_token):
    """GET /stem/stats returns statistics (authenticated since hardening)."""
    resp = await client.get("/api/v1/stem/stats", headers=auth_header(student_token))
    assert resp.status_code == 200
    data = resp.json()
    assert "total_concepts" in data
    assert data["total_concepts"] >= 1


# ── Phase 2: Knowledge graph, formulas, careers, labs ────────────


async def test_get_knowledge_graph(client: AsyncClient, stem_phase2, stem_setup):
    """GET /stem/knowledge-graph/subject/{slug} returns edges."""
    resp = await client.get("/api/v1/stem/knowledge-graph/subject/mathematics")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_list_formulas(client: AsyncClient, stem_phase2):
    """GET /stem/formulas returns formulas."""
    resp = await client.get("/api/v1/stem/formulas")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_get_formula_by_id(client: AsyncClient, stem_phase2):
    """GET /stem/formulas/{id} returns a formula."""
    resp = await client.get(f"/api/v1/stem/formulas/{stem_phase2['formula_id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "Quadratic Formula"


async def test_get_formula_not_found(client: AsyncClient):
    """GET /stem/formulas/{nonexistent} returns 404."""
    resp = await client.get("/api/v1/stem/formulas/99999")
    assert resp.status_code == 404


async def test_get_formula_categories(client: AsyncClient, stem_phase2):
    """GET /stem/formulas/categories/{subject_slug} returns categories."""
    resp = await client.get("/api/v1/stem/formulas/categories/mathematics")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert "Algebra" in [c["category"] for c in data]


async def test_list_careers(client: AsyncClient, stem_phase2):
    """GET /stem/careers returns careers."""
    resp = await client.get("/api/v1/stem/careers")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_get_career_by_id(client: AsyncClient, stem_phase2):
    """GET /stem/careers/{id} returns a career."""
    resp = await client.get(f"/api/v1/stem/careers/{stem_phase2['career_id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["career_title"] == "Data Scientist"


async def test_list_career_paths(client: AsyncClient, stem_phase2):
    """GET /stem/careers/subject/{slug} returns career paths."""
    resp = await client.get("/api/v1/stem/careers/subject/mathematics")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


async def test_list_labs(client: AsyncClient, stem_phase2):
    """GET /stem/labs returns labs."""
    resp = await client.get("/api/v1/stem/labs")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_get_lab_by_id(client: AsyncClient, stem_phase2):
    """GET /stem/labs/{id} returns a lab."""
    resp = await client.get(f"/api/v1/stem/labs/{stem_phase2['lab_id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "Newton's Second Law Lab"


# ── Phase 3A: Analytics ───────────────────────────────────────────


async def test_get_analytics_heatmap(
    client: AsyncClient, stem_phase3_5, student_token, stem_setup
):
    """GET /stem/analytics/heatmap requires auth."""
    resp = await client.get(
        "/api/v1/stem/analytics/heatmap",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


async def test_get_analytics_progress(
    client: AsyncClient, stem_phase3_5, student_token
):
    """GET /stem/analytics/progress requires auth."""
    resp = await client.get(
        "/api/v1/stem/analytics/progress",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200


async def test_get_analytics_summary(client: AsyncClient, stem_phase3_5, student_token):
    """GET /stem/analytics/study-summary returns study summary."""
    resp = await client.get(
        "/api/v1/stem/analytics/study-summary",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "total_minutes" in data


async def test_get_analytics_weakest(client: AsyncClient, stem_phase3_5, student_token):
    """GET /stem/analytics/weakest-concepts returns weakest concepts."""
    resp = await client.get(
        "/api/v1/stem/analytics/weakest-concepts",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


# ── Phase 3B: Malawi STEM Context ─────────────────────────────────


async def test_get_malawi_stats(client: AsyncClient, stem_phase3_5):
    """GET /stem/malawi/stats returns stats."""
    resp = await client.get("/api/v1/stem/malawi/stats")
    assert resp.status_code == 200
    data = resp.json()
    assert "total_examples" in data
    assert data["total_examples"] >= 1


async def test_get_malawi_examples(client: AsyncClient, stem_phase3_5):
    """GET /stem/malawi/examples returns examples."""
    resp = await client.get("/api/v1/stem/malawi/examples")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_get_malawi_curriculum(client: AsyncClient, stem_phase3_5):
    """GET /stem/malawi/curriculum returns alignments."""
    resp = await client.get("/api/v1/stem/malawi/curriculum")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


# ── Phase 3C: Revision Tools ──────────────────────────────────────


async def test_get_due_flashcards(
    client: AsyncClient, stem_phase3_5, student_token, stem_setup
):
    """GET /stem/revision/flashcards/due requires auth."""
    resp = await client.get(
        "/api/v1/stem/revision/flashcards/due",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


async def test_get_flashcards(client: AsyncClient, stem_phase3_5, student_token):
    """GET /stem/revision/flashcards requires auth."""
    resp = await client.get(
        "/api/v1/stem/revision/flashcards",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


async def test_create_flashcard(
    client: AsyncClient, stem_phase3_5, student_token, stem_setup
):
    """POST /stem/revision/flashcards requires auth."""
    resp = await client.post(
        "/api/v1/stem/revision/flashcards",
        json={
            "concept_id": stem_setup["concept_id"],
            "front": "Front text",
            "back": "Back text",
        },
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200 or resp.status_code == 201
    data = resp.json()
    assert "id" in data


async def test_get_study_plans(client: AsyncClient, stem_phase3_5, student_token):
    """GET /stem/revision/plans requires auth."""
    resp = await client.get(
        "/api/v1/stem/revision/plans",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


async def test_create_study_plan(client: AsyncClient, stem_phase3_5, student_token):
    """POST /stem/revision/plans requires auth."""
    resp = await client.post(
        "/api/v1/stem/revision/plans",
        json={"title": "New Plan", "subject_slug": "mathematics"},
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200 or resp.status_code == 201


# ── Phase 4: Gamification ─────────────────────────────────────────


async def test_list_badges(client: AsyncClient, stem_phase3_5):
    """GET /stem/gamification/badges returns badges."""
    resp = await client.get("/api/v1/stem/gamification/badges")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_list_challenges(client: AsyncClient, stem_phase3_5):
    """GET /stem/gamification/challenges returns challenges."""
    resp = await client.get("/api/v1/stem/gamification/challenges")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_get_leaderboard(client: AsyncClient, stem_phase3_5):
    """GET /stem/gamification/leaderboard returns entries."""
    resp = await client.get("/api/v1/stem/gamification/leaderboard")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


async def test_get_streak(client: AsyncClient, stem_phase3_5, student_token):
    """GET /stem/gamification/streak requires auth."""
    resp = await client.get(
        "/api/v1/stem/gamification/streak",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200


async def test_get_points(client: AsyncClient, stem_phase3_5, student_token):
    """GET /stem/gamification/points requires auth."""
    resp = await client.get(
        "/api/v1/stem/gamification/points",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200


async def test_join_challenge(
    client: AsyncClient, stem_phase3_5, student_token, student_user
):
    """POST /stem/gamification/challenges/{id}/join requires auth."""
    resp = await client.post(
        f"/api/v1/stem/gamification/challenges/{stem_phase3_5['challenge_id']}/join",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200


# ── Phase 5: Study Groups ─────────────────────────────────────────


async def test_list_groups(client: AsyncClient, stem_phase3_5):
    """GET /stem/groups returns all groups."""
    resp = await client.get("/api/v1/stem/groups")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


async def test_get_my_groups(
    client: AsyncClient, stem_phase3_5, student_token, student_user
):
    """GET /stem/groups/mine requires auth."""
    resp = await client.get(
        "/api/v1/stem/groups/mine",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200


async def test_get_group_detail(client: AsyncClient, stem_phase3_5):
    """GET /stem/groups/{id} returns group detail."""
    resp = await client.get(f"/api/v1/stem/groups/{stem_phase3_5['group_id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "Math Study Group"


async def test_create_group(client: AsyncClient, stem_phase3_5, student_token):
    """POST /stem/groups requires auth."""
    resp = await client.post(
        "/api/v1/stem/groups",
        json={"name": "New Group", "subject_slug": "mathematics"},
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200 or resp.status_code == 201


async def test_get_group_messages(client: AsyncClient, stem_phase3_5, student_token):
    """GET /stem/groups/{id}/messages requires auth."""
    resp = await client.get(
        f"/api/v1/stem/groups/{stem_phase3_5['group_id']}/messages",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


# ── Auth & error tests ────────────────────────────────────────────


async def test_mastery_me_requires_auth(client: AsyncClient):
    """GET /stem/mastery/me without auth returns 403."""
    resp = await client.get("/api/v1/stem/mastery/me")
    assert resp.status_code == 403


async def test_mastery_me_with_auth(client: AsyncClient, stem_phase3_5, student_token):
    """GET /stem/mastery/me with auth returns mastery records."""
    resp = await client.get(
        "/api/v1/stem/mastery/me",
        headers=auth_header(student_token),
    )
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


async def test_analytics_requires_auth(client: AsyncClient):
    """GET /stem/analytics/heatmap without auth returns 403."""
    resp = await client.get("/api/v1/stem/analytics/heatmap")
    assert resp.status_code == 403


async def test_flashcards_requires_auth(client: AsyncClient):
    """GET /stem/revision/flashcards without auth returns 403."""
    resp = await client.get("/api/v1/stem/revision/flashcards")
    assert resp.status_code == 403


async def test_create_group_requires_auth(client: AsyncClient):
    """POST /stem/groups without auth returns 403."""
    resp = await client.post(
        "/api/v1/stem/groups",
        json={"name": "Test", "subject_slug": "math"},
    )
    assert resp.status_code == 403
