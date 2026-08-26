from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.context_engine.models import (
    ActiveVisualContext,
    ConversationContext,
    LearningState,
    ResponseMode,
    WorkspaceState,
)
from app.models.stem import MasteryRecord

log = logging.getLogger(__name__)


class ContextManager:
    """In-memory conversation context store keyed by (user_id, session_id).

    Maintains structured learning context across a conversation session.
    The frontend sends a WorkspaceState snapshot on every interaction; the
    manager merges it with persisted learning state to produce a full
    ConversationContext that is injected into the AI system prompt.
    """

    def __init__(self) -> None:
        self._store: dict[tuple[int, int], ConversationContext] = {}

    def _key(self, user_id: int, session_id: int) -> tuple[int, int]:
        return (user_id, session_id)

    def get(self, user_id: int, session_id: int) -> ConversationContext | None:
        return self._store.get(self._key(user_id, session_id))

    def upsert(self, ctx: ConversationContext) -> None:
        self._store[self._key(ctx.user_id, ctx.session_id)] = ctx

    def remove(self, user_id: int, session_id: int) -> None:
        self._store.pop(self._key(user_id, session_id), None)

    # ------------------------------------------------------------------
    # Build / refresh context from workspace + DB
    # ------------------------------------------------------------------

    async def build_context(
        self,
        user_id: int,
        session_id: int,
        workspace: WorkspaceState | None,
        db: AsyncSession,
        *,
        agent_type: str = "tutor",
    ) -> ConversationContext:
        """Build or update the live context for a conversation turn."""
        ctx = self.get(user_id, session_id)
        if ctx is None:
            ctx = ConversationContext(
                session_id=session_id,
                user_id=user_id,
                agent_type=agent_type,
            )

        # Merge workspace state (what the student is viewing right now)
        if workspace:
            ctx.workspace = workspace
            ctx.subject = workspace.subject or ctx.subject
            ctx.syllabus = workspace.syllabus or ctx.syllabus
            ctx.topic = workspace.topic or ctx.topic
            ctx.subtopic = workspace.subtopic or ctx.subtopic
            ctx.current_objective = workspace.current_objective or ctx.current_objective
            ctx.active_lesson = workspace.active_lesson or ctx.active_lesson
            ctx.current_learning_material = (
                workspace.active_content or ctx.current_learning_material
            )
            ctx.selected_text = workspace.selected_text or ctx.selected_text
            ctx.current_page = workspace.current_page or ctx.current_page

            # Visual context from workspace
            if workspace.active_visual_id:
                ctx.current_visual = ActiveVisualContext(
                    visual_id=workspace.active_visual_id,
                    visual_type=workspace.active_visual_type,
                    selected_element=workspace.active_visual_element,
                )

            if workspace.active_question_id:
                ctx.current_question = str(workspace.active_question_id)

        # Load learning state from DB
        ctx.learning_state = await self._load_learning_state(user_id, db)

        ctx.conversation_turns += 1
        ctx.updated_at = datetime.now(timezone.utc)
        self.upsert(ctx)
        return ctx

    async def _load_learning_state(
        self, user_id: int, db: AsyncSession
    ) -> LearningState:
        """Derive learning state from mastery records."""
        result = await db.execute(
            select(MasteryRecord).where(MasteryRecord.user_id == user_id)
        )
        records = result.scalars().all()

        if not records:
            return LearningState()

        total_attempts = sum(r.attempts for r in records)
        correct = sum(r.correct for r in records)
        avg_mastery = (
            sum(r.mastery_level for r in records) / len(records) if records else 0
        )

        struggling = [
            r.concept_id for r in records if r.mastery_level < 0.3 and r.attempts >= 2
        ]

        if avg_mastery < 0.3:
            difficulty = "beginner"
        elif avg_mastery < 0.6:
            difficulty = "intermediate"
        elif avg_mastery < 0.8:
            difficulty = "advanced"
        else:
            difficulty = "expert"

        return LearningState(
            current_mastery_pct=round(avg_mastery * 100, 1),
            total_attempts=total_attempts,
            correct_answers=correct,
            struggling_concepts=[str(c) for c in struggling[:10]],
            difficulty_level=difficulty,
        )

    # ------------------------------------------------------------------
    # Update context after AI responds
    # ------------------------------------------------------------------

    def record_ai_response(
        self,
        user_id: int,
        session_id: int,
        ai_topic: str = "",
        intent: str = "",
    ) -> None:
        ctx = self.get(user_id, session_id)
        if not ctx:
            return
        if ai_topic:
            ctx.last_ai_topic = ai_topic
            if ai_topic not in ctx.referenced_topics:
                ctx.referenced_topics.append(ai_topic)
                if len(ctx.referenced_topics) > 20:
                    ctx.referenced_topics = ctx.referenced_topics[-20:]
        if intent:
            ctx.last_user_intent = intent
        self.upsert(ctx)

    # ------------------------------------------------------------------
    # Update context with user's explicit visual selection
    # ------------------------------------------------------------------

    def set_visual_selection(
        self,
        user_id: int,
        session_id: int,
        visual_id: str,
        visual_type: str,
        element: str = "",
        element_label: str = "",
        element_description: str = "",
    ) -> None:
        ctx = self.get(user_id, session_id)
        if not ctx:
            return
        ctx.current_visual = ActiveVisualContext(
            visual_id=visual_id,
            visual_type=visual_type,
            selected_element=element,
            element_label=element_label,
            element_description=element_description,
        )
        self.upsert(ctx)

    def set_selected_text(self, user_id: int, session_id: int, text: str) -> None:
        ctx = self.get(user_id, session_id)
        if not ctx:
            return
        ctx.selected_text = text
        self.upsert(ctx)

    def set_response_mode(
        self, user_id: int, session_id: int, mode: ResponseMode
    ) -> None:
        ctx = self.get(user_id, session_id)
        if not ctx:
            return
        ctx.preferred_response_mode = mode
        self.upsert(ctx)

    def record_question(self, user_id: int, session_id: int, question: str) -> None:
        ctx = self.get(user_id, session_id)
        if not ctx:
            return
        ctx.current_question = question
        if question not in ctx.asked_questions:
            ctx.asked_questions.append(question)
        self.upsert(ctx)


# Module-level singleton
context_manager = ContextManager()
