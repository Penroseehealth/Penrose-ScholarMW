from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import get_db
from app.models.stem import STEMFormula

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class FormulaResponse(BaseModel):
    id: int
    subject_slug: str
    title: str
    formula: str
    description: str | None
    category: str
    variables: str | None
    tags: str | None
    is_published: bool


class CategoryResponse(BaseModel):
    category: str


def _formula_to_response(f: STEMFormula) -> FormulaResponse:
    return FormulaResponse(
        id=f.id,
        subject_slug=f.subject_slug,
        title=f.title,
        formula=f.formula,
        description=f.description,
        category=f.category,
        variables=f.variables,
        tags=f.tags,
        is_published=f.is_published,
    )


@router.get("/formulas", response_model=list[FormulaResponse])
async def list_formulas(
    subject_slug: str | None = Query(None),
    category: str | None = Query(None),
    q: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(STEMFormula).where(STEMFormula.is_published.is_(True))

    if subject_slug:
        stmt = stmt.where(STEMFormula.subject_slug == subject_slug)
    if category:
        stmt = stmt.where(STEMFormula.category == category)
    if q:
        stmt = stmt.where(
            STEMFormula.title.ilike(f"%{q}%")
            | STEMFormula.formula.ilike(f"%{q}%")
            | STEMFormula.description.ilike(f"%{q}%")
        )

    stmt = stmt.order_by(STEMFormula.category, STEMFormula.title)
    result = await db.execute(stmt)
    return [_formula_to_response(f) for f in result.scalars().all()]


@router.get("/formulas/{id}", response_model=FormulaResponse)
async def get_formula(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(STEMFormula).where(STEMFormula.id == id))
    formula = result.scalar_one_or_none()
    if not formula:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Formula not found"
        )
    return _formula_to_response(formula)


@router.get(
    "/formulas/categories/{subject_slug}", response_model=list[CategoryResponse]
)
async def list_formula_categories(
    subject_slug: str, db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(STEMFormula.category)
        .where(
            STEMFormula.subject_slug == subject_slug,
            STEMFormula.is_published.is_(True),
        )
        .distinct()
        .order_by(STEMFormula.category)
    )
    return [CategoryResponse(category=row[0]) for row in result.all()]
