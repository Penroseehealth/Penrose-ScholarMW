"""add file_name and file_size to vault_documents

Revision ID: add_vault_file_metadata
Revises: a6fe10720778
Create Date: 2026-08-19

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "add_vault_file_metadata"
down_revision: Union[str, None] = "a6fe10720778"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "vault_documents", sa.Column("file_name", sa.String(255), nullable=True)
    )
    op.add_column(
        "vault_documents", sa.Column("file_size", sa.Integer(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("vault_documents", "file_name")
    op.drop_column("vault_documents", "file_size")
