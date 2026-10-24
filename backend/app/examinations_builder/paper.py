"""Professional examination paper model + renderers (PDF via reportlab, DOCX).

Turns an examination (flat questions plus optional paper/section/cover config)
into an institution-quality printable paper: cover page (excluded from the
content page-numbering count), named sections, configurable numbering and mark
styles, dynamic answer lines, essay/structured areas, keep-together pagination,
header/footer, content-relative "Page X of Y", math/scientific notation, tables,
diagrams and graph paper, plus automatic mark totals and mismatch reporting.

The two public renderers are :func:`build_professional_pdf` and
:func:`build_professional_docx`. Both consume a :class:`ConstructedPaper`.
"""

from __future__ import annotations

import io
import os
from dataclasses import dataclass, field

from app.examinations_builder.typeset import (
    runs_to_docx_runs,
    runs_to_reportlab,
    typeset,
)

__all__ = [
    "PaperOptions",
    "CoverData",
    "SectionData",
    "PaperQuestion",
    "ConstructedPaper",
    "lines_for_question",
    "build_constructed_paper",
    "build_professional_pdf",
    "build_professional_docx",
    "validate_paper",
    "mark_text",
    "number_question",
    "number_subquestion",
]

# ── Constants ───────────────────────────────────────────────────────────────

PAPER_SIZES_PT = {"A4": (595.0, 842.0), "letter": (612.0, 792.0)}

LINE_SCALE = {"minimal": 0.5, "standard": 1.5, "generous": 2.0}

_LETTERS = "abcdefghijklmnopqrstuvwxyz"


def _safe_int(value, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


# ── Data model ──────────────────────────────────────────────────────────────


@dataclass
class PaperOptions:
    """Global page / typography settings (spec §26, §22–§25)."""

    paper_size: str = "A4"
    margin_points: float = 54.0
    font_name: str = "Helvetica"
    font_size: float = 10.5
    line_spacing: float = 1.35
    heading_size: float = 13.0
    mark_style: str = "[2 marks]"
    numbering_style: str = "decimal"  # decimal | alphabetic | subsection | alpha_letter
    answer_space: str = "standard"  # auto | minimal | standard | generous | custom
    custom_lines_per_question: int = 4
    show_page_numbers: bool = True
    show_turn_over: bool = True
    show_sections: bool = True  # False = MSCE style: straight numbered questions
    header_lines: list[str] = field(default_factory=list)
    footer_left: str = ""
    footer_right: str = "Examination Code: {exam_code}"
    show_header: bool = True
    watermark_text: str = ""
    confidentiality: str = ""


@dataclass
class CoverData:
    """Editable cover-page fields (spec §2, §3, §4)."""

    institution: str = "PENROSE SCHOLARMW"
    logo_path: str = ""
    faculty: str = ""
    exam_name: str = "END OF TERM EXAMINATION"
    subject: str = "Biology"
    paper_number: str = "Paper 1"
    form: str = "Form 4"
    academic_year: str = "2026"
    term: str = ""
    exam_date: str = ""
    duration: str = "2 hours"
    total_marks: str = "100"
    exam_code: str = ""
    version: str = "V1.0"
    candidate_name: bool = True
    candidate_number: bool = True
    candidate_class: bool = True
    candidate_school: bool = True
    center_number: bool = True
    signature: bool = True
    declaration: str = "I declare that this examination is my own work."
    instructions: list[str] = field(
        default_factory=lambda: [
            "Answer all questions in the spaces provided.",
            "Write your answers clearly.",
            "Show all working where required.",
            "Calculators may be used unless stated otherwise.",
            "Do not write in the margins.",
            "Check that your paper contains all pages before starting.",
        ]
    )
    show_instructions: bool = True
    show_logo: bool = False
    show_exam_code: bool = True
    show_version: bool = True
    show_declaration: bool = True
    show_signature: bool = True
    style: str = "classic"  # classic (institutional) | msce (Marist-style exam cover)
    num_questions: int = 0


@dataclass
class PaperQuestion:
    """A single editable question (spec §9–§16, §33, §35)."""

    id: str = ""
    question_type: str = "short_answer"
    question_text: str = ""
    options: list[str] = field(default_factory=list)
    correct_answer: str = ""
    marks: int = 1
    difficulty: str = "medium"
    bloom_level: str = "Understanding"
    learning_outcome: str = ""
    rubric: str = ""
    reference: str = ""
    section: str = ""
    answer_lines_override: int | None = None
    diagram: dict | None = None
    table: dict | None = None
    subquestions: list["PaperQuestion"] = field(default_factory=list)


@dataclass
class SectionData:
    """A named, numbered section (spec §6, §7)."""

    name: str = "SECTION"
    number: int = 1
    instructions: str = "Answer all questions."
    marks: int = 0
    question_types: list[str] = field(default_factory=list)
    questions: list[PaperQuestion] = field(default_factory=list)


@dataclass
class ConstructedPaper:
    """The assembled, render-ready examination document."""

    title: str = "Examination"
    subject: str = "Subject"
    cover: CoverData | None = None
    options: PaperOptions = field(default_factory=PaperOptions)
    sections: list[SectionData] = field(default_factory=list)
    include_answers: bool = False
    teacher_version: bool = False


# ── Formatting helpers ──────────────────────────────────────────────────────


def mark_text(marks: int, style: str) -> str:
    """Render a mark annotation in the chosen style (spec §9)."""
    m = max(1, int(marks))
    return {
        "[2 marks]": f"[{m} marks]",
        "[2]": f"[{m}]",
        "(2 marks)": f"({m} marks)",
        "(2)": f"({m})",
    }.get(style, f"[{m} marks]")


def number_question(qnum: int, style: str) -> str:
    """Render a top-level question number (spec §8)."""
    if style == "alpha_letter":
        return chr(ord("A") + (qnum - 1) % 26)
    if style == "subsection":
        return f"{qnum}.1"
    if style == "alphabetic":
        return _LETTERS[(qnum - 1) % 26].upper()
    return str(qnum)


def number_subquestion(qnum: int, s_num: int, style: str) -> str:
    """Render a subquestion number given its parent question number."""
    if style == "subsection":
        return f"{qnum}.{s_num}"
    return f"{qnum}({_LETTERS[(s_num - 1) % 26]})"


def lines_for_question(q: PaperQuestion, options: PaperOptions) -> int:
    """Number of answer lines for a question (spec §11, §12, §20).

    Selection-based types (multiple_choice, true_false, matching) take NO answer
    lines — a candidate ticks/selects instead of writing. Written-response types
    scale their lines with the marks and chosen spacing:
    - ``essay`` always gets a large area (>= 8 lines).
    - ``structured`` uses fewer lines (sub-questions provide their own space).
    - ``calculation`` provides working area.
    - ``short_answer`` / ``fill_in_blank`` / ``practical`` / ``case_study``
      scale roughly one line per mark.
    """
    if q.answer_lines_override is not None:
        return max(0, int(q.answer_lines_override))
    if q.question_type in ("multiple_choice", "true_false", "matching"):
        return 0
    if options.answer_space == "custom":
        return max(1, int(options.custom_lines_per_question))
    scale = LINE_SCALE.get(options.answer_space, 1.0)
    if q.question_type == "essay":
        return max(8, round(6 * scale))
    if q.question_type == "structured":
        return max(4, round(2 * max(1, q.marks) * scale))
    if q.question_type == "calculation":
        return max(4, round(3 * max(1, q.marks) * scale))
    return max(1, round(scale * max(1, q.marks)))


def _esc(text: str) -> str:
    return (
        str(text or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    )


def _markup(text: str) -> str:
    return runs_to_reportlab(typeset(text or ""))


def _runs_plain(text: str) -> list[tuple[str, str]]:
    return runs_to_docx_runs(typeset(text or ""))


def _label_value(label: str, value: str) -> str:
    return f"<b>{label}:</b> {_esc(value)}"


def _underline(extra: int = 20) -> str:
    return "<u>" + "&nbsp;" * extra + "</u>"


# ── Paper assembly ──────────────────────────────────────────────────────────


def _question_from_dict(q: dict) -> PaperQuestion:
    return PaperQuestion(
        id=str(q.get("id", "")),
        question_type=str(q.get("question_type", "short_answer")),
        question_text=str(q.get("question_text", "")),
        options=[str(o) for o in (q.get("options") or [])],
        correct_answer=str(q.get("correct_answer", "")),
        marks=_safe_int(q.get("marks"), 1),
        difficulty=str(q.get("difficulty", "medium")),
        bloom_level=str(q.get("bloom_level", "Understanding")),
        learning_outcome=str(q.get("learning_outcome", "")),
        rubric=str(q.get("rubric", "")),
        reference=str(q.get("reference", "")),
        section=str(q.get("section", "")),
        answer_lines_override=q.get("answer_lines_override"),
        diagram=q.get("diagram"),
        table=q.get("table"),
        subquestions=[_question_from_dict(s) for s in (q.get("subquestions") or [])],
    )


def _default_sections(questions: list[PaperQuestion]) -> list[SectionData]:
    headers = {
        "multiple_choice": "SECTION A — MULTIPLE CHOICE QUESTIONS",
        "true_false": "SECTION A — TRUE / FALSE QUESTIONS",
        "matching": "SECTION A — MATCHING QUESTIONS",
        "fill_in_blank": "SECTION B — FILL IN THE BLANK QUESTIONS",
        "short_answer": "SECTION B — SHORT ANSWER QUESTIONS",
        "structured": "SECTION C — STRUCTURED QUESTIONS",
        "essay": "SECTION D — ESSAY QUESTIONS",
        "practical": "SECTION D — PRACTICAL QUESTIONS",
        "calculation": "SECTION D — CALCULATION QUESTIONS",
        "case_study": "SECTION D — CASE STUDY QUESTIONS",
    }
    grouped: dict[str, list[PaperQuestion]] = {}
    for q in questions:
        grouped.setdefault(q.question_type, []).append(q)
    sections: list[SectionData] = []
    for q_type in (
        "multiple_choice",
        "true_false",
        "matching",
        "fill_in_blank",
        "short_answer",
        "structured",
        "essay",
        "practical",
        "calculation",
        "case_study",
    ):
        group = grouped.pop(q_type, None)
        if not group:
            continue
        sections.append(
            SectionData(
                name=headers.get(
                    q_type, f"{q_type.replace('_', ' ').upper()} QUESTIONS"
                ),
                number=len(sections) + 1,
                marks=sum(_safe_int(q.marks, 1) for q in group),
                question_types=[q_type],
                questions=group,
            )
        )
    for q_type, group in grouped.items():
        sections.append(
            SectionData(
                name=f"{q_type.replace('_', ' ').upper()} QUESTIONS",
                number=len(sections) + 1,
                marks=sum(_safe_int(q.marks, 1) for q in group),
                question_types=[q_type],
                questions=group,
            )
        )
    return sections


def build_constructed_paper(
    title: str,
    subject: str,
    questions: list[dict],
    cover: CoverData | None = None,
    options: PaperOptions | None = None,
    sections: list[SectionData] | None = None,
    include_answers: bool = False,
    teacher_version: bool = False,
) -> ConstructedPaper:
    """Assemble a ConstructedPaper from engine-style question dicts."""
    options = options or PaperOptions()
    pqs = [_question_from_dict(q) for q in questions]
    combined = list(sections) if sections else _default_sections(pqs)
    if not combined:
        combined = [SectionData(name="QUESTIONS", number=1)]
    flat = {id(q) for s in combined for q in s.questions}
    for q in pqs:
        if id(q) not in flat:
            combined[0].questions.append(q)
    return ConstructedPaper(
        title=title,
        subject=subject,
        cover=cover,
        options=options,
        sections=combined,
        include_answers=include_answers,
        teacher_version=teacher_version,
    )


def validate_paper(paper: ConstructedPaper) -> dict:
    """Return section totals, grand total and warnings (spec §29)."""
    section_totals: list[dict] = []
    grand_total = 0
    warnings: list[str] = []
    for section in paper.sections:
        sec_total = sum(_safe_int(q.marks, 1) for q in section.questions)
        grand_total += sec_total
        section_totals.append({"name": section.name, "marks": sec_total})
        if section.marks != 0 and section.marks != sec_total:
            warnings.append(
                f"'{section.name}' declared {section.marks} marks but its questions total {sec_total}."
            )
        if not section.questions:
            warnings.append(f"Section '{section.name}' has no questions.")
    if paper.cover and _safe_int(paper.cover.total_marks, 0):
        declared = _safe_int(paper.cover.total_marks, 0)
        if declared != grand_total:
            warnings.append(f"Mark total mismatch: {grand_total}/{declared}.")
    return {
        "section_totals": section_totals,
        "grand_total": grand_total,
        "warnings": warnings,
    }


# ── Shared flow builders (PDF only) ─────────────────────────────────────────


def _table_flow(table: dict):
    from reportlab.lib import colors
    from reportlab.platypus import Table, TableStyle

    headers = list(table.get("headers") or [])
    rows = [[str(c) for c in r] for r in (table.get("rows") or [])]
    data = [headers] + rows if headers else rows
    if not data:
        return None
    t = Table(data, repeatRows=1 if headers else 0, hAlign="LEFT")
    t.setStyle(
        TableStyle(
            [
                ("GRID", (0, 0), (-1, -1), 0.5, colors.black),
                ("FONTSIZE", (0, 0), (-1, -1), 8.5),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#eef2f7")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ]
        )
    )
    return t


def _diagram_flow(diagram: dict):
    from reportlab.platypus import Image

    from app.examinations_builder.diagrams import render_diagram

    try:
        png = render_diagram(diagram)
    except Exception:
        return None
    width = float(diagram.get("width", 6.0))
    height = float(diagram.get("height", 4.0))
    img = Image(
        io.BytesIO(png), width=min(width, 6.0) * 72, height=min(height, 4.5) * 72
    )
    img.hAlign = "CENTER"
    return img


def _answer_line_flow():
    from reportlab.lib import colors
    from reportlab.platypus import Table, TableStyle

    t = Table([[""]], colWidths=[420], rowHeights=[12])
    t.setStyle(
        TableStyle(
            [
                ("LINEBELOW", (0, 0), (-1, -1), 0.6, colors.HexColor("#111111")),
                ("LEFTPADDING", (0, 0), (-1, -1), 0),
                ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                ("TOPPADDING", (0, 0), (-1, -1), 2),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
            ]
        )
    )
    return t


def _answer_lines(count: int):
    if count <= 0:
        return []
    return [_answer_line_flow() for _ in range(count)]


def _section_heading(section: SectionData, opts: PaperOptions):
    from reportlab.lib import colors
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.platypus import Paragraph

    style = ParagraphStyle(
        "sectionHead",
        fontName="Helvetica-Bold",
        fontSize=opts.heading_size,
        leading=opts.heading_size * 1.2,
        spaceBefore=8,
        spaceAfter=4,
        textColor=colors.HexColor("#1F4E79"),
    )
    text = section.name
    return Paragraph(_esc(text), style)


def _question_paragraph(num: str, stem_markup: str, mark: str, bold: bool = True):
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.platypus import Paragraph

    b = "Helvetica-Bold" if bold else "Helvetica"
    style = ParagraphStyle(
        "q", fontName=b, fontSize=10.5, leading=14, spaceBefore=5, spaceAfter=2
    )
    return Paragraph(f"<b>{num}.</b> {stem_markup} &nbsp; {mark}", style)


def _options_paragraph(options: list[str]):
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.platypus import Paragraph

    style = ParagraphStyle(
        "opts", fontName="Helvetica", fontSize=10, leading=13, leftIndent=16
    )
    body = "<br/>".join(f"({_LETTERS[i]}) {_esc(o)}" for i, o in enumerate(options))
    return Paragraph(body, style)


def _end_style():
    from reportlab.lib.styles import ParagraphStyle

    return ParagraphStyle(
        "endMark",
        fontName="Helvetica-Bold",
        fontSize=11,
        leading=15,
        spaceBefore=12,
        alignment=1,
    )


def _msce_cover_story(c: "CoverData", paper: "ConstructedPaper") -> list:
    """Strict Marist-style MSCE cover.

    Reserved school-logo space (top-left), EXAMINATION NO line (top-right),
    centred exam header block (exam name / subject / paper / marks), subject
    number, date + time allowed, numbered instructions, the question tick
    table with a Total row, and a "Turn over" footer — matching the 2024
    Marist MSCE Mock II sample layout.
    """
    from reportlab.lib import colors
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.platypus import Image, Paragraph, Spacer, Table, TableStyle

    left = ParagraphStyle("msceL", fontName="Helvetica", fontSize=10.5, leading=15)
    centre = ParagraphStyle("msceC", parent=left, alignment=1)
    centre_b = ParagraphStyle("msceCB", parent=centre, fontName="Helvetica-Bold")
    head = ParagraphStyle("msceHead", parent=centre_b, fontSize=14, leading=18)
    head_big = ParagraphStyle("msceBig", parent=head, fontSize=16, leading=20)
    tiny_r = ParagraphStyle(
        "msceTinyR", fontName="Helvetica-Oblique", fontSize=8, leading=10, alignment=2
    )
    turn_over = ParagraphStyle(
        "msceTurn", fontName="Helvetica-Bold", fontSize=9.5, leading=12, alignment=2
    )

    story: list = []

    # Reserved school-logo space (top-left) with the EXAMINATION NO line top-right.
    if c.logo_path and c.show_logo and os.path.exists(c.logo_path):
        logo_flow = Image(c.logo_path, width=90, height=60)
    else:
        box = Table([[""]], colWidths=[92], rowHeights=[58])
        box.setStyle(TableStyle([("BOX", (0, 0), (-1, -1), 0.8, colors.black)]))
        logo_flow = box
    top = Table(
        [[logo_flow, Paragraph("<b>EXAMINATION NO</b> " + "_" * 26, left)]],
        colWidths=[120, 330],
    )
    top.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ALIGN", (1, 0), (1, 0), "RIGHT"),
                ("LEFTPADDING", (0, 0), (-1, -1), 0),
                ("RIGHTPADDING", (0, 0), (-1, -1), 0),
            ]
        )
    )
    story.append(top)
    story.append(Spacer(1, 20))

    story.append(Paragraph(_esc(c.exam_name), head))
    story.append(Paragraph(_esc(c.subject), head_big))
    if c.paper_number:
        story.append(Paragraph(_esc(c.paper_number), head))
    if _safe_int(c.total_marks, 0):
        story.append(Paragraph(f"({_esc(c.total_marks)} marks)", centre_b))
    story.append(Spacer(1, 8))
    if c.exam_code:
        story.append(Paragraph(f"Subject Number: {_esc(c.exam_code)}", left))
    story.append(Spacer(1, 8))
    meta_bits = [
        bit
        for bit in (
            c.exam_date,
            (f"Time Allowed: {_esc(c.duration)}" if c.duration else ""),
        )
        if bit
    ]
    if meta_bits:
        story.append(
            Paragraph(
                "&nbsp;&nbsp;&nbsp;&nbsp;".join(_esc(b) for b in meta_bits), left
            )
        )
    story.append(Spacer(1, 12))

    num_q = c.num_questions or sum(len(s.questions) for s in paper.sections)
    total_marks = _safe_int(c.total_marks, 0) or sum(
        _safe_int(q.marks, 1) for s in paper.sections for q in s.questions
    )
    classic_defaults = [
        "Answer all questions in the spaces provided.",
        "Write your answers clearly.",
        "Show all working where required.",
        "Calculators may be used unless stated otherwise.",
        "Do not write in the margins.",
        "Check that your paper contains all pages before starting.",
    ]
    instructions = (
        list(c.instructions)
        if c.instructions and list(c.instructions) != classic_defaults
        else [
            "This paper contains printed pages. Please check that all pages are present.",
            f"Answer all the {num_q} questions in the spaces provided in the question paper.",
            "The maximum number of marks for each question is indicated against each question.",
            "Calculators may be used.",
            "All working must be clearly shown.",
            "Write your name at the top of each page in the spaces provided.",
            "In the table provided on this page, tick against the question number you have answered.",
        ]
    )
    story.append(
        Paragraph(
            "Instructions",
            ParagraphStyle("msceInstr", parent=left, fontName="Helvetica-Bold"),
        )
    )
    for n, ins in enumerate(instructions, 1):
        story.append(Paragraph(_markup(f"{n}. {ins}"), left))
    story.append(Spacer(1, 16))

    def tick_chunk(start: int, count: int, is_last: bool) -> Table:
        numbers = [str(start + i) for i in range(count)]
        data = [
            [Paragraph("Question Number", centre_b)] + [""] * (count - 1),
            [Paragraph("Tick if answered", tiny_r)] + [""] * (count - 1),
            [Paragraph("Do not write in these columns", tiny_r)] + [""] * (count - 1),
            numbers,
            ["" for _ in numbers],
            [Paragraph(f"Total {total_marks}", centre_b), "", ""] + [""] * (count - 3),
        ]
        if not is_last:
            data[-1] = ["" for _ in data[-1]]
        t = Table(data, colWidths=[44] * count, hAlign="LEFT")
        t.setStyle(
            TableStyle(
                [
                    ("SPAN", (0, 0), (-1, 0)),
                    ("SPAN", (0, 1), (-1, 1)),
                    ("SPAN", (0, 2), (-1, 2)),
                    ("SPAN", (0, 5), (-2, 5)),
                    ("GRID", (0, 3), (-1, 4), 0.7, colors.black),
                    ("FONTSIZE", (0, 0), (-1, -1), 8.5),
                    ("LEFTPADDING", (0, 0), (-1, -1), 2),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 2),
                    ("TOPPADDING", (0, 0), (-1, -1), 3),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                ]
            )
        )
        return t

    start = 1
    remaining = num_q
    while remaining > 0:
        count = min(10, remaining)
        story.append(tick_chunk(start, count, is_last=(remaining == count)))
        story.append(Spacer(1, 8))
        start += count
        remaining -= count

    story.append(Spacer(1, 4))
    story.append(Paragraph("Turn over", turn_over))
    return story


# ── PDF renderer ────────────────────────────────────────────────────────────


def build_professional_pdf(paper: ConstructedPaper) -> io.BytesIO:
    """Render the professional PDF (cover excluded from content page count)."""
    from reportlab.lib import colors
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.platypus import (
        BaseDocTemplate,
        Frame,
        Image,
        KeepTogether,
        NextPageTemplate,
        PageBreak,
        PageTemplate,
        Paragraph,
        Spacer,
    )

    opts = paper.options
    size = PAPER_SIZES_PT.get(opts.paper_size, PAPER_SIZES_PT["A4"])
    margin = opts.margin_points
    buf = io.BytesIO()

    # Styles
    body = ParagraphStyle(
        "body",
        fontName=opts.font_name,
        fontSize=opts.font_size,
        leading=opts.font_size * opts.line_spacing,
        spaceAfter=4,
    )
    small = ParagraphStyle(
        "small",
        parent=body,
        fontSize=opts.font_size - 1.5,
        textColor=colors.HexColor("#444444"),
    )
    cover_head = ParagraphStyle(
        "coverHead",
        fontName="Helvetica-Bold",
        fontSize=15,
        leading=19,
        alignment=1,
        textColor=colors.HexColor("#1F4E79"),
    )
    cover_mid = ParagraphStyle(
        "coverMid", fontName="Helvetica", fontSize=11, alignment=1, leading=15
    )
    cover_small = ParagraphStyle(
        "coverSmall", fontName="Helvetica", fontSize=8, alignment=1, leading=12
    )
    body_c = ParagraphStyle(
        "bodyC", parent=body, alignment=1
    )  # centered body for cover meta

    # Page-numbering: content-relative "Page X of Y" with the cover excluded
    # (spec §23). A two-pass build first counts content pages, then stamps
    # the footer via the content PageTemplate on-page hook.
    cover_offset = 1 if paper.cover else 0
    footer_left = opts.footer_left
    footer_right = opts.footer_right.replace(
        "{exam_code}", (paper.cover.exam_code if paper.cover else "")
    )

    def _content_on_page(canvas, doc_, total_content=0):
        # Top rule + optional confidentiality (drawn for every page).
        canvas.saveState()
        _msce = (
            paper.cover is not None
            and getattr(paper.cover, "style", "classic") == "msce"
        )
        if not _msce:
            canvas.setStrokeColor(colors.HexColor("#aaaaaa"))
            canvas.setLineWidth(0.5)
            canvas.line(
                margin, size[1] - margin + 8, size[0] - margin, size[1] - margin + 8
            )
        if opts.confidentiality and not _msce:
            canvas.setFont("Helvetica-Bold", 8)
            canvas.setFillColor(colors.HexColor("#a33"))
            canvas.drawCentredString(
                size[0] / 2, size[1] - margin + 3, _esc(opts.confidentiality)
            )
        if opts.show_page_numbers and canvas.getPageNumber() > cover_offset:
            canvas.setFont("Helvetica", 8.5)
            canvas.setFillColorRGB(0.27, 0.27, 0.27)
            msce = (
                paper.cover is not None
                and getattr(paper.cover, "style", "classic") == "msce"
            )
            if msce:
                page_num = canvas.getPageNumber()
                page_total = total_content + cover_offset
            else:
                page_num = canvas.getPageNumber() - cover_offset
                page_total = total_content
            canvas.drawString(margin, 28, footer_left)
            if not msce:
                canvas.drawRightString(size[0] - margin, 28, footer_right)
            if msce:
                code = getattr(paper.cover, "exam_code", "")
                canvas.drawRightString(
                    size[0] - margin,
                    size[1] - margin - 4,
                    f"Page {page_num} of {page_total}"
                    + (f"   {code}" if code else ""),
                )
                if page_num < page_total:
                    canvas.drawRightString(size[0] - margin, 28, "Continued/…")
            else:
                canvas.drawCentredString(
                    size[0] / 2,
                    28,
                    f"Page {page_num} of {page_total}",
                )
        canvas.restoreState()

    # reportlab mutates flowables while building, so the counting probe and the
    # final render each construct their own fresh story (spec §23).
    def build_story() -> list:
        story: list = []

        # ── Cover page ────────────────────────────────────────────────────────
        if paper.cover and getattr(paper.cover, "style", "classic") != "msce":
            c = paper.cover
            if c.logo_path and c.show_logo and os.path.exists(c.logo_path):
                story.append(Image(c.logo_path, width=80, height=60))
            story.append(Paragraph(_esc(c.institution), cover_head))
            if c.faculty:
                story.append(Paragraph(_esc(c.faculty), cover_mid))
            story.append(Spacer(1, 14))
            story.append(Paragraph(_esc(c.exam_name), cover_mid))
            story.append(Paragraph(_esc(c.subject), cover_head))
            story.append(Paragraph(_esc(c.paper_number), cover_mid))
            story.append(Paragraph(_esc(c.form), cover_mid))
            story.append(Spacer(1, 12))
            meta = [
                ("Academic Year", c.academic_year),
                ("Term", c.term),
                ("Date", c.exam_date),
                ("Duration", c.duration),
                ("Total Marks", c.total_marks),
                ("Examination Code", c.exam_code),
            ]
            for label, value in meta:
                if value:
                    story.append(Paragraph(_label_value(label, value), body_c))
            if c.show_version and c.version:
                story.append(Paragraph(_esc(f"Version: {c.version}"), cover_small))
            story.append(Spacer(1, 14))
            candidate_rows = []
            if c.candidate_name:
                candidate_rows.append(
                    Paragraph(f"Candidate Name: {_underline(22)}", body)
                )
            if c.candidate_number:
                candidate_rows.append(
                    Paragraph(f"Candidate Number: {_underline(22)}", body)
                )
            if c.candidate_class:
                candidate_rows.append(Paragraph(f"Class: {_underline(22)}", body))
            if c.candidate_school:
                candidate_rows.append(Paragraph(f"School: {_underline(22)}", body))
            if c.center_number:
                candidate_rows.append(
                    Paragraph(f"Centre / School Code: {_underline(18)}", body)
                )
            if c.show_signature:
                candidate_rows.append(Paragraph(f"Signature: {_underline(22)}", body))
            for row in candidate_rows:
                story.append(row)

            if c.show_instructions and c.instructions:
                story.append(Spacer(1, 14))
                story.append(
                    Paragraph("INSTRUCTIONS TO CANDIDATES", _cover_instr_style())
                )
                for n, ins in enumerate(c.instructions, 1):
                    story.append(Paragraph(_markup(f"{n}. {ins}"), small))
            if c.show_declaration and c.declaration:
                story.append(Spacer(1, 10))
                story.append(Paragraph("DECLARATION", _cover_instr_style()))
                story.append(Paragraph(_esc(c.declaration), small))

            # Switch to the content frame/page-numbering for all pages after the cover.
            story.append(NextPageTemplate("content"))
            story.append(PageBreak())

        if paper.cover and getattr(paper.cover, "style", "classic") == "msce":
            story.extend(_msce_cover_story(paper.cover, paper))
            story.append(NextPageTemplate("content"))
            story.append(PageBreak())

        # ── Content pages ────────────────────────────────────────────────────
        if opts.show_header and opts.header_lines:
            story.append(
                Paragraph(
                    _esc("   &nbsp;  ".join(opts.header_lines)), _header_style(opts)
                )
            )

        qnum = 0
        for section in paper.sections:
            if not opts.show_sections:
                for q in section.questions:
                    qnum += 1
                    story.extend(_render_question_pdf(q, qnum, opts))
                continue
            heading = _section_heading(section, opts)
            section_intro = Paragraph(
                _esc(section.instructions or "Answer all questions."), small
            )
            story.append(KeepTogether([heading, section_intro]))
            for q in section.questions:
                qnum += 1
                story.extend(_render_question_pdf(q, qnum, opts))
            story.append(Spacer(1, 6))

        if not opts.show_sections:
            story.append(Spacer(1, 14))
            story.append(Paragraph("END OF QUESTION PAPER", _end_style()))
        if paper.include_answers:
            story.append(PageBreak())
            story.append(Paragraph("MARKING SCHEME / ANSWER KEY", _header_style(opts)))
            a_num = 0
            for section in paper.sections:
                for q in section.questions:
                    a_num += 1
                    story.extend(_render_answer_pdf(q, a_num, opts))
        return story

    # Page templates + two-pass build
    cover_frame = Frame(
        margin, margin, size[0] - 2 * margin, size[1] - 2 * margin, id="cover"
    )
    content_frame = Frame(
        margin,
        margin + 18,
        size[0] - 2 * margin,
        size[1] - 2 * margin - 36,
        id="content",
    )
    if paper.cover:
        templates = [
            PageTemplate(id="cover", frames=[cover_frame]),
            PageTemplate(id="content", frames=[content_frame]),
        ]
    else:
        # No cover page: content starts on page 1 in the full-page frame.
        content_frame = Frame(
            margin, margin, size[0] - 2 * margin, size[1] - 2 * margin, id="content"
        )
        templates = [PageTemplate(id="content", frames=[content_frame])]

    # Pass 1 — learn the total content-page count (cover excluded).
    counter = {"pages": 0}

    def _count_on_page(_canvas, _doc_):
        counter["pages"] += 1

    probe = BaseDocTemplate(
        io.BytesIO(),
        pagesize=size,
        leftMargin=margin,
        rightMargin=margin,
        topMargin=margin,
        bottomMargin=margin,
    )
    probe_templates = []
    for t in templates:
        if t.id == "content":
            probe_templates.append(
                PageTemplate(id=t.id, frames=t.frames, onPage=_count_on_page)
            )
        else:
            probe_templates.append(
                PageTemplate(id=t.id, frames=t.frames, onPage=lambda _c, _d: None)
            )
    probe.addPageTemplates(probe_templates)
    probe.build(build_story())
    total_content = counter["pages"]

    # Pass 2 — real render with footer stamping using the known total.
    doc = BaseDocTemplate(
        buf,
        pagesize=size,
        leftMargin=margin,
        rightMargin=margin,
        topMargin=margin,
        bottomMargin=margin,
        title=paper.title,
        author="PENROSE SCHOLARMW",
    )
    doc_templates = []
    for t in templates:
        if t.id == "content":
            doc_templates.append(
                PageTemplate(
                    id=t.id,
                    frames=t.frames,
                    onPage=lambda c, d: _content_on_page(c, d, total_content),
                )
            )
        else:
            doc_templates.append(
                PageTemplate(id=t.id, frames=t.frames, onPage=_content_on_page)
            )
    doc.addPageTemplates(doc_templates)
    doc.build(build_story())
    buf.seek(0)
    return buf


def _cover_instr_style():
    from reportlab.lib.styles import ParagraphStyle

    return ParagraphStyle(
        "instrHead",
        fontName="Helvetica-Bold",
        fontSize=11,
        leading=15,
        spaceBefore=8,
        spaceAfter=4,
    )


def _header_style(opts: PaperOptions):
    from reportlab.lib import colors
    from reportlab.lib.styles import ParagraphStyle

    return ParagraphStyle(
        "sectHead",
        fontName="Helvetica-Bold",
        fontSize=opts.heading_size,
        leading=opts.heading_size * 1.2,
        spaceBefore=6,
        spaceAfter=4,
        textColor=colors.HexColor("#1F4E79"),
    )


def _render_question_pdf(q: PaperQuestion, qnum: int, opts: PaperOptions):
    """PDF flowables for one question.

    The non-splittable content (stem + options/diagram/table + sub-question
    stems) is kept together so it is never torn across a page boundary. Answer
    lines are appended as individual, freely-flowing tables so a question that
    starts near the bottom of a page can carry its writing space onto the next
    page instead of raising reportlab's "too large on page" LayoutError.
    """
    from reportlab.platypus import KeepTogether

    num = number_question(qnum, opts.numbering_style)
    mark = mark_text(q.marks, opts.mark_style)
    stem = _markup(q.question_text)
    block = [_question_paragraph(num, stem, mark)]
    if q.options:
        block.append(_options_paragraph(q.options))
    if q.subquestions:
        subnum = 0
        for sub in q.subquestions:
            subnum += 1
            s_num = number_subquestion(qnum, subnum, opts.numbering_style)
            s_mark = mark_text(sub.marks, opts.mark_style)
            s_stem = _markup(sub.question_text)
            block.append(_question_paragraph(s_num, s_stem, s_mark))
    if q.table:
        t = _table_flow(q.table)
        if t is not None:
            block.append(t)
    if q.diagram:
        d = _diagram_flow(q.diagram)
        if d is not None:
            block.append(d)
    flowables = [KeepTogether(block)]
    if q.subquestions:
        for sub in q.subquestions:
            flowables.extend(_answer_lines(lines_for_question(sub, opts)))
    else:
        flowables.extend(_answer_lines(lines_for_question(q, opts)))
    return flowables


def _render_answer_pdf(q: PaperQuestion, a_num: int, opts: PaperOptions):
    from reportlab.platypus import KeepTogether, Paragraph

    ans = q.correct_answer or q.rubric or "-"
    block = [
        Paragraph(
            f"<b>{a_num}.</b> {_markup(q.question_text)} &nbsp; <font color='#335'>Answer: {_esc(ans)}</font>",
            _answer_style(),
        )
    ]
    return [KeepTogether(block)]


def _answer_style():
    from reportlab.lib import colors
    from reportlab.lib.styles import ParagraphStyle

    return ParagraphStyle(
        "ans",
        fontName="Helvetica",
        fontSize=9.5,
        leading=13,
        spaceBefore=3,
        textColor=colors.HexColor("#222222"),
    )


# ── DOCX renderer ───────────────────────────────────────────────────────────


def build_professional_docx(paper: ConstructedPaper) -> io.BytesIO:
    """Render an editable DOCX mirroring the paper structure (spec §41)."""
    from docx import Document
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.shared import Pt

    doc = Document()
    doc.styles["Normal"].font.name = "Calibri"
    doc.styles["Normal"].font.size = Pt(11)

    if paper.cover:
        c = paper.cover
        t = doc.add_paragraph()
        t.alignment = WD_ALIGN_PARAGRAPH.CENTER
        t.add_run(c.institution).bold = True
        sub = doc.add_paragraph()
        sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
        sub.add_run(c.subject).bold = True
        for label, value in (
            ("Paper", c.paper_number),
            ("Form", c.form),
            ("Academic Year", c.academic_year),
            ("Term", c.term),
            ("Duration", c.duration),
            ("Total Marks", c.total_marks),
            ("Examination Code", c.exam_code),
        ):
            if value:
                p = doc.add_paragraph()
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                p.add_run(f"{label}: {value}").bold = label in (
                    "Paper",
                    "Form",
                    "Examination Code",
                )
        doc.add_page_break()
        if c.show_instructions and c.instructions:
            doc.add_heading("INSTRUCTIONS TO CANDIDATES", level=1)
            for i, ins in enumerate(c.instructions, 1):
                doc.add_paragraph(f"{i}. {ins}")
        doc.add_page_break()

    qnum = 0
    for section in paper.sections:
        doc.add_heading(section.name, level=1)
        if section.questions:
            total = sum(_safe_int(q.marks, 1) for q in section.questions)
            doc.add_paragraph(
                f"{section.instructions or 'Answer all questions.'} [{total} marks]"
            ).italic = True
        for q in section.questions:
            qnum += 1
            _docx_question(doc, q, qnum, paper)

    if paper.include_answers:
        doc.add_page_break()
        doc.add_heading("MARKING SCHEME / ANSWER KEY", level=1)
        a_num = 0
        for section in paper.sections:
            for q in section.questions:
                a_num += 1
                p = doc.add_paragraph()
                p.add_run(f"{a_num}. {q.question_text}").bold = True
                ans = q.correct_answer or q.rubric or "-"
                ap = doc.add_paragraph()
                ap.add_run("Answer: ").bold = True
                ap.add_run(ans)
                if q.reference:
                    ref = doc.add_paragraph()
                    ref.add_run(f"Source: {q.reference}").italic = True

    buf = io.BytesIO()
    doc.save(buf)
    buf.seek(0)
    return buf


def _docx_question(doc, q: PaperQuestion, qnum: int, paper: ConstructedPaper):
    """Append a question (with answer lines) to a DOCX document."""
    from docx.shared import Pt

    num = number_question(qnum, paper.options.numbering_style)
    mark = mark_text(q.marks, paper.options.mark_style)
    line = doc.add_paragraph()
    line.add_run(f"{num}. ").bold = True
    for text, run_style in _runs_plain(q.question_text):
        r = line.add_run(text)
        if run_style == "sup":
            r.font.superscript = True
        elif run_style == "sub":
            r.font.subscript = True
    line.add_run(f"  {mark}").bold = True

    if q.options:
        for i, opt in enumerate(q.options):
            op = doc.add_paragraph()
            op.paragraph_format.left_indent = Pt(24)
            op.add_run(f"({_LETTERS[i]}) {opt}")

    if q.subquestions:
        subnum = 0
        for sub in q.subquestions:
            subnum += 1
            _docx_question(doc, sub, qnum, paper)
            # subquestions render their own inline number via a sub-flattening:
            continue

    if q.table:
        _docx_table(doc, q.table)

    if not q.subquestions:
        for _ in range(lines_for_question(q, paper.options)):
            ln = doc.add_paragraph("_" * 96)
            ln.paragraph_format.space_after = Pt(0)
            ln.paragraph_format.space_before = Pt(0)


def _docx_table(doc, table: dict):
    headers = list(table.get("headers") or [])
    rows = [[str(c) for c in r] for r in (table.get("rows") or [])]
    if not headers and not rows:
        return
    cols = len(headers) or max((len(r) for r in rows), default=1)
    tbl = doc.add_table(rows=len(rows) + (1 if headers else 0), cols=cols)
    tbl.style = "Table Grid"
    r0 = 0
    if headers:
        for j, h in enumerate(headers):
            tbl.rows[0].cells[j].text = str(h)
        r0 = 1
    for i, row in enumerate(rows, r0):
        for j, cell in enumerate(row):
            if j < cols:
                tbl.rows[i].cells[j].text = str(cell)
