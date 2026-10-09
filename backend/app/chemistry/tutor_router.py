"""API for the Penrose chemistry laboratory tutor.

Mirrors the physics tutor: one conversational endpoint grounded in the
**validated state of the running simulation**. The deterministic chemistry
(frontend ``stoichiometry.dart`` / 3D scene) owns every number; the tutor may
only explain what it is given and must never invent or change a measurement.

* ``POST /chemistry/tutor/explain`` - explain the current observation,
  procedure step or calculation, using the actual experiment state.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.config.ai_client import AIProviderError, call_ai_json
from app.dependencies.auth import get_current_user
from app.models.models import User

log = logging.getLogger(__name__)

router = APIRouter(prefix="/chemistry/tutor", tags=["Chemistry Tutor"])

_EXPLAIN_SYSTEM = (
    "You are the Penrose ScholarMW chemistry lab tutor. You guide learners "
    "through an interactive acid-base titration practical.\n"
    "RULES YOU MUST OBEY:\n"
    "1. Every number in VERIFIED EXPERIMENT STATE was computed by the "
    "deterministic chemistry engine. Use them exactly as given; never invent, "
    "round differently or 'correct' a measurement.\n"
    "2. If a value is missing from the state, say what must be measured first "
    "instead of guessing.\n"
    "3. Explain observations (indicator colour changes), procedure and safety; "
    "ask short prediction questions to prompt reasoning; give hints before "
    "revealing answers.\n"
    "4. Keep replies under 120 words, plain language, and refer to apparatus "
    "by name (burette, stopcock, conical flask, pipette, meniscus)."
)


class ChatTurn(BaseModel):
    role: str
    content: str


class ExperimentState(BaseModel):
    """Validated snapshot of the running titration (no student input here)."""

    experiment: str = Field(default="acid-base titration")
    phase: str = Field(default="notStarted", max_length=32)
    step: int | None = None
    delivered_ml: float | None = Field(default=None, ge=0, le=100)
    initial_reading_ml: float | None = Field(default=None, ge=0, le=100)
    final_reading_ml: float | None = Field(default=None, ge=0, le=100)
    titre_ml: float | None = Field(default=None, ge=0, le=100)
    current_ph: float | None = Field(default=None, ge=0, le=14)
    indicator_colour: str | None = Field(default=None, max_length=64)
    at_endpoint: bool | None = None
    calculated_concentration: float | None = Field(default=None, ge=0)
    analyte: str | None = Field(default=None, max_length=64)
    titrant: str | None = Field(default=None, max_length=64)
    analyte_concentration: float | None = Field(default=None, ge=0)
    expected_titre_ml: float | None = Field(default=None, ge=0, le=100)


class ExplainRequest(BaseModel):
    question: str = Field(min_length=1, max_length=1000)
    state: ExperimentState = Field(default_factory=ExperimentState)
    history: list[ChatTurn] = Field(default_factory=list)


class ExplainResponse(BaseModel):
    reply: str
    source: str  # 'ai' or 'deterministic'


def _state_brief(state: ExperimentState) -> str:
    lines = [
        f"Experiment: {state.experiment}",
        f"Phase: {state.phase}",
        f"Titrant: {state.titrant or 'unknown'} in the burette",
        f"Analyte: {state.analyte or 'unknown'} in the conical flask",
    ]
    if state.step is not None:
        lines.append(f"Current procedure step: {state.step + 1}")
    if state.delivered_ml is not None:
        lines.append(f"Titrant delivered so far: {state.delivered_ml:.2f} mL")
    if state.initial_reading_ml is not None:
        lines.append(f"Initial burette reading: {state.initial_reading_ml:.2f} mL")
    if state.final_reading_ml is not None:
        lines.append(f"Final burette reading: {state.final_reading_ml:.2f} mL")
    if state.titre_ml is not None:
        lines.append(f"Recorded titre: {state.titre_ml:.2f} mL")
    if state.current_ph is not None:
        lines.append(f"Current flask pH: {state.current_ph:.2f}")
    if state.indicator_colour:
        lines.append(f"Indicator colour right now: {state.indicator_colour}")
    if state.at_endpoint is not None:
        lines.append(f"Endpoint reached: {state.at_endpoint}")
    if state.calculated_concentration is not None:
        lines.append(
            "Titrant concentration calculated from the run: "
            f"{state.calculated_concentration:.4f} mol/dm3"
        )
    if state.expected_titre_ml is not None:
        lines.append(f"Theoretical equivalence volume: {state.expected_titre_ml:.2f} mL")
    return "\n".join(lines)


def _deterministic_reply(question: str, state: ExperimentState) -> str:
    """Grounded reply without a model, so the panel never goes silent."""
    lowered = question.lower()

    if any(w in lowered for w in ("pink", "colour", "color", "indicator")):
        if state.at_endpoint:
            return (
                "The phenolphthalein has turned pale pink because the flask "
                "contents just passed pH 8.2 - the acid has been neutralised "
                "and you now have a trace of excess base. That first permanent "
                "pink is the endpoint: stop the titration now and record the "
                "final burette reading."
            )
        if state.indicator_colour:
            return (
                "The indicator is currently colourless because the flask is "
                f"still acidic (pH {state.current_ph:.2f}). Phenolphthalein only "
                "turns pale pink once the contents pass pH 8.2, so keep adding "
                "titrant slowly near the equivalence volume."
            )
        return (
            "Add a few drops of phenolphthalein to the flask first - it is "
            "colourless in acid and turns pale pink at the endpoint."
        )

    if any(w in lowered for w in ("titre", "reading", "record")):
        if state.initial_reading_ml is not None and state.final_reading_ml is not None:
            titre = state.final_reading_ml - state.initial_reading_ml
            return (
                "Your titre is the difference between the readings: "
                f"{state.final_reading_ml:.2f} - {state.initial_reading_ml:.2f} "
                f"= {titre:.2f} mL. Read the meniscus at eye level, to 0.05 mL."
            )
        return (
            "Record the initial burette reading before you start, then the "
            "final reading when the endpoint appears. The titre is the "
            "difference between them."
        )

    if any(w in lowered for w in ("concentration", "calculate", "mole")):
        if state.calculated_concentration is not None:
            return (
                "At the equivalence point, moles of base = moles of acid for "
                "this 1:1 reaction. From the verified run: concentration = "
                f"{state.calculated_concentration:.4f} mol/dm3. The same value "
                "is shown in your results panel."
            )
        if state.initial_reading_ml is not None and state.final_reading_ml is not None:
            titre = state.final_reading_ml - state.initial_reading_ml
            return (
                "Once the titre is recorded, the moles of acid in the flask "
                "are known, and at equivalence moles of base equal moles of "
                "acid. Divide those moles by your titre volume in dm3 - try "
                "it, then check the results panel."
            )
        return (
            "To calculate the unknown concentration you first need a complete "
            "run: fill the burette, record both readings, and stop at the "
            "first permanent pale pink."
        )

    if "swirl" in lowered:
        return (
            "Swirling keeps every drop that leaves the burette mixed evenly "
            "through the flask, so the colour change appears as a true "
            "endpoint of the whole solution rather than a local hot spot of "
            "base around the drop."
        )

    if any(w in lowered for w in ("safe", "safety", "danger")):
        return (
            "Wear goggles throughout; NaOH and HCl are corrosive. Fill the "
            "burette below eye level with the stopcock closed, use a funnel, "
            "and remove it before titrating so drips cannot enter the "
            "reading. Rinse any spill with plenty of water immediately."
        )

    if any(w in lowered for w in ("equivalence", "curve", "graph")):
        if state.expected_titre_ml is not None:
            return (
                "The equivalence point for this system is at about "
                f"{state.expected_titre_ml:.2f} mL of titrant, where the pH "
                "curve is steepest and jumps around pH 7. The indicator "
                "endpoint sits where the colour first stays pink - very close "
                "to, but not identical with, that theoretical point."
            )
        return (
            "The titration curve plots pH against volume added; the steep "
            "vertical jump marks the equivalence point, where moles of acid "
            "and base exactly balance."
        )

    phase = state.phase
    if phase == "notStarted":
        return (
            "Start by collecting the apparatus and filling the burette with "
            "the titrant, then record the initial reading. Ask me about any "
            "step before you begin."
        )
    if phase == "ready":
        return (
            "The burette is filled and the flask is prepared. Open the "
            "stopcock, swirl gently, and watch the flask as you approach the "
            "equivalence volume."
        )
    if phase == "titrating":
        return (
            "Titrant is flowing. Slow the drops as the pink flashes start to "
            "last longer - a half-drop at a time near the endpoint. Ask me "
            "why swirling matters if you are unsure."
        )
    return (
        "Tell me what you would like explained - the colour change, your "
        "readings, or the concentration calculation - and I will walk you "
        "through it using the verified state of your run."
    )


@router.post("/explain", response_model=ExplainResponse)
async def explain(
    payload: ExplainRequest, user: User = Depends(get_current_user)
) -> ExplainResponse:
    """Answer a question using only the validated experiment state."""
    messages: list[dict[str, str]] = [
        {"role": "system", "content": _EXPLAIN_SYSTEM},
        {
            "role": "user",
            "content": (
                "VERIFIED EXPERIMENT STATE\n"
                f"{_state_brief(payload.state)}\n\n"
                f"STUDENT QUESTION: {payload.question}"
            ),
        },
    ]
    for turn in payload.history[-6:]:
        if turn.role in {"user", "assistant"} and turn.content.strip():
            messages.append({"role": turn.role, "content": turn.content})

    try:
        parsed = await call_ai_json(messages, max_tokens=500, temperature=0.3)
    except (AIProviderError, RuntimeError, ValueError, TimeoutError, OSError) as exc:
        log.info("Chemistry tutor falling back to deterministic reply: %s", exc)
        return ExplainResponse(
            reply=_deterministic_reply(payload.question, payload.state),
            source="deterministic",
        )

    reply = ""
    if isinstance(parsed, dict):
        reply = str(parsed.get("reply") or "").strip()
    if not reply:
        return ExplainResponse(
            reply=_deterministic_reply(payload.question, payload.state),
            source="deterministic",
        )
    return ExplainResponse(reply=reply, source="ai")
