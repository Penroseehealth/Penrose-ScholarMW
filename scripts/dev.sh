#!/usr/bin/env bash
set -euo pipefail

echo "=== Penrose ScholarMW — Development Setup ==="

# Check Python
if ! command -v python &>/dev/null; then
    echo "Error: Python not found. Install Python 3.12+"
    exit 1
fi

# Backend setup
echo ""
echo "--- Backend Setup ---"
cd backend
python -m pip install -r requirements.txt -q

if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env from .env.example"
fi

echo "Running migrations..."
python -m alembic upgrade head 2>/dev/null || echo "Migration skipped (no DB running)"

echo "Starting backend on :8000..."
python run.py &
BACKEND_PID=$!

echo ""
echo "=== Backend running at http://localhost:8000 ==="
echo "=== API docs at http://localhost:8000/docs ==="
echo ""
echo "Press Ctrl+C to stop"

trap "kill $BACKEND_PID 2>/dev/null; exit" INT TERM
wait
