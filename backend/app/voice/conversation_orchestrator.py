from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone

from app.voice.models import ConversationTurn, VoiceSessionState

log = logging.getLogger(__name__)


@dataclass
class VoiceConversationContext:
    session_id: str
    user_id: int
    agent_type: str = "tutor"
    subject: str = ""
    topic: str = ""
    language: str = "en"
    state: VoiceSessionState = VoiceSessionState.IDLE
    turns: list[ConversationTurn] = field(default_factory=list)
    response_modality: str = "combined"
    education_level: str = ""
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @property
    def history_for_ai(self) -> list[dict[str, str]]:
        return [{"role": t.role, "content": t.content} for t in self.turns[-20:]]

    @property
    def conversation_summary(self) -> str:
        if not self.turns:
            return "New conversation"
        recent = self.turns[-3:]
        return " | ".join(f"{t.role}: {t.content[:100]}" for t in recent)


class ConversationOrchestrator:
    """Manages voice conversation sessions.

    Decides response modality, manages context, and coordinates
    between STT, AI, and TTS pipelines.
    """

    def __init__(self) -> None:
        self._sessions: dict[str, VoiceConversationContext] = {}

    def create_session(
        self,
        user_id: int,
        agent_type: str = "tutor",
        subject: str = "",
        topic: str = "",
        language: str = "en",
    ) -> VoiceConversationContext:
        session_id = str(uuid.uuid4())[:12]
        ctx = VoiceConversationContext(
            session_id=session_id,
            user_id=user_id,
            agent_type=agent_type,
            subject=subject,
            topic=topic,
            language=language,
        )
        self._sessions[session_id] = ctx
        log.info("Voice session created: %s for user %d", session_id, user_id)
        return ctx

    def get_session(self, session_id: str) -> VoiceConversationContext | None:
        return self._sessions.get(session_id)

    def remove_session(self, session_id: str) -> None:
        self._sessions.pop(session_id, None)

    def classify_response_modality(self, user_text: str, ai_text: str) -> str:
        """Determine how the response should be delivered."""
        lower = user_text.lower()

        audio_keywords = (
            "speak",
            "say it",
            "tell me verbally",
            "read aloud",
            "voice",
            "audio",
        )
        if any(kw in lower for kw in audio_keywords):
            return "audio"

        text_keywords = ("just text", "don't speak", "write it", "text only", "show me")
        if any(kw in lower for kw in text_keywords):
            return "text"

        visual_keywords = (
            "show",
            "diagram",
            "draw",
            "visual",
            "chart",
            "graph",
            "picture",
        )
        if any(kw in lower for kw in visual_keywords):
            return "visual"

        return "combined"

    def record_turn(
        self,
        session_id: str,
        role: str,
        content: str,
        modality: str = "text",
        metadata: dict | None = None,
    ) -> None:
        ctx = self._sessions.get(session_id)
        if not ctx:
            return
        ctx.turns.append(
            ConversationTurn(
                role=role,
                content=content,
                modality=modality,
                metadata=metadata or {},
            )
        )

    def interrupt(self, session_id: str) -> bool:
        ctx = self._sessions.get(session_id)
        if not ctx or ctx.state != VoiceSessionState.SPEAKING:
            return False
        ctx.state = VoiceSessionState.INTERRUPTED
        log.info("Voice session %s interrupted", session_id)
        return True

    def get_context_for_ai(self, session_id: str) -> dict:
        ctx = self._sessions.get(session_id)
        if not ctx:
            return {}
        return {
            "session_id": ctx.session_id,
            "subject": ctx.subject,
            "topic": ctx.topic,
            "agent_type": ctx.agent_type,
            "language": ctx.language,
            "response_modality": ctx.response_modality,
            "turn_count": len(ctx.turns),
            "history": ctx.history_for_ai,
            "summary": ctx.conversation_summary,
        }


orchestrator = ConversationOrchestrator()
