from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass
class UserIntent:
    """Classified intent from a user message."""

    action: str
    target: str
    response_mode: str
    is_followup: bool
    is_visual_request: bool
    is_audio_request: bool
    is_quiz_request: bool
    is_teaching_mode: bool
    is_interrupt: bool
    is_combined: bool = False
    confidence: float = 0.7


class IntentClassifier:
    """Rule-based + keyword intent classifier.

    Classifies the user's message into an action, target, and response mode
    without requiring an LLM call. Fast, deterministic, and always available.
    """

    # -- action patterns (order matters: first match wins) --

    _VISUAL_KEYWORDS = re.compile(
        r"\b(show|draw|diagram|plot|graph|chart|illustrat|visualis|visualiz|"
        r"picture|image|figure|sketch|depict|render|display|map|timeline)\b",
        re.IGNORECASE,
    )
    _AUDIO_KEYWORDS = re.compile(
        r"\b(speak|say|tell me|read aloud|narrate|voice|audio|listen|"
        r"talk to me|verbal|pronounce|recite)\b",
        re.IGNORECASE,
    )
    _QUIZ_KEYWORDS = re.compile(
        r"\b(quiz|test|exam|assess|question|challenge|check my|"
        r"evaluate|mcq|multiple.choice|true.false|fill.in)\b",
        re.IGNORECASE,
    )
    _TEACH_KEYWORDS = re.compile(
        r"\b(teach|lesson|tutor|guide|walk me|step by step|"
        r"interactive|learn|study|explain and teach)\b",
        re.IGNORECASE,
    )
    _EXPLAIN_KEYWORDS = re.compile(
        r"\b(explain|what is|what are|what does|define|describe|"
        r"tell me about|how does|how do|how is|why does|why do|why is|"
        r"describe|clarify|elaborate|meaning)\b",
        re.IGNORECASE,
    )
    _EXAMPLE_KEYWORDS = re.compile(
        r"\b(example|give me|show me an|demonstrate|illustrate with|"
        r"work through|worked example|sample)\b",
        re.IGNORECASE,
    )
    _PRACTICE_KEYWORDS = re.compile(
        r"\b(practice|practise|exercises|problems|drill|"
        r"let me try|let me attempt|i want to try)\b",
        re.IGNORECASE,
    )
    _SUMMARY_KEYWORDS = re.compile(
        r"\b(summarise|summarize|recap|review|brief|quick|overview|"
        r"in short|tldr|key points|main points)\b",
        re.IGNORECASE,
    )
    _SIMPLIFY_KEYWORDS = re.compile(
        r"\b(simpl|easier|basic|beginner|in simple|plain english|"
        r"ELI5|child|young student|less complicated)\b",
        re.IGNORECASE,
    )
    _DEEPEN_KEYWORDS = re.compile(
        r"\b(deeper|advanced|proof|theorem|rigorous|formal|"
        r"mathematical|theory|principle|underlying|foundation)\b",
        re.IGNORECASE,
    )
    _SOLVE_KEYWORDS = re.compile(
        r"\b(solve|calculate|compute|find|work out|solve this|"
        r"answer|derive|evaluate the)\b",
        re.IGNORECASE,
    )

    # -- follow-up / anaphora patterns --

    _FOLLOWUP_PATTERNS = re.compile(
        r"^(explain this|explain it|why\??|how\??|what about|"
        r"and then|what if|go on|continue|more|again|"
        r"say that again|repeat|another example|give me another|"
        r"what about this|what does this mean|what is this|"
        r"draw it|show me|teach me|test me|quiz me)$",
        re.IGNORECASE,
    )

    # -- interruption patterns --

    _INTERRUPT_PATTERNS = re.compile(
        r"^(wait|stop|hold on|pause|interrupt|never mind|nevermind|"
        r"forget that|cancel|skip|go back|actually|no forget)\b",
        re.IGNORECASE,
    )

    # -- explicit response mode overrides --

    _COMBINED_KEYWORDS = re.compile(
        r"\b(and show|and draw|and diagram|while showing|"
        r"with diagram|with visual|with audio|both text|"
        r"explain and show|explain and draw|text and audio)\b",
        re.IGNORECASE,
    )

    @classmethod
    def classify(cls, message: str) -> UserIntent:
        text = message.strip()
        lower = text.lower()

        # Detect interruption
        is_interrupt = bool(cls._INTERRUPT_PATTERNS.match(lower))

        # Detect follow-up / anaphora
        is_followup = bool(cls._FOLLOWUP_PATTERNS.match(lower)) or (
            len(text.split()) <= 6
            and any(
                w in lower
                for w in ("this", "it", "that", "them", "again", "more", "why", "how")
            )
        )

        # Detect explicit response modes
        is_visual_request = bool(cls._VISUAL_KEYWORDS.search(text))
        is_audio_request = bool(cls._AUDIO_KEYWORDS.search(text))
        is_quiz_request = bool(cls._QUIZ_KEYWORDS.search(text))
        is_teaching_mode = bool(cls._TEACH_KEYWORDS.search(text))

        # Combined mode
        is_combined = bool(cls._COMBINED_KEYWORDS.search(text))

        # Determine primary action
        action = "explain"  # default
        if is_quiz_request:
            action = "quiz"
        elif is_teaching_mode:
            action = "teach"
        elif is_visual_request and not is_audio_request:
            action = "visual"
        elif is_audio_request and not is_visual_request:
            action = "audio"
        elif is_combined:
            action = "combined"
        elif cls._EXAMPLE_KEYWORDS.search(text):
            action = "example"
        elif cls._PRACTICE_KEYWORDS.search(text):
            action = "practice"
        elif cls._SUMMARY_KEYWORDS.search(text):
            action = "summary"
        elif cls._SIMPLIFY_KEYWORDS.search(text):
            action = "simplify"
        elif cls._DEEPEN_KEYWORDS.search(text):
            action = "deepen"
        elif cls._SOLVE_KEYWORDS.search(text):
            action = "solve"
        elif cls._EXPLAIN_KEYWORDS.search(text):
            action = "explain"

        # Determine response mode
        if is_combined:
            response_mode = "combined"
        elif is_visual_request:
            response_mode = "visual"
        elif is_audio_request:
            response_mode = "audio"
        elif is_teaching_mode:
            response_mode = "interactive"
        else:
            response_mode = "text"

        # Determine target (what the action is about — extracted from message)
        target = cls._extract_target(text, action)

        confidence = (
            0.9 if (is_followup or is_visual_request or is_audio_request) else 0.7
        )

        return UserIntent(
            action=action,
            target=target,
            response_mode=response_mode,
            is_followup=is_followup,
            is_visual_request=is_visual_request,
            is_audio_request=is_audio_request,
            is_quiz_request=is_quiz_request,
            is_teaching_mode=is_teaching_mode,
            is_interrupt=is_interrupt,
            is_combined=is_combined,
            confidence=confidence,
        )

    @staticmethod
    def _extract_target(text: str, action: str) -> str:
        """Best-effort extraction of the topic/target from the message."""
        # Remove common command prefixes
        cleaned = re.sub(
            r"^(please\s+)?(can you|could you|would you|will you|"
            r"explain|tell me about|show me|describe|draw|what is|what are|"
            r"what does|how does|how do|why does|why do|teach me|"
            r"give me|let me|help me|let's)\s+",
            "",
            text,
            flags=re.IGNORECASE,
        ).strip()
        # Remove trailing punctuation
        cleaned = cleaned.rstrip("?.!")
        if len(cleaned) > 5:
            return cleaned[:200]
        return text[:200]
