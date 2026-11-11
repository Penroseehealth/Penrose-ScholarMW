"""Asymptote-backed scientific diagram generation for Aminiology EduTech."""

from .orchestrator import build_lesson_assets, classify_lesson_need
from .router import router
from .service import find_asy_executable, health, render_diagram

__all__ = [
    "router",
    "find_asy_executable",
    "health",
    "render_diagram",
    "build_lesson_assets",
    "classify_lesson_need",
]
