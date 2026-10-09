"""Tests for deriving a first name from the stored full name."""

from __future__ import annotations

import pytest

from app.core.names import first_name_from, greeting_name
from app.schemas.user import UserResponse
from app.stem.subject_dashboard_router import _build_greeting


@pytest.mark.parametrize(
    ("full_name", "expected"),
    [
        ("Amin J. Doe", "Amin"),
        ("Dr Amin J. Doe", "Amin"),
        ("Prof. Grace Chitedze", "Grace"),
        ("Mrs Bwana Tiwonge", "Bwana"),
        ("Amin, J. Doe", "Amin"),
        ("  Amin   Doe  ", "Amin"),
        ("Amin", "Amin"),
        ("Amin-Doe", "Amin"),
        ("Dr. Amin", "Amin"),
        ("", ""),
        ("   ", ""),
        (None, ""),
        ("Dr", ""),
    ],
)
def test_first_name_is_derived_from_the_full_name(
    full_name: str | None, expected: str
) -> None:
    assert first_name_from(full_name) == expected


def test_titles_are_skipped_so_greetings_never_say_good_morning_doctor() -> None:
    assert first_name_from("Dr Amin J. Doe") == "Amin"
    assert first_name_from("Prof. Grace Chitedze") == "Grace"


def test_bwana_is_treated_as_a_first_name_not_a_title() -> None:
    """ "Bwana" is a common Malawian given name, so it must never be stripped."""
    assert first_name_from("Bwana Tiwonge") == "Bwana"
    assert first_name_from("Mrs Bwana Tiwonge") == "Bwana"


def test_greeting_name_falls_back_when_there_is_no_usable_name() -> None:
    assert greeting_name("") == "there"
    assert greeting_name(None) == "there"
    assert greeting_name("Amin Doe") == "Amin"


def test_greeting_uses_the_first_name_not_the_whole_name() -> None:
    greeting = _build_greeting("Dr Amin J. Doe")

    assert greeting.endswith(", Amin")
    assert "Doe" not in greeting


def test_greeting_still_reads_naturally_without_a_name() -> None:
    assert _build_greeting("").endswith(", there")


def test_user_response_exposes_first_name_without_a_database_column() -> None:
    response = UserResponse(
        id=1,
        email="amin@test.com",
        full_name="Dr Amin J. Doe",
        role="student",
        is_active=True,
        is_verified=False,
        created_at="2026-01-01T00:00:00Z",
    )

    assert response.first_name == "Amin"
    assert response.display_name == "Dr Amin J. Doe"
    assert response.model_dump()["first_name"] == "Amin"
