"""add_forum_and_announcements

Revision ID: d9f1a2b3c4e5
Revises: c7a91b2e4f30
Create Date: 2026-08-20 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "d9f1a2b3c4e5"
down_revision: Union[str, None] = "c7a91b2e4f30"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "stem_forum_posts",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "concept_id",
            sa.Integer(),
            sa.ForeignKey("stem_concepts.id"),
            nullable=True,
        ),
        sa.Column("subject_slug", sa.String(100), nullable=True, index=True),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("is_question", sa.Boolean(), server_default=sa.text("1")),
        sa.Column("is_resolved", sa.Boolean(), server_default=sa.text("0")),
        sa.Column("upvotes", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column(
            "view_count", sa.Integer(), server_default=sa.text("0"), nullable=False
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )

    op.create_table(
        "stem_forum_answers",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "post_id",
            sa.Integer(),
            sa.ForeignKey("stem_forum_posts.id"),
            nullable=False,
        ),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("is_accepted", sa.Boolean(), server_default=sa.text("0")),
        sa.Column("upvotes", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )

    op.create_table(
        "stem_forum_votes",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "post_id",
            sa.Integer(),
            sa.ForeignKey("stem_forum_posts.id"),
            nullable=True,
        ),
        sa.Column(
            "answer_id",
            sa.Integer(),
            sa.ForeignKey("stem_forum_answers.id"),
            nullable=True,
        ),
        sa.Column("value", sa.Integer(), server_default=sa.text("1"), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )

    op.create_table(
        "stem_announcements",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("author_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("subject_slug", sa.String(100), nullable=True),
        sa.Column("priority", sa.String(20), server_default="normal", nullable=False),
        sa.Column("is_pinned", sa.Boolean(), server_default=sa.text("0")),
        sa.Column(
            "target_audience", sa.String(20), server_default="all", nullable=False
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )

    op.create_table(
        "stem_content_reports",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "reporter_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False
        ),
        sa.Column("content_type", sa.String(50), nullable=False),
        sa.Column("content_id", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), server_default="pending", nullable=False),
        sa.Column(
            "reviewed_by",
            sa.Integer(),
            sa.ForeignKey("users.id"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )


def downgrade() -> None:
    op.drop_table("stem_content_reports")
    op.drop_table("stem_announcements")
    op.drop_table("stem_forum_votes")
    op.drop_table("stem_forum_answers")
    op.drop_table("stem_forum_posts")
