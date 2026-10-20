from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum

from pydantic import BaseModel, Field

# ---------------------------------------------------------------------------
# Response modes
# ---------------------------------------------------------------------------


class ResponseMode(str, Enum):
    TEXT = "text"
    AUDIO = "audio"
    VISUAL = "visual"
    INTERACTIVE = "interactive"
    COMBINED = "combined"
    STREAMING = "streaming"


# ---------------------------------------------------------------------------
# Workspace / screen state — sent by the Flutter client on every interaction
# ---------------------------------------------------------------------------


class WorkspaceState(BaseModel):
    """What the student is currently viewing or doing in the app."""

    screen: str = ""
    subject: str = ""
    syllabus: str = ""
    topic: str = ""
    subtopic: str = ""
    current_objective: str = ""
    active_lesson: str = ""
    active_content: str = ""
    selected_text: str = ""
    active_visual_id: str = ""
    active_visual_type: str = ""
    active_visual_element: str = ""
    active_question_id: str | int = ""
    current_page: str = ""
    active_tab: str = ""
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


# ---------------------------------------------------------------------------
# Active visual context — for tap-select-ask on diagrams/charts/equations
# ---------------------------------------------------------------------------


class ActiveVisualContext(BaseModel):
    visual_id: str = ""
    visual_type: str = ""
    selected_element: str = ""
    element_label: str = ""
    element_description: str = ""


# ---------------------------------------------------------------------------
# Learning state — derived from mastery records + session history
# ---------------------------------------------------------------------------


class LearningState(BaseModel):
    """Tracks what the learner knows, struggles with, and prefers."""

    current_mastery_pct: float = 0.0
    total_attempts: int = 0
    correct_answers: int = 0
    struggling_concepts: list[str] = Field(default_factory=list)
    recent_mistakes: list[str] = Field(default_factory=list)
    difficulty_level: str = "intermediate"
    preferred_response_mode: str = "text"
    session_count: int = 0
    total_study_minutes: int = 0
    streak_days: int = 0


# ---------------------------------------------------------------------------
# Conversation context — full structured context for each conversation
# ---------------------------------------------------------------------------


class ConversationContext(BaseModel):
    """Structured context maintained across a conversation session."""

    session_id: int = 0
    user_id: int = 0
    agent_type: str = "tutor"

    # Academic context
    subject: str = ""
    syllabus: str = ""
    topic: str = ""
    subtopic: str = ""
    current_objective: str = ""
    active_lesson: str = ""
    current_learning_material: str = ""
    current_page: str = ""

    # Active items
    current_question: str = ""
    current_visual: ActiveVisualContext = Field(default_factory=ActiveVisualContext)
    selected_text: str = ""
    active_command: str = ""

    # Workspace snapshot
    workspace: WorkspaceState = Field(default_factory=WorkspaceState)

    # Learning state
    learning_state: LearningState = Field(default_factory=LearningState)

    # Conversation
    preferred_response_mode: ResponseMode = ResponseMode.TEXT
    conversation_turns: int = 0
    last_user_intent: str = ""
    last_ai_topic: str = ""

    # History summaries (not full messages — just key references)
    referenced_topics: list[str] = Field(default_factory=list)
    asked_questions: list[str] = Field(default_factory=list)

    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    def to_prompt_block(self) -> str:
        """Serialise into a concise block for injection into the system prompt."""
        parts = ["\n\n=== ACTIVE LEARNING CONTEXT ==="]

        if self.subject:
            parts.append(f"Subject: {self.subject}")
        if self.syllabus:
            parts.append(f"Syllabus: {self.syllabus}")
        if self.topic:
            parts.append(f"Topic: {self.topic}")
        if self.subtopic:
            parts.append(f"Subtopic: {self.subtopic}")
        if self.current_objective:
            parts.append(f"Current Learning Objective: {self.current_objective}")
        if self.active_lesson:
            parts.append(f"Active Lesson: {self.active_lesson}")
        if self.current_learning_material:
            parts.append(f"Current Learning Material: {self.current_learning_material}")
        if self.current_page:
            parts.append(f"Current Page: {self.current_page}")
        if self.current_question:
            parts.append(f"Current Question Being Answered: {self.current_question}")
        if self.selected_text:
            parts.append(f'Student Has Selected Text: "{self.selected_text}"')
        if self.current_visual.visual_id:
            parts.append(
                f"Active Visual: {self.current_visual.visual_type} "
                f"(id={self.current_visual.visual_id})"
            )
            if self.current_visual.selected_element:
                parts.append(
                    f"Student Tapped/Selected Element: "
                    f'"{self.current_visual.selected_element}" '
                    f"({self.current_visual.element_label})"
                )
        if self.active_command:
            parts.append(f'Student Command: "{self.active_command}"')

        if self.learning_state.current_mastery_pct > 0:
            ls = self.learning_state
            parts.append(
                f"Mastery: {ls.current_mastery_pct:.0f}% "
                f"({ls.correct_answers}/{ls.total_attempts} correct)"
            )
            if ls.struggling_concepts:
                parts.append(
                    f"Struggling With: {', '.join(ls.struggling_concepts[:5])}"
                )
            if ls.recent_mistakes:
                parts.append(f"Recent Mistakes: {', '.join(ls.recent_mistakes[:3])}")

        if self.preferred_response_mode != ResponseMode.TEXT:
            parts.append(
                f"Preferred Response Mode: {self.preferred_response_mode.value}"
            )

        if self.referenced_topics:
            parts.append(
                f"Previously Discussed: {', '.join(self.referenced_topics[-5:])}"
            )

        parts.append(
            "The student's current context is provided above. "
            "When they say 'this', 'it', 'explain again', 'why', 'show me', etc. "
            "respond in relation to the ACTIVE context above without asking for clarification."
        )
        parts.append("=== END ACTIVE LEARNING CONTEXT ===\n")

        return "\n".join(parts)
