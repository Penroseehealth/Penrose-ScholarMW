from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config.settings import get_settings

settings = get_settings()


def _async_url(url: str) -> str:
    if url.startswith("postgres://"):
        return "postgresql+asyncpg://" + url[len("postgres://") :]
    if url.startswith("postgresql://"):
        return "postgresql+asyncpg://" + url[len("postgresql://") :]
    return url


engine = create_async_engine(
    _async_url(settings.DATABASE_URL),
    echo=settings.ENVIRONMENT == "development",
)

if engine.url.get_backend_name() == "sqlite":

    @event.listens_for(engine.sync_engine, "connect")
    def _sqlite_pragmas(dbapi_connection, _connection_record) -> None:
        """Make SQLite survive concurrent reads while a write is in flight.

        The default rollback journal serialises writers and readers, so a save
        that commits while the UI is polling can block until the busy timeout
        expires (which the user experiences as "saving is taking forever").
        WAL allows reads during a write, NORMAL drops the per-commit fsync, and
        the busy timeout keeps the remaining writer/writer overlap patient
        instead of failing fast.
        """
        cursor = dbapi_connection.cursor()
        try:
            cursor.execute("PRAGMA journal_mode=WAL")
            cursor.execute("PRAGMA synchronous=NORMAL")
            cursor.execute("PRAGMA busy_timeout=5000")
        finally:
            cursor.close()


async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:  # type: ignore[misc]
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()
