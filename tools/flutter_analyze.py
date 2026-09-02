#!/usr/bin/env python3
"""Pre-commit hook: run flutter analyze on staged .dart files.
Exit 0 = no issues, exit 1 = issues found.
"""

import os
import shutil
import subprocess
import sys


def find_flutter():
    flutter = shutil.which("flutter")
    if flutter:
        return flutter
    for candidate in [
        r"C:\flutter\flutter\bin\flutter.bat",
        r"C:\flutter\flutter\bin\flutter",
    ]:
        if os.path.isfile(candidate):
            return candidate
    return None


def main():
    flutter = find_flutter()
    if not flutter:
        print("ERROR: flutter executable not found on PATH", file=sys.stderr)
        return 1

    frontend_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "frontend"
    )
    if not os.path.isdir(frontend_dir):
        print(f"ERROR: frontend dir not found: {frontend_dir}", file=sys.stderr)
        return 1

    args = [flutter, "analyze", "--no-fatal-infos", "--no-fatal-warnings"]
    result = subprocess.run(args, capture_output=True, text=True, cwd=frontend_dir)
    print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)

    # flutter analyze exits 1 if there are issues
    if result.returncode != 0:
        print("\nFIX ALL ANALYZE ERRORS BEFORE COMMITTING", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())