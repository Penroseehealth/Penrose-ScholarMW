from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database.engine import get_db
from app.models.languages import (
    Language,
    LanguageGrammarRule,
    LanguageLesson,
    LanguageLevel,
    LanguagePlacement,
    LanguageUnit,
    LanguageUserProgress,
    LanguageVocabulary,
)

router = APIRouter(prefix="/languages", tags=["Languages"])


class PlacementStartRequest(BaseModel):
    user_id: int
    language_id: int


@router.get("")
async def list_languages(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Language).where(Language.is_active == True).order_by(Language.id)
    )
    langs = result.scalars().all()
    out = []
    for lang in langs:
        lvls = await db.execute(
            select(func.count(LanguageLevel.id)).where(
                LanguageLevel.language_id == lang.id, LanguageLevel.is_active == True
            )
        )
        level_count = lvls.scalar() or 0
        vcnt = await db.execute(
            select(func.count(LanguageVocabulary.id))
            .join(LanguageLesson)
            .join(LanguageUnit)
            .join(LanguageLevel)
            .where(LanguageLevel.language_id == lang.id)
        )
        vocab_count = vcnt.scalar() or 0
        gcnt = await db.execute(
            select(func.count(LanguageGrammarRule.id))
            .join(LanguageLesson)
            .join(LanguageUnit)
            .join(LanguageLevel)
            .where(LanguageLevel.language_id == lang.id)
        )
        grammar_count = gcnt.scalar() or 0
        out.append(
            {
                "id": lang.id,
                "name": lang.name,
                "slug": lang.slug,
                "native_name": lang.native_name,
                "description": lang.description,
                "icon": lang.icon,
                "color": lang.color,
                "level_system": lang.level_system,
                "level_system_description": lang.level_system_description,
                "level_count": level_count,
                "vocabulary_count": vocab_count,
                "grammar_count": grammar_count,
            }
        )
    return out


@router.get("/search")
async def search_languages(
    q: str = "",
    db: AsyncSession = Depends(get_db),
):
    if not q or len(q) < 2:
        return []
    pattern = f"%{q}%"
    vr = await db.execute(
        select(LanguageVocabulary)
        .join(LanguageLesson)
        .join(LanguageUnit)
        .join(LanguageLevel)
        .join(Language)
        .where(
            LanguageVocabulary.word.ilike(pattern)
            | LanguageVocabulary.translation.ilike(pattern)
        )
        .limit(20)
    )
    vocab = vr.scalars().all()
    gr = await db.execute(
        select(LanguageGrammarRule)
        .join(LanguageLesson)
        .join(LanguageUnit)
        .join(LanguageLevel)
        .join(Language)
        .where(LanguageGrammarRule.rule_name.ilike(pattern))
        .limit(10)
    )
    grammar = gr.scalars().all()
    return {
        "vocabulary": [
            {
                "id": v.id,
                "word": v.word,
                "translation": v.translation,
                "pronunciation": v.pronunciation,
            }
            for v in vocab
        ],
        "grammar": [
            {"id": g.id, "rule_name": g.rule_name, "explanation": g.explanation}
            for g in grammar
        ],
    }


@router.get("/{slug}")
async def get_language(slug: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Language).where(Language.slug == slug))
    lang = result.scalar_one_or_none()
    if not lang:
        raise HTTPException(404, "Language not found")
    lvls = await db.execute(
        select(LanguageLevel)
        .where(LanguageLevel.language_id == lang.id, LanguageLevel.is_active == True)
        .order_by(LanguageLevel.order_index)
    )
    levels = lvls.scalars().all()
    return {
        "id": lang.id,
        "name": lang.name,
        "slug": lang.slug,
        "native_name": lang.native_name,
        "description": lang.description,
        "icon": lang.icon,
        "color": lang.color,
        "level_system": lang.level_system,
        "level_system_description": lang.level_system_description,
        "levels": [
            {
                "id": lv.id,
                "name": lv.name,
                "slug": lv.slug,
                "form_mapping": lv.form_mapping,
                "proficiency_label": lv.proficiency_label,
                "description": lv.description,
                "order_index": lv.order_index,
            }
            for lv in levels
        ],
    }


@router.get("/{slug}/tree")
async def get_language_tree(slug: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Language).where(Language.slug == slug))
    lang = result.scalar_one_or_none()
    if not lang:
        raise HTTPException(404, "Language not found")
    lvls = await db.execute(
        select(LanguageLevel)
        .where(LanguageLevel.language_id == lang.id)
        .options(
            selectinload(LanguageLevel.units)
            .selectinload(LanguageUnit.lessons)
            .selectinload(LanguageLesson.vocabulary)
        )
        .order_by(LanguageLevel.order_index)
    )
    levels = lvls.scalars().unique().all()
    return {
        "language": {
            "name": lang.name,
            "slug": lang.slug,
            "icon": lang.icon,
            "color": lang.color,
        },
        "levels": [
            {
                "id": lv.id,
                "name": lv.name,
                "slug": lv.slug,
                "form_mapping": lv.form_mapping,
                "proficiency_label": lv.proficiency_label,
                "units": [
                    {
                        "id": u.id,
                        "name": u.name,
                        "description": u.description,
                        "lesson_count": len(u.lessons),
                        "vocab_count": sum(
                            len(lesson.vocabulary) for lesson in u.lessons
                        ),
                    }
                    for u in sorted(lv.units, key=lambda x: x.order_index)
                ],
            }
            for lv in levels
        ],
    }


@router.get("/{slug}/levels")
async def list_levels(slug: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Language).where(Language.slug == slug))
    lang = result.scalar_one_or_none()
    if not lang:
        raise HTTPException(404, "Language not found")
    lvls = await db.execute(
        select(LanguageLevel)
        .where(LanguageLevel.language_id == lang.id, LanguageLevel.is_active == True)
        .order_by(LanguageLevel.order_index)
    )
    levels = lvls.scalars().all()
    out = []
    for lv in levels:
        ucnt = await db.execute(
            select(func.count(LanguageUnit.id)).where(LanguageUnit.level_id == lv.id)
        )
        lcnt = await db.execute(
            select(func.count(LanguageLesson.id))
            .join(LanguageUnit)
            .where(LanguageUnit.level_id == lv.id)
        )
        out.append(
            {
                "id": lv.id,
                "name": lv.name,
                "slug": lv.slug,
                "form_mapping": lv.form_mapping,
                "proficiency_label": lv.proficiency_label,
                "description": lv.description,
                "order_index": lv.order_index,
                "unit_count": ucnt.scalar() or 0,
                "lesson_count": lcnt.scalar() or 0,
            }
        )
    return out


@router.get("/{slug}/levels/{level_slug}")
async def get_level(slug: str, level_slug: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Language).where(Language.slug == slug))
    lang = result.scalar_one_or_none()
    if not lang:
        raise HTTPException(404, "Language not found")
    lr = await db.execute(
        select(LanguageLevel).where(
            LanguageLevel.language_id == lang.id, LanguageLevel.slug == level_slug
        )
    )
    lv = lr.scalar_one_or_none()
    if not lv:
        raise HTTPException(404, "Level not found")
    ur = await db.execute(
        select(LanguageUnit)
        .where(LanguageUnit.level_id == lv.id)
        .options(selectinload(LanguageUnit.lessons))
        .order_by(LanguageUnit.order_index)
    )
    units = ur.scalars().unique().all()
    return {
        "id": lv.id,
        "name": lv.name,
        "slug": lv.slug,
        "form_mapping": lv.form_mapping,
        "proficiency_label": lv.proficiency_label,
        "description": lv.description,
        "units": [
            {
                "id": u.id,
                "name": u.name,
                "description": u.description,
                "lessons": [
                    {
                        "id": les.id,
                        "title": les.title,
                        "description": les.description,
                        "lesson_type": les.lesson_type,
                        "order_index": les.order_index,
                    }
                    for les in sorted(u.lessons, key=lambda x: x.order_index)
                ],
            }
            for u in units
        ],
    }


@router.get("/units/{unit_id}")
async def get_unit(unit_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(LanguageUnit)
        .where(LanguageUnit.id == unit_id)
        .options(
            selectinload(LanguageUnit.lessons).selectinload(LanguageLesson.vocabulary)
        )
    )
    unit = result.scalar_one_or_none()
    if not unit:
        raise HTTPException(404, "Unit not found")
    return {
        "id": unit.id,
        "name": unit.name,
        "description": unit.description,
        "lessons": [
            {
                "id": les.id,
                "title": les.title,
                "description": les.description,
                "lesson_type": les.lesson_type,
                "vocabulary_count": len(les.vocabulary),
            }
            for les in sorted(unit.lessons, key=lambda x: x.order_index)
        ],
    }


@router.get("/lessons/{lesson_id}")
async def get_lesson(lesson_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(LanguageLesson)
        .where(LanguageLesson.id == lesson_id)
        .options(
            selectinload(LanguageLesson.vocabulary),
            selectinload(LanguageLesson.grammar_rules),
        )
    )
    les = result.scalar_one_or_none()
    if not les:
        raise HTTPException(404, "Lesson not found")
    return {
        "id": les.id,
        "title": les.title,
        "description": les.description,
        "lesson_type": les.lesson_type,
        "vocabulary": [
            {
                "id": v.id,
                "word": v.word,
                "translation": v.translation,
                "pronunciation": v.pronunciation,
                "part_of_speech": v.part_of_speech,
                "example_sentence": v.example_sentence,
                "example_translation": v.example_translation,
                "theme": v.theme,
                "difficulty": v.difficulty,
            }
            for v in sorted(les.vocabulary, key=lambda x: x.order_index)
        ],
        "grammar_rules": [
            {
                "id": g.id,
                "rule_name": g.rule_name,
                "rule_category": g.rule_category,
                "explanation": g.explanation,
                "examples": g.examples,
                "contrast": g.contrast,
                "difficulty": g.difficulty,
            }
            for g in sorted(les.grammar_rules, key=lambda x: x.order_index)
        ],
    }


@router.get("/{slug}/vocabulary")
async def list_vocabulary(
    slug: str,
    theme: str | None = None,
    difficulty: str | None = None,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
):
    lang_r = await db.execute(select(Language).where(Language.slug == slug))
    lang = lang_r.scalar_one_or_none()
    if not lang:
        raise HTTPException(404, "Language not found")
    stmt = (
        select(LanguageVocabulary)
        .join(LanguageLesson)
        .join(LanguageUnit)
        .join(LanguageLevel)
        .where(LanguageLevel.language_id == lang.id)
    )
    if theme:
        stmt = stmt.where(LanguageVocabulary.theme == theme)
    if difficulty:
        stmt = stmt.where(LanguageVocabulary.difficulty == difficulty)
    stmt = stmt.order_by(LanguageVocabulary.order_index).limit(limit)
    result = await db.execute(stmt)
    vocab = result.scalars().all()
    return [
        {
            "id": v.id,
            "word": v.word,
            "translation": v.translation,
            "pronunciation": v.pronunciation,
            "part_of_speech": v.part_of_speech,
            "example_sentence": v.example_sentence,
            "example_translation": v.example_translation,
            "theme": v.theme,
            "difficulty": v.difficulty,
        }
        for v in vocab
    ]


@router.get("/{slug}/vocabulary/themes")
async def vocabulary_themes(slug: str, db: AsyncSession = Depends(get_db)):
    lang_r = await db.execute(select(Language).where(Language.slug == slug))
    lang = lang_r.scalar_one_or_none()
    if not lang:
        raise HTTPException(404, "Language not found")
    result = await db.execute(
        select(LanguageVocabulary.theme, func.count(LanguageVocabulary.id))
        .join(LanguageLesson)
        .join(LanguageUnit)
        .join(LanguageLevel)
        .where(
            LanguageLevel.language_id == lang.id, LanguageVocabulary.theme.isnot(None)
        )
        .group_by(LanguageVocabulary.theme)
        .order_by(func.count(LanguageVocabulary.id).desc())
    )
    return [{"theme": row[0], "count": row[1]} for row in result.all()]


@router.get("/{slug}/grammar")
async def list_grammar(
    slug: str,
    category: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    lang_r = await db.execute(select(Language).where(Language.slug == slug))
    lang = lang_r.scalar_one_or_none()
    if not lang:
        raise HTTPException(404, "Language not found")
    stmt = (
        select(LanguageGrammarRule)
        .join(LanguageLesson)
        .join(LanguageUnit)
        .join(LanguageLevel)
        .where(LanguageLevel.language_id == lang.id)
    )
    if category:
        stmt = stmt.where(LanguageGrammarRule.rule_category == category)
    stmt = stmt.order_by(LanguageGrammarRule.order_index)
    result = await db.execute(stmt)
    rules = result.scalars().all()
    return [
        {
            "id": g.id,
            "rule_name": g.rule_name,
            "rule_category": g.rule_category,
            "explanation": g.explanation,
            "examples": g.examples,
            "contrast": g.contrast,
            "difficulty": g.difficulty,
        }
        for g in rules
    ]


@router.get("/{slug}/grammar/categories")
async def grammar_categories(slug: str, db: AsyncSession = Depends(get_db)):
    lang_r = await db.execute(select(Language).where(Language.slug == slug))
    lang = lang_r.scalar_one_or_none()
    if not lang:
        raise HTTPException(404, "Language not found")
    result = await db.execute(
        select(LanguageGrammarRule.rule_category, func.count(LanguageGrammarRule.id))
        .join(LanguageLesson)
        .join(LanguageUnit)
        .join(LanguageLevel)
        .where(LanguageLevel.language_id == lang.id)
        .group_by(LanguageGrammarRule.rule_category)
        .order_by(func.count(LanguageGrammarRule.id).desc())
    )
    return [{"category": row[0], "count": row[1]} for row in result.all()]


@router.get("/{slug}/analytics/{user_id}")
async def get_analytics(slug: str, user_id: int, db: AsyncSession = Depends(get_db)):
    lang_r = await db.execute(select(Language).where(Language.slug == slug))
    lang = lang_r.scalar_one_or_none()
    if not lang:
        raise HTTPException(404, "Language not found")
    pr = await db.execute(
        select(LanguageUserProgress).where(
            LanguageUserProgress.user_id == user_id,
            LanguageUserProgress.language_id == lang.id,
        )
    )
    prog = pr.scalar_one_or_none()
    if prog:
        return {
            "language": lang.name,
            "vocabulary_mastered": prog.vocabulary_mastered,
            "vocabulary_learning": prog.vocabulary_learning,
            "grammar_mastered": prog.grammar_mastered,
            "grammar_learning": prog.grammar_learning,
            "listening_score": prog.listening_score,
            "speaking_score": prog.speaking_score,
            "reading_score": prog.reading_score,
            "writing_score": prog.writing_score,
            "pronunciation_score": prog.pronunciation_score,
            "overall_mastery": prog.overall_mastery,
            "streak_days": prog.streak_days,
            "total_study_minutes": prog.total_study_minutes,
            "lessons_completed": prog.lessons_completed,
        }
    return {
        "language": lang.name,
        "vocabulary_mastered": 0,
        "vocabulary_learning": 0,
        "grammar_mastered": 0,
        "grammar_learning": 0,
        "listening_score": 0,
        "speaking_score": 0,
        "reading_score": 0,
        "writing_score": 0,
        "pronunciation_score": 0,
        "overall_mastery": 0,
        "streak_days": 0,
        "total_study_minutes": 0,
        "lessons_completed": 0,
    }


@router.post("/placement/start")
async def start_placement(
    req: PlacementStartRequest, db: AsyncSession = Depends(get_db)
):
    lang_r = await db.execute(select(Language).where(Language.id == req.language_id))
    lang = lang_r.scalar_one_or_none()
    if not lang:
        raise HTTPException(404, "Language not found")
    pr = await db.execute(
        select(LanguagePlacement).where(
            LanguagePlacement.user_id == req.user_id,
            LanguagePlacement.language_id == req.language_id,
            LanguagePlacement.completed == False,
        )
    )
    existing = pr.scalar_one_or_none()
    if existing:
        return {
            "placement_id": existing.id,
            "language": lang.name,
            "status": "in_progress",
        }
    placement = LanguagePlacement(user_id=req.user_id, language_id=req.language_id)
    db.add(placement)
    await db.commit()
    await db.refresh(placement)
    return {
        "placement_id": placement.id,
        "language": lang.name,
        "status": "in_progress",
    }
