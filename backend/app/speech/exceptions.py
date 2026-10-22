"""Domain exceptions for the speech module and their FastAPI handler.

Raised by the service/cloning layers so provider failures surface as structured
JSON (422/429/503) instead of leaking raw upstream errors as 500s.
"""

from __future__ import annotations

from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse


class AppException(Exception):
    """Base class for all handled application errors."""

    def __init__(
        self,
        message: str,
        *,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        code: str = "app_error",
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.code = code
        self.details = details or {}


class NotFoundError(AppException):
    def __init__(self, resource: str, resource_id: Any = None) -> None:
        suffix = f" {resource_id!r}" if resource_id is not None else ""
        super().__init__(
            f"{resource}{suffix} not found", status_code=404, code="not_found"
        )


class ValidationError(AppException):
    def __init__(self, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(
            message, status_code=422, code="validation_error", details=details
        )


class ConflictError(AppException):
    """The request was valid but the resource is busy for a moment."""

    def __init__(self, message: str, details: dict[str, Any] | None = None) -> None:
        super().__init__(message, status_code=409, code="conflict", details=details)


class ModuleDisabledError(AppException):
    def __init__(self, module: str) -> None:
        super().__init__(
            f"Module '{module}' is disabled. Enable it via configuration.",
            status_code=403,
            code="module_disabled",
        )


class ServiceUnavailableError(AppException):
    """Raised when an optional capability (STT/TTS/cloning) is unconfigured."""

    def __init__(
        self,
        message: str,
        *,
        code: str = "service_unavailable",
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message, status_code=503, code=code, details=details)


class RateLimitedError(AppException):
    """An upstream provider's own rate/quota limit was reached (429)."""

    def __init__(
        self,
        message: str,
        *,
        code: str = "rate_limited",
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message, status_code=429, code=code, details=details)


class VoiceUnavailableError(ServiceUnavailableError):
    """The voice a request asked for cannot be spoken with right now."""

    def __init__(
        self,
        message: str,
        *,
        voice_id: int | None = None,
        details: dict[str, Any] | None = None,
    ) -> None:
        payload: dict[str, Any] = dict(details or {})
        if voice_id is not None:
            payload["voice_id"] = voice_id
        super().__init__(message, code="voice_unavailable", details=payload)
        self.voice_id = voice_id


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppException)
    async def app_exception_handler(_: Request, exc: AppException) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "ok": False,
                "error": exc.message,
                "code": exc.code,
                "details": exc.details,
            },
        )
