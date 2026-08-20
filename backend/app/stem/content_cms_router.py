from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import require_lecturer
from app.models.models import User
from app.models.stem import (
    STEMCareerPath,
    STEMConcept,
    STEMDiscipline,
    STEMFormula,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
    STLearningMaterial,
    STLearningObjective,
    STMAssessmentQuestion,
    STPractice,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------


class SubjectCreate(BaseModel):
    title: str
    subject_slug: str
    description: str | None = None
    icon: str | None = None
    color: str | None = None


class SubjectUpdate(BaseModel):
    title: str | None = None
    subject_slug: str | None = None
    description: str | None = None
    icon: str | None = None
    color: str | None = None


class DisciplineCreate(BaseModel):
    title: str
    discipline_slug: str
    description: str | None = None
    order_index: int = 0


class DisciplineUpdate(BaseModel):
    title: str | None = None
    discipline_slug: str | None = None
    description: str | None = None
    order_index: int | None = None


class TopicCreate(BaseModel):
    title: str
    description: str | None = None
    difficulty_level: str = "foundational"
    order_index: int = 0


class TopicUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    difficulty_level: str | None = None
    order_index: int | None = None


class SubtopicCreate(BaseModel):
    title: str
    description: str | None = None
    difficulty_level: str = "foundational"
    order_index: int = 0


class SubtopicUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    difficulty_level: str | None = None
    order_index: int | None = None


class ConceptCreate(BaseModel):
    title: str
    description: str | None = None
    learning_objectives_text: str | None = None
    prerequisites_text: str | None = None
    difficulty_level: str = "foundational"
    order_index: int = 0


class ConceptUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    learning_objectives_text: str | None = None
    prerequisites_text: str | None = None
    difficulty_level: str | None = None
    order_index: int | None = None


class MaterialCreate(BaseModel):
    title: str
    content: str | None = None
    material_type: str = "text"
    duration_minutes: int | None = None
    order_index: int = 0
    is_published: bool = True


class MaterialUpdate(BaseModel):
    title: str | None = None
    content: str | None = None
    material_type: str | None = None
    duration_minutes: int | None = None
    order_index: int | None = None
    is_published: bool | None = None


class ObjectiveCreate(BaseModel):
    title: str
    description: str | None = None
    bloom_level: str = "understand"
    order_index: int = 0


class ObjectiveUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    bloom_level: str | None = None
    order_index: int | None = None


class PracticeCreate(BaseModel):
    title: str
    question_text: str
    question_type: str = "mcq"
    options: str | None = None
    answer: str | None = None
    explanation: str | None = None
    difficulty: str = "medium"
    marks: int = 1
    order_index: int = 0
    is_published: bool = True


class PracticeUpdate(BaseModel):
    title: str | None = None
    question_text: str | None = None
    question_type: str | None = None
    options: str | None = None
    answer: str | None = None
    explanation: str | None = None
    difficulty: str | None = None
    marks: int | None = None
    order_index: int | None = None
    is_published: bool | None = None


class FormulaCreate(BaseModel):
    subject_slug: str
    title: str
    formula: str
    description: str | None = None
    category: str
    variables: str | None = None
    tags: str | None = None
    is_published: bool = True


class FormulaUpdate(BaseModel):
    subject_slug: str | None = None
    title: str | None = None
    formula: str | None = None
    description: str | None = None
    category: str | None = None
    variables: str | None = None
    tags: str | None = None
    is_published: bool | None = None


class CareerPathCreate(BaseModel):
    subject_slug: str
    career_title: str
    description: str | None = None
    required_subjects: str | None = None
    recommended_skills: str | None = None
    related_programmes: str | None = None
    competencies: str | None = None
    icon: str | None = None


class CareerPathUpdate(BaseModel):
    subject_slug: str | None = None
    career_title: str | None = None
    description: str | None = None
    required_subjects: str | None = None
    recommended_skills: str | None = None
    related_programmes: str | None = None
    competencies: str | None = None
    icon: str | None = None


class AssessmentQuestionCreate(BaseModel):
    concept_id: int
    question_text: str
    question_type: str = "mcq"
    options: str | None = None
    answer: str | None = None
    explanation: str | None = None
    bloom_level: str = "remember"
    difficulty: str = "medium"
    marks: int = 1
    assessment_type: str = "formative"
    source_reference: str | None = None
    is_published: bool = True


class AssessmentQuestionUpdate(BaseModel):
    concept_id: int | None = None
    question_text: str | None = None
    question_type: str | None = None
    options: str | None = None
    answer: str | None = None
    explanation: str | None = None
    bloom_level: str | None = None
    difficulty: str | None = None
    marks: int | None = None
    assessment_type: str | None = None
    source_reference: str | None = None
    is_published: bool | None = None


class ReorderRequest(BaseModel):
    level: str
    parent_id: int
    ordered_ids: list[int]


# ---------------------------------------------------------------------------
# Response helpers (with child counts where useful)
# ---------------------------------------------------------------------------


class SubjectResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    title: str
    subject_slug: str
    description: str | None
    icon: str | None
    color: str | None
    discipline_count: int = 0


class DisciplineResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    subject_id: int
    title: str
    discipline_slug: str
    description: str | None
    order_index: int
    topic_count: int = 0


class TopicResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    discipline_id: int
    title: str
    description: str | None
    difficulty_level: str
    order_index: int
    subtopic_count: int = 0


class SubtopicResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    topic_id: int
    title: str
    description: str | None
    difficulty_level: str
    order_index: int
    concept_count: int = 0


class ConceptResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    subtopic_id: int
    title: str
    description: str | None
    learning_objectives_text: str | None
    prerequisites_text: str | None
    difficulty_level: str
    order_index: int
    material_count: int = 0
    objective_count: int = 0
    practice_count: int = 0


class MaterialResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    concept_id: int
    title: str
    content: str | None
    material_type: str
    duration_minutes: int | None
    order_index: int
    is_published: bool


class ObjectiveResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    concept_id: int
    title: str
    description: str | None
    bloom_level: str
    order_index: int


class PracticeResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    concept_id: int
    title: str
    question_text: str
    question_type: str
    options: str | None
    answer: str | None
    explanation: str | None
    difficulty: str
    marks: int
    order_index: int
    is_published: bool


class FormulaResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    subject_slug: str
    title: str
    formula: str
    description: str | None
    category: str
    variables: str | None
    tags: str | None
    is_published: bool


class CareerPathResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    subject_slug: str
    career_title: str
    description: str | None
    required_subjects: str | None
    recommended_skills: str | None
    related_programmes: str | None
    competencies: str | None
    icon: str | None


class AssessmentQuestionResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    concept_id: int
    question_text: str
    question_type: str
    options: str | None
    answer: str | None
    explanation: str | None
    bloom_level: str
    difficulty: str
    marks: int
    assessment_type: str
    source_reference: str | None
    is_published: bool


class CMSStatsResponse(BaseModel):
    model_config = {"from_attributes": True}

    total_subjects: int
    total_disciplines: int
    total_topics: int
    total_subtopics: int
    total_concepts: int
    total_materials: int
    total_objectives: int
    total_practices: int
    published_materials: int
    published_practices: int


# ---------------------------------------------------------------------------
# Conversion helpers
# ---------------------------------------------------------------------------


def _subject_response(s: STEMSubject, discipline_count: int = 0) -> SubjectResponse:
    return SubjectResponse(
        id=s.id,
        title=s.title,
        subject_slug=s.subject_slug,
        description=s.description,
        icon=s.icon,
        color=s.color,
        discipline_count=discipline_count,
    )


def _discipline_response(d: STEMDiscipline, topic_count: int = 0) -> DisciplineResponse:
    return DisciplineResponse(
        id=d.id,
        subject_id=d.subject_id,
        title=d.title,
        discipline_slug=d.discipline_slug,
        description=d.description,
        order_index=d.order_index,
        topic_count=topic_count,
    )


def _topic_response(t: STEMTopic, subtopic_count: int = 0) -> TopicResponse:
    return TopicResponse(
        id=t.id,
        discipline_id=t.discipline_id,
        title=t.title,
        description=t.description,
        difficulty_level=t.difficulty_level,
        order_index=t.order_index,
        subtopic_count=subtopic_count,
    )


def _subtopic_response(st: STEMSubtopic, concept_count: int = 0) -> SubtopicResponse:
    return SubtopicResponse(
        id=st.id,
        topic_id=st.topic_id,
        title=st.title,
        description=st.description,
        difficulty_level=st.difficulty_level,
        order_index=st.order_index,
        concept_count=concept_count,
    )


def _concept_response(
    c: STEMConcept,
    material_count: int = 0,
    objective_count: int = 0,
    practice_count: int = 0,
) -> ConceptResponse:
    return ConceptResponse(
        id=c.id,
        subtopic_id=c.subtopic_id,
        title=c.title,
        description=c.description,
        learning_objectives_text=c.learning_objectives_text,
        prerequisites_text=c.prerequisites_text,
        difficulty_level=c.difficulty_level,
        order_index=c.order_index,
        material_count=material_count,
        objective_count=objective_count,
        practice_count=practice_count,
    )


def _material_response(m: STLearningMaterial) -> MaterialResponse:
    return MaterialResponse(
        id=m.id,
        concept_id=m.concept_id,
        title=m.title,
        content=m.content,
        material_type=m.material_type,
        duration_minutes=m.duration_minutes,
        order_index=m.order_index,
        is_published=m.is_published,
    )


def _objective_response(o: STLearningObjective) -> ObjectiveResponse:
    return ObjectiveResponse(
        id=o.id,
        concept_id=o.concept_id,
        title=o.title,
        description=o.description,
        bloom_level=o.bloom_level,
        order_index=o.order_index,
    )


def _practice_response(p: STPractice) -> PracticeResponse:
    return PracticeResponse(
        id=p.id,
        concept_id=p.concept_id,
        title=p.title,
        question_text=p.question_text,
        question_type=p.question_type,
        options=p.options,
        answer=p.answer,
        explanation=p.explanation,
        difficulty=p.difficulty,
        marks=p.marks,
        order_index=p.order_index,
        is_published=p.is_published,
    )


def _formula_response(f: STEMFormula) -> FormulaResponse:
    return FormulaResponse(
        id=f.id,
        subject_slug=f.subject_slug,
        title=f.title,
        formula=f.formula,
        description=f.description,
        category=f.category,
        variables=f.variables,
        tags=f.tags,
        is_published=f.is_published,
    )


def _career_response(c: STEMCareerPath) -> CareerPathResponse:
    return CareerPathResponse(
        id=c.id,
        subject_slug=c.subject_slug,
        career_title=c.career_title,
        description=c.description,
        required_subjects=c.required_subjects,
        recommended_skills=c.recommended_skills,
        related_programmes=c.related_programmes,
        competencies=c.competencies,
        icon=c.icon,
    )


def _assessment_question_response(
    q: STMAssessmentQuestion,
) -> AssessmentQuestionResponse:
    return AssessmentQuestionResponse(
        id=q.id,
        concept_id=q.concept_id,
        question_text=q.question_text,
        question_type=q.question_type,
        options=q.options,
        answer=q.answer,
        explanation=q.explanation,
        bloom_level=q.bloom_level,
        difficulty=q.difficulty,
        marks=q.marks,
        assessment_type=q.assessment_type,
        source_reference=q.source_reference,
        is_published=q.is_published,
    )


# ---------------------------------------------------------------------------
# Count helpers
# ---------------------------------------------------------------------------


async def _count_children(
    db: AsyncSession, model, foreign_key_col, parent_id: int
) -> int:
    result = await db.execute(
        select(func.count()).select_from(model).where(foreign_key_col == parent_id)
    )
    return result.scalar_one() or 0


# ===========================================================================
# SUBJECTS
# ===========================================================================


@router.get("/cms/subjects", response_model=list[SubjectResponse])
async def list_subjects(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(STEMSubject).order_by(STEMSubject.title))
    subjects = result.scalars().all()
    responses: list[SubjectResponse] = []
    for s in subjects:
        count = await _count_children(
            db, STEMDiscipline, STEMDiscipline.subject_id, s.id
        )
        responses.append(_subject_response(s, count))
    return responses


@router.post(
    "/cms/subjects", response_model=SubjectResponse, status_code=status.HTTP_201_CREATED
)
async def create_subject(
    body: SubjectCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    subject = STEMSubject(**body.model_dump())
    db.add(subject)
    await db.commit()
    await db.refresh(subject)
    return _subject_response(subject)


@router.get("/cms/subjects/{subject_id}", response_model=SubjectResponse)
async def get_subject(subject_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(STEMSubject).where(STEMSubject.id == subject_id))
    subject = result.scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    count = await _count_children(
        db, STEMDiscipline, STEMDiscipline.subject_id, subject.id
    )
    return _subject_response(subject, count)


@router.put("/cms/subjects/{subject_id}", response_model=SubjectResponse)
async def update_subject(
    subject_id: int,
    body: SubjectUpdate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMSubject).where(STEMSubject.id == subject_id))
    subject = result.scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(subject, field, value)
    await db.commit()
    await db.refresh(subject)
    return _subject_response(subject)


@router.delete("/cms/subjects/{subject_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_subject(
    subject_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMSubject).where(STEMSubject.id == subject_id))
    subject = result.scalar_one_or_none()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    await db.delete(subject)
    await db.commit()


# ===========================================================================
# DISCIPLINES
# ===========================================================================


@router.get(
    "/cms/subjects/{subject_id}/disciplines",
    response_model=list[DisciplineResponse],
)
async def list_disciplines(subject_id: int, db: AsyncSession = Depends(get_db)):
    parent = await db.execute(select(STEMSubject).where(STEMSubject.id == subject_id))
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Subject not found")
    result = await db.execute(
        select(STEMDiscipline)
        .where(STEMDiscipline.subject_id == subject_id)
        .order_by(STEMDiscipline.order_index, STEMDiscipline.title)
    )
    disciplines = result.scalars().all()
    responses: list[DisciplineResponse] = []
    for d in disciplines:
        count = await _count_children(db, STEMTopic, STEMTopic.discipline_id, d.id)
        responses.append(_discipline_response(d, count))
    return responses


@router.post(
    "/cms/subjects/{subject_id}/disciplines",
    response_model=DisciplineResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_discipline(
    subject_id: int,
    body: DisciplineCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    parent = await db.execute(select(STEMSubject).where(STEMSubject.id == subject_id))
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Subject not found")
    discipline = STEMDiscipline(subject_id=subject_id, **body.model_dump())
    db.add(discipline)
    await db.commit()
    await db.refresh(discipline)
    return _discipline_response(discipline)


@router.put("/cms/disciplines/{discipline_id}", response_model=DisciplineResponse)
async def update_discipline(
    discipline_id: int,
    body: DisciplineUpdate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMDiscipline).where(STEMDiscipline.id == discipline_id)
    )
    discipline = result.scalar_one_or_none()
    if not discipline:
        raise HTTPException(status_code=404, detail="Discipline not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(discipline, field, value)
    await db.commit()
    await db.refresh(discipline)
    return _discipline_response(discipline)


@router.delete(
    "/cms/disciplines/{discipline_id}", status_code=status.HTTP_204_NO_CONTENT
)
async def delete_discipline(
    discipline_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMDiscipline).where(STEMDiscipline.id == discipline_id)
    )
    discipline = result.scalar_one_or_none()
    if not discipline:
        raise HTTPException(status_code=404, detail="Discipline not found")
    await db.delete(discipline)
    await db.commit()


# ===========================================================================
# TOPICS
# ===========================================================================


@router.get(
    "/cms/disciplines/{discipline_id}/topics",
    response_model=list[TopicResponse],
)
async def list_topics(discipline_id: int, db: AsyncSession = Depends(get_db)):
    parent = await db.execute(
        select(STEMDiscipline).where(STEMDiscipline.id == discipline_id)
    )
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Discipline not found")
    result = await db.execute(
        select(STEMTopic)
        .where(STEMTopic.discipline_id == discipline_id)
        .order_by(STEMTopic.order_index, STEMTopic.title)
    )
    topics = result.scalars().all()
    responses: list[TopicResponse] = []
    for t in topics:
        count = await _count_children(db, STEMSubtopic, STEMSubtopic.topic_id, t.id)
        responses.append(_topic_response(t, count))
    return responses


@router.post(
    "/cms/disciplines/{discipline_id}/topics",
    response_model=TopicResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_topic(
    discipline_id: int,
    body: TopicCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    parent = await db.execute(
        select(STEMDiscipline).where(STEMDiscipline.id == discipline_id)
    )
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Discipline not found")
    topic = STEMTopic(discipline_id=discipline_id, **body.model_dump())
    db.add(topic)
    await db.commit()
    await db.refresh(topic)
    return _topic_response(topic)


@router.put("/cms/topics/{topic_id}", response_model=TopicResponse)
async def update_topic(
    topic_id: int,
    body: TopicUpdate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMTopic).where(STEMTopic.id == topic_id))
    topic = result.scalar_one_or_none()
    if not topic:
        raise HTTPException(status_code=404, detail="Topic not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(topic, field, value)
    await db.commit()
    await db.refresh(topic)
    return _topic_response(topic)


@router.delete("/cms/topics/{topic_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_topic(
    topic_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMTopic).where(STEMTopic.id == topic_id))
    topic = result.scalar_one_or_none()
    if not topic:
        raise HTTPException(status_code=404, detail="Topic not found")
    await db.delete(topic)
    await db.commit()


# ===========================================================================
# SUBTOPICS
# ===========================================================================


@router.get(
    "/cms/topics/{topic_id}/subtopics",
    response_model=list[SubtopicResponse],
)
async def list_subtopics(topic_id: int, db: AsyncSession = Depends(get_db)):
    parent = await db.execute(select(STEMTopic).where(STEMTopic.id == topic_id))
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Topic not found")
    result = await db.execute(
        select(STEMSubtopic)
        .where(STEMSubtopic.topic_id == topic_id)
        .order_by(STEMSubtopic.order_index, STEMSubtopic.title)
    )
    subtopics = result.scalars().all()
    responses: list[SubtopicResponse] = []
    for st in subtopics:
        count = await _count_children(db, STEMConcept, STEMConcept.subtopic_id, st.id)
        responses.append(_subtopic_response(st, count))
    return responses


@router.post(
    "/cms/topics/{topic_id}/subtopics",
    response_model=SubtopicResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_subtopic(
    topic_id: int,
    body: SubtopicCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    parent = await db.execute(select(STEMTopic).where(STEMTopic.id == topic_id))
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Topic not found")
    subtopic = STEMSubtopic(topic_id=topic_id, **body.model_dump())
    db.add(subtopic)
    await db.commit()
    await db.refresh(subtopic)
    return _subtopic_response(subtopic)


@router.put("/cms/subtopics/{subtopic_id}", response_model=SubtopicResponse)
async def update_subtopic(
    subtopic_id: int,
    body: SubtopicUpdate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMSubtopic).where(STEMSubtopic.id == subtopic_id)
    )
    subtopic = result.scalar_one_or_none()
    if not subtopic:
        raise HTTPException(status_code=404, detail="Subtopic not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(subtopic, field, value)
    await db.commit()
    await db.refresh(subtopic)
    return _subtopic_response(subtopic)


@router.delete("/cms/subtopics/{subtopic_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_subtopic(
    subtopic_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMSubtopic).where(STEMSubtopic.id == subtopic_id)
    )
    subtopic = result.scalar_one_or_none()
    if not subtopic:
        raise HTTPException(status_code=404, detail="Subtopic not found")
    await db.delete(subtopic)
    await db.commit()


# ===========================================================================
# CONCEPTS
# ===========================================================================


@router.get(
    "/cms/subtopics/{subtopic_id}/concepts",
    response_model=list[ConceptResponse],
)
async def list_concepts(subtopic_id: int, db: AsyncSession = Depends(get_db)):
    parent = await db.execute(
        select(STEMSubtopic).where(STEMSubtopic.id == subtopic_id)
    )
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Subtopic not found")
    result = await db.execute(
        select(STEMConcept)
        .where(STEMConcept.subtopic_id == subtopic_id)
        .order_by(STEMConcept.order_index, STEMConcept.title)
    )
    concepts = result.scalars().all()
    responses: list[ConceptResponse] = []
    for c in concepts:
        mat_count = await _count_children(
            db, STLearningMaterial, STLearningMaterial.concept_id, c.id
        )
        obj_count = await _count_children(
            db, STLearningObjective, STLearningObjective.concept_id, c.id
        )
        prac_count = await _count_children(db, STPractice, STPractice.concept_id, c.id)
        responses.append(_concept_response(c, mat_count, obj_count, prac_count))
    return responses


@router.post(
    "/cms/subtopics/{subtopic_id}/concepts",
    response_model=ConceptResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_concept(
    subtopic_id: int,
    body: ConceptCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    parent = await db.execute(
        select(STEMSubtopic).where(STEMSubtopic.id == subtopic_id)
    )
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Subtopic not found")
    concept = STEMConcept(subtopic_id=subtopic_id, **body.model_dump())
    db.add(concept)
    await db.commit()
    await db.refresh(concept)
    return _concept_response(concept)


@router.put("/cms/concepts/{concept_id}", response_model=ConceptResponse)
async def update_concept(
    concept_id: int,
    body: ConceptUpdate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMConcept).where(STEMConcept.id == concept_id))
    concept = result.scalar_one_or_none()
    if not concept:
        raise HTTPException(status_code=404, detail="Concept not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(concept, field, value)
    await db.commit()
    await db.refresh(concept)
    return _concept_response(concept)


@router.delete("/cms/concepts/{concept_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_concept(
    concept_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMConcept).where(STEMConcept.id == concept_id))
    concept = result.scalar_one_or_none()
    if not concept:
        raise HTTPException(status_code=404, detail="Concept not found")
    await db.delete(concept)
    await db.commit()


# ===========================================================================
# LEARNING MATERIALS
# ===========================================================================


@router.get(
    "/cms/concepts/{concept_id}/materials",
    response_model=list[MaterialResponse],
)
async def list_materials(concept_id: int, db: AsyncSession = Depends(get_db)):
    parent = await db.execute(select(STEMConcept).where(STEMConcept.id == concept_id))
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Concept not found")
    result = await db.execute(
        select(STLearningMaterial)
        .where(STLearningMaterial.concept_id == concept_id)
        .order_by(STLearningMaterial.order_index, STLearningMaterial.title)
    )
    return [_material_response(m) for m in result.scalars().all()]


@router.post(
    "/cms/concepts/{concept_id}/materials",
    response_model=MaterialResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_material(
    concept_id: int,
    body: MaterialCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    parent = await db.execute(select(STEMConcept).where(STEMConcept.id == concept_id))
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Concept not found")
    material = STLearningMaterial(concept_id=concept_id, **body.model_dump())
    db.add(material)
    await db.commit()
    await db.refresh(material)
    return _material_response(material)


@router.put("/cms/materials/{material_id}", response_model=MaterialResponse)
async def update_material(
    material_id: int,
    body: MaterialUpdate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STLearningMaterial).where(STLearningMaterial.id == material_id)
    )
    material = result.scalar_one_or_none()
    if not material:
        raise HTTPException(status_code=404, detail="Material not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(material, field, value)
    await db.commit()
    await db.refresh(material)
    return _material_response(material)


@router.delete("/cms/materials/{material_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_material(
    material_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STLearningMaterial).where(STLearningMaterial.id == material_id)
    )
    material = result.scalar_one_or_none()
    if not material:
        raise HTTPException(status_code=404, detail="Material not found")
    await db.delete(material)
    await db.commit()


# ===========================================================================
# LEARNING OBJECTIVES
# ===========================================================================


@router.get(
    "/cms/concepts/{concept_id}/objectives",
    response_model=list[ObjectiveResponse],
)
async def list_objectives(concept_id: int, db: AsyncSession = Depends(get_db)):
    parent = await db.execute(select(STEMConcept).where(STEMConcept.id == concept_id))
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Concept not found")
    result = await db.execute(
        select(STLearningObjective)
        .where(STLearningObjective.concept_id == concept_id)
        .order_by(STLearningObjective.order_index, STLearningObjective.title)
    )
    return [_objective_response(o) for o in result.scalars().all()]


@router.post(
    "/cms/concepts/{concept_id}/objectives",
    response_model=ObjectiveResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_objective(
    concept_id: int,
    body: ObjectiveCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    parent = await db.execute(select(STEMConcept).where(STEMConcept.id == concept_id))
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Concept not found")
    objective = STLearningObjective(concept_id=concept_id, **body.model_dump())
    db.add(objective)
    await db.commit()
    await db.refresh(objective)
    return _objective_response(objective)


@router.put("/cms/objectives/{objective_id}", response_model=ObjectiveResponse)
async def update_objective(
    objective_id: int,
    body: ObjectiveUpdate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STLearningObjective).where(STLearningObjective.id == objective_id)
    )
    objective = result.scalar_one_or_none()
    if not objective:
        raise HTTPException(status_code=404, detail="Objective not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(objective, field, value)
    await db.commit()
    await db.refresh(objective)
    return _objective_response(objective)


@router.delete("/cms/objectives/{objective_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_objective(
    objective_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STLearningObjective).where(STLearningObjective.id == objective_id)
    )
    objective = result.scalar_one_or_none()
    if not objective:
        raise HTTPException(status_code=404, detail="Objective not found")
    await db.delete(objective)
    await db.commit()


# ===========================================================================
# PRACTICES
# ===========================================================================


@router.get(
    "/cms/concepts/{concept_id}/practices",
    response_model=list[PracticeResponse],
)
async def list_practices(concept_id: int, db: AsyncSession = Depends(get_db)):
    parent = await db.execute(select(STEMConcept).where(STEMConcept.id == concept_id))
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Concept not found")
    result = await db.execute(
        select(STPractice)
        .where(STPractice.concept_id == concept_id)
        .order_by(STPractice.order_index, STPractice.title)
    )
    return [_practice_response(p) for p in result.scalars().all()]


@router.post(
    "/cms/concepts/{concept_id}/practices",
    response_model=PracticeResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_practice(
    concept_id: int,
    body: PracticeCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    parent = await db.execute(select(STEMConcept).where(STEMConcept.id == concept_id))
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Concept not found")
    practice = STPractice(concept_id=concept_id, **body.model_dump())
    db.add(practice)
    await db.commit()
    await db.refresh(practice)
    return _practice_response(practice)


@router.put("/cms/practices/{practice_id}", response_model=PracticeResponse)
async def update_practice(
    practice_id: int,
    body: PracticeUpdate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STPractice).where(STPractice.id == practice_id))
    practice = result.scalar_one_or_none()
    if not practice:
        raise HTTPException(status_code=404, detail="Practice not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(practice, field, value)
    await db.commit()
    await db.refresh(practice)
    return _practice_response(practice)


@router.delete("/cms/practices/{practice_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_practice(
    practice_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STPractice).where(STPractice.id == practice_id))
    practice = result.scalar_one_or_none()
    if not practice:
        raise HTTPException(status_code=404, detail="Practice not found")
    await db.delete(practice)
    await db.commit()


# ===========================================================================
# FORMULAS (CMS CRUD)
# ===========================================================================


@router.get("/cms/formulas", response_model=list[FormulaResponse])
async def list_formulas(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(STEMFormula).order_by(STEMFormula.category, STEMFormula.title)
    )
    return [_formula_response(f) for f in result.scalars().all()]


@router.post(
    "/cms/formulas", response_model=FormulaResponse, status_code=status.HTTP_201_CREATED
)
async def create_formula(
    body: FormulaCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    formula = STEMFormula(**body.model_dump())
    db.add(formula)
    await db.commit()
    await db.refresh(formula)
    return _formula_response(formula)


@router.put("/cms/formulas/{formula_id}", response_model=FormulaResponse)
async def update_formula(
    formula_id: int,
    body: FormulaUpdate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMFormula).where(STEMFormula.id == formula_id))
    formula = result.scalar_one_or_none()
    if not formula:
        raise HTTPException(status_code=404, detail="Formula not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(formula, field, value)
    await db.commit()
    await db.refresh(formula)
    return _formula_response(formula)


@router.delete("/cms/formulas/{formula_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_formula(
    formula_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMFormula).where(STEMFormula.id == formula_id))
    formula = result.scalar_one_or_none()
    if not formula:
        raise HTTPException(status_code=404, detail="Formula not found")
    await db.delete(formula)
    await db.commit()


# ===========================================================================
# CAREER PATHS (CMS CRUD)
# ===========================================================================


@router.get("/cms/careers", response_model=list[CareerPathResponse])
async def list_careers(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(STEMCareerPath).order_by(STEMCareerPath.career_title)
    )
    return [_career_response(c) for c in result.scalars().all()]


@router.post(
    "/cms/careers",
    response_model=CareerPathResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_career(
    body: CareerPathCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    career = STEMCareerPath(**body.model_dump())
    db.add(career)
    await db.commit()
    await db.refresh(career)
    return _career_response(career)


@router.put("/cms/careers/{career_id}", response_model=CareerPathResponse)
async def update_career(
    career_id: int,
    body: CareerPathUpdate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMCareerPath).where(STEMCareerPath.id == career_id)
    )
    career = result.scalar_one_or_none()
    if not career:
        raise HTTPException(status_code=404, detail="Career path not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(career, field, value)
    await db.commit()
    await db.refresh(career)
    return _career_response(career)


@router.delete("/cms/careers/{career_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_career(
    career_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMCareerPath).where(STEMCareerPath.id == career_id)
    )
    career = result.scalar_one_or_none()
    if not career:
        raise HTTPException(status_code=404, detail="Career path not found")
    await db.delete(career)
    await db.commit()


# ===========================================================================
# ASSESSMENT QUESTIONS (CMS CRUD)
# ===========================================================================


@router.get("/cms/questions", response_model=list[AssessmentQuestionResponse])
async def list_assessment_questions(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(STMAssessmentQuestion).order_by(
            STMAssessmentQuestion.concept_id, STMAssessmentQuestion.order_index
        )
    )
    return [_assessment_question_response(q) for q in result.scalars().all()]


@router.post(
    "/cms/questions",
    response_model=AssessmentQuestionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_assessment_question(
    body: AssessmentQuestionCreate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    parent = await db.execute(
        select(STEMConcept).where(STEMConcept.id == body.concept_id)
    )
    if not parent.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Concept not found")
    question = STMAssessmentQuestion(**body.model_dump())
    db.add(question)
    await db.commit()
    await db.refresh(question)
    return _assessment_question_response(question)


@router.put(
    "/cms/questions/{question_id}",
    response_model=AssessmentQuestionResponse,
)
async def update_assessment_question(
    question_id: int,
    body: AssessmentQuestionUpdate,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STMAssessmentQuestion).where(STMAssessmentQuestion.id == question_id)
    )
    question = result.scalar_one_or_none()
    if not question:
        raise HTTPException(status_code=404, detail="Assessment question not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(question, field, value)
    await db.commit()
    await db.refresh(question)
    return _assessment_question_response(question)


@router.delete("/cms/questions/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_assessment_question(
    question_id: int,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STMAssessmentQuestion).where(STMAssessmentQuestion.id == question_id)
    )
    question = result.scalar_one_or_none()
    if not question:
        raise HTTPException(status_code=404, detail="Assessment question not found")
    await db.delete(question)
    await db.commit()


# ===========================================================================
# DASHBOARD / STATS
# ===========================================================================


async def _total(db: AsyncSession, model) -> int:
    result = await db.execute(select(func.count()).select_from(model))
    return result.scalar_one() or 0


@router.get("/cms/stats", response_model=CMSStatsResponse)
async def get_cms_stats(db: AsyncSession = Depends(get_db)):
    return CMSStatsResponse(
        total_subjects=await _total(db, STEMSubject),
        total_disciplines=await _total(db, STEMDiscipline),
        total_topics=await _total(db, STEMTopic),
        total_subtopics=await _total(db, STEMSubtopic),
        total_concepts=await _total(db, STEMConcept),
        total_materials=await _total(db, STLearningMaterial),
        total_objectives=await _total(db, STLearningObjective),
        total_practices=await _total(db, STPractice),
        published_materials=await _count_where(
            db, STLearningMaterial, STLearningMaterial.is_published.is_(True)
        ),
        published_practices=await _count_where(
            db, STPractice, STPractice.is_published.is_(True)
        ),
    )


async def _count_where(db: AsyncSession, model, *where_clauses) -> int:
    stmt = select(func.count()).select_from(model).where(*where_clauses)
    result = await db.execute(stmt)
    return result.scalar_one() or 0


# ===========================================================================
# BULK REORDER
# ===========================================================================

_REORDER_MODELS = {
    "discipline": (STEMDiscipline, STEMDiscipline.id),
    "topic": (STEMTopic, STEMTopic.id),
    "subtopic": (STEMSubtopic, STEMSubtopic.id),
    "concept": (STEMConcept, STEMConcept.id),
    "objective": (STLearningObjective, STLearningObjective.id),
    "material": (STLearningMaterial, STLearningMaterial.id),
    "practice": (STPractice, STPractice.id),
}


@router.post("/cms/reorder", status_code=status.HTTP_200_OK)
async def reorder_items(
    body: ReorderRequest,
    user: User = Depends(require_lecturer),
    db: AsyncSession = Depends(get_db),
):
    if body.level not in _REORDER_MODELS:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid level '{body.level}'. Must be one of: {', '.join(sorted(_REORDER_MODELS))}",
        )

    model_class, id_col = _REORDER_MODELS[body.level]

    result = await db.execute(select(model_class).where(id_col.in_(body.ordered_ids)))
    items = {item.id: item for item in result.scalars().all()}

    if len(items) != len(body.ordered_ids):
        raise HTTPException(
            status_code=400,
            detail="One or more IDs are invalid for the given level",
        )

    for idx, item_id in enumerate(body.ordered_ids):
        items[item_id].order_index = idx

    await db.commit()
    return {"updated": len(body.ordered_ids)}
