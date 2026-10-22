"""Voice library service â€” the MY VOICES backing store.

This is a *selection* layer, not a training layer. The configured TTS provider
serves a fixed set of native voices and has no cloning or fine-tuning endpoint,
so a library entry selects one of those real voices and stores the user's own
naming/accent/style metadata against it. Nothing here fabricates a trained
profile, a fidelity score or a training job.

Two invariants keep the rest of Penrose consistent:

* `voice_key` is validated against the provider's advertised voice list on
  write, so a stored entry can never reference a voice the engine cannot
  synthesize.
* Exactly one entry is the default, and resolving it never raises: if the
  default points at a voice the engine no longer offers, callers fall back
  through [resolve_default_voice] to the configured default and finally to a
  known-good engine voice.
"""

from __future__ import annotations

from app.speech.config import get_settings
from app.speech.exceptions import ValidationError
from app.speech.models import VoiceProfile
from app.speech.repository import VoiceProfileRepository
from app.speech.service import available_voices, is_available_voice


def voice_profile_read(profile: VoiceProfile) -> dict:
    return {
        "id": profile.id,
        "voice_key": profile.voice_key,
        "display_name": profile.display_name,
        "accent_label": profile.accent_label,
        "style_note": profile.style_note,
        "language": profile.language,
        "is_default": bool(profile.is_default),
        "is_archived": bool(profile.is_archived),
        "source": profile.source,
        "created_at": profile.created_at,
        "updated_at": profile.updated_at,
    }


def resolve_default_voice(repo: VoiceProfileRepository) -> str | None:
    """The library default's engine voice id, or None when none is usable.

    Archived and stale defaults are ignored rather than surfaced, so a deleted
    or unavailable voice can never become the application's default.
    """
    for profile in repo.list(include_archived=False):
        if profile.is_default and is_available_voice(profile.voice_key):
            return profile.voice_key
    return None


def effective_default_voice(repo: VoiceProfileRepository | None) -> str:
    """The voice the app should speak with when a request omits one."""
    settings = get_settings()
    if repo is not None:
        chosen = resolve_default_voice(repo)
        if chosen:
            return chosen
    configured = (settings.tts_voice or "hannah").strip().lower()
    if is_available_voice(configured):
        return configured
    supported = available_voices()
    return supported[0] if supported else "hannah"


class VoiceLibraryService:
    def __init__(self, repo: VoiceProfileRepository) -> None:
        self.repo = repo

    def list(self, include_archived: bool = False) -> list[dict]:
        return [voice_profile_read(p) for p in self.repo.list(include_archived)]

    def get(self, profile_id: int) -> dict:
        return voice_profile_read(self.repo.get(profile_id))

    def add(
        self,
        voice_key: str,
        display_name: str | None = None,
        accent_label: str = "",
        style_note: str = "",
        language: str = "",
        make_default: bool = False,
    ) -> dict:
        key = (voice_key or "").strip().lower()
        if not key:
            raise ValidationError("voice_key is required")
        if not is_available_voice(key):
            raise ValidationError(
                f"'{key}' is not a voice the configured TTS engine provides",
                details={"available": available_voices()},
            )
        if self.repo.by_voice_key(key):
            raise ValidationError(
                f"'{key}' is already in your voice library",
                details={"voice_key": key},
            )
        name = (display_name or "").strip() or key.replace("_", " ").title()
        profile = self.repo.create(
            voice_key=key,
            display_name=name,
            accent_label=accent_label.strip(),
            style_note=style_note.strip(),
            language=language.strip(),
            source="my_voices",
        )
        if make_default:
            self._promote(profile)
        return voice_profile_read(self.repo.save(profile))

    def update(
        self,
        profile_id: int,
        *,
        display_name: str | None = None,
        accent_label: str | None = None,
        style_note: str | None = None,
        language: str | None = None,
        is_default: bool | None = None,
        is_archived: bool | None = None,
    ) -> dict:
        profile = self.repo.get(profile_id)
        if display_name is not None:
            name = display_name.strip()
            if not name:
                raise ValidationError("display_name cannot be empty")
            profile.display_name = name
        if accent_label is not None:
            profile.accent_label = accent_label.strip()
        if style_note is not None:
            profile.style_note = style_note.strip()
        if language is not None:
            profile.language = language.strip()
        if is_archived is not None:
            profile.is_archived = 1 if is_archived else 0
        if is_default is not None and is_default:
            self._promote(profile)
        self.repo.save(profile)
        return voice_profile_read(profile)

    def delete(self, profile_id: int) -> None:
        profile = self.repo.get(profile_id)
        was_default = bool(profile.is_default)
        self.repo.delete(profile_id)
        if was_default:
            # Never leave the application pointing at a row that is gone.
            self.repo.clear_default()

    def _promote(self, profile: VoiceProfile) -> None:
        """Make one entry the default, clearing any previous default first."""
        self.repo.clear_default()
        profile.is_default = 1
        profile.is_archived = 0
