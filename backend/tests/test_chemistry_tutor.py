"""Unit tests for the chemistry lab tutor's deterministic fallback.

The fallback must explain using ONLY the validated experiment state it is
given — never invent a measurement.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.chemistry.tutor_router import ExperimentState, _deterministic_reply  # noqa: E402


def _state(**overrides) -> ExperimentState:
    base = dict(
        phase="titrating",
        delivered_ml=24.60,
        current_ph=6.9,
        indicator_colour="colourless",
        at_endpoint=False,
        titrant="NaOH",
        analyte="HCl",
        analyte_concentration=0.1,
        expected_titre_ml=25.0,
    )
    base.update(overrides)
    return ExperimentState(**base)


def test_colour_question_before_endpoint_refuses_to_invent_pink():
    reply = _deterministic_reply("why hasn't it turned pink?", _state())
    assert "colourless" in reply
    assert "pH 6.90" in reply  # uses the verified pH verbatim


def test_colour_question_at_endpoint_describes_the_real_colour():
    reply = _deterministic_reply("why is it pink?", _state(at_endpoint=True, indicator_colour="pale pink"))
    assert "pale pink" in reply.lower() or "pink" in reply.lower()
    assert "final burette reading" in reply


def test_titre_question_uses_recorded_readings_only():
    reply = _deterministic_reply("how do I get the titre?", _state(initial_reading_ml=0.05, final_reading_ml=25.15))
    assert "25.10" in reply  # 25.15 - 0.05, computed from given readings


def test_titre_question_without_readings_tells_student_what_to_measure():
    reply = _deterministic_reply("what is my titre?", _state())
    assert "record" in reply.lower()
    assert "25.10" not in reply  # nothing to compute from — no invented number


def test_concentration_reply_grounds_in_calculated_value():
    reply = _deterministic_reply("what is the concentration?", _state(calculated_concentration=0.0996))
    assert "0.0996" in reply


def test_concentration_reply_without_a_full_run_does_not_guess():
    reply = _deterministic_reply("what is the concentration?", _state())
    assert "0." not in reply.split("mol/dm3")[0].split()[-1] if "mol/dm3" in reply else True
    assert "first need a complete" in reply


def test_equivalence_reply_uses_expected_titre():
    reply = _deterministic_reply("where is the equivalence point?", _state())
    assert "25.00" in reply


def test_unknown_question_stays_phase_aware():
    reply = _deterministic_reply("hello", _state())
    assert reply.strip()
    reply2 = _deterministic_reply("hello", _state(phase="notStarted"))
    assert "burette" in reply2.lower()
