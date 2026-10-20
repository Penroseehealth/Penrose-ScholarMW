"""Live, keyless educational/knowledge search providers.

Priority is educational databases and general educational sources. Every
provider is defensive: network/JSON failures return an empty list so the
orchestrator can continue with whichever sources answer.
"""

from __future__ import annotations

import logging
import re
import xml.etree.ElementTree as ET
from typing import Any
from urllib.parse import quote

import httpx

from app.config.settings import get_settings
from app.retrieval.models import RetrievedItem

log = logging.getLogger(__name__)


def _strip_html(text: str) -> str:
    text = re.sub(r"<[^>]+>", " ", text or "")
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def _join_names(authors: list[dict[str, Any]] | None, limit: int = 3) -> str:
    names = [
        a.get("name") or a.get("author", {}).get("display_name", "")
        for a in (authors or [])
    ]
    names = [n for n in names if n]
    if not names:
        return ""
    if len(names) > limit:
        return ", ".join(names[:limit]) + " et al."
    return ", ".join(names)


# ---------------------------------------------------------------------------
# Provider: OpenAlex (broadest open scholarly index)
# ---------------------------------------------------------------------------


async def search_openalex(
    query: str, limit: int, client: httpx.AsyncClient
) -> list[RetrievedItem]:
    s = get_settings()
    params = {
        "search": query,
        "per-page": str(limit),
        "mailto": s.RETRIEVAL_CONTACT_EMAIL,
    }
    r = await client.get("https://api.openalex.org/works", params=params)
    r.raise_for_status()
    out: list[RetrievedItem] = []
    for w in r.json().get("results", []):
        title = w.get("title") or w.get("display_name") or ""
        if not title:
            continue
        abstract = w.get("abstract_inverted_index")
        snippet = ""
        if abstract:
            # Rebuild abstract from inverted index.
            positions: list[tuple[int, str]] = []
            for word, idxs in abstract.items():
                for i in idxs:
                    positions.append((i, word))
            positions.sort()
            snippet = " ".join(word for _, word in positions)
        host = (w.get("primary_location") or {}).get("source") or {}
        venue = host.get("display_name") or ""
        out.append(
            RetrievedItem(
                title=title,
                url=w.get("doi") or w.get("id") or "",
                snippet=snippet[:900] or venue,
                provider="OpenAlex",
                authors=_join_names(w.get("authorships")),
                year=str(w.get("publication_year") or ""),
                kind="paper",
                extra={"venue": venue, "cited_by": str(w.get("cited_by_count") or 0)},
            )
        )
    return out


# ---------------------------------------------------------------------------
# Provider: Crossref (DOIs + metadata)
# ---------------------------------------------------------------------------


async def search_crossref(
    query: str, limit: int, client: httpx.AsyncClient
) -> list[RetrievedItem]:
    s = get_settings()
    params = {
        "query": query,
        "rows": str(limit),
        "select": "title,URL,author,issued,container-title,abstract",
        "mailto": s.RETRIEVAL_CONTACT_EMAIL,
    }
    r = await client.get("https://api.crossref.org/works", params=params)
    r.raise_for_status()
    out: list[RetrievedItem] = []
    for w in r.json().get("message", {}).get("items", []):
        titles = w.get("title") or []
        title = titles[0] if titles else ""
        if not title:
            continue
        issued = w.get("issued", {}).get("date-parts", [[None]])
        year = str(issued[0][0]) if issued and issued[0] and issued[0][0] else ""
        authors = ", ".join(
            f"{a.get('given', '')} {a.get('family', '')}".strip()
            for a in (w.get("author") or [])[:3]
        )
        containers = w.get("container-title") or []
        out.append(
            RetrievedItem(
                title=title,
                url=w.get("URL") or "",
                snippet=_strip_html(
                    w.get("abstract") or (containers[0] if containers else "")
                ),
                provider="Crossref",
                authors=authors + (" et al." if len(w.get("author") or []) > 3 else ""),
                year=year,
                kind="paper",
            )
        )
    return out


# ---------------------------------------------------------------------------
# Provider: arXiv (preprints, STEM)
# ---------------------------------------------------------------------------


async def search_arxiv(
    query: str, limit: int, client: httpx.AsyncClient
) -> list[RetrievedItem]:
    params = {"search_query": f"all:{query}", "start": "0", "max_results": str(limit)}
    r = await client.get("http://export.arxiv.org/api/query", params=params)
    r.raise_for_status()
    ns = {"a": "http://www.w3.org/2005/Atom"}
    root = ET.fromstring(r.text)
    out: list[RetrievedItem] = []
    for entry in root.findall("a:entry", ns):
        title = (entry.findtext("a:title", default="", namespaces=ns) or "").strip()
        summary = (entry.findtext("a:summary", default="", namespaces=ns) or "").strip()
        link = entry.findtext("a:id", default="", namespaces=ns) or ""
        published = entry.findtext("a:published", default="", namespaces=ns) or ""
        authors = [
            a.findtext("a:name", default="", namespaces=ns) or ""
            for a in entry.findall("a:author", ns)
        ]
        if not title:
            continue
        out.append(
            RetrievedItem(
                title=title,
                url=link,
                snippet=summary[:900],
                provider="arXiv",
                authors=_join_names([{"name": n} for n in authors]),
                year=published[:4],
                kind="preprint",
            )
        )
    return out


# ---------------------------------------------------------------------------
# Provider: PubMed / NCBI (biomedical & life sciences)
# ---------------------------------------------------------------------------


async def search_pubmed(
    query: str, limit: int, client: httpx.AsyncClient
) -> list[RetrievedItem]:
    base = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
    esearch = await client.get(
        f"{base}/esearch.fcgi",
        params={"db": "pubmed", "term": query, "retmode": "json", "retmax": str(limit)},
    )
    esearch.raise_for_status()
    ids = esearch.json().get("esearchresult", {}).get("idlist", [])
    if not ids:
        return []
    esummary = await client.get(
        f"{base}/esummary.fcgi",
        params={"db": "pubmed", "id": ",".join(ids), "retmode": "json"},
    )
    esummary.raise_for_status()
    result = esummary.json().get("result", {})
    out: list[RetrievedItem] = []
    for pid in ids:
        doc = result.get(pid)
        if not doc:
            continue
        authors = _join_names(doc.get("authors"))
        out.append(
            RetrievedItem(
                title=doc.get("title", "") or "",
                url=f"https://pubmed.ncbi.nlm.nih.gov/{pid}/",
                snippet=doc.get("source", "") or "",
                provider="PubMed",
                authors=authors,
                year=(doc.get("pubdate", "") or "")[:4],
                kind="paper",
            )
        )
    return out


# ---------------------------------------------------------------------------
# Provider: Semantic Scholar (papers + abstracts)
# ---------------------------------------------------------------------------


async def search_semantic_scholar(
    query: str, limit: int, client: httpx.AsyncClient
) -> list[RetrievedItem]:
    params = {
        "query": query,
        "limit": str(limit),
        "fields": "title,abstract,url,year,authors,venue",
    }
    r = await client.get(
        "https://api.semanticscholar.org/graph/v1/paper/search", params=params
    )
    r.raise_for_status()
    out: list[RetrievedItem] = []
    for p in r.json().get("data", []):
        title = p.get("title") or ""
        if not title:
            continue
        out.append(
            RetrievedItem(
                title=title,
                url=p.get("url") or "",
                snippet=(p.get("abstract") or p.get("venue") or "")[:900],
                provider="Semantic Scholar",
                authors=_join_names(p.get("authors")),
                year=str(p.get("year") or ""),
                kind="paper",
            )
        )
    return out


# ---------------------------------------------------------------------------
# Provider: ERIC (education research, via the public IEEE-style JSON API)
# ---------------------------------------------------------------------------


async def search_eric(
    query: str, limit: int, client: httpx.AsyncClient
) -> list[RetrievedItem]:
    params = {
        "search": query,
        "format": "json",
        "rows": str(limit),
        "fields": "title,author,description,publicationdateyear,url",
    }
    r = await client.get("https://api.ies.ed.gov/eric/", params=params)
    r.raise_for_status()
    docs = r.json().get("response", {}).get("docs", [])
    out: list[RetrievedItem] = []
    for d in docs:
        title = d.get("title") or ""
        if not title:
            continue
        url = d.get("url") or ""
        if isinstance(url, list):
            url = url[0] if url else ""
        out.append(
            RetrievedItem(
                title=title,
                url=url or "https://eric.ed.gov/",
                snippet=_strip_html(d.get("description") or "")[:900],
                provider="ERIC",
                authors=d.get("author") or "",
                year=str(d.get("publicationdateyear") or ""),
                kind="education",
            )
        )
    return out


# ---------------------------------------------------------------------------
# Provider: Wikipedia (general educational overview)
# ---------------------------------------------------------------------------


async def search_wikipedia(
    query: str, limit: int, client: httpx.AsyncClient
) -> list[RetrievedItem]:
    s = get_settings()
    lang = s.RETRIEVAL_WIKI_LANG
    r = await client.get(
        f"https://{lang}.wikipedia.org/w/api.php",
        params={
            "action": "query",
            "list": "search",
            "srsearch": query,
            "format": "json",
            "srlimit": str(limit),
        },
    )
    r.raise_for_status()
    out: list[RetrievedItem] = []
    for item in r.json().get("query", {}).get("search", []):
        title = item.get("title") or ""
        if not title:
            continue
        out.append(
            RetrievedItem(
                title=title,
                url=f"https://{lang}.wikipedia.org/wiki/{quote(title.replace(' ', '_'))}",
                snippet=_strip_html(item.get("snippet") or ""),
                provider="Wikipedia",
                kind="encyclopedia",
            )
        )
    return out


# ---------------------------------------------------------------------------
# Provider: Wikidata (structured facts)
# ---------------------------------------------------------------------------


async def search_wikidata(
    query: str, limit: int, client: httpx.AsyncClient
) -> list[RetrievedItem]:
    r = await client.get(
        "https://www.wikidata.org/w/api.php",
        params={
            "action": "wbsearchentities",
            "search": query,
            "language": get_settings().RETRIEVAL_WIKI_LANG,
            "format": "json",
            "limit": str(limit),
        },
    )
    r.raise_for_status()
    out: list[RetrievedItem] = []
    for item in r.json().get("search", []):
        title = item.get("label") or item.get("id") or ""
        if not title:
            continue
        out.append(
            RetrievedItem(
                title=title,
                url=item.get("concepturi")
                or f"https://www.wikidata.org/wiki/{item.get('id', '')}",
                snippet=item.get("description") or "",
                provider="Wikidata",
                kind="fact",
            )
        )
    return out


# Registry in priority order (educational databases first, general sources last).
PROVIDERS: dict[str, Any] = {
    "openalex": search_openalex,
    "crossref": search_crossref,
    "arxiv": search_arxiv,
    "pubmed": search_pubmed,
    "semantic_scholar": search_semantic_scholar,
    "eric": search_eric,
    "wikipedia": search_wikipedia,
    "wikidata": search_wikidata,
}
