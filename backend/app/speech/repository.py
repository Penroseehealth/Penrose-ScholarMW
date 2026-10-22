"""Repository for the voice library and for cloned voice models."""

from __future__ import annotations

from collections.abc import Sequence

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.speech.exceptions import NotFoundError
from app.speech.models import VoiceModel, VoiceModelVersion, VoiceProfile


class VoiceProfileRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def list(self, include_archived: bool = False) -> Sequence[VoiceProfile]:
        stmt = select(VoiceProfile).order_by(
            VoiceProfile.is_default.desc(),
            VoiceProfile.display_name.asc(),
        )
        if not include_archived:
            stmt = stmt.where(VoiceProfile.is_archived == 0)
        return list(self.db.scalars(stmt))

    def get(self, profile_id: int) -> VoiceProfile:
        profile = self.db.get(VoiceProfile, profile_id)
        if not profile:
            raise NotFoundError("Voice", profile_id)
        return profile

    def by_voice_key(self, voice_key: str) -> VoiceProfile | None:
        stmt = select(VoiceProfile).where(VoiceProfile.voice_key == voice_key)
        return self.db.scalars(stmt).first()

    def create(self, **values) -> VoiceProfile:
        profile = VoiceProfile(**values)
        self.db.add(profile)
        self.db.commit()
        self.db.refresh(profile)
        return profile

    def save(self, profile: VoiceProfile) -> VoiceProfile:
        self.db.commit()
        self.db.refresh(profile)
        return profile

    def clear_default(self) -> None:
        self.db.execute(update(VoiceProfile).values(is_default=0))
        self.db.commit()

    def delete(self, profile_id: int) -> None:
        profile = self.get(profile_id)
        self.db.delete(profile)
        self.db.commit()


class VoiceModelRepository:
    """Persistence for cloned voices and their training runs."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def list(self, include_archived: bool = False) -> Sequence[VoiceModel]:
        stmt = select(VoiceModel).order_by(
            VoiceModel.is_default.desc(),
            VoiceModel.display_name.asc(),
        )
        if not include_archived:
            stmt = stmt.where(VoiceModel.is_archived == 0)
        return list(self.db.scalars(stmt))

    def get(self, voice_id: int) -> VoiceModel:
        model = self.db.get(VoiceModel, voice_id)
        if not model:
            raise NotFoundError("Voice", voice_id)
        return model

    def by_name(self, display_name: str) -> VoiceModel | None:
        stmt = select(VoiceModel).where(VoiceModel.display_name == display_name)
        return self.db.scalars(stmt).first()

    def add(self, model: VoiceModel) -> VoiceModel:
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return model

    def save(self, model: VoiceModel) -> VoiceModel:
        self.db.commit()
        self.db.refresh(model)
        return model

    def clear_default(self) -> None:
        self.db.execute(update(VoiceModel).values(is_default=0))
        self.db.commit()

    def delete(self, voice_id: int) -> None:
        model = self.get(voice_id)
        # The pointer is dropped before the rows it refers to. SQLite only
        # enforces the foreign key when `PRAGMA foreign_keys=ON`, so relying on
        # the cascade alone would leave an insert-order-dependent constraint
        # failure behind for anyone running with it enabled.
        model.current_version_id = None
        self.db.commit()
        # The versions cascade in the schema, but the children are removed
        # explicitly so a delete never leaves orphan training runs behind.
        for version in self.versions(voice_id):
            self.db.delete(version)
        self.db.delete(model)
        self.db.commit()

    # --- versions -----------------------------------------------------------

    def versions(self, voice_id: int) -> Sequence[VoiceModelVersion]:
        stmt = (
            select(VoiceModelVersion)
            .where(VoiceModelVersion.voice_model_id == voice_id)
            .order_by(VoiceModelVersion.version.desc())
        )
        return list(self.db.scalars(stmt))

    def get_version(self, version_id: int) -> VoiceModelVersion:
        version = self.db.get(VoiceModelVersion, version_id)
        if not version:
            raise NotFoundError("Voice model version", version_id)
        return version

    def add_version(self, version: VoiceModelVersion) -> VoiceModelVersion:
        self.db.add(version)
        self.db.commit()
        self.db.refresh(version)
        return version

    def save_version(self, version: VoiceModelVersion) -> VoiceModelVersion:
        self.db.commit()
        self.db.refresh(version)
        return version

    def delete_version(self, version: VoiceModelVersion) -> None:
        self.db.delete(version)
        self.db.commit()

    def next_version_number(self, voice_id: int) -> int:
        """1 for the first run, then one past the highest that exists.

        Counted from the max rather than the row count so a deleted run never
        makes the next retrain reuse a version number the user has already seen.
        """
        current = self.db.scalar(
            select(func.max(VoiceModelVersion.version)).where(
                VoiceModelVersion.voice_model_id == voice_id
            )
        )
        return int(current or 0) + 1
