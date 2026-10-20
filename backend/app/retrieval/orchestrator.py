"""Retrieval orchestrator: query educational sources and rank the results.

This is the layer the AI tutor talks to. It:
  1. decides whether a question actually needs external grounding,
  2. fans out to the keyless educational providers in parallel,
  3. dedupes + ranks the results (educational databases first),
  4. returns a compact, citable set of snippets plus a prompt block.

Everything is best-effort: if every provider fails the caller simply gets an
empty result and answers from the model's own knowledge.
"""

from __future__ import annotations

import asyncio
import logging
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass

import httpx

from app.config.settings import get_settings
from app.retrieval.models import RetrievedItem
from app.retrieval.providers import PROVIDERS

log = logging.getLogger(__name__)

# Provider authority weight — educational databases outrank general sources.
_PROVIDER_WEIGHT = {
    "OpenAlex": 1.00,
    "PubMed": 0.98,
    "arXiv": 0.96,
    "Semantic Scholar": 0.95,
    "ERIC": 0.94,
    "Crossref": 0.90,
    "Wikipedia": 0.70,
    "Wikidata": 0.65,
}

# Questions that clearly do NOT need a live lookup.
_NO_RETRIEVAL_PATTERNS = (
    r"^\s*(hi|hello|hey|thanks|thank you|ok|okay|yes|no|please|help)\b",
    r"\b(explain|define|what is|who is)\b.*\b(step by step|simply)\b",
)


@dataclass
class RetrievalResult:
    query: str
    items: list[RetrievedItem]

    @property
    def has_results(self) -> bool:
        return bool(self.items)

    def citations(self) -> list[str]:
        return [item.citation() for item in self.items]

    def grounding_prompt_block(self) -> str:
        """Build the snippet block injected into the model's system prompt."""
        if not self.items:
            return ""
        blocks = "\n\n".join(
            item.grounding_block(i + 1) for i, item in enumerate(self.items)
        )
        return (
            "\n\n--- LIVE RETRIEVED SOURCES (use these to ground your answer) ---\n"
            "The following excerpts were retrieved moments ago from academic and "
            "educational databases. Prioritise them over your own memory, cite the "
            "numbered sources inline like [1], and prefer the most recent/authoritative "
            "where they disagree. If they do not cover the question, say so and answer "
            "from your general knowledge.\n\n"
            f"{blocks}\n"
            "--- END RETRIEVED SOURCES ---\n"
        )


def _needs_retrieval(message: str) -> bool:
    s = get_settings()
    if not s.RETRIEVAL_ENABLED:
        return False
    text = (message or "").strip()
    if len(text) < 12:
        return False
    low = text.lower()
    for pat in _NO_RETRIEVAL_PATTERNS:
        if re.search(pat, low) and len(text) < 60:
            return False
    return True


def _rank_key(item: RetrievedItem) -> float:
    """Higher is better: provider authority, recency, snippet richness."""
    weight = _PROVIDER_WEIGHT.get(item.provider, 0.5)
    year = 0
    m = re.search(r"(19|20)\d{2}", item.year or "")
    if m:
        year = int(m.group(0))
    recency = (year - 1990) / 40.0 if year else 0.0
    recency = max(0.0, min(1.0, recency))
    richness = min(len(item.snippet) / 500.0, 1.0)
    has_url = 1.0 if item.url else 0.0
    return weight * 0.6 + recency * 0.2 + richness * 0.15 + has_url * 0.05


async def _run_provider(
    name: str,
    fn,
    query: str,
    limit: int,
    client: httpx.AsyncClient,
) -> list[RetrievedItem]:
    try:
        return await fn(query, limit, client)
    except (httpx.HTTPError, ET.ParseError, ValueError, KeyError, TypeError) as exc:
        log.info("Retrieval provider %s failed: %s", name, exc)
        return []


async def search(
    message: str, *, providers: list[str] | None = None, max_items: int | None = None
) -> RetrievalResult:
    """Query the educational providers in parallel and return ranked results."""
    s = get_settings()
    if not _needs_retrieval(message):
        return RetrievalResult(query=message, items=[])

    names = providers or list(PROVIDERS.keys())
    per_provider = s.RETRIEVAL_MAX_RESULTS_PER_PROVIDER
    cap = max_items or s.RETRIEVAL_MAX_SNIPPETS

    timeout = httpx.Timeout(s.RETRIEVAL_TIMEOUT_SECONDS)
    headers = {
        "User-Agent": "PenroseScholarAI/1.0 (educational tutor; "
        f"mailto:{s.RETRIEVAL_CONTACT_EMAIL})"
    }
    async with httpx.AsyncClient(
        timeout=timeout, headers=headers, follow_redirects=True
    ) as client:
        tasks = [
            _run_provider(name, PROVIDERS[name], message, per_provider, client)
            for name in names
            if name in PROVIDERS
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)

    items: list[RetrievedItem] = []
    for res in results:
        if isinstance(res, list):
            items.extend(res)

    # Dedupe by normalised title.
    seen: set[str] = set()
    deduped: list[RetrievedItem] = []
    for item in items:
        key = re.sub(r"\W+", "", (item.title or "").lower())[:80]
        if not key or key in seen:
            continue
        seen.add(key)
        deduped.append(item)

    deduped.sort(key=_rank_key, reverse=True)
    top = deduped[:cap]
    log.info(
        "Retrieval: %d providers, %d raw, %d selected", len(tasks), len(items), len(top)
    )
    return RetrievalResult(query=message, items=top)


def format_results_json(result: RetrievalResult) -> dict:
    """Serialise a retrieval result for API responses."""
    return {
        "query": result.query,
        "count": len(result.items),
        "results": [
            {
                "title": item.title,
                "url": item.url,
                "snippet": item.snippet,
                "provider": item.provider,
                "authors": item.authors,
                "year": item.year,
                "kind": item.kind,
            }
            for item in result.items
        ],
    }
