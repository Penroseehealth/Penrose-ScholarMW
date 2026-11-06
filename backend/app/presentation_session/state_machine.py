"""Dual state machines for presentation sessions (approved Phase 0D §4).

Presentation lifecycle (``pres_state``) is presenter-controlled; AI
interaction (``ai_state``) is event-driven. They are separate enum columns on
one row, updated in one transaction, with the combination matrix below as the
only guard against contradictory states.

pres:  IDLE → LIVE → PAUSED → LIVE → ... → COMPLETED
ai:    IDLE/LISTENING/AWAITING_APPROVAL/RESPONDING/SUSPENDED
"""

from __future__ import annotations

from dataclasses import dataclass, field

PRES_IDLE = "idle"
PRES_LIVE = "live"
PRES_PAUSED = "paused"
PRES_COMPLETED = "completed"

AI_IDLE = "idle"
AI_LISTENING = "listening"
AI_AWAITING = "awaiting_approval"
AI_RESPONDING = "responding"
AI_SUSPENDED = "suspended"

AI_POLICIES = ("auto", "approval", "presenter_only")

# Valid (pres_state, ai_state) combinations. The completed session allows
# only AI idle; suspended AI is legal in any non-completed presentation
# state (the presenter can disable narration without touching playback).
VALID_COMBINATIONS: set[tuple[str, str]] = {
    (PRES_IDLE, AI_IDLE),
    (PRES_IDLE, AI_SUSPENDED),
    (PRES_LIVE, AI_IDLE),
    (PRES_LIVE, AI_LISTENING),
    (PRES_LIVE, AI_AWAITING),
    (PRES_LIVE, AI_RESPONDING),
    (PRES_LIVE, AI_SUSPENDED),
    (PRES_PAUSED, AI_IDLE),
    (PRES_PAUSED, AI_LISTENING),
    (PRES_PAUSED, AI_AWAITING),
    (PRES_PAUSED, AI_RESPONDING),
    (PRES_PAUSED, AI_SUSPENDED),
    (PRES_COMPLETED, AI_IDLE),
}

# Presenter-controlled presentation transitions.
PRES_TRANSITIONS: dict[str, set[str]] = {
    PRES_IDLE: {PRES_LIVE, PRES_COMPLETED},
    PRES_LIVE: {PRES_PAUSED, PRES_COMPLETED},
    PRES_PAUSED: {PRES_LIVE, PRES_COMPLETED},
    PRES_COMPLETED: set(),
}

# Event-driven AI transitions. RESPONDING → IDLE happens on answer completion
# OR on interrupt/takeover (cancellation path). SUSPENDED returns to the
# pre-suspension state on re-enable (the service re-derives it).
AI_TRANSITIONS: dict[str, set[str]] = {
    AI_IDLE: {AI_LISTENING, AI_RESPONDING, AI_SUSPENDED},
    AI_LISTENING: {AI_IDLE, AI_AWAITING, AI_RESPONDING, AI_SUSPENDED},
    AI_AWAITING: {AI_LISTENING, AI_RESPONDING, AI_SUSPENDED},
    AI_RESPONDING: {AI_IDLE, AI_SUSPENDED},
    AI_SUSPENDED: {AI_IDLE, AI_LISTENING, AI_AWAITING, AI_RESPONDING},
}


@dataclass
class TransitionResult:
    allowed: bool
    reason: str = ""
    pres_state: str = ""
    ai_state: str = ""
    events: list[str] = field(default_factory=list)


def check_pres_transition(current: str, target: str) -> TransitionResult:
    if target not in PRES_TRANSITIONS.get(current, set()):
        return TransitionResult(False, f"presentation state {current} cannot become {target}")
    return TransitionResult(True, pres_state=target)


def check_ai_transition(current: str, target: str) -> TransitionResult:
    if target not in AI_TRANSITIONS.get(current, set()):
        return TransitionResult(False, f"AI state {current} cannot become {target}")
    return TransitionResult(True, ai_state=target)


def check_combination(pres_state: str, ai_state: str) -> TransitionResult:
    if (pres_state, ai_state) not in VALID_COMBINATIONS:
        return TransitionResult(
            False,
            f"combination pres={pres_state} + ai={ai_state} is not a valid session state",
        )
    return TransitionResult(True, pres_state=pres_state, ai_state=ai_state)


def policy_allows_auto_answer(policy: str) -> bool:
    """Whether a raised question can be answered without presenter approval."""
    return policy == "auto"


def policy_allows_ai_any_answer(policy: str) -> bool:
    """Whether the AI may answer at all — presenter_only never lets it."""
    return policy in ("auto", "approval")
