import json
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import get_settings
from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    STEMConcept,
    STEMFlashcard,
    STEMStudyPlan,
    STEMStudyPlanItem,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])
settings = get_settings()


class FlashcardCreate(BaseModel):
    concept_id: int
    front: str
    back: str
    difficulty: str = "medium"


class FlashcardReview(BaseModel):
    quality: int


class FlashcardGenerateRequest(BaseModel):
    concept_id: int
    count: int = 5


class FlashcardGeneratedItem(BaseModel):
    front: str
    back: str
    difficulty: str


class FlashcardGenerateResponse(BaseModel):
    flashcards: list[FlashcardGeneratedItem]
    concept_id: int
    saved: int


class FlashcardResponse(BaseModel):
    id: int
    concept_id: int
    front: str
    back: str
    difficulty: str
    ease_factor: float
    interval_days: int
    review_count: int
    next_review: datetime | None
    created_at: datetime


class StudyPlanCreate(BaseModel):
    title: str
    description: str | None = None
    subject_slug: str
    target_date: datetime | None = None


class StudyPlanItemCreate(BaseModel):
    concept_id: int
    title: str


class StudyPlanItemResponse(BaseModel):
    id: int
    concept_id: int
    title: str
    is_completed: bool
    order_index: int
    created_at: datetime


class StudyPlanResponse(BaseModel):
    id: int
    subject_slug: str | None
    title: str
    description: str | None
    target_date: datetime | None
    progress_pct: float
    status: str
    created_at: datetime


class StudyPlanDetailResponse(StudyPlanResponse):
    items: list[StudyPlanItemResponse]


def _flashcard_to_response(card: STEMFlashcard) -> FlashcardResponse:
    return FlashcardResponse(
        id=card.id,
        concept_id=card.concept_id,
        front=card.front,
        back=card.back,
        difficulty=card.difficulty,
        ease_factor=card.ease_factor,
        interval_days=card.interval_days,
        review_count=card.review_count,
        next_review=card.next_review,
        created_at=card.created_at,
    )


def _plan_to_response(plan: STEMStudyPlan) -> StudyPlanResponse:
    return StudyPlanResponse(
        id=plan.id,
        subject_slug=plan.subject_slug,
        title=plan.title,
        description=plan.description,
        target_date=plan.target_date,
        progress_pct=plan.progress_pct,
        status=plan.status,
        created_at=plan.created_at,
    )


def _plan_item_to_response(item: STEMStudyPlanItem) -> StudyPlanItemResponse:
    return StudyPlanItemResponse(
        id=item.id,
        concept_id=item.concept_id,
        title=item.title,
        is_completed=item.is_completed,
        order_index=item.order_index,
        created_at=item.created_at,
    )


@router.get("/revision/flashcards", response_model=list[FlashcardResponse])
async def list_flashcards(
    concept_id: int | None = Query(None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(STEMFlashcard).where(STEMFlashcard.user_id == user.id)
    if concept_id is not None:
        stmt = stmt.where(STEMFlashcard.concept_id == concept_id)
    stmt = stmt.order_by(STEMFlashcard.created_at.desc())
    result = await db.execute(stmt)
    return [_flashcard_to_response(c) for c in result.scalars().all()]


@router.post(
    "/revision/flashcards",
    response_model=FlashcardResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_flashcard(
    body: FlashcardCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    concept_result = await db.execute(
        select(STEMConcept).where(STEMConcept.id == body.concept_id)
    )
    if not concept_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Concept not found"
        )

    card = STEMFlashcard(
        user_id=user.id,
        concept_id=body.concept_id,
        front=body.front,
        back=body.back,
        difficulty=body.difficulty,
    )
    db.add(card)
    await db.commit()
    await db.refresh(card)
    return _flashcard_to_response(card)


@router.post("/revision/flashcards/{id}/review", response_model=FlashcardResponse)
async def review_flashcard(
    id: int,
    body: FlashcardReview,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.quality < 1 or body.quality > 5:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Quality must be between 1 and 5",
        )

    result = await db.execute(
        select(STEMFlashcard).where(
            STEMFlashcard.id == id,
            STEMFlashcard.user_id == user.id,
        )
    )
    card = result.scalar_one_or_none()
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Flashcard not found"
        )

    quality = body.quality
    if quality >= 3:
        if card.review_count == 0:
            card.interval_days = 1
        elif card.review_count == 1:
            card.interval_days = 6
        else:
            card.interval_days = round(card.interval_days * card.ease_factor)
        card.ease_factor = max(
            1.3,
            card.ease_factor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)),
        )
    else:
        card.review_count = 0
        card.interval_days = 1
        card.ease_factor = max(1.3, card.ease_factor - 0.2)
    card.review_count += 1
    card.next_review = datetime.now(timezone.utc) + timedelta(days=card.interval_days)

    await db.commit()
    await db.refresh(card)
    return _flashcard_to_response(card)


@router.get("/revision/flashcards/due", response_model=list[FlashcardResponse])
async def get_due_flashcards(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.now(timezone.utc)
    stmt = (
        select(STEMFlashcard)
        .where(
            STEMFlashcard.user_id == user.id,
            (STEMFlashcard.next_review.is_(None)) | (STEMFlashcard.next_review <= now),
        )
        .order_by(STEMFlashcard.next_review.asc())
    )
    result = await db.execute(stmt)
    return [_flashcard_to_response(c) for c in result.scalars().all()]


@router.delete("/revision/flashcards/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_flashcard(
    id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMFlashcard).where(
            STEMFlashcard.id == id,
            STEMFlashcard.user_id == user.id,
        )
    )
    card = result.scalar_one_or_none()
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Flashcard not found"
        )
    await db.delete(card)
    await db.commit()


@router.get("/revision/plans", response_model=list[StudyPlanResponse])
async def list_study_plans(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMStudyPlan)
        .where(STEMStudyPlan.user_id == user.id)
        .order_by(STEMStudyPlan.created_at.desc())
    )
    return [_plan_to_response(p) for p in result.scalars().all()]


@router.post(
    "/revision/plans",
    response_model=StudyPlanResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_study_plan(
    body: StudyPlanCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plan = STEMStudyPlan(
        user_id=user.id,
        subject_slug=body.subject_slug,
        title=body.title,
        description=body.description,
        target_date=body.target_date,
    )
    db.add(plan)
    await db.commit()
    await db.refresh(plan)
    return _plan_to_response(plan)


@router.get("/revision/plans/{id}", response_model=StudyPlanDetailResponse)
async def get_study_plan(
    id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMStudyPlan).where(
            STEMStudyPlan.id == id,
            STEMStudyPlan.user_id == user.id,
        )
    )
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Study plan not found"
        )

    items_result = await db.execute(
        select(STEMStudyPlanItem)
        .where(STEMStudyPlanItem.plan_id == plan.id)
        .order_by(STEMStudyPlanItem.order_index)
    )
    items = [_plan_item_to_response(i) for i in items_result.scalars().all()]

    return StudyPlanDetailResponse(
        id=plan.id,
        subject_slug=plan.subject_slug,
        title=plan.title,
        description=plan.description,
        target_date=plan.target_date,
        progress_pct=plan.progress_pct,
        status=plan.status,
        created_at=plan.created_at,
        items=items,
    )


@router.post(
    "/revision/plans/{id}/items",
    response_model=StudyPlanItemResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_plan_item(
    id: int,
    body: StudyPlanItemCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plan_result = await db.execute(
        select(STEMStudyPlan).where(
            STEMStudyPlan.id == id,
            STEMStudyPlan.user_id == user.id,
        )
    )
    plan = plan_result.scalar_one_or_none()
    if not plan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Study plan not found"
        )

    concept_result = await db.execute(
        select(STEMConcept).where(STEMConcept.id == body.concept_id)
    )
    if not concept_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Concept not found"
        )

    max_order_result = await db.execute(
        select(func.coalesce(func.max(STEMStudyPlanItem.order_index), 0)).where(
            STEMStudyPlanItem.plan_id == plan.id
        )
    )
    next_order = max_order_result.scalar() + 1

    item = STEMStudyPlanItem(
        plan_id=plan.id,
        concept_id=body.concept_id,
        title=body.title,
        order_index=next_order,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return _plan_item_to_response(item)


@router.post(
    "/revision/plans/{id}/items/{item_id}/complete",
    response_model=StudyPlanItemResponse,
)
async def complete_plan_item(
    id: int,
    item_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plan_result = await db.execute(
        select(STEMStudyPlan).where(
            STEMStudyPlan.id == id,
            STEMStudyPlan.user_id == user.id,
        )
    )
    plan = plan_result.scalar_one_or_none()
    if not plan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Study plan not found"
        )

    item_result = await db.execute(
        select(STEMStudyPlanItem).where(
            STEMStudyPlanItem.id == item_id,
            STEMStudyPlanItem.plan_id == plan.id,
        )
    )
    item = item_result.scalar_one_or_none()
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plan item not found",
        )

    if not item.is_completed:
        item.is_completed = True

        total_result = await db.execute(
            select(func.count()).where(STEMStudyPlanItem.plan_id == plan.id)
        )
        total = total_result.scalar()

        completed_result = await db.execute(
            select(func.count()).where(
                STEMStudyPlanItem.plan_id == plan.id,
                STEMStudyPlanItem.is_completed.is_(True),
            )
        )
        completed = completed_result.scalar()

        plan.progress_pct = completed / total if total > 0 else 0.0
        if plan.progress_pct >= 1.0:
            plan.status = "completed"

    await db.commit()
    await db.refresh(item)
    return _plan_item_to_response(item)


@router.post(
    "/revision/flashcards/generate",
    response_model=FlashcardGenerateResponse,
)
async def generate_flashcards(
    body: FlashcardGenerateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    concept_result = await db.execute(
        select(STEMConcept).where(STEMConcept.id == body.concept_id)
    )
    concept = concept_result.scalar_one_or_none()
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Concept not found"
        )

    try:
        from app.config.ai_client import AIProviderError, call_ai_chat

        prompt = (
            f"Generate {body.count} flashcards for the following concept:\n"
            f"Title: {concept.title}\n"
        )
        if concept.description:
            prompt += f"Description: {concept.description}\n"
        if concept.learning_objectives_text:
            prompt += f"Learning Objectives: {concept.learning_objectives_text}\n"

        prompt += (
            "\nReturn a JSON array of objects with keys: front, back, difficulty "
            "(one of 'easy', 'medium', 'hard').\n"
            "Make flashcards educational and varied in difficulty. "
            "Front should be a clear question or prompt. "
            "Back should be a concise but complete answer."
        )

        completion, _provider = await call_ai_chat(
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are an expert educational flashcard generator. "
                        "Create clear, concise, and accurate flashcards."
                    ),
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0.7,
            max_tokens=2000,
        )
        raw = completion.choices[0].message.content or "[]"
        start = raw.find("[")
        end = raw.rfind("]") + 1
        if start != -1 and end > start:
            items = json.loads(raw[start:end])
        else:
            items = []
    except (AIProviderError, Exception):
        items = []

    saved_count = 0
    for item in items:
        if isinstance(item, dict) and "front" in item and "back" in item:
            card = STEMFlashcard(
                user_id=user.id,
                concept_id=body.concept_id,
                front=item["front"],
                back=item["back"],
                difficulty=item.get("difficulty", "medium"),
            )
            db.add(card)
            saved_count += 1

    await db.commit()

    return FlashcardGenerateResponse(
        flashcards=[
            FlashcardGeneratedItem(
                front=item.get("front", ""),
                back=item.get("back", ""),
                difficulty=item.get("difficulty", "medium"),
            )
            for item in items
            if isinstance(item, dict)
        ],
        concept_id=body.concept_id,
        saved=saved_count,
    )
