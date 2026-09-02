#!/usr/bin/env python3
"""Pre-commit hook: run dart format on staged .dart files.
Usage: python tools/dart_format.py [--check] [file1.dart file2.dart ...]
Exit 0 = all formatted, exit 1 = formatting needed (or errors).
"""

import os
import shutil
import subprocess
import sys


def find_dart():
    """Find dart executable."""
    dart = shutil.which("dart")
    if dart:
        return dart
    flutter = shutil.which("flutter")
    if flutter:
        return flutter
    # Windows fallback
    for candidate in [
        r"C:\flutter\flutter\bin\dart.bat",
        r"C:\flutter\flutter\bin\dart",
    ]:
        if os.path.isfile(candidate):
            return candidate
    return None


def main():
    check_only = "--check" in sys.argv
    files = [f for f in sys.argv[1:] if f.endswith(".dart")]
    if not files:
        return 0

    dart = find_dart()
    if not dart:
        print("ERROR: dart executable not found on PATH", file=sys.stderr)
        return 1

    args = [dart, "format", "--line-length=120"]
    if check_only:
        args.append("--output=none")
        args.append("--set-exit-if-changed")

    args.extend(files)
    result = subprocess.run(args, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
