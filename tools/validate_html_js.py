#!/usr/bin/env python3
"""
Post-edit validator for index.html.
Three-tier validation:
  1. Fast structural check (delimiter balance per function, raw counts)
  2. HR reference integrity (window exports, showPage calls, HTML elements)
  3. Per-line-range deep check (optional)

Exit code 0 = PASS, 1 = FAIL.
Always run after editing index.html.
"""

import re
import sys
import os

FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "frontend", "index.html"
)


def load():
    fp = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.abspath(FILE)
    if len(sys.argv) <= 1 and not os.path.exists(fp):
        # legacy entry was retired; the live SPA shell is frontend/web/index.html
        fp = os.path.join(os.path.dirname(fp), "web", "index.html")
    with open(fp, "r", encoding="utf-8") as f:
        return f.read(), fp


# ── Tier 1: Structural checks ──────────────────────────────────────────────


def raw_delimiter_counts(html):
    """Count raw delimiters (unreliable for deep analysis, good for quick sanity)."""
    return {
        "braces": (html.count("{"), html.count("}")),
        "parens": (html.count("("), html.count(")")),
        "brackets": (html.count("["), html.count("]")),
    }


def extract_scripts(html):
    scripts = []
    # Use iterative approach to find script boundaries, skipping </script>
    # that appears inside JS string literals (strings containing '<script>...</script>').
    for m in re.finditer(r"<script\b([^>]*)>", html, re.IGNORECASE):
        attrs = m.group(1)
        start = m.end()
        rest = html[start:]
        body_end = -1
        for em in re.finditer(r"</script>", rest, re.IGNORECASE | re.DOTALL):
            pre = rest[: em.start()]
            # Strip escaped quotes before counting to avoid bias from \' and \"
            clean = pre.replace("\\'", "__ESC__").replace('\\"', "__ESC__")
            if clean.count("'") % 2 == 0 and clean.count('"') % 2 == 0:
                body_end = em.start()
                break
        if body_end < 0:
            continue
        body = rest[:body_end]
        start_line = html[: m.start()].count("\n") + 1
        if (
            "application/json" in attrs
            or not body.strip()
            or "self.__next" in body[:500]
        ):
            continue
        scripts.append({"attrs": attrs, "body": body, "start": start_line})
    return scripts


def function_scope_balance(html):
    """
    For each 'function NAME(' or 'window.NAME = function', check brace balance
    of the function body. Uses simple brace counting (not literal-aware) but
    filters out obvious false positives (words that look like 'function NAME'
    but are inside strings).
    """
    scripts = extract_scripts(html)
    issues = []

    for s in scripts:
        body = s["body"]
        s_start = s["start"]
        lines = body.split("\n")

        func_re = re.compile(r"(?:function\s+(\w+)|(\w+)\s*=\s*(?:async\s+)?function)")
        for i, line in enumerate(lines):
            for m in func_re.finditer(line):
                fname = m.group(1) or m.group(2)
                real_line = s_start + i

                # Skip false positives: if the "function" keyword is inside a string
                prefix = line[: m.start()]
                if prefix.count("'") % 2 != 0 or prefix.count('"') % 2 != 0:
                    continue  # likely inside a string literal

                depth = 0
                started = False
                for j in range(i, min(i + 2000, len(lines))):
                    for ch in lines[j]:
                        if ch == "{":
                            depth += 1
                            started = True
                        elif ch == "}":
                            depth -= 1
                    if started and depth == 0:
                        break
                    if started and depth < 0:
                        issues.append(
                            f"Extra '}}' in function '{fname}' near line {s_start + j}"
                        )
                        break

                if started and depth != 0:
                    issues.append(
                        f"Function '{fname}' at line {real_line}: unmatched braces (depth={depth})"
                    )
    return issues


# ── Tier 2: HR reference integrity ─────────────────────────────────────────


def check_hr_integrity(html):
    """Check HR reference integrity — only if HR workspace exists."""
    issues = []

    # If HR workspace was intentionally removed, skip these checks
    has_hr_workspace = (
        "page-hr-workspace" in html or "hrWsNav" in html or "renderHRDashboard" in html
    )
    if not has_hr_workspace:
        return []  # HR workspace not present — nothing to check

    # 1. All renderHR* / hrWsNav calls in showPage or launchWorkspace must have window.* exports
    # Check both showPage and launchWorkspace for HR references
    for func_name in ["showPage", "launchWorkspace"]:
        func_match = re.search(rf"function {func_name}\s*\(", html)
        if func_match:
            sp_start = func_match.start()
            sp_body = html[sp_start : sp_start + 30000]
            hr_calls = set(
                re.findall(
                    r"\b(hrWsNav|hrNav|renderHR\w+|hrFilter\w+|hrModal\w+|hrWs\w+)\s*\(",
                    sp_body,
                )
            )
            # Also check for HR function calls via string matching
            hr_calls.update(
                re.findall(
                    r"'(hr-dashboard|hr-recruitment|hr-records|hr-attendance|hr-training|hr-payroll|hr-performance)'",
                    sp_body,
                )
            )

            window_exports = set(
                re.findall(r"window\.(hr\w+|renderHR\w+)\s*=\s*(\w+)", html)
            )
            export_names = {name for name, _ in window_exports}

            for call in hr_calls:
                if call not in export_names and not call.startswith("hr-"):
                    issues.append(
                        f"{func_name} calls '{call}' but no window.{call} export found"
                    )

    # 2. All window.* HR exports must reference defined functions
    window_exports = set(re.findall(r"window\.(hr\w+|renderHR\w+)\s*=\s*(\w+)", html))
    for export_name, func_name in window_exports:
        if func_name == "function":
            # Pattern: window.X = function() {} — check that the assignment exists
            if not re.search(rf"window\.{re.escape(export_name)}\s*=\s*function", html):
                issues.append(
                    f"window.{export_name} = function but no function expression found"
                )
        else:
            pattern = re.compile(
                rf"(?:function\s+{re.escape(func_name)}\s*\(|{re.escape(func_name)}\s*=\s*(?:async\s+)?function)"
            )
            if not pattern.search(html):
                issues.append(
                    f"window.{export_name} = {func_name} but '{func_name}' not defined as function"
                )

    # 3. Check that page-hr-workspace div exists (new pattern) or page-hr-dashboard (old pattern)
    if "page-hr-workspace" not in html and "page-hr-dashboard" not in html:
        issues.append("Missing HR workspace HTML container")

    # 4. Check PAGE_WORKSPACES has hr-dashboard (or hr-workspace routing)
    if (
        "'hr-dashboard'" not in html
        and '"hr-dashboard"' not in html
        and "'hr'" not in html
    ):
        issues.append("hr workspace not in PAGE_WORKSPACES or routing")

    # 5. Check that hr-ws class exists in CSS
    if ".hr-ws" not in html:
        issues.append("Missing .hr-ws CSS styles")

    return issues


# ── Tier 3: Quick syntax spot-check ────────────────────────────────────────


def spot_check_inline_handlers(html):
    """Check for broken inline onclick handlers in HTML."""
    issues = []
    # Find onclick="..." with unbalanced quotes
    for m in re.finditer(r'onclick="([^"]*)"', html):
        handler = m.group(1)
        # Count unescaped single quotes (should be even for balanced JS)
        sq = handler.count("'") - handler.count("\\'")
        if sq % 2 != 0:
            line = html[: m.start()].count("\n") + 1
            issues.append(
                f"Unbalanced quotes in onclick at line ~{line}: {handler[:80]}"
            )
    return issues


def check_duplicate_var_declarations(html):
    """Check for duplicate var declarations in same scope that cause issues."""
    issues = []
    # Check for 'var _HR_STAFF' inside IIFE when 'window._HR_STAFF' exists outside
    iife_start = html.find("(function(){")
    iife_end = html.find("})();", iife_start) if iife_start >= 0 else -1
    if iife_start >= 0 and iife_end >= 0:
        iife_body = html[iife_start:iife_end]
        if "var _HR_STAFF" in iife_body and "window._HR_STAFF" in html[:iife_start]:
            issues.append(
                "Potential scope conflict: 'var _HR_STAFF' in IIFE shadows 'window._HR_STAFF'"
            )
    return issues


# ── Main ────────────────────────────────────────────────────────────────────


def main():
    html, fp = load()
    total = html.count("\n") + 1
    print(f"Validating: {fp} ({total} lines)")
    print("=" * 60)

    all_ok = True

    # Tier 1: Structural
    print("\n[Tier 1] Structural checks...")
    counts = raw_delimiter_counts(html)
    for name, (o, c) in counts.items():
        status = (
            "OK"
            if o == c
            else f"MISMATCH ({o} vs {c}) [raw count - may include delimiters inside strings]"
        )
        print(f"  {name}: {status}")
        # Raw mismatches are informational only (strings contain delimiters)

    func_issues = function_scope_balance(html)
    if func_issues:
        print(f"\n  Function scope issues ({len(func_issues)}):")
        for issue in func_issues[:20]:
            print(f"    {issue}")
        if len(func_issues) > 20:
            print(f"    ... and {len(func_issues)-20} more")
        all_ok = False
    else:
        print("  Function scope balance: OK")

    # Tier 2: HR integrity
    print("\n[Tier 2] HR reference integrity...")
    hr_issues = check_hr_integrity(html)
    if hr_issues:
        for issue in hr_issues:
            print(f"  ISSUE: {issue}")
        all_ok = False
    else:
        print("  All HR references OK")

    # Tier 3: Spot checks (informational, non-fatal)
    print("\n[Tier 3] Spot checks...")
    spot_issues = spot_check_inline_handlers(html)
    var_issues = check_duplicate_var_declarations(html)
    all_spot = spot_issues + var_issues
    if all_spot:
        for issue in all_spot:
            print(f"  INFO: {issue}")
    else:
        print("  Spot checks OK")

    # Summary
    print("\n" + "=" * 60)
    if all_ok:
        print("RESULT: PASS")
    else:
        print("RESULT: FAIL — issues found above")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
