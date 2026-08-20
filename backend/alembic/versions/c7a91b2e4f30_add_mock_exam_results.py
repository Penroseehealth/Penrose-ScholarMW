"""add mock exam results

Revision ID: c7a91b2e4f30
Revises: 4836e54d6751
Create Date: 2026-08-20 12:00:00.000000
"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "c7a91b2e4f30"
down_revision: Union[str, None] = "4836e54d6751"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "mock_exam_results",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("subject_slug", sa.String(100), nullable=False, index=True),
        sa.Column("total_questions", sa.Integer(), nullable=False),
        sa.Column("correct_count", sa.Integer(), nullable=False),
        sa.Column("total_marks", sa.Integer(), server_default="0"),
        sa.Column("score_marks", sa.Integer(), server_default="0"),
        sa.Column("percentage", sa.Float(), server_default="0.0"),
        sa.Column("time_taken_seconds", sa.Integer(), server_default="0"),
        sa.Column("time_limit_minutes", sa.Integer(), server_default="60"),
        sa.Column("difficulty_breakdown", sa.Text(), nullable=True),
        sa.Column("concept_breakdown", sa.Text(), nullable=True),
        sa.Column("bloom_breakdown", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now()
        ),
    )


def downgrade() -> None:
    op.drop_table("mock_exam_results")
