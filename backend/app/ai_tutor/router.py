import json

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config.settings import get_settings
from app.config.stem_latex import (
    CONTEXT_AWARE_INSTRUCTION,
    STEM_LATEX_INSTRUCTION,
    VISUAL_GENERATION_POLICY,
)
from app.context_engine.context_manager import context_manager
from app.context_engine.intent_classifier import IntentClassifier
from app.context_engine.models import WorkspaceState
from app.context_engine.response_mode_router import ResponseModeRouter
from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import ChatMessage, ChatSession, User
from app.schemas.ai import (
    AssessmentGenerateRequest,
    ChatMessageResponse,
    ChatRequest,
    ChatSessionDetail,
    ChatSessionResponse,
    LessonPlanRequest,
    LessonPlanResponse,
    StudyPlanRequest,
    StudyPlanResponse,
)

router = APIRouter(prefix="/ai", tags=["ScholarAI"])
settings = get_settings()


SOURCE_CITATION_INSTRUCTION = (
    "\n\nIMPORTANT — Source Attribution:\n"
    "After your main response, always append a '--- SOURCES ---' section listing the "
    "references, textbooks, papers, or standards you used. Format each source on its own line "
    "starting with '- '. Include author, title, year where possible.\n"
    "If you used no specific source, list 'General STEM knowledge' as the source.\n"
    "The SOURCES section MUST appear at the very end of every response, after all other content.\n"
)


def _extract_sources(text: str) -> tuple[str, str | None]:
    marker = "--- SOURCES ---"
    idx = text.rfind(marker)
    if idx == -1:
        return text, None
    content = text[:idx].rstrip()
    sources_block = text[idx + len(marker) :].strip()
    source_lines = [
        line.lstrip("- ").strip()
        for line in sources_block.splitlines()
        if line.strip().startswith("-")
    ]
    if not source_lines:
        return content, None
    return content, json.dumps(source_lines)


async def _retrieve_grounding(message: str) -> str:
    """Fetch live educational sources and return the prompt block (or '').

    Best-effort: any failure yields an empty string so the tutor still answers
    from its own knowledge.
    """
    try:
        from app.retrieval.orchestrator import search

        result = await search(message)
        if not result.has_results:
            return ""
        return result.grounding_prompt_block()
    except Exception as exc:  # noqa: BLE001 - retrieval must never break chat
        import logging

        logging.getLogger(__name__).info("Retrieval grounding skipped: %s", exc)
        return ""


def _merge_live_sources(sources_json: str | None, grounding_block: str) -> str | None:
    """Append the retrieved source citations to the stored sources list."""
    import logging

    if not grounding_block:
        return sources_json
    try:
        import re as _re

        urls = _re.findall(r"^Source: .*?— (\S+)$", grounding_block, _re.MULTILINE)
        titles = _re.findall(r"^\[\d+\] (.+)$", grounding_block, _re.MULTILINE)
        live = [f"{t} — {u}" if u else t for t, u in zip(titles, urls, strict=False)]
        if not live:
            return sources_json
        existing = json.loads(sources_json) if sources_json else []
        merged = existing + [s for s in live if s not in existing]
        return json.dumps(merged)
    except Exception as exc:  # noqa: BLE001
        logging.getLogger(__name__).info("Source merge skipped: %s", exc)
        return sources_json


def _build_system_prompt(agent_type: str) -> str:
    prompts = {
        "tutor": (
            "You are ScholarAI Tutor, an expert academic tutor for Malawian university students. "
            "Explain concepts clearly, use analogies, provide examples, and use Socratic questioning. "
            "Adapt explanation level to the student's year of study."
        ),
        "study_coach": (
            "You are ScholarAI Study Coach. Create personalized study plans, identify weak areas, "
            "track progress, and recommend resources tailored to Malawian university curricula."
        ),
        "writer": (
            "You are ScholarAI Academic Writer. Help structure assignments, improve academic language, "
            "generate outlines, provide citation guidance, and detect unsupported claims."
        ),
        "research": (
            "You are ScholarAI Research Assistant. Search literature, summarize papers, extract "
            "methodologies, compare studies, and build evidence tables for academic research."
        ),
        "assessment": (
            "You are ScholarAI Assessment Generator. Create questions of various types, generate "
            "marking schemes, map questions to learning outcomes, and adjust difficulty levels."
        ),
        "lesson_builder": (
            "You are ScholarAI Lesson Builder. Generate comprehensive lesson plans with objectives, "
            "structure, activities, case studies, discussion questions, quizzes, and references."
        ),
    }
    base = prompts.get(agent_type, prompts["tutor"])
    return (
        base
        + CONTEXT_AWARE_INSTRUCTION
        + STEM_LATEX_INSTRUCTION
        + VISUAL_GENERATION_POLICY
        + SOURCE_CITATION_INSTRUCTION
    )


async def _call_llm(system_prompt: str, messages: list[dict]) -> str:
    from app.config.ai_client import AIProviderError, call_ai_text

    full_messages = [{"role": "system", "content": system_prompt}] + messages
    try:
        return await call_ai_text(full_messages, max_tokens=2000, temperature=0.7)
    except (AIProviderError, RuntimeError, TimeoutError, OSError, Exception) as exc:
        import logging

        logging.getLogger(__name__).warning("AI call failed: %s", exc)
        return f"ScholarAI is currently unavailable. Please try again later. (Detail: {exc})"


class DataAnalysisRequest(BaseModel):
    csv_text: str
    question: str = ""


class CodingPlaygroundRequest(BaseModel):
    code: str
    language: str = "python"


class CodingPlaygroundResponse(BaseModel):
    output: str
    error: str | None = None
    language: str


@router.post("/chat", response_model=ChatMessageResponse)
async def chat(
    body: ChatRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await _chat_impl(body, user, db)
    except HTTPException:
        raise
    except Exception as exc:
        import logging

        logging.getLogger(__name__).exception("Chat endpoint error")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Chat failed: {type(exc).__name__}: {exc}",
        )


async def _chat_impl(
    body: ChatRequest,
    user: User,
    db: AsyncSession,
) -> ChatMessageResponse:
    session_id = body.session_id
    if not session_id:
        session = ChatSession(
            user_id=user.id,
            agent_type=body.agent_type,
            context_course_id=body.context_course_id,
            title=body.message[:80],
        )
        db.add(session)
        await db.commit()
        await db.refresh(session)
        session_id = session.id
    else:
        result = await db.execute(
            select(ChatSession).where(ChatSession.id == session_id)
        )
        session = result.scalar_one_or_none()
        if not session or session.user_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Session not found"
            )

    # --- Live Context Engine: build/update context from workspace ----------
    workspace = None
    if body.workspace:
        workspace = WorkspaceState(
            screen=body.workspace.screen,
            subject=body.workspace.subject,
            syllabus=body.workspace.syllabus,
            topic=body.workspace.topic,
            subtopic=body.workspace.subtopic,
            current_objective=body.workspace.current_objective,
            active_lesson=body.workspace.active_lesson,
            active_content=body.workspace.active_content,
            selected_text=body.workspace.selected_text,
            active_visual_id=body.workspace.active_visual_id,
            active_visual_type=body.workspace.active_visual_type,
            active_visual_element=body.workspace.active_visual_element,
            active_question_id=str(body.workspace.active_question_id),
            current_page=body.workspace.current_page,
        )

    ctx = await context_manager.build_context(
        user_id=user.id,
        session_id=session_id,
        workspace=workspace,
        db=db,
        agent_type=body.agent_type,
    )

    # --- Intent Classification --------------------------------------------
    intent = IntentClassifier.classify(body.message)

    # If the frontend sent an explicit preferred mode, honour it
    if body.preferred_response_mode:
        from app.context_engine.models import ResponseMode as RM

        try:
            ctx.preferred_response_mode = RM(body.preferred_response_mode)
            context_manager.upsert(ctx)
        except ValueError:
            pass

    # --- Record the user's question in context ----------------------------
    context_manager.record_question(user.id, session_id, body.message)

    user_msg = ChatMessage(session_id=session_id, role="user", content=body.message)
    db.add(user_msg)
    await db.commit()

    history_result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.id)
    )
    history = [
        {"role": m.role, "content": m.content} for m in history_result.scalars().all()
    ]

    system_prompt = _build_system_prompt(body.agent_type)

    # --- Inject live context + response mode into system prompt -----------
    system_prompt += ctx.to_prompt_block()
    system_prompt += ResponseModeRouter.get_system_prompt_addition(ctx, intent)

    # --- Ground the answer in live educational sources --------------------
    grounding_block = await _retrieve_grounding(body.message)
    if grounding_block:
        system_prompt += grounding_block

    if body.file_ids:
        from app.stem.multimodal_router import _file_store

        file_context_parts = []
        for fid in body.file_ids:
            f = _file_store.get(fid)
            if f and f.get("user_id") == user.id:
                file_context_parts.append(
                    f"[Uploaded File: {f['filename']} ({f['file_type']})]\n"
                    f"{f.get('extracted_text', '(no text extracted)')}"
                )
        if file_context_parts:
            file_context = "\n\n".join(file_context_parts)
            system_prompt += (
                "\n\nIMPORTANT — The student has uploaded the following file(s). "
                "Use the content as the primary source for your answer. "
                "If the student asks to answer 'using this document only', "
                "do NOT introduce information outside the uploaded content.\n\n"
                f"--- UPLOADED CONTENT ---\n{file_context}\n--- END UPLOADED CONTENT ---"
            )

    ai_response = await _call_llm(system_prompt, history)

    content, sources = _extract_sources(ai_response)
    sources = _merge_live_sources(sources, grounding_block)

    ai_msg = ChatMessage(
        session_id=session_id,
        role="assistant",
        content=content,
        sources=sources,
    )
    db.add(ai_msg)
    await db.commit()
    await db.refresh(ai_msg)

    # --- Update context with what the AI just discussed -------------------
    context_manager.record_ai_response(
        user.id, session_id, ai_topic=ctx.topic, intent=intent.action
    )

    return ChatMessageResponse.model_validate(ai_msg)


@router.get("/sessions", response_model=list[ChatSessionResponse])
async def list_sessions(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ChatSession)
        .where(ChatSession.user_id == user.id)
        .order_by(ChatSession.updated_at.desc())
    )
    return [ChatSessionResponse.model_validate(s) for s in result.scalars().all()]


@router.get("/sessions/{session_id}", response_model=ChatSessionDetail)
async def get_session(
    session_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ChatSession)
        .options(selectinload(ChatSession.messages))
        .where(ChatSession.id == session_id, ChatSession.user_id == user.id)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Session not found"
        )
    return ChatSessionDetail.model_validate(session)


@router.post("/lesson-plan", response_model=LessonPlanResponse)
async def generate_lesson_plan(
    body: LessonPlanRequest,
    user: User = Depends(get_current_user),
):
    system = _build_system_prompt("lesson_builder")
    prompt = (
        f"Generate a {body.duration_minutes}-minute lesson plan for:\n"
        f"Topic: {body.topic}\nLevel: {body.level}\n\n"
        "Return JSON with keys: objectives, introduction, structure (list of dicts with "
        "time_minutes, activity, description), activities, case_study, discussion_questions, "
        "quiz (list of dicts with question, options, answer), homework, references."
    )
    response = await _call_llm(system, [{"role": "user", "content": prompt}])
    try:
        data = json.loads(response)
        return LessonPlanResponse(**data)
    except (json.JSONDecodeError, Exception):
        return LessonPlanResponse(
            objectives=["Understand " + body.topic],
            introduction=f"Introduction to {body.topic}",
            structure=[
                {
                    "time_minutes": body.duration_minutes,
                    "activity": "Lecture",
                    "description": body.topic,
                }
            ],
            activities=["Class discussion"],
            discussion_questions=[f"What are the key concepts in {body.topic}?"],
            quiz=[],
        )


@router.post("/generate-assessment")
async def generate_assessment(
    body: AssessmentGenerateRequest,
    user: User = Depends(get_current_user),
):
    system = _build_system_prompt("assessment")
    prompt = (
        f"Generate {body.num_questions} {body.difficulty}-difficulty questions for topic: "
        f"{body.topic}. Types: {', '.join(body.question_types)}. "
        "Return JSON with keys: questions (list with question_text, question_type, marks, "
        "options, correct_answer, learning_outcome, difficulty), marking_scheme."
    )
    response = await _call_llm(system, [{"role": "user", "content": prompt}])
    try:
        return json.loads(response)
    except json.JSONDecodeError:
        return {"questions": [], "marking_scheme": []}


@router.post("/study-plan", response_model=StudyPlanResponse)
async def generate_study_plan(
    body: StudyPlanRequest,
    user: User = Depends(get_current_user),
):
    system = _build_system_prompt("study_coach")
    prompt = (
        f"Create a study plan for course ID {body.course_id}. "
        f"Exam date: {body.exam_date or 'not set'}. Hours/day: {body.hours_per_day}. "
        "Return JSON with keys: schedule (list of dicts with date, topic, hours, activity), "
        "weak_topics, recommended_resources."
    )
    response = await _call_llm(system, [{"role": "user", "content": prompt}])
    try:
        data = json.loads(response)
        return StudyPlanResponse(**data)
    except (json.JSONDecodeError, Exception):
        return StudyPlanResponse(schedule=[], weak_topics=[], recommended_resources=[])


def _parse_csv_basic(csv_text: str) -> dict:
    lines = [line.strip() for line in csv_text.strip().splitlines() if line.strip()]
    if not lines:
        return {"error": "Empty CSV data"}
    delimiter = ","
    if "\t" in lines[0]:
        delimiter = "\t"
    elif ";" in lines[0] and lines[0].count(";") > lines[0].count(","):
        delimiter = ";"
    headers = [h.strip() for h in lines[0].split(delimiter)]
    rows = []
    for line in lines[1:]:
        vals = [v.strip() for v in line.split(delimiter)]
        rows.append(dict(zip(headers, vals)))
    numeric_cols: dict[str, list[float]] = {}
    for h in headers:
        nums = []
        for row in rows:
            try:
                nums.append(float(row[h]))
            except (ValueError, KeyError):
                pass
        if len(nums) > len(rows) * 0.5:
            numeric_cols[h] = nums
    stats: dict[str, dict] = {}
    for col, vals in numeric_cols.items():
        n = len(vals)
        mean = sum(vals) / n
        variance = sum((x - mean) ** 2 for x in vals) / n if n > 1 else 0
        stats[col] = {
            "count": n,
            "mean": round(mean, 4),
            "min": round(min(vals), 4),
            "max": round(max(vals), 4),
            "std_dev": round(variance**0.5, 4),
            "sum": round(sum(vals), 4),
        }
    return {
        "headers": headers,
        "row_count": len(rows),
        "sample_rows": rows[:10],
        "numeric_stats": stats,
        "all_rows": rows,
    }


@router.post("/data-analysis")
async def analyze_data(
    body: DataAnalysisRequest,
    user: User = Depends(get_current_user),
):
    parsed = _parse_csv_basic(body.csv_text)
    if "error" in parsed:
        raise HTTPException(status_code=400, detail=parsed["error"])

    system = (
        "You are ScholarAI Data Analyst. Analyze the provided dataset and give clear, "
        "educational insights. Explain statistical concepts where relevant. "
        "For Malawian students, relate findings to local context where possible."
    )
    prompt = (
        f"Dataset with {parsed['row_count']} rows and columns: {', '.join(parsed['headers'])}\n\n"
        f"Column statistics:\n{json.dumps(parsed['numeric_stats'], indent=2)}\n\n"
        f"Sample data (first 5 rows):\n{json.dumps(parsed['sample_rows'][:5], indent=2)}\n\n"
    )
    if body.question:
        prompt += f"Student's question: {body.question}\n\n"
    prompt += (
        "Provide: 1) Key insights about the data, 2) Statistical summary in plain language, "
        "3) Any interesting patterns or outliers, 4) Educational notes about the statistics used."
    )

    analysis_text = await _call_llm(system, [{"role": "user", "content": prompt}])
    content, sources = _extract_sources(analysis_text)

    return {
        "analysis": content,
        "sources": sources,
        "stats": parsed["numeric_stats"],
        "headers": parsed["headers"],
        "row_count": parsed["row_count"],
        "sample_data": parsed["sample_rows"][:5],
    }


@router.post("/coding-playground", response_model=CodingPlaygroundResponse)
async def run_code(
    body: CodingPlaygroundRequest,
    user: User = Depends(get_current_user),
):
    if body.language.lower() in ("python", "py"):
        try:
            import subprocess

            result = subprocess.run(
                ["python", "-c", body.code],
                capture_output=True,
                text=True,
                timeout=10,
            )
            output = result.stdout
            error = result.stderr if result.returncode != 0 else None
            return CodingPlaygroundResponse(
                output=output[:5000] if output else "(no output)",
                error=error[:2000] if error else None,
                language="python",
            )
        except subprocess.TimeoutExpired:
            return CodingPlaygroundResponse(
                output="",
                error="Execution timed out (10s limit)",
                language="python",
            )
        except Exception as e:
            return CodingPlaygroundResponse(
                output="",
                error=str(e)[:2000],
                language="python",
            )
    else:
        system = (
            "You are an expert programming tutor. The student will give you code in a "
            "language. Simulate what the code would output. If there is a bug, explain it. "
            "Give the output as plain text, then add a brief explanation if needed."
        )
        prompt = (
            f"Simulate the output of this {body.language} code:\n\n```{body.language}\n"
            f"{body.code}\n```\n\n"
            "Provide the exact output, then explain any issues if present."
        )
        response = await _call_llm(system, [{"role": "user", "content": prompt}])
        return CodingPlaygroundResponse(
            output=response[:5000],
            error=None,
            language=body.language,
        )


# ---------------------------------------------------------------------------
# Streaming chat endpoint (SSE)
# ---------------------------------------------------------------------------


@router.post("/chat/stream")
async def chat_stream(
    body: ChatRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Stream AI response as Server-Sent Events (SSE).

    Each event is a JSON object: {"type": "chunk"|"done"|"error", "content": "..."}
    """
    try:
        return await _chat_stream_impl(body, user, db)
    except HTTPException:
        raise
    except Exception as exc:
        import logging

        logging.getLogger(__name__).exception("Stream chat endpoint error")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Stream chat failed: {type(exc).__name__}: {exc}",
        )


async def _chat_stream_impl(
    body: ChatRequest,
    user: User,
    db: AsyncSession,
):
    """Stream AI response as Server-Sent Events (SSE).

    Each event is a JSON object: {"type": "chunk"|"done"|"error", "content": "..."}
    """
    session_id = body.session_id
    if not session_id:
        session = ChatSession(
            user_id=user.id,
            agent_type=body.agent_type,
            context_course_id=body.context_course_id,
            title=body.message[:80],
        )
        db.add(session)
        await db.commit()
        await db.refresh(session)
        session_id = session.id
    else:
        result = await db.execute(
            select(ChatSession).where(ChatSession.id == session_id)
        )
        session = result.scalar_one_or_none()
        if not session or session.user_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Session not found"
            )

    # Build context (same as non-streaming endpoint)
    workspace = None
    if body.workspace:
        workspace = WorkspaceState(
            screen=body.workspace.screen,
            subject=body.workspace.subject,
            syllabus=body.workspace.syllabus,
            topic=body.workspace.topic,
            subtopic=body.workspace.subtopic,
            current_objective=body.workspace.current_objective,
            active_lesson=body.workspace.active_lesson,
            active_content=body.workspace.active_content,
            selected_text=body.workspace.selected_text,
            active_visual_id=body.workspace.active_visual_id,
            active_visual_type=body.workspace.active_visual_type,
            active_visual_element=body.workspace.active_visual_element,
            active_question_id=str(body.workspace.active_question_id),
            current_page=body.workspace.current_page,
        )

    ctx = await context_manager.build_context(
        user_id=user.id,
        session_id=session_id,
        workspace=workspace,
        db=db,
        agent_type=body.agent_type,
    )

    intent = IntentClassifier.classify(body.message)
    context_manager.record_question(user.id, session_id, body.message)

    user_msg = ChatMessage(session_id=session_id, role="user", content=body.message)
    db.add(user_msg)
    await db.commit()

    history_result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.id)
    )
    history = [
        {"role": m.role, "content": m.content} for m in history_result.scalars().all()
    ]

    system_prompt = _build_system_prompt(body.agent_type)
    system_prompt += ctx.to_prompt_block()
    system_prompt += ResponseModeRouter.get_system_prompt_addition(ctx, intent)

    grounding_block = await _retrieve_grounding(body.message)
    if grounding_block:
        system_prompt += grounding_block

    if body.file_ids:
        from app.stem.multimodal_router import _file_store

        file_context_parts = []
        for fid in body.file_ids:
            f = _file_store.get(fid)
            if f and f.get("user_id") == user.id:
                file_context_parts.append(
                    f"[Uploaded File: {f['filename']} ({f['file_type']})]\n"
                    f"{f.get('extracted_text', '(no text extracted)')}"
                )
        if file_context_parts:
            file_context = "\n\n".join(file_context_parts)
            system_prompt += (
                "\n\nIMPORTANT — The student has uploaded the following file(s). "
                "Use the content as the primary source for your answer.\n\n"
                f"--- UPLOADED CONTENT ---\n{file_context}\n--- END UPLOADED CONTENT ---"
            )

    full_messages = [{"role": "system", "content": system_prompt}] + history

    async def event_generator():
        from app.config.ai_client import AIProviderError, call_ai_stream_with_fallback

        collected = []
        try:
            async for chunk in call_ai_stream_with_fallback(
                full_messages, max_tokens=2048, temperature=0.7
            ):
                text = str(chunk)
                collected.append(text)
                yield f"data: {json.dumps({'type': 'chunk', 'content': text})}\n\n"
        except (AIProviderError, RuntimeError, TimeoutError, OSError) as exc:
            yield f"data: {json.dumps({'type': 'error', 'content': str(exc)[:500]})}\n\n"
            return

        # Save the complete response to DB
        complete_response = "".join(collected)
        content, sources = _extract_sources(complete_response)
        sources = _merge_live_sources(sources, grounding_block)

        ai_msg = ChatMessage(
            session_id=session_id,
            role="assistant",
            content=content,
            sources=sources,
        )
        db.add(ai_msg)
        await db.commit()
        await db.refresh(ai_msg)

        context_manager.record_ai_response(
            user.id, session_id, ai_topic=ctx.topic, intent=intent.action
        )

        yield f"data: {json.dumps({'type': 'done', 'message_id': ai_msg.id, 'sources': sources})}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
