from __future__ import annotations

import logging
from typing import TYPE_CHECKING, AsyncIterator

from openai import APIStatusError, AsyncOpenAI

from app.config.settings import get_settings

if TYPE_CHECKING:
    from openai.types.chat import ChatCompletion

log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Provider error
# ---------------------------------------------------------------------------


class AIProviderError(Exception):
    """Raised when all AI providers fail."""

    def __init__(self, errors: list[tuple[str, Exception]]):
        self.errors = errors
        names = [f"{n}: {type(e).__name__}" for n, e in errors]
        super().__init__(f"All AI providers failed: {'; '.join(names)}")


class OfflineError(Exception):
    """Raised when the application detects it is offline."""


# ---------------------------------------------------------------------------
# Provider chain: HuggingFace (primary) → Groq (fallback)
# Cloudflare is kept as an optional extra if already configured.
# ---------------------------------------------------------------------------


def _build_providers() -> list[tuple[str, AsyncOpenAI, str]]:
    """Return ordered list of (name, client, model) for available providers.

    Provider priority:
    1. HuggingFace ScholarAI (primary)
    2. Groq (fallback)
    3. Cloudflare Workers AI (if configured, kept for backward compat)
    """
    s = get_settings()
    providers: list[tuple[str, AsyncOpenAI, str]] = []

    # 1. HuggingFace — PRIMARY
    if s.HUGGINGFACE_API_TOKEN:
        providers.append(
            (
                "huggingface",
                AsyncOpenAI(
                    api_key=s.HUGGINGFACE_API_TOKEN,
                    base_url="https://router.huggingface.co/v1",
                    timeout=60.0,
                ),
                s.HUGGINGFACE_MODEL,
            )
        )

    # 2. Groq — FALLBACK
    if s.GROQ_API_KEY:
        providers.append(
            (
                "groq",
                AsyncOpenAI(
                    api_key=s.GROQ_API_KEY,
                    base_url="https://api.groq.com/openai/v1",
                    timeout=60.0,
                ),
                s.GROQ_MODEL,
            )
        )

    # 3. Cloudflare Workers AI — optional extra
    if s.CLOUDFLARE_ACCOUNT_ID and s.CLOUDFLARE_API_TOKEN:
        base_url = (
            f"https://api.cloudflare.com/client/v4/accounts/"
            f"{s.CLOUDFLARE_ACCOUNT_ID}/ai/v1"
        )
        providers.append(
            (
                "cloudflare",
                AsyncOpenAI(
                    api_key=s.CLOUDFLARE_API_TOKEN,
                    base_url=base_url,
                    timeout=60.0,
                ),
                s.CLOUDFLARE_AI_MODEL,
            )
        )

    return providers


def get_ai_client() -> tuple[AsyncOpenAI, str]:
    """Return the primary (client, model). Preserved for backward compat."""
    providers = _build_providers()
    if not providers:
        raise RuntimeError(
            "No AI provider configured. Set HUGGINGFACE_API_TOKEN or "
            "GROQ_API_KEY in .env."
        )
    name, client, model = providers[0]
    log.info("AI primary provider: %s (%s)", name, model)
    return client, model


# ---------------------------------------------------------------------------
# Non-streaming calls
# ---------------------------------------------------------------------------


async def call_ai_chat(
    messages: list[dict[str, str]],
    *,
    max_tokens: int = 1024,
    temperature: float = 0.7,
    **kwargs,
) -> tuple[ChatCompletion, str]:
    """Try providers in order (HuggingFace → Groq → Cloudflare).
    Returns (completion, provider_name).
    Raises AIProviderError if all fail."""
    providers = _build_providers()
    if not providers:
        raise RuntimeError("No AI provider configured.")

    errors: list[tuple[str, Exception]] = []
    for name, client, model in providers:
        try:
            log.info("Trying AI provider: %s (%s)", name, model)
            completion = await client.chat.completions.create(
                model=model,
                messages=messages,
                max_tokens=max_tokens,
                temperature=temperature,
                **kwargs,
            )
            log.info("AI provider %s succeeded", name)
            return completion, name
        except (APIStatusError, Exception) as e:
            log.warning("AI provider %s failed: %s", name, e)
            errors.append((name, e))
            continue

    raise AIProviderError(errors)


async def call_ai_text(
    messages: list[dict[str, str]],
    *,
    max_tokens: int = 1024,
    temperature: float = 0.7,
    **kwargs,
) -> str:
    """Convenience wrapper: returns the assistant content string."""
    completion, _provider = await call_ai_chat(
        messages, max_tokens=max_tokens, temperature=temperature, **kwargs
    )
    return completion.choices[0].message.content or "No response generated."


# ---------------------------------------------------------------------------
# Streaming calls
# ---------------------------------------------------------------------------


async def call_ai_stream(
    messages: list[dict[str, str]],
    *,
    max_tokens: int = 2048,
    temperature: float = 0.7,
) -> AsyncIterator[str]:
    """Stream AI response chunks. Yields content strings as they arrive."""
    providers = _build_providers()
    if not providers:
        raise RuntimeError("No AI provider configured.")

    errors: list[tuple[str, Exception]] = []
    for name, client, model in providers:
        try:
            log.info("Trying AI stream provider: %s (%s)", name, model)
            stream = await client.chat.completions.create(
                model=model,
                messages=messages,
                max_tokens=max_tokens,
                temperature=temperature,
                stream=True,
            )
            async for chunk in stream:
                if chunk.choices and chunk.choices[0].delta.content:
                    yield chunk.choices[0].delta.content
            log.info("AI stream provider %s succeeded", name)
            return
        except (APIStatusError, Exception) as e:
            log.warning("AI stream provider %s failed: %s", name, e)
            errors.append((name, e))
            continue

    raise AIProviderError(errors)


async def call_ai_stream_with_fallback(
    messages: list[dict[str, str]],
    *,
    max_tokens: int = 2048,
    temperature: float = 0.7,
) -> AsyncIterator[str]:
    """Stream with automatic fallback to non-streaming on failure."""
    try:
        async for chunk in call_ai_stream(
            messages, max_tokens=max_tokens, temperature=temperature
        ):
            yield chunk
    except AIProviderError:
        log.info("Streaming failed, falling back to non-streaming")
        text = await call_ai_text(
            messages, max_tokens=max_tokens, temperature=temperature
        )
        yield text


# ---------------------------------------------------------------------------
# Health / connectivity
# ---------------------------------------------------------------------------


async def check_provider_health() -> list[dict]:
    """Probe each configured provider and return status list."""
    providers = _build_providers()
    results = []
    for name, client, model in providers:
        try:
            completion = await client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": "Reply OK"}],
                max_tokens=5,
                temperature=0,
            )
            content = completion.choices[0].message.content or ""
            results.append(
                {
                    "provider": name,
                    "model": model,
                    "status": "healthy",
                    "response": content.strip()[:50],
                }
            )
        except Exception as e:
            results.append(
                {
                    "provider": name,
                    "model": model,
                    "status": "unhealthy",
                    "error": f"{type(e).__name__}: {str(e)[:200]}",
                }
            )
    return results


async def check_ai_connectivity() -> dict:
    """Quick connectivity check — returns overall status + per-provider."""
    providers = _build_providers()
    if not providers:
        return {
            "online": False,
            "message": "No AI providers configured",
            "providers": [],
        }

    health = await check_provider_health()
    any_healthy = any(p["status"] == "healthy" for p in health)
    return {
        "online": any_healthy,
        "message": "AI services available"
        if any_healthy
        else "All AI providers unreachable",
        "providers": health,
    }
