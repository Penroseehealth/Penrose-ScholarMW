from __future__ import annotations

import logging
from typing import TYPE_CHECKING, AsyncIterator

from openai import APIStatusError, AsyncOpenAI

from app.config.settings import get_settings

if TYPE_CHECKING:
    from openai.types.chat import ChatCompletion

log = logging.getLogger(__name__)


class AIProviderError(Exception):
    """Raised when all AI providers fail."""

    def __init__(self, errors: list[tuple[str, Exception]]):
        self.errors = errors
        names = [f"{n}: {type(e).__name__}" for n, e in errors]
        super().__init__(f"All AI providers failed: {'; '.join(names)}")


def _build_providers() -> list[tuple[str, AsyncOpenAI, str]]:
    """Return ordered list of (name, client, model) for available providers."""
    s = get_settings()
    providers: list[tuple[str, AsyncOpenAI, str]] = []

    if s.CLOUDFLARE_ACCOUNT_ID and s.CLOUDFLARE_API_TOKEN:
        base_url = f"https://api.cloudflare.com/client/v4/accounts/{s.CLOUDFLARE_ACCOUNT_ID}/ai/v1"
        providers.append(
            (
                "cloudflare",
                AsyncOpenAI(
                    api_key=s.CLOUDFLARE_API_TOKEN, base_url=base_url, timeout=60.0
                ),
                s.CLOUDFLARE_AI_MODEL,
            )
        )

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

    if s.OPENAI_API_KEY and s.OPENAI_API_KEY != "sk-your-openai-key":
        providers.append(
            (
                "openai",
                AsyncOpenAI(api_key=s.OPENAI_API_KEY, timeout=60.0),
                s.OPENAI_MODEL,
            )
        )

    return providers


def get_ai_client() -> tuple[AsyncOpenAI, str]:
    """Return the primary (client, model). Preserved for backward compat."""
    providers = _build_providers()
    if not providers:
        raise RuntimeError(
            "No AI provider configured. Set CLOUDFLARE_* or HUGGINGFACE_* in .env."
        )
    name, client, model = providers[0]
    log.info("AI primary provider: %s (%s)", name, model)
    return client, model


async def call_ai_chat(
    messages: list[dict[str, str]],
    *,
    max_tokens: int = 1024,
    temperature: float = 0.7,
    **kwargs,
) -> tuple[ChatCompletion, str]:
    """Try providers in order (Cloudflare → HuggingFace → OpenAI).
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
    """Convenience wrapper: returns the assistant content string.
    Raises AIProviderError on failure."""
    completion, _provider = await call_ai_chat(
        messages, max_tokens=max_tokens, temperature=temperature, **kwargs
    )
    return completion.choices[0].message.content or "No response generated."


async def call_ai_stream(
    messages: list[dict[str, str]],
    *,
    max_tokens: int = 2048,
    temperature: float = 0.7,
) -> AsyncIterator[str]:
    """Stream AI response chunks. Yields content strings as they arrive.

    Falls back to non-streaming if the provider doesn't support streaming.
    """
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
