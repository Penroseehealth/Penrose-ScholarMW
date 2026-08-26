from __future__ import annotations

from app.context_engine.intent_classifier import UserIntent
from app.context_engine.models import ConversationContext, ResponseMode


class ResponseModeRouter:
    """Determines the optimal response modality based on:

    1. User's explicit command (highest priority)
    2. Intent classification
    3. Learning state adaptation
    4. Content type in context
    5. Fallback to text
    """

    @staticmethod
    def decide(
        ctx: ConversationContext,
        intent: UserIntent,
    ) -> ResponseMode:
        # Priority 1: explicit user command overrides everything
        if intent.is_combined:
            return ResponseMode.COMBINED
        if intent.is_visual_request:
            return ResponseMode.VISUAL
        if intent.is_audio_request:
            return ResponseMode.AUDIO
        if intent.is_teaching_mode:
            return ResponseMode.INTERACTIVE

        # Priority 2: prefer user's stored preference if they set one explicitly
        if ctx.preferred_response_mode != ResponseMode.TEXT:
            return ctx.preferred_response_mode

        # Priority 3: learning-state adaptation
        if intent.action in ("quiz", "practice", "challenge"):
            return ResponseMode.INTERACTIVE
        if intent.action == "teach":
            return ResponseMode.INTERACTIVE

        # Priority 4: content-type based
        if ctx.current_visual.visual_id and intent.is_followup:
            return ResponseMode.COMBINED

        # Default: text
        return ResponseMode.TEXT

    @staticmethod
    def mode_to_mode_instruction(mode: ResponseMode) -> str:
        """Return a system-prompt instruction fragment for the chosen mode."""
        return {
            ResponseMode.TEXT: (
                "Respond with a clear, well-structured text explanation. "
                "Use markdown and LaTeX notation as instructed."
            ),
            ResponseMode.AUDIO: (
                "Respond with text that will be read aloud via text-to-speech. "
                "Use natural spoken language. Avoid heavy LaTeX; use verbal-friendly notation. "
                "Keep sentences clear and pronounceable. Avoid bullet-heavy formatting."
            ),
            ResponseMode.VISUAL: (
                "Respond with a text explanation accompanied by a visual (diagram, chart, graph). "
                "Follow the visual generation policy strictly. "
                "The visual must be the centrepiece of your response."
            ),
            ResponseMode.INTERACTIVE: (
                "Enter interactive tutoring mode. Explain one concept at a time. "
                "After each explanation, check the student's understanding with a question. "
                "Wait for their response before continuing. "
                "Adapt depth based on their answers."
            ),
            ResponseMode.COMBINED: (
                "Provide a multimodal response: text explanation + visual + "
                "a brief spoken-friendly summary at the end."
            ),
            ResponseMode.STREAMING: (
                "Respond in a streaming-friendly way: start with the most important "
                "point first, then progressively elaborate. "
                "Each paragraph should be self-contained and meaningful on its own."
            ),
        }.get(mode, "Respond clearly and helpfully.")

    @classmethod
    def get_system_prompt_addition(
        cls,
        ctx: ConversationContext,
        intent: UserIntent,
    ) -> str:
        mode = cls.decide(ctx, intent)
        parts = [
            "\n\n=== RESPONSE MODE ===",
            cls.mode_to_mode_instruction(mode),
        ]

        if ctx.selected_text:
            parts.append(
                f'The student has selected text: "{ctx.selected_text}". '
                "Explain or respond about this specific selection."
            )
        if ctx.current_visual.visual_id and ctx.current_visual.selected_element:
            parts.append(
                f'The student tapped on "{ctx.current_visual.selected_element}" '
                f"in the {ctx.current_visual.visual_type}. "
                "Explain this specific element."
            )
        if intent.is_followup:
            parts.append(
                "This is a follow-up question. Do NOT ask what they mean. "
                "Respond directly using the active learning context."
            )

        parts.append("=== END RESPONSE MODE ===\n")
        return "\n".join(parts)
