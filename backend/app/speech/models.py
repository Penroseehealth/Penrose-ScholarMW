"""Two kinds of voice in MY VOICES.

`VoiceProfile` is a **selection**: one of the fixed engine voices Groq Canopy
Orpheus can already speak. It stores an engine voice id rather than audio
because the engine has no cloning endpoint, and `voice_key` is validated against
the provider's advertised list so a stored entry can never point at a voice the
engine cannot produce.

`VoiceModel` is a **clone**: a speaker the user actually trained from their own
recording, which is what makes "Use for Penrose" meaningful rather than a
rename. Cloning needs a provider that mints its own voice ids (ElevenLabs), and
that provider hands back an id the rest of Penrose can synthesize with.

Clones are split across two tables because a retrain must never destroy a
working model (Â§17):

* `VoiceModel` is the logical voice the user names ("My Natural Voice"). It owns
  the consent record, the default flag, and a pointer to the version in use.
* `VoiceModelVersion` is one training run, each with its own
  `provider_voice_id`, so a bad retrain is recovered by promoting an older
  version rather than re-recording.

`status` is a real column, not something inferred. A clone is only offered to
the conversation layer once the provider has confirmed a usable voice id, so a
`training` or `failed` row can never be spoken with.

`init_db()` calls `Base.metadata.create_all`, so these tables are created on
startup without a migration; `_ensure_missing_columns` then adds any newly
declared nullable column to an existing database.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database.engine import Base


class VoiceProfile(Base):
    __tablename__ = "voice_profiles"

    id: Mapped[int] = mapped_column(primary_key=True)

    # Provider voice id used for synthesis, e.g. "hannah". Unique so the library
    # holds one entry per real voice and the default is never ambiguous.
    voice_key: Mapped[str] = mapped_column(String(64), unique=True, index=True)

    # User-facing name, e.g. "Amin Natural".
    display_name: Mapped[str] = mapped_column(String(120))

    # Accent/style descriptors the user records with the entry. These are notes
    # about the selected voice, not a conversion instruction: nothing here
    # rewrites the user's speech into another accent.
    accent_label: Mapped[str] = mapped_column(String(80), default="")
    style_note: Mapped[str] = mapped_column(String(300), default="")
    language: Mapped[str] = mapped_column(String(40), default="")

    # 1/0 flags rather than booleans to match the rest of the schema.
    is_default: Mapped[int] = mapped_column(Integer, default=0, index=True)
    is_archived: Mapped[int] = mapped_column(Integer, default=0, index=True)

    # Provenance, so the UI can explain where an entry came from without
    # inventing a training history the engine does not have.
    # engine | my_voices
    source: Mapped[str] = mapped_column(String(20), default="engine")

    created_at: Mapped[str] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[str] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


# Lifecycle shared by a voice and each of its training runs. `ready` is the only
# state the conversation layer will speak with; everything else is visible in
# MY VOICES so the user can see the work happening instead of a voice that
# silently never appears.
VOICE_STATUSES = ("queued", "training", "processing", "ready", "failed")


class VoiceModel(Base):
    """One cloned voice in MY VOICES â€” the thing "Use for Penrose" selects."""

    __tablename__ = "voice_models"

    id: Mapped[int] = mapped_column(primary_key=True)

    display_name: Mapped[str] = mapped_column(String(120), index=True)

    # Which provider minted the speaker model behind this voice. Kept on the row
    # (not only on the version) so a provider outage can be reported for every
    # affected voice at once.
    provider: Mapped[str] = mapped_column(String(40), default="")

    language: Mapped[str] = mapped_column(String(40), default="")
    accent_label: Mapped[str] = mapped_column(String(80), default="")

    status: Mapped[str] = mapped_column(String(20), default="queued", index=True)

    # The version currently spoken with. Null until a training run succeeds, so
    # a voice that has never trained is never treated as usable.
    current_version_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("voice_model_versions.id", use_alter=True), nullable=True
    )

    # Human-readable similarity band ("High"/"Medium"/"Low"), never a claim of
    # identity. Â§6 forbids "exactly identical" and the score is copied from the
    # provider's own analysis rather than invented here.
    similarity_label: Mapped[str] = mapped_column(String(20), default="")
    similarity_score: Mapped[float] = mapped_column(default=0.0)

    # Â§8: cloning someone's voice is consent-gated, and the consent travels with
    # the voice so a later audit can see exactly what was agreed to.
    consent_given: Mapped[int] = mapped_column(Integer, default=0)
    consent_text: Mapped[str] = mapped_column(String(300), default="")
    consented_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    is_default: Mapped[int] = mapped_column(Integer, default=0, index=True)
    is_archived: Mapped[int] = mapped_column(Integer, default=0, index=True)

    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class VoiceModelVersion(Base):
    """One training run. Kept even after a newer run succeeds, so Â§17 can fall
    back to an earlier model when a retrain comes out worse."""

    __tablename__ = "voice_model_versions"

    id: Mapped[int] = mapped_column(primary_key=True)
    voice_model_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("voice_models.id", ondelete="CASCADE"), index=True
    )

    # 1-based, so the UI can say "Version 2" without a count query.
    version: Mapped[int] = mapped_column(Integer, default=1)

    # The id the provider will actually synthesize with. Empty until the
    # provider confirms the clone, which is why status is not `ready` before it.
    provider_voice_id: Mapped[str] = mapped_column(String(80), default="", index=True)
    model_version: Mapped[str] = mapped_column(String(80), default="")

    status: Mapped[str] = mapped_column(String(20), default="queued", index=True)
    error_message: Mapped[str] = mapped_column(String(400), default="")

    # The training sample, kept so "Retrain" and "Test Voice" compare against
    # the original rather than against a copy of the current output.
    sample_ref: Mapped[str] = mapped_column(String(500), default="")
    sample_mime: Mapped[str] = mapped_column(String(80), default="")
    sample_duration_ms: Mapped[int] = mapped_column(Integer, default=0)
    sample_sha256: Mapped[str] = mapped_column(String(64), default="")
    sample_transcript: Mapped[str] = mapped_column(Text, default="")

    # JSON blob from `quality.py`: SNR, clipping, silence, intelligibility, etc.
    # Stored rather than recomputed so the numbers in MY VOICES are the numbers
    # the sample was actually accepted with.
    quality_json: Mapped[str] = mapped_column(Text, default="{}")
    similarity_label: Mapped[str] = mapped_column(String(20), default="")
    similarity_score: Mapped[float] = mapped_column(default=0.0)

    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
