"""Explicit educational-search endpoint.

Backs the "search the web/education sources" action and lets the frontend show
live results with links. Grounding for normal chat happens inside the tutor
router; this is the transparent, user-triggered counterpart.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.dependencies.auth import get_current_user
from app.models.models import User
from app.retrieval.orchestrator import format_results_json, search
from app.retrieval.providers import PROVIDERS

router = APIRouter(prefix="/retrieval", tags=["Educational Search"])


@router.get("/providers")
async def list_providers(user: User = Depends(get_current_user)):
    """List the educational sources backing retrieval."""
    return {
        "providers": list(PROVIDERS.keys()),
        "note": "Educational databases are prioritised over general sources.",
    }


@router.get("/search")
async def educational_search(
    q: str = Query(..., min_length=3, description="The search query"),
    providers: str | None = Query(None, description="Comma-separated provider names"),
    limit: int = Query(8, ge=1, le=20),
    user: User = Depends(get_current_user),
):
    """Search live educational/academic sources and return ranked, citable results."""
    selected = (
        [p.strip() for p in providers.split(",") if p.strip()] if providers else None
    )
    result = await search(q, providers=selected, max_items=limit)
    return format_results_json(result)
