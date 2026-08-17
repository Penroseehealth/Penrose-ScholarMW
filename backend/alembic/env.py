from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.engine import Connection

from alembic import context
from app.config.settings import get_settings
from app.database.engine import Base
from app.models import models  # noqa: F401 — ensure all models are registered

config = context.config
settings = get_settings()
config.set_main_option(
    "sqlalchemy.url",
    settings.DATABASE_URL_SYNC.replace("+asyncpg", "").replace("+psycopg2", ""),
)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


def run_async_migrations() -> None:
    import sqlalchemy as sa

    connectable = sa.create_engine(
        config.get_main_option("sqlalchemy.url"),
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        do_run_migrations(connection)


def run_migrations_online() -> None:
    run_async_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
