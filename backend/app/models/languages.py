from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.engine import Base


class Language(Base):
    __tablename__ = "languages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    slug: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    native_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon: Mapped[str | None] = mapped_column(String(50), nullable=True)
    color: Mapped[str | None] = mapped_column(String(50), nullable=True)
    level_system: Mapped[str | None] = mapped_column(String(255), nullable=True)
    level_system_description: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    levels: Mapped[list["LanguageLevel"]] = relationship(back_populates="language")


class LanguageLevel(Base):
    __tablename__ = "language_levels"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    language_id: Mapped[int] = mapped_column(ForeignKey("languages.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    slug: Mapped[str] = mapped_column(String(100), nullable=False)
    form_mapping: Mapped[str | None] = mapped_column(String(50), nullable=True)
    proficiency_label: Mapped[str | None] = mapped_column(String(100), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    language: Mapped["Language"] = relationship(back_populates="levels")
    units: Mapped[list["LanguageUnit"]] = relationship(back_populates="level")


class LanguageUnit(Base):
    __tablename__ = "language_units"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    level_id: Mapped[int] = mapped_column(
        ForeignKey("language_levels.id"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    level: Mapped["LanguageLevel"] = relationship(back_populates="units")
    lessons: Mapped[list["LanguageLesson"]] = relationship(back_populates="unit")


class LanguageLesson(Base):
    __tablename__ = "language_lessons"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    unit_id: Mapped[int] = mapped_column(
        ForeignKey("language_units.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    lesson_type: Mapped[str] = mapped_column(String(50), default="grammar")
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    unit: Mapped["LanguageUnit"] = relationship(back_populates="lessons")
    vocabulary: Mapped[list["LanguageVocabulary"]] = relationship(
        back_populates="lesson"
    )
    grammar_rules: Mapped[list["LanguageGrammarRule"]] = relationship(
        back_populates="lesson"
    )


class LanguageVocabulary(Base):
    __tablename__ = "language_vocabulary"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    lesson_id: Mapped[int] = mapped_column(
        ForeignKey("language_lessons.id"), nullable=False
    )
    word: Mapped[str] = mapped_column(String(255), nullable=False)
    translation: Mapped[str] = mapped_column(String(255), nullable=False)
    pronunciation: Mapped[str | None] = mapped_column(String(255), nullable=True)
    part_of_speech: Mapped[str | None] = mapped_column(String(50), nullable=True)
    example_sentence: Mapped[str | None] = mapped_column(Text, nullable=True)
    example_translation: Mapped[str | None] = mapped_column(Text, nullable=True)
    theme: Mapped[str | None] = mapped_column(String(100), nullable=True)
    difficulty: Mapped[str] = mapped_column(String(20), default="beginner")
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    lesson: Mapped["LanguageLesson"] = relationship(back_populates="vocabulary")


class LanguageGrammarRule(Base):
    __tablename__ = "language_grammar_rules"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    lesson_id: Mapped[int] = mapped_column(
        ForeignKey("language_lessons.id"), nullable=False
    )
    rule_name: Mapped[str] = mapped_column(String(255), nullable=False)
    rule_category: Mapped[str] = mapped_column(String(100), default="basic")
    explanation: Mapped[str] = mapped_column(Text, nullable=False)
    examples: Mapped[str | None] = mapped_column(Text, nullable=True)
    contrast: Mapped[str | None] = mapped_column(Text, nullable=True)
    difficulty: Mapped[str] = mapped_column(String(20), default="beginner")
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    lesson: Mapped["LanguageLesson"] = relationship(back_populates="grammar_rules")


class LanguageUserProgress(Base):
    __tablename__ = "language_user_progress"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    language_id: Mapped[int] = mapped_column(ForeignKey("languages.id"), nullable=False)
    current_level_id: Mapped[int | None] = mapped_column(
        ForeignKey("language_levels.id"), nullable=True
    )
    vocabulary_mastered: Mapped[int] = mapped_column(Integer, default=0)
    vocabulary_learning: Mapped[int] = mapped_column(Integer, default=0)
    grammar_mastered: Mapped[int] = mapped_column(Integer, default=0)
    grammar_learning: Mapped[int] = mapped_column(Integer, default=0)
    listening_score: Mapped[float] = mapped_column(Float, default=0.0)
    speaking_score: Mapped[float] = mapped_column(Float, default=0.0)
    reading_score: Mapped[float] = mapped_column(Float, default=0.0)
    writing_score: Mapped[float] = mapped_column(Float, default=0.0)
    pronunciation_score: Mapped[float] = mapped_column(Float, default=0.0)
    overall_mastery: Mapped[float] = mapped_column(Float, default=0.0)
    streak_days: Mapped[int] = mapped_column(Integer, default=0)
    total_study_minutes: Mapped[int] = mapped_column(Integer, default=0)
    lessons_completed: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )


class LanguagePlacement(Base):
    __tablename__ = "language_placements"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    language_id: Mapped[int] = mapped_column(ForeignKey("languages.id"), nullable=False)
    vocab_score: Mapped[float] = mapped_column(Float, default=0.0)
    grammar_score: Mapped[float] = mapped_column(Float, default=0.0)
    listening_score: Mapped[float] = mapped_column(Float, default=0.0)
    reading_score: Mapped[float] = mapped_column(Float, default=0.0)
    writing_score: Mapped[float] = mapped_column(Float, default=0.0)
    speaking_score: Mapped[float] = mapped_column(Float, default=0.0)
    recommended_level_id: Mapped[int | None] = mapped_column(
        ForeignKey("language_levels.id"), nullable=True
    )
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
