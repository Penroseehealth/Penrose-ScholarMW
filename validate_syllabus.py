"""Comprehensive validation of MATH_SYLLABUS seed data."""
import ast, sys

with open("backend/app/mathematics/seed_math_syllabus.py", "r", encoding="utf-8") as f:
    content = f.read()

start = content.index("MATH_SYLLABUS = {")
# Find the matching closing brace, tracking string literals and nesting
in_string = False
escape = False
string_char = None
depth = 0
i = start + 14  # position of opening {
for j in range(start + 15, len(content)):
    ch = content[j]
    if escape:
        escape = False
        continue
    if ch == '\\' and in_string:
        escape = True
        continue
    if in_string:
        if ch == string_char:
            in_string = False
        continue
    if ch in ('"', "'"):
        # Check for triple quotes
        if content[j:j+3] in ('"""', "'''"):
            in_string = True
            string_char = ch
            j += 2  # skip the triple
        else:
            in_string = True
            string_char = ch
        continue
    if ch == '{':
        depth += 1
    elif ch == '}':
        depth -= 1
        if depth == 0:
            break

data = ast.literal_eval(content[start + 15 : j + 1])

errors = []
warnings = []

# Expected core elements and their numbers
CE_NAMES = {
    1: "Number and Numeration",
    2: "Structure",
    3: "Space, Shape and Measurement",
    4: "Pattern, Relations, Functions and Change",
    5: "Statistics",
}

# Expected Form 4 topics per core element (from MoEST syllabus)
EXPECTED_F4 = {
    1: {"Matrices", "Simultaneous Linear and Quadratic Equations", "Progressions", "Polynomials", "Exponential and Logarithmic Equations", "Subject of the Formulae"},
    2: {"Vectors", "Transformations"},
    3: {"Circle Geometry (Angle Properties)", "Trigonometry", "Tangents to Circles", "Mensuration", "Similarity"},
    4: {"Coordinate Geometry", "Variations", "Inequalities", "Graphs of Quadratic Functions", "Mapping and Functions", "Travel Graphs", "Linear Programming", "Cubic Graphs"},
    5: {"Statistics", "Probability"},
}

print("=" * 80)
print("MATH SYLLABUS VALIDATION REPORT")
print("=" * 80)

# ── 1. Core element structure ──────────────────────────────────────────
print("\n1. CORE ELEMENT STRUCTURE")
print("-" * 40)
ces = data.get("core_elements", [])
if len(ces) != 5:
    errors.append(f"Expected 5 core elements, found {len(ces)}")
for ce in ces:
    num = ce["number"]
    name = ce["name"]
    expected_name = CE_NAMES.get(num, "UNKNOWN")
    if name != expected_name:
        errors.append(f"CE{num} name mismatch: '{name}' != '{expected_name}'")
    topics = ce.get("topics", [])
    print(f"  CE{num} ({name}): {len(topics)} topics")

# ── 2. Check for misplaced topics (wrong CE) ──────────────────────────
print("\n2. TOPIC PLACEMENT CHECK")
print("-" * 40)
CE3_KEYWORDS = {"circle", "trigonom", "pythagoras", "congruent", "similar", "mensuration", "quadrilateral", "angle", "triangle", "polygon", "geometric", "tangent", "construction", "line", "similarity"}
CE1_KEYWORDS = {"algebra", "factor", "hcf", "lcm", "index", "indices", "irrational", "linear equat", "simultaneous linear", "logarithm", "matrix", "matri", "number pattern", "number system", "polynomial", "progression", "proportion", "quadratic equat", "standard form", "subject", "exponential", "approximation", "commercial", "mixture", "simple algebraic"}
CE2_KEYWORDS = {"set", "transformation", "transform", "vector"}
CE4_KEYWORDS = {"coordinate", "graph", "travel", "linear program", "mapping", "function", "variation", "inequalit", "cubic"}
CE5_KEYWORDS = {"statistic", "probabil"}

for ce in ces:
    num = ce["number"]
    for t in ce.get("topics", []):
        title_lower = t["title"].lower()
        year = t.get("year_level", 0)

        # Check if topic title strongly suggests wrong CE
        if num == 1 and not any(kw in title_lower for kw in CE1_KEYWORDS):
            warnings.append(f"CE1: '{t['title']}' (Form {year}) may be misplaced — no CE1 keywords found")
        if num == 3 and not any(kw in title_lower for kw in CE3_KEYWORDS):
            warnings.append(f"CE3: '{t['title']}' (Form {year}) may be misplaced — no CE3 keywords found")
        if num == 4 and not any(kw in title_lower for kw in CE4_KEYWORDS):
            warnings.append(f"CE4: '{t['title']}' (Form {year}) may be misplaced — no CE4 keywords found")
        if num == 5 and not any(kw in title_lower for kw in CE5_KEYWORDS):
            warnings.append(f"CE5: '{t['title']}' (Form {year}) may be misplaced — no CE5 keywords found")

# ── 3. Year level distribution ─────────────────────────────────────────
print("\n3. YEAR LEVEL DISTRIBUTION")
print("-" * 40)
for ce in ces:
    num = ce["number"]
    years = {}
    for t in ce.get("topics", []):
        y = t.get("year_level", 0)
        years.setdefault(y, []).append(t["title"])
    print(f"  CE{num}:")
    for y in sorted(years.keys()):
        print(f"    Form {y}: {len(years[y])} topics")

# ── 4. Duplicate check ────────────────────────────────────────────────
print("\n4. DUPLICATE TOPIC CHECK")
print("-" * 40)
all_topics = []
for ce in ces:
    for t in ce.get("topics", []):
        all_topics.append((ce["number"], t["title"], t.get("year_level", 0)))

seen = {}
for ce_num, title, year in all_topics:
    key = (ce_num, title, year)
    if key in seen:
        errors.append(f"DUPLICATE: CE{ce_num} '{title}' (Form {year}) appears twice")
    seen[key] = True
print(f"  Total topic entries: {len(all_topics)}")
dups = [k for k, v in list(seen.items()) if list(seen.keys()).count(k) > 1]  # won't work with dict
# Better approach
from collections import Counter
counts = Counter(all_topics)
dups_found = {k: v for k, v in counts.items() if v > 1}
if dups_found:
    for (ce_num, title, year), cnt in dups_found.items():
        errors.append(f"DUPLICATE: CE{ce_num} '{title}' (Form {year}) appears {cnt} times")
else:
    print("  No duplicates found")

# ── 5. Subtopic validation ────────────────────────────────────────────
print("\n5. SUBTOPIC VALIDATION")
print("-" * 40)
total_subtopics = 0
total_objectives = 0
topics_without_subtopics = 0
for ce in ces:
    for t in ce.get("topics", []):
        subs = t.get("subtopics", [])
        if not subs:
            topics_without_subtopics += 1
            warnings.append(f"CE{ce['number']}: '{t['title']}' (Form {t.get('year_level', '?')}) has NO subtopics")
        for s in subs:
            total_subtopics += 1
            los = s.get("learning_objectives", [])
            total_objectives += len(los)
            if not los:
                warnings.append(f"  Subtopic '{s['title']}' in '{t['title']}' has NO learning objectives")
            for lo in los:
                if "objective" not in lo:
                    errors.append(f"  Learning objective missing 'objective' field in '{s['title']}'")
                if "cognitive_level" not in lo:
                    warnings.append(f"  Learning objective missing 'cognitive_level' in '{s['title']}': {lo.get('objective', '?')[:50]}")
                if "teaching_method" not in lo:
                    warnings.append(f"  Learning objective missing 'teaching_method' in '{s['title']}': {lo.get('objective', '?')[:50]}")

print(f"  Total subtopics: {total_subtopics}")
print(f"  Total learning objectives: {total_objectives}")
print(f"  Topics without subtopics: {topics_without_subtopics}")

# ── 6. Resources check ────────────────────────────────────────────────
print("\n6. RESOURCES CHECK")
print("-" * 40)
no_resources = 0
for ce in ces:
    for t in ce.get("topics", []):
        res = t.get("resources", [])
        if not res:
            no_resources += 1
            warnings.append(f"CE{ce['number']}: '{t['title']}' (Form {t.get('year_level', '?')}) has NO resources")
print(f"  Topics without resources: {no_resources}")

# ── 7. Form 4 coverage ───────────────────────────────────────────────
print("\n7. FORM 4 COVERAGE (expected vs actual)")
print("-" * 40)
for ce in ces:
    num = ce["number"]
    expected = EXPECTED_F4.get(num, set())
    actual = {t["title"] for t in ce.get("topics", []) if t.get("year_level") == 4}
    missing = expected - actual
    extra = actual - expected
    if missing:
        errors.append(f"CE{num}: Missing Form 4 topics: {missing}")
    if extra:
        warnings.append(f"CE{num}: Extra Form 4 topics not in expected: {extra}")
    status = "OK" if not missing else f"MISSING: {missing}"
    print(f"  CE{num}: {len(actual)} Form 4 topics — {status}")

# ── 8. Required fields ────────────────────────────────────────────────
print("\n8. REQUIRED FIELD CHECK")
print("-" * 40)
for ce in ces:
    for t in ce.get("topics", []):
        if "title" not in t:
            errors.append(f"Topic missing 'title'")
        if "year_level" not in t:
            errors.append(f"Topic '{t.get('title', '?')}' missing 'year_level'")
        for s in t.get("subtopics", []):
            if "title" not in s:
                errors.append(f"Subtopic in '{t['title']}' missing 'title'")

# ── SUMMARY ───────────────────────────────────────────────────────────
print("\n" + "=" * 80)
print("SUMMARY")
print("=" * 80)
print(f"  Errors:   {len(errors)}")
print(f"  Warnings: {len(warnings)}")
if errors:
    print("\n  ERRORS:")
    for e in errors:
        print(f"    X {e}")
if warnings:
    print("\n  WARNINGS:")
    for w in warnings[:30]:
        print(f"    ! {w}")
    if len(warnings) > 30:
        print(f"    ... and {len(warnings) - 30} more warnings")
if not errors and not warnings:
    print("  OK - All checks passed!")
