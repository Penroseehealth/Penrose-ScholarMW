from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.engine import Base


class STEMSubject(Base):
    __tablename__ = "stem_subjects"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    subject_slug: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon: Mapped[str | None] = mapped_column(String(100), nullable=True)
    color: Mapped[str | None] = mapped_column(String(50), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    disciplines: Mapped[list["STEMDiscipline"]] = relationship(back_populates="subject")


class STEMDiscipline(Base):
    __tablename__ = "stem_disciplines"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    subject_id: Mapped[int] = mapped_column(
        ForeignKey("stem_subjects.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    discipline_slug: Mapped[str] = mapped_column(
        String(100), nullable=False, index=True
    )
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    subject: Mapped["STEMSubject"] = relationship(back_populates="disciplines")
    topics: Mapped[list["STEMTopic"]] = relationship(back_populates="discipline")


class STEMTopic(Base):
    __tablename__ = "stem_topics"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    discipline_id: Mapped[int] = mapped_column(
        ForeignKey("stem_disciplines.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    difficulty_level: Mapped[str] = mapped_column(String(20), default="foundational")
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    discipline: Mapped["STEMDiscipline"] = relationship(back_populates="topics")
    subtopics: Mapped[list["STEMSubtopic"]] = relationship(back_populates="topic")


class STEMSubtopic(Base):
    __tablename__ = "stem_subtopics"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    topic_id: Mapped[int] = mapped_column(ForeignKey("stem_topics.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    difficulty_level: Mapped[str] = mapped_column(String(20), default="foundational")
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    topic: Mapped["STEMTopic"] = relationship(back_populates="subtopics")
    concepts: Mapped[list["STEMConcept"]] = relationship(back_populates="subtopic")


class STEMConcept(Base):
    __tablename__ = "stem_concepts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    subtopic_id: Mapped[int] = mapped_column(
        ForeignKey("stem_subtopics.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    learning_objectives_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    prerequisites_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    difficulty_level: Mapped[str] = mapped_column(String(20), default="foundational")
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    subtopic: Mapped["STEMSubtopic"] = relationship(back_populates="concepts")
    objectives: Mapped[list["STLearningObjective"]] = relationship(
        back_populates="concept"
    )
    materials: Mapped[list["STLearningMaterial"]] = relationship(
        back_populates="concept"
    )
    practices: Mapped[list["STPractice"]] = relationship(back_populates="concept")


class STLearningObjective(Base):
    __tablename__ = "stem_learning_objectives"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    bloom_level: Mapped[str] = mapped_column(String(20), default="understand")
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    concept: Mapped["STEMConcept"] = relationship(back_populates="objectives")


class STLearningMaterial(Base):
    __tablename__ = "stem_learning_materials"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    content: Mapped[str | None] = mapped_column(Text, nullable=True)
    material_type: Mapped[str] = mapped_column(String(20), default="text")
    duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    concept: Mapped["STEMConcept"] = relationship(back_populates="materials")


class STPractice(Base):
    __tablename__ = "stem_practices"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    question_text: Mapped[str] = mapped_column(Text, nullable=False)
    question_type: Mapped[str] = mapped_column(String(20), default="mcq")
    options: Mapped[str | None] = mapped_column(Text, nullable=True)
    answer: Mapped[str | None] = mapped_column(Text, nullable=True)
    explanation: Mapped[str | None] = mapped_column(Text, nullable=True)
    difficulty: Mapped[str] = mapped_column(String(20), default="medium")
    marks: Mapped[int] = mapped_column(Integer, default=1)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    concept: Mapped["STEMConcept"] = relationship(back_populates="practices")


class STEMAssessment(Base):
    __tablename__ = "stem_assessments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    assessment_type: Mapped[str] = mapped_column(String(20), default="quiz")
    total_marks: Mapped[int] = mapped_column(Integer, default=100)
    duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    questions: Mapped[list["STEMAssessmentQuestion"]] = relationship(
        back_populates="assessment"
    )


class STEMAssessmentQuestion(Base):
    __tablename__ = "stem_assessment_questions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    assessment_id: Mapped[int] = mapped_column(
        ForeignKey("stem_assessments.id"), nullable=False
    )
    practice_id: Mapped[int] = mapped_column(
        ForeignKey("stem_practices.id"), nullable=False
    )
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    marks: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    assessment: Mapped["STEMAssessment"] = relationship(back_populates="questions")
    practice: Mapped["STPractice"] = relationship()


class MasteryRecord(Base):
    __tablename__ = "stem_mastery_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )
    mastery_level: Mapped[float] = mapped_column(Float, default=0.0)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    correct: Mapped[int] = mapped_column(Integer, default=0)
    last_practiced: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    next_review: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    concept: Mapped["STEMConcept"] = relationship()


class KnowledgeGraphEdge(Base):
    __tablename__ = "stem_knowledge_edges"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    source_concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )
    target_concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )
    relationship_type: Mapped[str] = mapped_column(String(50), default="related")
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    weight: Mapped[float] = mapped_column(Float, default=1.0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    source_concept: Mapped["STEMConcept"] = relationship(
        foreign_keys=[source_concept_id]
    )
    target_concept: Mapped["STEMConcept"] = relationship(
        foreign_keys=[target_concept_id]
    )


class STEMFormula(Base):
    __tablename__ = "stem_formulas"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    subject_slug: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    formula: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    category: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    variables: Mapped[str | None] = mapped_column(Text, nullable=True)
    tags: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class STEMCareerPath(Base):
    __tablename__ = "stem_career_paths"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    subject_slug: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    career_title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    required_subjects: Mapped[str | None] = mapped_column(Text, nullable=True)
    recommended_skills: Mapped[str | None] = mapped_column(Text, nullable=True)
    related_programmes: Mapped[str | None] = mapped_column(Text, nullable=True)
    competencies: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class STMAssessmentQuestion(Base):
    __tablename__ = "stem_enhanced_questions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )
    question_text: Mapped[str] = mapped_column(Text, nullable=False)
    question_type: Mapped[str] = mapped_column(String(30), default="mcq")
    options: Mapped[str | None] = mapped_column(Text, nullable=True)
    answer: Mapped[str | None] = mapped_column(Text, nullable=True)
    explanation: Mapped[str | None] = mapped_column(Text, nullable=True)
    bloom_level: Mapped[str] = mapped_column(String(20), default="remember")
    difficulty: Mapped[str] = mapped_column(String(20), default="medium")
    marks: Mapped[int] = mapped_column(Integer, default=1)
    assessment_type: Mapped[str] = mapped_column(String(30), default="formative")
    source_reference: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    concept: Mapped["STEMConcept"] = relationship()


class STLabActivity(Base):
    __tablename__ = "stem_lab_activities"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    subject_slug: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    lab_type: Mapped[str] = mapped_column(String(50), default="virtual")
    instructions: Mapped[str | None] = mapped_column(Text, nullable=True)
    materials_needed: Mapped[str | None] = mapped_column(Text, nullable=True)
    steps: Mapped[str | None] = mapped_column(Text, nullable=True)
    expected_outcome: Mapped[str | None] = mapped_column(Text, nullable=True)
    difficulty: Mapped[str] = mapped_column(String(20), default="intermediate")
    duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class MasteryRecommendation(Base):
    __tablename__ = "stem_mastery_recommendations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )
    recommendation_type: Mapped[str] = mapped_column(String(50), default="review")
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    resource_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    priority: Mapped[int] = mapped_column(Integer, default=1)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    concept: Mapped["STEMConcept"] = relationship()


# ── Phase 3A: Analytics & Visualization ──


class STEMStudySession(Base):
    __tablename__ = "stem_study_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    subject_slug: Mapped[str | None] = mapped_column(String(100), nullable=True)
    concept_id: Mapped[int | None] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=True
    )
    duration_minutes: Mapped[int] = mapped_column(Integer, default=0)
    activity_type: Mapped[str] = mapped_column(String(30), default="study")
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class STEMDailyProgress(Base):
    __tablename__ = "stem_daily_progress"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    date: Mapped[str] = mapped_column(String(10), nullable=False)
    concepts_reviewed: Mapped[int] = mapped_column(Integer, default=0)
    concepts_mastered: Mapped[int] = mapped_column(Integer, default=0)
    practice_correct: Mapped[int] = mapped_column(Integer, default=0)
    practice_total: Mapped[int] = mapped_column(Integer, default=0)
    study_minutes: Mapped[int] = mapped_column(Integer, default=0)
    streak_days: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


# ── Phase 3B: Malawi STEM Context ──


class STEMMalawiExample(Base):
    __tablename__ = "stem_malawi_examples"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    local_context: Mapped[str | None] = mapped_column(Text, nullable=True)
    region: Mapped[str | None] = mapped_column(String(100), nullable=True)
    real_world_application: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    concept: Mapped["STEMConcept"] = relationship()


class STEMCurriculumAlignment(Base):
    __tablename__ = "stem_curriculum_alignments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )
    curriculum_name: Mapped[str] = mapped_column(String(100), nullable=False)
    syllabus_code: Mapped[str | None] = mapped_column(String(50), nullable=True)
    form_level: Mapped[str | None] = mapped_column(String(20), nullable=True)
    exam_board: Mapped[str | None] = mapped_column(String(100), nullable=True)
    learning_outcome: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    concept: Mapped["STEMConcept"] = relationship()


# ── Phase 3C: Revision Tools ──


class STEMFlashcard(Base):
    __tablename__ = "stem_flashcards"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )
    front: Mapped[str] = mapped_column(Text, nullable=False)
    back: Mapped[str] = mapped_column(Text, nullable=False)
    difficulty: Mapped[str] = mapped_column(String(20), default="medium")
    ease_factor: Mapped[float] = mapped_column(Float, default=2.5)
    interval_days: Mapped[int] = mapped_column(Integer, default=1)
    next_review: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    review_count: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    concept: Mapped["STEMConcept"] = relationship()


class STEMStudyPlan(Base):
    __tablename__ = "stem_study_plans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    subject_slug: Mapped[str | None] = mapped_column(String(100), nullable=True)
    target_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    status: Mapped[str] = mapped_column(String(20), default="active")
    progress_pct: Mapped[float] = mapped_column(Float, default=0.0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    items: Mapped[list["STEMStudyPlanItem"]] = relationship(back_populates="plan")


class STEMStudyPlanItem(Base):
    __tablename__ = "stem_study_plan_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    plan_id: Mapped[int] = mapped_column(
        ForeignKey("stem_study_plans.id"), nullable=False
    )
    concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    plan: Mapped["STEMStudyPlan"] = relationship(back_populates="items")
    concept: Mapped["STEMConcept"] = relationship()


# ── Phase 4: Gamification ──


class STEMBadge(Base):
    __tablename__ = "stem_badges"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon: Mapped[str | None] = mapped_column(String(100), nullable=True)
    category: Mapped[str] = mapped_column(String(50), default="achievement")
    points: Mapped[int] = mapped_column(Integer, default=10)
    requirement_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    requirement_value: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class STEMUserBadge(Base):
    __tablename__ = "stem_user_badges"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    badge_id: Mapped[int] = mapped_column(ForeignKey("stem_badges.id"), nullable=False)
    earned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    badge: Mapped["STEMBadge"] = relationship()


class STEMChallenge(Base):
    __tablename__ = "stem_challenges"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    challenge_type: Mapped[str] = mapped_column(String(30), default="daily")
    subject_slug: Mapped[str | None] = mapped_column(String(100), nullable=True)
    points_reward: Mapped[int] = mapped_column(Integer, default=50)
    difficulty: Mapped[str] = mapped_column(String(20), default="medium")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class STEMChallengeParticipant(Base):
    __tablename__ = "stem_challenge_participants"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    challenge_id: Mapped[int] = mapped_column(
        ForeignKey("stem_challenges.id"), nullable=False
    )
    progress_pct: Mapped[float] = mapped_column(Float, default=0.0)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    challenge: Mapped["STEMChallenge"] = relationship()


class STEMLeaderboardEntry(Base):
    __tablename__ = "stem_leaderboard"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    subject_slug: Mapped[str | None] = mapped_column(String(100), nullable=True)
    total_points: Mapped[int] = mapped_column(Integer, default=0)
    concepts_mastered: Mapped[int] = mapped_column(Integer, default=0)
    challenges_completed: Mapped[int] = mapped_column(Integer, default=0)
    current_streak: Mapped[int] = mapped_column(Integer, default=0)
    longest_streak: Mapped[int] = mapped_column(Integer, default=0)
    rank: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )


# ── Phase 5: Study Groups ──


class STEMStudyGroup(Base):
    __tablename__ = "stem_study_groups"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    subject_slug: Mapped[str | None] = mapped_column(String(100), nullable=True)
    creator_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    max_members: Mapped[int] = mapped_column(Integer, default=10)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    members: Mapped[list["STEMGroupMember"]] = relationship(back_populates="group")
    messages: Mapped[list["STEMGroupMessage"]] = relationship(back_populates="group")


class STEMGroupMember(Base):
    __tablename__ = "stem_group_members"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    group_id: Mapped[int] = mapped_column(
        ForeignKey("stem_study_groups.id"), nullable=False
    )
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    role: Mapped[str] = mapped_column(String(20), default="member")
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    group: Mapped["STEMStudyGroup"] = relationship(back_populates="members")


class STEMGroupMessage(Base):
    __tablename__ = "stem_group_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    group_id: Mapped[int] = mapped_column(
        ForeignKey("stem_study_groups.id"), nullable=False
    )
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    group: Mapped["STEMStudyGroup"] = relationship(back_populates="messages")


class STEMGroupSession(Base):
    __tablename__ = "stem_group_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    group_id: Mapped[int] = mapped_column(
        ForeignKey("stem_study_groups.id"), nullable=False
    )
    started_by: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class STEMGroupSessionConcept(Base):
    __tablename__ = "stem_group_session_concepts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    session_id: Mapped[int] = mapped_column(
        ForeignKey("stem_group_sessions.id"), nullable=False
    )
    concept_id: Mapped[int] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=False
    )


class MockExamResult(Base):
    __tablename__ = "mock_exam_results"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    subject_slug: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    total_questions: Mapped[int] = mapped_column(Integer, nullable=False)
    correct_count: Mapped[int] = mapped_column(Integer, nullable=False)
    total_marks: Mapped[int] = mapped_column(Integer, default=0)
    score_marks: Mapped[int] = mapped_column(Integer, default=0)
    percentage: Mapped[float] = mapped_column(Float, default=0.0)
    time_taken_seconds: Mapped[int] = mapped_column(Integer, default=0)
    time_limit_minutes: Mapped[int] = mapped_column(Integer, default=60)
    difficulty_breakdown: Mapped[str | None] = mapped_column(Text, nullable=True)
    concept_breakdown: Mapped[str | None] = mapped_column(Text, nullable=True)
    bloom_breakdown: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


# ── Phase 10: Auto-grading, Exam Proctoring, Certificate Export ──


class ExamProctorEvent(Base):
    __tablename__ = "exam_proctor_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    exam_type: Mapped[str] = mapped_column(String(50), nullable=False)
    exam_id: Mapped[int] = mapped_column(Integer, nullable=False)
    event_type: Mapped[str] = mapped_column(String(50), nullable=False)
    event_data: Mapped[str | None] = mapped_column(Text, nullable=True)
    ip_address: Mapped[str | None] = mapped_column(String(100), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class STEMUserCertificate(Base):
    __tablename__ = "stem_user_certificates"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    certificate_type: Mapped[str] = mapped_column(String(50), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    subject_slug: Mapped[str | None] = mapped_column(String(100), nullable=True)
    score: Mapped[float | None] = mapped_column(Float, nullable=True)
    issued_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    certificate_data: Mapped[str | None] = mapped_column(Text, nullable=True)


# ── Phase 9: Q&A Discussion Forum + Announcements ──


class STEMForumPost(Base):
    __tablename__ = "stem_forum_posts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    concept_id: Mapped[int | None] = mapped_column(
        ForeignKey("stem_concepts.id"), nullable=True
    )
    subject_slug: Mapped[str | None] = mapped_column(
        String(100), nullable=True, index=True
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    is_question: Mapped[bool] = mapped_column(Boolean, default=True)
    is_resolved: Mapped[bool] = mapped_column(Boolean, default=False)
    upvotes: Mapped[int] = mapped_column(Integer, default=0)
    view_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class STEMForumAnswer(Base):
    __tablename__ = "stem_forum_answers"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    post_id: Mapped[int] = mapped_column(
        ForeignKey("stem_forum_posts.id"), nullable=False
    )
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    is_accepted: Mapped[bool] = mapped_column(Boolean, default=False)
    upvotes: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class STEMForumVote(Base):
    __tablename__ = "stem_forum_votes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    post_id: Mapped[int | None] = mapped_column(
        ForeignKey("stem_forum_posts.id"), nullable=True
    )
    answer_id: Mapped[int | None] = mapped_column(
        ForeignKey("stem_forum_answers.id"), nullable=True
    )
    value: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class STEMAnnouncement(Base):
    __tablename__ = "stem_announcements"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    author_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    subject_slug: Mapped[str | None] = mapped_column(String(100), nullable=True)
    priority: Mapped[str] = mapped_column(String(20), default="normal")
    is_pinned: Mapped[bool] = mapped_column(Boolean, default=False)
    target_audience: Mapped[str] = mapped_column(String(20), default="all")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class STEMContentReport(Base):
    __tablename__ = "stem_content_reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    reporter_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    content_type: Mapped[str] = mapped_column(String(50), nullable=False)
    content_id: Mapped[int] = mapped_column(Integer, nullable=False)
    reason: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    reviewed_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class SyllabusSubject(Base):
    __tablename__ = "syllabus_subjects"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    slug: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon: Mapped[str | None] = mapped_column(String(100), nullable=True)
    color: Mapped[str | None] = mapped_column(String(50), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    versions: Mapped[list["SyllabusVersion"]] = relationship(back_populates="subject")


class SyllabusVersion(Base):
    __tablename__ = "syllabus_versions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    subject_id: Mapped[int] = mapped_column(
        ForeignKey("syllabus_subjects.id"), nullable=False
    )
    version_name: Mapped[str] = mapped_column(String(255), nullable=False)
    year_effective: Mapped[int | None] = mapped_column(Integer, nullable=True)
    examination_board: Mapped[str | None] = mapped_column(String(255), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_current: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    subject: Mapped["SyllabusSubject"] = relationship(back_populates="versions")
    core_elements: Mapped[list["SyllabusCoreElement"]] = relationship(
        back_populates="version"
    )


class SyllabusCoreElement(Base):
    __tablename__ = "syllabus_core_elements"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    version_id: Mapped[int] = mapped_column(
        ForeignKey("syllabus_versions.id"), nullable=False
    )
    number: Mapped[int] = mapped_column(Integer, nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    version: Mapped["SyllabusVersion"] = relationship(back_populates="core_elements")
    topics: Mapped[list["SyllabusTopic"]] = relationship(back_populates="core_element")


class SyllabusTopic(Base):
    __tablename__ = "syllabus_topics"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    core_element_id: Mapped[int] = mapped_column(
        ForeignKey("syllabus_core_elements.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    year_level: Mapped[int] = mapped_column(Integer, default=3)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    core_element: Mapped["SyllabusCoreElement"] = relationship(back_populates="topics")
    subtopics: Mapped[list["SyllabusSubtopic"]] = relationship(back_populates="topic")
    resources: Mapped[list["SyllabusResource"]] = relationship(back_populates="topic")


class SyllabusSubtopic(Base):
    __tablename__ = "syllabus_subtopics"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    topic_id: Mapped[int] = mapped_column(
        ForeignKey("syllabus_topics.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    topic: Mapped["SyllabusTopic"] = relationship(back_populates="subtopics")
    learning_objectives: Mapped[list["SyllabusLearningObjective"]] = relationship(
        back_populates="subtopic"
    )


class SyllabusLearningObjective(Base):
    __tablename__ = "syllabus_learning_objectives"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    subtopic_id: Mapped[int] = mapped_column(
        ForeignKey("syllabus_subtopics.id"), nullable=False
    )
    objective: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    cognitive_level: Mapped[str] = mapped_column(String(50), default="Knowledge")
    teaching_activity: Mapped[str | None] = mapped_column(Text, nullable=True)
    teaching_method: Mapped[str | None] = mapped_column(String(255), nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    subtopic: Mapped["SyllabusSubtopic"] = relationship(
        back_populates="learning_objectives"
    )


class SyllabusResource(Base):
    __tablename__ = "syllabus_resources"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    topic_id: Mapped[int] = mapped_column(
        ForeignKey("syllabus_topics.id"), nullable=False
    )
    resource_text: Mapped[str] = mapped_column(Text, nullable=False)
    resource_type: Mapped[str] = mapped_column(String(50), default="equipment")
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    topic: Mapped["SyllabusTopic"] = relationship(back_populates="resources")
