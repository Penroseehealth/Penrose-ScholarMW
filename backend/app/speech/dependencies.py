"""Shared dependencies for the speech module."""

from __future__ import annotations

from app.speech.database import DbSessionDep  # noqa: F401  (re-export)
from app.speech.exceptions import ModuleDisabledError


def require_module_enabled(feature: str):
    """Dependency factory that 403s when a feature toggle is off."""

    def _check() -> None:
        from app.config.settings import get_settings

        if feature == "speech" and not get_settings().ENABLE_SPEECH:
            raise ModuleDisabledError(feature)

    return _check
