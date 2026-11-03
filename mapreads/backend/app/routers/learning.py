from fastapi import APIRouter, HTTPException

from ..schemas.learning import QuestionGenerationRequest, TeachingAssistanceRequest


router = APIRouter(tags=["learning"])


@router.post("/api/questions/generate")
def generate_questions(request: QuestionGenerationRequest) -> None:
    raise HTTPException(
        status_code=501,
        detail={
            "code": "not_implemented",
            "message": "Question generation is currently provided by the JavaScript smartboard.",
        },
    )


@router.post("/api/teaching/assist")
def teaching_assistance(request: TeachingAssistanceRequest) -> None:
    raise HTTPException(
        status_code=501,
        detail={
            "code": "not_implemented",
            "message": "A teaching-assistance service has not been configured.",
        },
    )
