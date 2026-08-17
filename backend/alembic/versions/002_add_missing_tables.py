"""add missing tables from models

Revision ID: 002_add_missing_tables
Revises: 001_initial
Create Date: 2026-08-17
"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "002_add_missing_tables"
down_revision: Union[str, None] = "001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "vault_documents",
        sa.Column("content", sa.Text(), nullable=True),
    )

    op.create_table(
        "knowledge_layers",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("layer_type", sa.String(50), nullable=False),
        sa.Column("institution_id", sa.Integer(), nullable=True),
        sa.Column("faculty", sa.String(255), nullable=True),
        sa.Column("department", sa.String(255), nullable=True),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=True
        ),
        sa.Column("owner_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), default=True),
        sa.Column("priority", sa.Integer(), default=0),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "knowledge_documents",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "layer_id",
            sa.Integer(),
            sa.ForeignKey("knowledge_layers.id"),
            nullable=False,
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("content", sa.Text(), nullable=True),
        sa.Column("doc_type", sa.String(50), nullable=False),
        sa.Column("file_path", sa.String(500), nullable=True),
        sa.Column("tags", sa.Text(), nullable=True),
        sa.Column("is_indexed", sa.Boolean(), default=False),
        sa.Column(
            "uploaded_by", sa.Integer(), sa.ForeignKey("users.id"), nullable=True
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "institution_knowledge",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=False
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("doc_type", sa.String(50), nullable=False),
        sa.Column("access_level", sa.String(30), default="course"),
        sa.Column(
            "uploaded_by", sa.Integer(), sa.ForeignKey("users.id"), nullable=False
        ),
        sa.Column("is_ai_exclusive", sa.Boolean(), default=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "student_performance",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "student_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False
        ),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=False
        ),
        sa.Column("overall_score", sa.Float(), default=0.0),
        sa.Column("trend", sa.String(10), default="stable"),
        sa.Column("weak_areas", sa.Text(), nullable=True),
        sa.Column("strong_areas", sa.Text(), nullable=True),
        sa.Column("ai_insights", sa.Text(), nullable=True),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "course_analytics",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=False
        ),
        sa.Column("class_average", sa.Float(), default=0.0),
        sa.Column("attendance_pct", sa.Float(), default=0.0),
        sa.Column("assignment_completion", sa.Float(), default=0.0),
        sa.Column("difficult_topics", sa.Text(), nullable=True),
        sa.Column("engagement_trend", sa.Text(), nullable=True),
        sa.Column("ai_insights", sa.Text(), nullable=True),
        sa.Column("students_at_risk", sa.Text(), nullable=True),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "learning_plans",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "student_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("plan_type", sa.String(30), default="weekly"),
        sa.Column("start_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("is_active", sa.Boolean(), default=True),
        sa.Column("ai_generated", sa.Boolean(), default=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "learning_plan_items",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "plan_id",
            sa.Integer(),
            sa.ForeignKey("learning_plans.id"),
            nullable=False,
        ),
        sa.Column("day_of_week", sa.String(10), nullable=False),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=True
        ),
        sa.Column("topic", sa.String(255), nullable=False),
        sa.Column("activity_type", sa.String(50), default="study"),
        sa.Column("duration_minutes", sa.Integer(), default=30),
        sa.Column("order", sa.Integer(), default=0),
        sa.Column("is_completed", sa.Boolean(), default=False),
    )

    op.create_table(
        "examinations",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "course_id", sa.Integer(), sa.ForeignKey("courses.id"), nullable=False
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("total_marks", sa.Integer(), default=100),
        sa.Column("duration_minutes", sa.Integer(), default=120),
        sa.Column("exam_type", sa.String(30), default="final"),
        sa.Column("is_timed", sa.Boolean(), default=True),
        sa.Column("allow_offline", sa.Boolean(), default=False),
        sa.Column("randomize_questions", sa.Boolean(), default=False),
        sa.Column("status", sa.String(20), default="draft"),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_by", sa.Integer(), sa.ForeignKey("users.id"), nullable=False
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "exam_questions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "examination_id",
            sa.Integer(),
            sa.ForeignKey("examinations.id"),
            nullable=False,
        ),
        sa.Column("question_text", sa.Text(), nullable=False),
        sa.Column("question_type", sa.String(50), nullable=False),
        sa.Column("marks", sa.Integer(), default=1),
        sa.Column("options", sa.Text(), nullable=True),
        sa.Column("correct_answer", sa.Text(), nullable=True),
        sa.Column("rubric", sa.Text(), nullable=True),
        sa.Column("learning_outcome", sa.String(255), nullable=True),
        sa.Column("bloom_level", sa.String(30), nullable=True),
        sa.Column("difficulty", sa.String(20), default="medium"),
        sa.Column("reference", sa.Text(), nullable=True),
        sa.Column("order", sa.Integer(), default=0),
    )

    op.create_table(
        "exam_submissions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "examination_id",
            sa.Integer(),
            sa.ForeignKey("examinations.id"),
            nullable=False,
        ),
        sa.Column(
            "student_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False
        ),
        sa.Column("answers", sa.Text(), nullable=True),
        sa.Column("ai_marks", sa.Integer(), nullable=True),
        sa.Column("ai_feedback", sa.Text(), nullable=True),
        sa.Column("final_marks", sa.Integer(), nullable=True),
        sa.Column("lecturer_feedback", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), default="in_progress"),
        sa.Column(
            "started_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("graded_at", sa.DateTime(timezone=True), nullable=True),
    )

    op.create_table(
        "evidence_cards",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "project_id",
            sa.Integer(),
            sa.ForeignKey("research_projects.id"),
            nullable=False,
        ),
        sa.Column("paper_title", sa.String(500), nullable=False),
        sa.Column("authors", sa.Text(), nullable=True),
        sa.Column("year", sa.Integer(), nullable=True),
        sa.Column("doi", sa.String(255), nullable=True),
        sa.Column("study_design", sa.String(100), nullable=True),
        sa.Column("population", sa.String(255), nullable=True),
        sa.Column("sample_size", sa.String(50), nullable=True),
        sa.Column("setting", sa.String(255), nullable=True),
        sa.Column("exposure", sa.String(255), nullable=True),
        sa.Column("outcome", sa.String(255), nullable=True),
        sa.Column("main_finding", sa.Text(), nullable=True),
        sa.Column("limitations", sa.Text(), nullable=True),
        sa.Column("conclusions", sa.Text(), nullable=True),
        sa.Column("is_verified", sa.Boolean(), default=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "evidence_matrices",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "project_id",
            sa.Integer(),
            sa.ForeignKey("research_projects.id"),
            nullable=False,
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("columns_config", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "writing_projects",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("owner_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("project_type", sa.String(50), default="essay"),
        sa.Column("status", sa.String(20), default="draft"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "writing_sections",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "project_id",
            sa.Integer(),
            sa.ForeignKey("writing_projects.id"),
            nullable=False,
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("section_type", sa.String(50), nullable=False),
        sa.Column("content", sa.Text(), nullable=True),
        sa.Column("order", sa.Integer(), default=0),
        sa.Column("word_count", sa.Integer(), default=0),
        sa.Column("ai_suggestions", sa.Text(), nullable=True),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "reference_collections",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("owner_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "citations",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "collection_id",
            sa.Integer(),
            sa.ForeignKey("reference_collections.id"),
            nullable=False,
        ),
        sa.Column("title", sa.String(500), nullable=False),
        sa.Column("authors", sa.Text(), nullable=True),
        sa.Column("year", sa.Integer(), nullable=True),
        sa.Column("doi", sa.String(255), nullable=True),
        sa.Column("journal", sa.String(255), nullable=True),
        sa.Column("volume", sa.String(50), nullable=True),
        sa.Column("pages", sa.String(50), nullable=True),
        sa.Column("url", sa.String(500), nullable=True),
        sa.Column("citation_style", sa.String(20), nullable=True),
        sa.Column("tags", sa.Text(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "sync_records",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("entity_type", sa.String(50), nullable=False),
        sa.Column("entity_id", sa.String(100), nullable=False),
        sa.Column("action", sa.String(20), nullable=False),
        sa.Column("payload", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), default="pending"),
        sa.Column("merged_payload", sa.Text(), nullable=True),
        sa.Column("resolution", sa.String(20), nullable=True),
        sa.Column("local_timestamp", sa.DateTime(timezone=True), nullable=True),
        sa.Column("synced_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "scholar_points",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id"),
            unique=True,
            nullable=False,
        ),
        sa.Column("total_earned", sa.Integer(), default=0),
        sa.Column("level", sa.Integer(), default=1),
        sa.Column("streak_days", sa.Integer(), default=0),
        sa.Column("last_activity_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "achievements",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("icon", sa.String(50), nullable=True),
        sa.Column("category", sa.String(50), default="general"),
        sa.Column("points_required", sa.Integer(), default=0),
        sa.Column("criteria", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "user_achievements",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "achievement_id",
            sa.Integer(),
            sa.ForeignKey("achievements.id"),
            nullable=False,
        ),
        sa.Column(
            "earned_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "notification_preferences",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id"),
            unique=True,
            nullable=False,
        ),
        sa.Column("assessment_reminders", sa.Boolean(), default=True),
        sa.Column("study_nudges", sa.Boolean(), default=True),
        sa.Column("resource_alerts", sa.Boolean(), default=True),
        sa.Column("weekly_summary", sa.Boolean(), default=True),
        sa.Column("ai_insights", sa.Boolean(), default=True),
        sa.Column("quiet_hours_start", sa.String(5), nullable=True),
        sa.Column("quiet_hours_end", sa.String(5), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "institutions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("code", sa.String(20), unique=True, nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("website", sa.String(500), nullable=True),
        sa.Column("logo_url", sa.String(500), nullable=True),
        sa.Column("country", sa.String(100), default="Malawi"),
        sa.Column("city", sa.String(100), nullable=True),
        sa.Column("is_active", sa.Boolean(), default=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "audit_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("action", sa.String(100), nullable=False),
        sa.Column("resource_type", sa.String(50), nullable=False),
        sa.Column("resource_id", sa.String(100), nullable=True),
        sa.Column("details", sa.Text(), nullable=True),
        sa.Column("ip_address", sa.String(50), nullable=True),
        sa.Column("user_agent", sa.String(500), nullable=True),
        sa.Column("institution_id", sa.Integer(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "conversations",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title", sa.String(255), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "conversation_members",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "conversation_id",
            sa.Integer(),
            sa.ForeignKey("conversations.id"),
            nullable=False,
        ),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "joined_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )

    op.create_table(
        "messages",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "conversation_id",
            sa.Integer(),
            sa.ForeignKey("conversations.id"),
            nullable=False,
        ),
        sa.Column("sender_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column("is_read", sa.Boolean(), default=False),
    )


def downgrade() -> None:
    op.drop_table("messages")
    op.drop_table("conversation_members")
    op.drop_table("conversations")
    op.drop_table("audit_logs")
    op.drop_table("institutions")
    op.drop_table("notification_preferences")
    op.drop_table("user_achievements")
    op.drop_table("achievements")
    op.drop_table("scholar_points")
    op.drop_table("sync_records")
    op.drop_table("citations")
    op.drop_table("reference_collections")
    op.drop_table("writing_sections")
    op.drop_table("writing_projects")
    op.drop_table("evidence_matrices")
    op.drop_table("evidence_cards")
    op.drop_table("exam_submissions")
    op.drop_table("exam_questions")
    op.drop_table("examinations")
    op.drop_table("learning_plan_items")
    op.drop_table("learning_plans")
    op.drop_table("course_analytics")
    op.drop_table("student_performance")
    op.drop_table("institution_knowledge")
    op.drop_table("knowledge_documents")
    op.drop_table("knowledge_layers")
    op.drop_column("vault_documents", "content")
