"""add_proctor_and_certificate_tables

Revision ID: e0f2a3b4c5d6
Revises: d9f1a2b3c4e5
Create Date: 2026-08-20 12:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "e0f2a3b4c5d6"
down_revision: Union[str, None] = "d9f1a2b3c4e5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "exam_proctor_events",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("exam_type", sa.String(50), nullable=False),
        sa.Column("exam_id", sa.Integer(), nullable=False),
        sa.Column("event_type", sa.String(50), nullable=False),
        sa.Column("event_data", sa.Text(), nullable=True),
        sa.Column("ip_address", sa.String(100), nullable=True),
        sa.Column("user_agent", sa.String(500), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        op.f("ix_exam_proctor_events_id"),
        "exam_proctor_events",
        ["id"],
        unique=False,
    )

    op.create_table(
        "stem_user_certificates",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("certificate_type", sa.String(50), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("subject_slug", sa.String(100), nullable=True),
        sa.Column("score", sa.Float(), nullable=True),
        sa.Column(
            "issued_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column("certificate_data", sa.Text(), nullable=True),
    )
    op.create_index(
        op.f("ix_stem_user_certificates_id"),
        "stem_user_certificates",
        ["id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_stem_user_certificates_id"), table_name="stem_user_certificates"
    )
    op.drop_table("stem_user_certificates")
    op.drop_index(op.f("ix_exam_proctor_events_id"), table_name="exam_proctor_events")
    op.drop_table("exam_proctor_events")
