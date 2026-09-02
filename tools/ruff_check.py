#!/usr/bin/env python3
"""Pre-commit hook: run ruff check + format on staged Python files.
Exit 0 = clean, exit 1 = issues found.
"""

import shutil
import subprocess
import sys


def find_ruff():
    ruff = shutil.which("ruff")
    if ruff:
        return ruff
    # try python -m ruff
    return None


def main():
    files = [f for f in sys.argv[1:] if f.endswith(".py")]
    if not files:
        return 0

    ruff = find_ruff()
    if not ruff:
        # fallback to python -m ruff
        ruff_cmd = [sys.executable, "-m", "ruff"]
    else:
        ruff_cmd = [ruff]

    # Step 1: ruff check --fix
    check_args = ruff_cmd + ["check", "--fix", "--line-length", "120"] + files
    result = subprocess.run(check_args, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)

    # Step 2: ruff format
    fmt_args = ruff_cmd + ["format", "--line-length", "120"] + files
    result2 = subprocess.run(fmt_args, capture_output=True, text=True)
    if result2.stdout:
        print(result2.stdout)
    if result2.stderr:
        print(result2.stderr, file=sys.stderr)

    # Check if check failed
    check_result = subprocess.run(ruff_cmd + ["check", "--line-length", "120"] + files, capture_output=True, text=True)
    if check_result.returncode != 0:
        print("\nRUFF CHECK FAILED — fix issues before committing", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
