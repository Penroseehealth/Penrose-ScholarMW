"""Tests for the MathsDrill chat solve endpoint.

The chat in the MathsDrill web app posts its question here instead of feeding
the React classifier (which only knows its built-in families). The response
must be verified maths, an honestly-labelled AI answer, or an honest request
for more detail — never an invented one.
"""

from __future__ import annotations

import json

from tests.conftest import auth_header

PATH = "/api/v1/mathsdrill/solve"


async def test_solve_requires_a_signed_in_session(client) -> None:
    """Model calls cost provider credits, so the session must be real."""
    response = await client.post(PATH, json={"question": "Solve x^2 - 4x + 3 = 0"})

    assert response.status_code in {401, 403}


async def test_empty_question_is_rejected(client, student_token) -> None:
    response = await client.post(
        PATH, json={"question": ""}, headers=auth_header(student_token)
    )

    assert response.status_code == 422


async def test_quadratic_returns_verified_steps_and_a_parabola(
    client, student_token
) -> None:
    response = await client.post(
        PATH,
        json={"question": "Solve x^2 - 4x + 3 = 0"},
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    data = response.json()
    assert data["question"] == "Solve x^2 - 4x + 3 = 0"
    assert data["source"] == "sympy"
    assert data["verification_status"] == "verified"
    assert len(data["steps"]) >= 3
    assert all(step.get("title") for step in data["steps"])

    visual = data["visual"]
    assert visual["kind"] == "parabola"
    assert visual["params"]["a"] == 1
    assert visual["params"]["b"] == -4
    assert visual["params"]["c"] == 3
    roots = {round(root, 6) for root in visual["params"]["roots"]}
    assert roots == {1.0, 3.0}

    answer = data["answer_text"]
    assert "1" in answer and "3" in answer


async def test_right_triangle_returns_a_diagram_payload(client, student_token) -> None:
    response = await client.post(
        PATH,
        json={
            "question": "Find the hypotenuse of a right triangle with legs 3 and 4 cm"
        },
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    data = response.json()
    assert data["source"] == "sympy"
    assert data["visual"]["kind"] == "right_triangle"
    assert data["visual"]["params"]["a"] == 3
    assert data["visual"]["params"]["b"] == 4
    assert round(data["visual"]["params"]["c"]) == 5
    assert "5" in data["answer_text"]


async def test_percentage_returns_a_bar_payload(client, student_token) -> None:
    response = await client.post(
        PATH,
        json={"question": "What is 15% of 240?"},
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    data = response.json()
    assert data["source"] == "sympy"
    assert data["visual"]["kind"] == "percentage_bar"
    assert data["visual"]["part"] == 36
    assert "36" in data["answer_text"]


async def test_root_question_written_without_an_equals_sign(
    client, student_token
) -> None:
    """Regression: this used to fall through to the arithmetic evaluator and
    answer "-2" — a number that is not a root of the polynomial at all."""
    question = "Find the roots of x^2 - 4x + 3"
    response = await client.post(
        PATH, json={"question": question}, headers=auth_header(student_token)
    )

    assert response.status_code == 200
    data = response.json()
    assert data["question"] == question, "the caller's own wording is echoed back"
    assert data["topic"] == "quadratic_equation"
    assert data["source"] == "sympy"
    assert data["verification_status"] == "verified"
    roots = {round(r, 6) for r in data["visual"]["params"]["roots"]}
    assert roots == {1.0, 3.0}
    assert data["visual"]["kind"] == "parabola"


async def test_graph_wording_with_trailing_root_intent(client, student_token) -> None:
    """'Draw y = … and find its roots' must solve the polynomial, not evaluate
    something else, and still produce a graphable parabola."""
    question = "Draw y = x^2 - 4x + 3 and find its roots"
    response = await client.post(
        PATH, json={"question": question}, headers=auth_header(student_token)
    )

    assert response.status_code == 200
    data = response.json()
    assert data["question"] == question
    assert data["topic"] == "quadratic_equation"
    assert data["visual"]["kind"] == "parabola"
    roots = {round(r, 6) for r in data["visual"]["params"]["roots"]}
    assert roots == {1.0, 3.0}


async def test_everyday_forms_are_unchanged_by_the_rewrite(
    client, student_token
) -> None:
    """The rewrite must not disturb questions the engine already handled."""
    cases = {
        "Calculate 12 + 6 * 2": "24",
        "Solve 3x + 5 = 20": "5",
        "What is 15% of 240?": "36",
    }
    for question, expected in cases.items():
        response = await client.post(
            PATH, json={"question": question}, headers=auth_header(student_token)
        )
        assert response.status_code == 200, question
        data = response.json()
        assert data["source"] == "sympy", question
        assert expected in data["answer_text"], (question, data["answer_text"])


async def test_unrecognised_wording_is_reported_not_invented(
    client, student_token, monkeypatch
) -> None:
    """A question neither engine can work must still get an honest answer.

    Stubbed so the suite never waits on a provider: the wiring (assistant
    reached, AI labelled, no clarification text) is what is under test. The
    real provider path is exercised end-to-end in `scripts/cdp_chat_ai.py`.
    """
    _break_json(monkeypatch)

    async def fake_text(messages, **kwargs):
        return (
            "1. This question is not a maths problem.\n\n"
            "Explanation: Ask me a maths question and I will work it out."
        )

    monkeypatch.setattr("app.mathematics.tutor_router.call_ai_text", fake_text)

    response = await client.post(
        PATH,
        json={"question": "Tell me a story about a banana"},
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    data = response.json()
    assert data["source"] == "ai", "the assistant must answer, not the clarification"
    assert data["verification_status"] == "ai_unverified"
    assert data["steps"], "an AI answer still has to be worked step by step"
    assert "could not turn that into a calculation" not in json.dumps(data)


# ---------------------------------------------------------------------------
# ScholarAI fallback (the assistant behind /ai/chat)
# ---------------------------------------------------------------------------


def _break_json(monkeypatch) -> None:
    """Simulate the structured call failing, so the chat fallback is reached."""

    async def _fail(messages, **kwargs):
        raise ValueError("model did not return JSON")

    monkeypatch.setattr("app.mathematics.tutor_router.call_ai_json", _fail)


async def test_free_form_question_is_answered_by_the_assistant(
    client, student_token, monkeypatch
) -> None:
    """SymPy cannot parse it *and* the JSON call failed: ScholarAI still answers."""
    _break_json(monkeypatch)

    async def fake_text(messages, **kwargs):
        return (
            "1. Write down what the question already gives you.\n"
            "2. Substitute the numbers you know.\n\n"
            "Answer: 42"
        )

    monkeypatch.setattr("app.mathematics.tutor_router.call_ai_text", fake_text)

    response = await client.post(
        PATH,
        json={"question": "Crrrrffddd explain the Malawi weather question"},
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    data = response.json()
    assert data["source"] == "ai"
    assert data["topic"] == "assistant answer"
    assert data["verification_status"] == "ai_unverified"
    assert len(data["steps"]) >= 1
    assert data["answer_text"] == "42"
    # the deterministic clarification must be gone
    assert "could not turn that into a calculation" not in json.dumps(data)


async def test_assistant_structured_reply_is_honoured(
    client, student_token, monkeypatch
) -> None:
    """When the assistant replies in the structured shape, keep its steps."""
    _break_json(monkeypatch)

    async def fake_text(messages, **kwargs):
        return json.dumps(
            {
                "steps": [
                    {
                        "title": "Set up the equation",
                        "work": "2x + 1 = 7",
                        "explanation": "Subtract 1 from both sides.",
                    }
                ],
                "answer_text": "x = 3",
                "answer_latex": "x = 3",
            }
        )

    monkeypatch.setattr("app.mathematics.tutor_router.call_ai_text", fake_text)

    response = await client.post(
        PATH,
        json={"question": "solve 2x + 1 = 7 for me please"},
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    data = response.json()
    assert data["source"] == "ai"
    assert data["steps"][0]["title"] == "Set up the equation"
    assert data["answer_text"] == "x = 3"


async def test_assistant_unavailable_still_reports_honestly(
    client, student_token, monkeypatch
) -> None:
    """No working provider at all: say so, never present a guess as verified."""
    _break_json(monkeypatch)

    async def boom(messages, **kwargs):
        raise RuntimeError("provider unreachable")

    monkeypatch.setattr("app.mathematics.tutor_router.call_ai_text", boom)

    response = await client.post(
        PATH,
        json={"question": "tell me about angles in a circle"},
        headers=auth_header(student_token),
    )

    assert response.status_code == 200
    data = response.json()
    assert data["source"] == "clarification"
    assert data["verification_status"] != "verified"
