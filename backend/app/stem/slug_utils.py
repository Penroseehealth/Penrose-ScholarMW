"""Shared slug alias resolution for STEM subject slugs."""

_SLUG_ALIASES = {
    "math": "mathematics",
    "bio": "biology",
    "chem": "chemistry",
    "phys": "physics",
    "cs": "computer-science",
    "earth-science": "earth-geosciences",
    "engineering": "engineering-technology",
    "env-science": "environmental-science",
    "env": "environmental-science",
    "stats": "statistics",
    "agri": "agriculture",
}


def resolve_slug(slug: str) -> str:
    """Resolve short or variant slugs to their canonical form."""
    return _SLUG_ALIASES.get(slug, slug)
