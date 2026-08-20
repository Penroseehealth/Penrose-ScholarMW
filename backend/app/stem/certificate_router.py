import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.dependencies.auth import get_current_user
from app.models.models import User
from app.models.stem import (
    MasteryRecord,
    MockExamResult,
    STEMChallengeParticipant,
    STEMConcept,
    STEMDiscipline,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
    STEMUserCertificate,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class CertificateGenerateRequest(BaseModel):
    certificate_type: str
    subject_slug: str | None = None


class CertificateResponse(BaseModel):
    id: int
    user_id: int
    certificate_type: str
    title: str
    description: str | None
    subject_slug: str | None
    score: float | None
    issued_at: datetime


class CertificateShareResponse(CertificateResponse):
    certificate_data: dict | None


@router.post(
    "/certificates/generate",
    response_model=CertificateResponse,
    status_code=status.HTTP_201_CREATED,
)
async def generate_certificate(
    body: CertificateGenerateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.now(timezone.utc)

    if body.certificate_type == "subject_mastery":
        return await _generate_subject_mastery_cert(user, body.subject_slug, db, now)
    elif body.certificate_type == "exam_achievement":
        return await _generate_exam_achievement_cert(user, body.subject_slug, db, now)
    elif body.certificate_type == "challenge_champion":
        return await _generate_challenge_champion_cert(user, body.subject_slug, db, now)
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid certificate_type. Must be: subject_mastery, exam_achievement, challenge_champion",
        )


async def _generate_subject_mastery_cert(
    user: User, subject_slug: str | None, db: AsyncSession, now: datetime
):
    if not subject_slug:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="subject_slug is required for subject_mastery certificate",
        )

    subject_result = await db.execute(
        select(STEMSubject).where(STEMSubject.subject_slug == subject_slug)
    )
    subject = subject_result.scalar_one_or_none()
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Subject not found",
        )

    concept_stmt = (
        select(STEMConcept.id)
        .join(STEMSubtopic, STEMConcept.subtopic_id == STEMSubtopic.id)
        .join(STEMTopic, STEMSubtopic.topic_id == STEMTopic.id)
        .join(STEMDiscipline, STEMTopic.discipline_id == STEMDiscipline.id)
        .join(STEMSubject, STEMDiscipline.subject_id == STEMSubject.id)
        .where(STEMSubject.id == subject.id)
    )
    concept_result = await db.execute(concept_stmt)
    concept_ids = [row[0] for row in concept_result.all()]

    if not concept_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No concepts found for this subject",
        )

    mastery_stmt = select(MasteryRecord).where(
        MasteryRecord.user_id == user.id,
        MasteryRecord.concept_id.in_(concept_ids),
    )
    mastery_result = await db.execute(mastery_stmt)
    records = mastery_result.scalars().all()

    if len(records) < len(concept_ids):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Not enough concepts practiced. {len(records)}/{len(concept_ids)} concepts covered.",
        )

    avg_mastery = sum(r.mastery_level for r in records) / len(records)
    if avg_mastery < 0.80:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Average mastery is {avg_mastery:.1%}. Must be at least 80%.",
        )

    cert = STEMUserCertificate(
        user_id=user.id,
        certificate_type="subject_mastery",
        title=f"Subject Mastery: {subject.title}",
        description=f"Successfully demonstrated mastery across all concepts in {subject.title} with an average score of {avg_mastery:.1%}",
        subject_slug=subject_slug,
        score=round(avg_mastery * 100, 2),
        certificate_data=json.dumps(
            {
                "subject": subject.title,
                "concepts_mastered": len(concept_ids),
                "average_mastery": round(avg_mastery, 4),
                "total_concepts": len(concept_ids),
            }
        ),
    )
    db.add(cert)
    await db.commit()
    await db.refresh(cert)

    return CertificateResponse(
        id=cert.id,
        user_id=cert.user_id,
        certificate_type=cert.certificate_type,
        title=cert.title,
        description=cert.description,
        subject_slug=cert.subject_slug,
        score=cert.score,
        issued_at=cert.issued_at,
    )


async def _generate_exam_achievement_cert(
    user: User, subject_slug: str | None, db: AsyncSession, now: datetime
):
    if not subject_slug:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="subject_slug is required for exam_achievement certificate",
        )

    result = await db.execute(
        select(MockExamResult)
        .where(
            MockExamResult.user_id == user.id,
            MockExamResult.subject_slug == subject_slug,
            MockExamResult.percentage >= 90.0,
        )
        .order_by(MockExamResult.percentage.desc())
        .limit(1)
    )
    best_exam = result.scalar_one_or_none()
    if not best_exam:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No mock exam with 90%+ score found for this subject",
        )

    subject_result = await db.execute(
        select(STEMSubject).where(STEMSubject.subject_slug == subject_slug)
    )
    subject = subject_result.scalar_one_or_none()
    subject_name = subject.title if subject else subject_slug

    cert = STEMUserCertificate(
        user_id=user.id,
        certificate_type="exam_achievement",
        title=f"Exam Achievement: {subject_name}",
        description=f"Achieved {best_exam.percentage:.1f}% on mock examination in {subject_name}",
        subject_slug=subject_slug,
        score=best_exam.percentage,
        certificate_data=json.dumps(
            {
                "subject": subject_name,
                "score": best_exam.percentage,
                "total_questions": best_exam.total_questions,
                "correct_count": best_exam.correct_count,
                "time_taken_seconds": best_exam.time_taken_seconds,
                "result_id": best_exam.id,
            }
        ),
    )
    db.add(cert)
    await db.commit()
    await db.refresh(cert)

    return CertificateResponse(
        id=cert.id,
        user_id=cert.user_id,
        certificate_type=cert.certificate_type,
        title=cert.title,
        description=cert.description,
        subject_slug=cert.subject_slug,
        score=cert.score,
        issued_at=cert.issued_at,
    )


async def _generate_challenge_champion_cert(
    user: User, subject_slug: str | None, db: AsyncSession, now: datetime
):
    stmt = select(STEMChallengeParticipant).where(
        STEMChallengeParticipant.user_id == user.id,
        STEMChallengeParticipant.is_completed.is_(True),
    )
    if subject_slug:
        from app.models.stem import STEMChallenge

        stmt = stmt.join(
            STEMChallenge,
            STEMChallengeParticipant.challenge_id == STEMChallenge.id,
        ).where(STEMChallenge.subject_slug == subject_slug)

    result = await db.execute(stmt)
    participant = result.scalar_one_or_none()
    if not participant:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No completed challenges found",
        )

    from app.models.stem import STEMChallenge

    challenge_result = await db.execute(
        select(STEMChallenge).where(STEMChallenge.id == participant.challenge_id)
    )
    challenge = challenge_result.scalar_one_or_none()
    challenge_name = challenge.title if challenge else "Challenge"

    cert = STEMUserCertificate(
        user_id=user.id,
        certificate_type="challenge_champion",
        title=f"Challenge Champion: {challenge_name}",
        description=f"Successfully completed challenge: {challenge_name}",
        subject_slug=subject_slug or (challenge.subject_slug if challenge else None),
        score=None,
        certificate_data=json.dumps(
            {
                "challenge_id": participant.challenge_id,
                "challenge_title": challenge_name,
                "completed_at": participant.completed_at.isoformat()
                if participant.completed_at
                else None,
                "progress_pct": participant.progress_pct,
            }
        ),
    )
    db.add(cert)
    await db.commit()
    await db.refresh(cert)

    return CertificateResponse(
        id=cert.id,
        user_id=cert.user_id,
        certificate_type=cert.certificate_type,
        title=cert.title,
        description=cert.description,
        subject_slug=cert.subject_slug,
        score=cert.score,
        issued_at=cert.issued_at,
    )


@router.get("/certificates", response_model=list[CertificateResponse])
async def list_certificates(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMUserCertificate)
        .where(STEMUserCertificate.user_id == user.id)
        .order_by(STEMUserCertificate.issued_at.desc())
    )
    certs = result.scalars().all()

    return [
        CertificateResponse(
            id=c.id,
            user_id=c.user_id,
            certificate_type=c.certificate_type,
            title=c.title,
            description=c.description,
            subject_slug=c.subject_slug,
            score=c.score,
            issued_at=c.issued_at,
        )
        for c in certs
    ]


@router.get("/certificates/{cert_id}", response_model=CertificateResponse)
async def get_certificate(
    cert_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMUserCertificate).where(
            STEMUserCertificate.id == cert_id,
            STEMUserCertificate.user_id == user.id,
        )
    )
    cert = result.scalar_one_or_none()
    if not cert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Certificate not found",
        )

    return CertificateResponse(
        id=cert.id,
        user_id=cert.user_id,
        certificate_type=cert.certificate_type,
        title=cert.title,
        description=cert.description,
        subject_slug=cert.subject_slug,
        score=cert.score,
        issued_at=cert.issued_at,
    )


@router.get("/certificates/{cert_id}/share", response_model=CertificateShareResponse)
async def share_certificate(
    cert_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(STEMUserCertificate).where(
            STEMUserCertificate.id == cert_id,
            STEMUserCertificate.user_id == user.id,
        )
    )
    cert = result.scalar_one_or_none()
    if not cert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Certificate not found",
        )

    cert_data = None
    if cert.certificate_data:
        cert_data = json.loads(cert.certificate_data)

    user_result = await db.execute(select(User).where(User.id == user.id))
    current_user = user_result.scalar_one_or_none()

    share_data = {
        "certificate_id": cert.id,
        "type": cert.certificate_type,
        "title": cert.title,
        "description": cert.description,
        "subject_slug": cert.subject_slug,
        "score": cert.score,
        "issued_at": cert.issued_at.isoformat(),
        "recipient_name": current_user.full_name if current_user else "Student",
        "platform": "Penrose ScholarMW",
    }
    if cert_data:
        share_data["details"] = cert_data

    return CertificateShareResponse(
        id=cert.id,
        user_id=cert.user_id,
        certificate_type=cert.certificate_type,
        title=cert.title,
        description=cert.description,
        subject_slug=cert.subject_slug,
        score=cert.score,
        issued_at=cert.issued_at,
        certificate_data=share_data,
    )
