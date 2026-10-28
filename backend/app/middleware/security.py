"""Rate limiting and input sanitization middleware."""

import html
import re
import time
from collections import defaultdict
from typing import Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Simple in-memory rate limiter per IP address."""

    def __init__(
        self, app, requests_per_minute: int = 60, requests_per_hour: int = 500
    ):
        super().__init__(app)
        self.rpm = requests_per_minute
        self.rph = requests_per_hour
        self._minute_hits: dict[str, list[float]] = defaultdict(list)
        self._hour_hits: dict[str, list[float]] = defaultdict(list)

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Only rate-limit API calls. Static/SPA asset requests (Flutter's
        # flutter_bootstrap.js, main.dart.js, fonts, icons, ...) are served by a
        # catch-all route on the same host/IP and easily exceed 60/min on page
        # load; counting them would 429 the whole web app out of existence.
        if not request.url.path.startswith("/api/"):
            return await call_next(request)

        # The Voice Training Centre recorder polls capture status once a second
        # while a recording is running, which on its own exhausts the per-minute
        # budget and 429s the page mid-recording. It is a cheap, local,
        # read-only probe, so it is exempt from throttling.
        if request.url.path == "/api/v1/system-audio/status":
            return await call_next(request)

        client_ip = request.client.host if request.client else "unknown"
        now = time.time()

        self._minute_hits[client_ip] = [
            t for t in self._minute_hits[client_ip] if now - t < 60
        ]
        self._hour_hits[client_ip] = [
            t for t in self._hour_hits[client_ip] if now - t < 3600
        ]

        if len(self._minute_hits[client_ip]) >= self.rpm:
            return Response(
                content='{"detail":"Rate limit exceeded. Try again later."}',
                status_code=429,
                media_type="application/json",
                headers={"Retry-After": "60", "X-RateLimit-Limit": str(self.rpm)},
            )
        if len(self._hour_hits[client_ip]) >= self.rph:
            return Response(
                content='{"detail":"Hourly rate limit exceeded."}',
                status_code=429,
                media_type="application/json",
                headers={"Retry-After": "3600"},
            )

        self._minute_hits[client_ip].append(now)
        self._hour_hits[client_ip].append(now)

        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(self.rpm)
        response.headers["X-RateLimit-Remaining"] = str(
            max(0, self.rpm - len(self._minute_hits[client_ip]))
        )
        return response


def sanitize_input(text: str) -> str:
    """Escape HTML entities and strip potential XSS from user input."""
    text = html.escape(text, quote=True)
    text = re.sub(r"javascript:", "", text, flags=re.IGNORECASE)
    text = re.sub(r"on\w+\s*=", "", text, flags=re.IGNORECASE)
    return text.strip()


def sanitize_dict(data: dict) -> dict:
    """Recursively sanitize all string values in a dictionary."""
    sanitized = {}
    for key, value in data.items():
        if isinstance(value, str):
            sanitized[key] = sanitize_input(value)
        elif isinstance(value, dict):
            sanitized[key] = sanitize_dict(value)
        elif isinstance(value, list):
            sanitized[key] = [
                sanitize_input(v) if isinstance(v, str) else v for v in value
            ]
        else:
            sanitized[key] = value
    return sanitized
