#!/usr/bin/env bash
set -euo pipefail

echo "=== Penrose ScholarMW — Run Tests ==="

cd backend
echo "--- Backend Tests ---"
python -m pytest tests/ -v --tb=short

echo ""
echo "--- Lint Check ---"
python -m ruff check app tests
python -m ruff format --check app tests

echo ""
echo "=== All tests passed ==="
