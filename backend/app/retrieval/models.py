"""External, keyless educational retrieval providers.

Each provider implements a small async ``search`` coroutine that returns a list
of :class:`RetrievedItem`. Providers are wrapped so a single failing source can
never break an answer: the orchestrator treats every provider independently.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class RetrievedItem:
    """One grounded result from an external educational source."""

    title: str
    url: str
    snippet: str
    provider: str
    authors: str = ""
    year: str = ""
    kind: str = "article"
    extra: dict[str, str] = field(default_factory=dict)

    def citation(self) -> str:
        """A compact, human-readable citation line for the SOURCES block."""
        bits: list[str] = []
        if self.authors:
            bits.append(self.authors)
        bits.append(self.title)
        if self.year:
            bits.append(self.year)
        bits.append(self.provider)
        return f"{', '.join(bits)} — {self.url}"

    def grounding_block(self, index: int) -> str:
        """The text injected into the model prompt for this item."""
        head = f"[{index}] {self.title}"
        if self.authors:
            head += f" ({self.authors}"
            head += f", {self.year})" if self.year else ")"
        return (
            f"{head}\n"
            f"Source: {self.provider} — {self.url}\n"
            f"Excerpt: {self.snippet.strip()[:900]}"
        )
