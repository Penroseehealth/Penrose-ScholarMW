#!/usr/bin/env bash
set -euo pipefail

echo "=== Penrose ScholarMW — Flutter Dev ==="

cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
