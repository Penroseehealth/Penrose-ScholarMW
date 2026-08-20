"""add group sessions

Revision ID: 4836e54d6751
Revises: add_vault_file_metadata
Create Date: 2026-08-20 00:02:38.786649
"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "4836e54d6751"
down_revision: Union[str, None] = "add_vault_file_metadata"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "stem_group_sessions",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "group_id",
            sa.Integer(),
            sa.ForeignKey("stem_study_groups.id"),
            nullable=False,
        ),
        sa.Column(
            "started_by", sa.Integer(), sa.ForeignKey("users.id"), nullable=False
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column(
            "started_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )
    op.create_table(
        "stem_group_session_concepts",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "session_id",
            sa.Integer(),
            sa.ForeignKey("stem_group_sessions.id"),
            nullable=False,
        ),
        sa.Column(
            "concept_id",
            sa.Integer(),
            sa.ForeignKey("stem_concepts.id"),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_table("stem_group_session_concepts")
    op.drop_table("stem_group_sessions")
