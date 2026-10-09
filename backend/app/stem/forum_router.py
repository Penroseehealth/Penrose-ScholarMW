from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    STEMForumAnswer,
    STEMForumPost,
    STEMForumVote,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class ForumPostCreate(BaseModel):
    title: str
    body: str
    concept_id: int | None = None
    subject_slug: str | None = None
    is_question: bool = True


class ForumPostResponse(BaseModel):
    id: int
    user_id: int
    concept_id: int | None = None
    subject_slug: str | None = None
    title: str
    body: str
    is_question: bool
    is_resolved: bool
    upvotes: int
    view_count: int
    answer_count: int = 0
    created_at: datetime
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}


class ForumPostDetailResponse(ForumPostResponse):
    answers: list["ForumAnswerResponse"] = []


class ForumAnswerCreate(BaseModel):
    body: str


class ForumAnswerResponse(BaseModel):
    id: int
    post_id: int
    user_id: int
    body: str
    is_accepted: bool
    upvotes: int
    created_at: datetime

    model_config = {"from_attributes": True}


class VoteRequest(BaseModel):
    value: int


class ForumStatsResponse(BaseModel):
    total_posts: int
    total_answers: int
    accepted_answers: int
    total_upvotes_received: int


@router.post(
    "/forum/posts",
    response_model=ForumPostResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_forum_post(
    body: ForumPostCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    post = STEMForumPost(
        user_id=user.id,
        concept_id=body.concept_id,
        subject_slug=body.subject_slug,
        title=body.title,
        body=body.body,
        is_question=body.is_question,
    )
    db.add(post)
    await db.commit()
    await db.refresh(post)
    return ForumPostResponse(
        id=post.id,
        user_id=post.user_id,
        concept_id=post.concept_id,
        subject_slug=post.subject_slug,
        title=post.title,
        body=post.body,
        is_question=post.is_question,
        is_resolved=post.is_resolved,
        upvotes=post.upvotes,
        view_count=post.view_count,
        answer_count=0,
        created_at=post.created_at,
        updated_at=post.updated_at,
    )


@router.get("/forum/posts", response_model=list[ForumPostResponse])
async def list_forum_posts(
    subject_slug: str | None = Query(None),
    concept_id: int | None = Query(None),
    search: str | None = Query(None),
    resolved: bool | None = Query(None),
    sort: str = Query("newest"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(STEMForumPost)

    if subject_slug:
        query = query.where(STEMForumPost.subject_slug == subject_slug)
    if concept_id:
        query = query.where(STEMForumPost.concept_id == concept_id)
    if resolved is not None:
        query = query.where(STEMForumPost.is_resolved == resolved)
    if search:
        query = query.where(
            STEMForumPost.title.ilike(f"%{search}%")
            | STEMForumPost.body.ilike(f"%{search}%")
        )

    if sort == "votes":
        query = query.order_by(STEMForumPost.upvotes.desc())
    elif sort == "unanswered":
        subq = (
            select(
                STEMForumAnswer.post_id,
                func.count().label("answer_count"),
            )
            .group_by(STEMForumAnswer.post_id)
            .subquery()
        )
        query = query.outerjoin(subq, STEMForumPost.id == subq.c.post_id)
        query = query.where(subq.c.post_id.is_(None))
        query = query.order_by(STEMForumPost.created_at.desc())
    else:
        query = query.order_by(STEMForumPost.created_at.desc())

    query = query.offset(skip).limit(limit)
    result = await db.execute(query)
    posts = result.scalars().all()

    responses = []
    for post in posts:
        count_result = await db.execute(
            select(func.count()).where(STEMForumAnswer.post_id == post.id)
        )
        answer_count = count_result.scalar() or 0
        responses.append(
            ForumPostResponse(
                id=post.id,
                user_id=post.user_id,
                concept_id=post.concept_id,
                subject_slug=post.subject_slug,
                title=post.title,
                body=post.body,
                is_question=post.is_question,
                is_resolved=post.is_resolved,
                upvotes=post.upvotes,
                view_count=post.view_count,
                answer_count=answer_count,
                created_at=post.created_at,
                updated_at=post.updated_at,
            )
        )
    return responses


@router.get("/forum/posts/{post_id}", response_model=ForumPostDetailResponse)
async def get_forum_post(
    post_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMForumPost).where(STEMForumPost.id == post_id))
    post = result.scalar_one_or_none()
    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Post not found"
        )

    post.view_count += 1
    await db.flush()

    answers_result = await db.execute(
        select(STEMForumAnswer)
        .where(STEMForumAnswer.post_id == post_id)
        .order_by(STEMForumAnswer.is_accepted.desc(), STEMForumAnswer.upvotes.desc())
    )
    answers = answers_result.scalars().all()

    return ForumPostDetailResponse(
        id=post.id,
        user_id=post.user_id,
        concept_id=post.concept_id,
        subject_slug=post.subject_slug,
        title=post.title,
        body=post.body,
        is_question=post.is_question,
        is_resolved=post.is_resolved,
        upvotes=post.upvotes,
        view_count=post.view_count,
        answer_count=len(answers),
        created_at=post.created_at,
        updated_at=post.updated_at,
        answers=[
            ForumAnswerResponse(
                id=a.id,
                post_id=a.post_id,
                user_id=a.user_id,
                body=a.body,
                is_accepted=a.is_accepted,
                upvotes=a.upvotes,
                created_at=a.created_at,
            )
            for a in answers
        ],
    )


@router.post(
    "/forum/posts/{post_id}/answers",
    response_model=ForumAnswerResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_forum_answer(
    post_id: int,
    body: ForumAnswerCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    post_result = await db.execute(
        select(STEMForumPost).where(STEMForumPost.id == post_id)
    )
    if not post_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Post not found"
        )

    answer = STEMForumAnswer(
        post_id=post_id,
        user_id=user.id,
        body=body.body,
    )
    db.add(answer)
    await db.commit()
    await db.refresh(answer)
    return ForumAnswerResponse(
        id=answer.id,
        post_id=answer.post_id,
        user_id=answer.user_id,
        body=answer.body,
        is_accepted=answer.is_accepted,
        upvotes=answer.upvotes,
        created_at=answer.created_at,
    )


@router.post("/forum/posts/{post_id}/resolve")
async def resolve_forum_post(
    post_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(STEMForumPost).where(STEMForumPost.id == post_id))
    post = result.scalar_one_or_none()
    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Post not found"
        )
    if post.user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the post author can mark it as resolved",
        )

    post.is_resolved = True
    post.updated_at = datetime.now(timezone.utc)
    await db.commit()
    return {"detail": "Post marked as resolved"}


@router.post("/forum/posts/{post_id}/vote")
async def vote_forum_post(
    post_id: int,
    body: VoteRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.value not in (1, -1):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vote value must be 1 or -1",
        )

    post_result = await db.execute(
        select(STEMForumPost).where(STEMForumPost.id == post_id)
    )
    post = post_result.scalar_one_or_none()
    if not post:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Post not found"
        )

    existing_result = await db.execute(
        select(STEMForumVote).where(
            STEMForumVote.user_id == user.id,
            STEMForumVote.post_id == post_id,
        )
    )
    existing = existing_result.scalar_one_or_none()

    if existing:
        if existing.value == body.value:
            post.upvotes -= body.value
            await db.delete(existing)
        else:
            post.upvotes -= existing.value
            post.upvotes += body.value
            existing.value = body.value
    else:
        post.upvotes += body.value
        db.add(
            STEMForumVote(
                user_id=user.id,
                post_id=post_id,
                value=body.value,
            )
        )

    await db.commit()
    return {"upvotes": post.upvotes}


@router.post("/forum/answers/{answer_id}/vote")
async def vote_forum_answer(
    answer_id: int,
    body: VoteRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.value not in (1, -1):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vote value must be 1 or -1",
        )

    answer_result = await db.execute(
        select(STEMForumAnswer).where(STEMForumAnswer.id == answer_id)
    )
    answer = answer_result.scalar_one_or_none()
    if not answer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Answer not found"
        )

    existing_result = await db.execute(
        select(STEMForumVote).where(
            STEMForumVote.user_id == user.id,
            STEMForumVote.answer_id == answer_id,
        )
    )
    existing = existing_result.scalar_one_or_none()

    if existing:
        if existing.value == body.value:
            answer.upvotes -= body.value
            await db.delete(existing)
        else:
            answer.upvotes -= existing.value
            answer.upvotes += body.value
            existing.value = body.value
    else:
        answer.upvotes += body.value
        db.add(
            STEMForumVote(
                user_id=user.id,
                answer_id=answer_id,
                value=body.value,
            )
        )

    await db.commit()
    return {"upvotes": answer.upvotes}


@router.post("/forum/answers/{answer_id}/accept")
async def accept_forum_answer(
    answer_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    answer_result = await db.execute(
        select(STEMForumAnswer).where(STEMForumAnswer.id == answer_id)
    )
    answer = answer_result.scalar_one_or_none()
    if not answer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Answer not found"
        )

    post_result = await db.execute(
        select(STEMForumPost).where(STEMForumPost.id == answer.post_id)
    )
    post = post_result.scalar_one_or_none()
    if post.user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the post author can accept an answer",
        )

    unaccept_result = await db.execute(
        select(STEMForumAnswer).where(
            STEMForumAnswer.post_id == answer.post_id,
            STEMForumAnswer.is_accepted.is_(True),
        )
    )
    for prev in unaccept_result.scalars().all():
        prev.is_accepted = False

    answer.is_accepted = True
    post.is_resolved = True
    post.updated_at = datetime.now(timezone.utc)
    await db.commit()
    return {"detail": "Answer accepted"}


@router.get("/forum/stats", response_model=ForumStatsResponse)
async def get_forum_stats(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    posts_result = await db.execute(
        select(func.count()).where(STEMForumPost.user_id == user.id)
    )
    total_posts = posts_result.scalar() or 0

    answers_result = await db.execute(
        select(func.count()).where(STEMForumAnswer.user_id == user.id)
    )
    total_answers = answers_result.scalar() or 0

    accepted_result = await db.execute(
        select(func.count()).where(
            STEMForumAnswer.user_id == user.id,
            STEMForumAnswer.is_accepted.is_(True),
        )
    )
    accepted_answers = accepted_result.scalar() or 0

    post_upvotes_result = await db.execute(
        select(func.coalesce(func.sum(STEMForumPost.upvotes), 0)).where(
            STEMForumPost.user_id == user.id
        )
    )
    post_upvotes = post_upvotes_result.scalar() or 0

    answer_upvotes_result = await db.execute(
        select(func.coalesce(func.sum(STEMForumAnswer.upvotes), 0)).where(
            STEMForumAnswer.user_id == user.id
        )
    )
    answer_upvotes = answer_upvotes_result.scalar() or 0

    return ForumStatsResponse(
        total_posts=total_posts,
        total_answers=total_answers,
        accepted_answers=accepted_answers,
        total_upvotes_received=post_upvotes + answer_upvotes,
    )
