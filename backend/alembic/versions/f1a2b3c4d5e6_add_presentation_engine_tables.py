"""add presentation engine tables

Revision ID: f1a2b3c4d5e6
Revises: e0f2a3b4c5d6
Create Date: 2026-11-06 12:50:00.000000

Phase 1 of the authorized Interactive AI Presentation Engine implementation.
Creates the nine persistent tables for presentations, slides, live sessions,
participants, questions, instructions, transcripts, session events and
recording-consent history. Column definitions mirror
``app/models/presentation.py`` exactly (strings for enum values, Text for
JSON payloads, sparse integer slide positions).

Note: the live database was created via ``Base.metadata.create_all`` before
Alembic was adopted here, so it is stamped at ``e0f2a3b4c5d6`` (procedure,
2026-11-06) before this revision is applied.
"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "f1a2b3c4d5e6"
down_revision: Union[str, None] = "e0f2a3b4c5d6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "presentations",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("owner_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(255), nullable=False, server_default=""),
        sa.Column("config_json", sa.Text(), nullable=True),
        sa.Column("source_summary", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_presentations_owner_id", "presentations", ["owner_id"])

    op.create_table(
        "presentation_slides",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "presentation_id",
            sa.String(64),
            sa.ForeignKey("presentations.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("slide_id", sa.String(64), nullable=False),
        sa.Column("slide_type", sa.String(50), nullable=False, server_default="content"),
        sa.Column("title", sa.String(255), nullable=False, server_default=""),
        sa.Column("bullets_json", sa.Text(), nullable=True),
        sa.Column("body", sa.Text(), nullable=True),
        sa.Column("speaker_notes", sa.Text(), nullable=True),
        sa.Column("citation", sa.Text(), nullable=True),
        sa.Column("layout", sa.String(50), nullable=False, server_default="title_and_content"),
        sa.Column("learning_objective", sa.Text(), nullable=True),
        sa.UniqueConstraint("presentation_id", "slide_id", name="uq_presentation_slide_ids"),
    )
    op.create_index("ix_presentation_slides_id", "presentation_slides", ["id"])
    op.create_index(
        "ix_presentation_slides_deck_pos", "presentation_slides", ["presentation_id", "position"]
    )

    op.create_table(
        "presentation_sessions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("presentation_id", sa.String(64), sa.ForeignKey("presentations.id"), nullable=False),
        sa.Column("presenter_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("room_name", sa.String(80), nullable=False, unique=True),
        sa.Column("join_code_hash", sa.String(128), nullable=True),
        sa.Column("pres_state", sa.String(20), nullable=False, server_default="idle"),
        sa.Column("ai_state", sa.String(20), nullable=False, server_default="idle"),
        sa.Column("ai_policy", sa.String(20), nullable=False, server_default="approval"),
        sa.Column("voice_owner", sa.String(10), nullable=False, server_default="none"),
        sa.Column("voice_lease_token", sa.String(36), nullable=True),
        sa.Column("voice_lease_expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("voice_next_allowed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("presenter_heartbeat_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("presenter_lost_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("grace_period_s", sa.Integer(), nullable=False, server_default="180"),
        sa.Column("reconnect_window_s", sa.Integer(), nullable=False, server_default="3600"),
        sa.Column("recording_active", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("recording_recording_id", sa.String(64), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("end_reason", sa.String(20), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_presentation_sessions_presenter_id", "presentation_sessions", ["presenter_id"])
    op.create_index("ix_presentation_sessions_state", "presentation_sessions", ["pres_state", "ai_state"])

    op.create_table(
        "presentation_participants",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "session_id",
            sa.String(36),
            sa.ForeignKey("presentation_sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("display_name", sa.String(128), nullable=False, server_default="Guest"),
        sa.Column("role", sa.String(20), nullable=False, server_default="attendee"),
        sa.Column("guest_token_hash", sa.String(128), nullable=True),
        sa.Column("joined_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("left_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reconnected_count", sa.Integer(), nullable=False, server_default="0"),
        sa.UniqueConstraint("session_id", "user_id", name="uq_participant_session_user"),
    )
    op.create_index("ix_presentation_participants_id", "presentation_participants", ["id"])
    op.create_index("ix_presentation_participants_user_id", "presentation_participants", ["user_id"])
    op.create_index("ix_participants_session", "presentation_participants", ["session_id"])

    op.create_table(
        "presentation_questions",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "session_id",
            sa.String(36),
            sa.ForeignKey("presentation_sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "participant_id",
            sa.Integer(),
            sa.ForeignKey("presentation_participants.id"),
            nullable=False,
        ),
        sa.Column("source", sa.String(10), nullable=False, server_default="text"),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("audio_recording_id", sa.String(64), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="raised"),
        sa.Column("ai_answered", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("answer_text", sa.Text(), nullable=True),
        sa.Column("idempotency_key", sa.String(64), nullable=True),
        sa.Column("decided_by", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint(
            "session_id", "participant_id", "idempotency_key", name="uq_question_idempotency"
        ),
    )
    op.create_index("ix_presentation_questions_id", "presentation_questions", ["id"])
    op.create_index("ix_presentation_questions_status", "presentation_questions", ["status"])
    op.create_index("ix_presentation_questions_created_at", "presentation_questions", ["created_at"])
    op.create_index("ix_questions_session_status", "presentation_questions", ["session_id", "status"])

    op.create_table(
        "presentation_instructions",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "session_id",
            sa.String(36),
            sa.ForeignKey("presentation_sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("presenter_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("kind", sa.String(20), nullable=False, server_default="correction"),
        sa.Column("target_slide_id", sa.String(64), nullable=True),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("applied_to_context", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_presentation_instructions_id", "presentation_instructions", ["id"])
    op.create_index("ix_presentation_instructions_created_at", "presentation_instructions", ["created_at"])

    op.create_table(
        "presentation_transcript_events",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "session_id",
            sa.String(36),
            sa.ForeignKey("presentation_sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "participant_id",
            sa.Integer(),
            sa.ForeignKey("presentation_participants.id"),
            nullable=True,
        ),
        sa.Column("speaker_label", sa.String(128), nullable=False, server_default=""),
        sa.Column("source", sa.String(20), nullable=False, server_default="attendee"),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("started_ms", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("ended_ms", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_presentation_transcript_events_id", "presentation_transcript_events", ["id"])
    op.create_index("ix_transcript_session_time", "presentation_transcript_events", ["session_id", "created_at"])

    op.create_table(
        "presentation_session_events",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "session_id",
            sa.String(36),
            sa.ForeignKey("presentation_sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("seq", sa.Integer(), nullable=False),
        sa.Column("event_key", sa.String(64), nullable=False),
        sa.Column("event_type", sa.String(50), nullable=False),
        sa.Column("actor_role", sa.String(20), nullable=False, server_default="system"),
        sa.Column("actor_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("persistence", sa.String(12), nullable=False, server_default="persistent"),
        sa.Column("payload_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("session_id", "seq", name="uq_event_session_seq"),
        sa.UniqueConstraint("session_id", "event_key", name="uq_event_session_key"),
    )
    op.create_index("ix_presentation_session_events_id", "presentation_session_events", ["id"])
    op.create_index("ix_presentation_session_events_created_at", "presentation_session_events", ["created_at"])
    op.create_index("ix_events_session_seq", "presentation_session_events", ["session_id", "seq"])

    op.create_table(
        "presentation_recording_consents",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "session_id",
            sa.String(36),
            sa.ForeignKey("presentation_sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "participant_id",
            sa.Integer(),
            sa.ForeignKey("presentation_participants.id"),
            nullable=False,
        ),
        sa.Column("decision", sa.String(12), nullable=False),
        sa.Column("scope", sa.String(20), nullable=False, server_default="session_audio"),
        sa.Column("granted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("withdrawn_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("prev_record_id", sa.Integer(), nullable=True),
        sa.Column("recorded_by_endpoint", sa.String(80), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_presentation_recording_consents_id", "presentation_recording_consents", ["id"])
    op.create_index(
        "ix_consents_session_participant", "presentation_recording_consents", ["session_id", "participant_id"]
    )


def downgrade() -> None:
    op.drop_table("presentation_recording_consents")
    op.drop_table("presentation_session_events")
    op.drop_table("presentation_transcript_events")
    op.drop_table("presentation_instructions")
    op.drop_table("presentation_questions")
    op.drop_table("presentation_participants")
    op.drop_table("presentation_sessions")
    op.drop_table("presentation_slides")
    op.drop_table("presentations")
