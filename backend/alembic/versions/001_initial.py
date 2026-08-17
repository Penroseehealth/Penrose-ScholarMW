"""initial schema

Revision ID: 001_initial
Revises:
Create Date: 2026-08-16
"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    userrole = sa.Enum("student", "lecturer", "researcher", "admin", name="userrole")
    userrole.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("email", sa.String(255), unique=True, index=True, nullable=False),
        sa.Column("hashed_password", sa.String(255), nullable=False),
        sa.Column("full_name", sa.String(255), nullable=False),
        sa.Column("role", userrole, nullable=False, server_default="student"),
        sa.Column("is_active", sa.Boolean(), default=True),
        sa.Column("is_verified", sa.Boolean(), default=False),
        sa.Column("avatar_url", sa.String(500), nullable=True),
        sa.Column("phone", sa.String(20), nullable=True),
        sa.Column("institution", sa.String(255), nullable=True),
        sa.Column("department", sa.String(255), nullable=True),
        sa.Column("student_id", sa.String(50), nullable=True, unique=True),
        sa.Column("year_of_study", sa.Integer(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
    )

    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("token_hash", sa.String(255), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked", sa.Boolean(), default=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "courses",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("code", sa.String(20), unique=True, nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("level", sa.String(50), nullable=True),
        sa.Column("credits", sa.Integer(), default=3),
        sa.Column("semester", sa.String(20), nullable=True),
        sa.Column("year", sa.Integer(), nullable=True),
        sa.Column(
            "lecturer_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False
        ),
        sa.Column("is_active", sa.Boolean(), default=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "enrollments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "student_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False
        ),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=False
        ),
        sa.Column(
            "enrolled_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column("is_active", sa.Boolean(), default=True),
        sa.Column("progress_pct", sa.Float(), default=0.0),
        sa.Column("grade", sa.String(5), nullable=True),
    )

    op.create_table(
        "course_modules",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=False
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("order", sa.Integer(), default=0),
        sa.Column("is_published", sa.Boolean(), default=False),
    )

    op.create_table(
        "lessons",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "module_id",
            sa.Integer(),
            sa.ForeignKey("course_modules.id"),
            nullable=False,
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("content_type", sa.String(50), default="text"),
        sa.Column("content", sa.Text(), nullable=True),
        sa.Column("duration_minutes", sa.Integer(), nullable=True),
        sa.Column("order", sa.Integer(), default=0),
        sa.Column("is_published", sa.Boolean(), default=False),
    )

    op.create_table(
        "schedule_items",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=False
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("item_type", sa.String(50), nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("location", sa.String(255), nullable=True),
        sa.Column("recurrence", sa.String(50), nullable=True),
    )

    op.create_table(
        "assessments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=False
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("assessment_type", sa.String(50), nullable=False),
        sa.Column("total_marks", sa.Integer(), default=100),
        sa.Column("weight_pct", sa.Float(), default=0.0),
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_minutes", sa.Integer(), nullable=True),
        sa.Column("is_published", sa.Boolean(), default=False),
        sa.Column("ai_generated", sa.Boolean(), default=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "assessment_questions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "assessment_id",
            sa.Integer(),
            sa.ForeignKey("assessments.id"),
            nullable=False,
        ),
        sa.Column("question_text", sa.Text(), nullable=False),
        sa.Column("question_type", sa.String(50), nullable=False),
        sa.Column("marks", sa.Integer(), default=1),
        sa.Column("options", sa.Text(), nullable=True),
        sa.Column("correct_answer", sa.Text(), nullable=True),
        sa.Column("rubric", sa.Text(), nullable=True),
        sa.Column("learning_outcome", sa.String(255), nullable=True),
        sa.Column("order", sa.Integer(), default=0),
        sa.Column("difficulty", sa.String(20), default="medium"),
    )

    op.create_table(
        "submissions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "assessment_id",
            sa.Integer(),
            sa.ForeignKey("assessments.id"),
            nullable=False,
        ),
        sa.Column(
            "student_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False
        ),
        sa.Column("answers", sa.Text(), nullable=True),
        sa.Column("ai_suggested_marks", sa.Integer(), nullable=True),
        sa.Column("ai_feedback", sa.Text(), nullable=True),
        sa.Column("final_marks", sa.Integer(), nullable=True),
        sa.Column("lecturer_feedback", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), default="submitted"),
        sa.Column(
            "submitted_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column("graded_at", sa.DateTime(timezone=True), nullable=True),
    )

    op.create_table(
        "chat_sessions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(255), default="New Chat"),
        sa.Column("agent_type", sa.String(50), default="tutor"),
        sa.Column(
            "context_course_id",
            sa.Integer(),
            sa.ForeignKey("courses.id"),
            nullable=True,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "chat_messages",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "session_id",
            sa.Integer(),
            sa.ForeignKey("chat_sessions.id"),
            nullable=False,
        ),
        sa.Column("role", sa.String(20), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("sources", sa.Text(), nullable=True),
        sa.Column("token_count", sa.Integer(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "vault_documents",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("doc_type", sa.String(50), nullable=False),
        sa.Column("file_path", sa.String(500), nullable=False),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=True
        ),
        sa.Column(
            "uploaded_by", sa.Integer(), sa.ForeignKey("users.id"), nullable=False
        ),
        sa.Column("is_indexed", sa.Boolean(), default=False),
        sa.Column("tags", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("notif_type", sa.String(50), nullable=False),
        sa.Column("is_read", sa.Boolean(), default=False),
        sa.Column("link", sa.String(500), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "research_projects",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("owner_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", sa.String(30), default="draft"),
        sa.Column("research_question", sa.Text(), nullable=True),
        sa.Column("methodology", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "research_notes",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "project_id",
            sa.Integer(),
            sa.ForeignKey("research_projects.id"),
            nullable=False,
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("note_type", sa.String(30), default="general"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )


def downgrade() -> None:
    op.drop_table("research_notes")
    op.drop_table("research_projects")
    op.drop_table("notifications")
    op.drop_table("vault_documents")
    op.drop_table("chat_messages")
    op.drop_table("chat_sessions")
    op.drop_table("submissions")
    op.drop_table("assessment_questions")
    op.drop_table("assessments")
    op.drop_table("schedule_items")
    op.drop_table("lessons")
    op.drop_table("course_modules")
    op.drop_table("enrollments")
    op.drop_table("courses")
    op.drop_table("refresh_tokens")
    op.drop_table("users")
    sa.Enum(name="userrole").drop(op.get_bind(), checkfirst=True)
