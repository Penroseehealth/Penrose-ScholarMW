# Penrose ScholarMW

**AI-Powered Academic Intelligence & Learning Platform for Malawi**

> Learn. Teach. Research. Advance.

## Architecture

- **Frontend:** Flutter/Dart (cross-platform: Android, iOS, Web, Desktop)
- **Backend:** Python FastAPI
- **Database:** PostgreSQL (SQLite for local dev)
- **AI Engine:** OpenAI + LangChain + ChromaDB (RAG)
- **Offline:** SQLite sync engine

## Modules

| Module | Description |
|--------|-------------|
| Student Intelligence Hub | Personalized dashboard with courses, progress, schedule |
| ScholarAI Tutor | AI tutoring with chat, voice, study coaching |
| Lecturer Command Centre | Course management, AI lesson builder, assessment studio |
| Research Intelligence Lab | Literature search, evidence extraction, systematic reviews |
| Academic Knowledge Vault | Centralized document storage with RAG indexing |
| Smart Marking Assistant | AI-assisted grading with lecturer override |

## Quick Start

### Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
copy .env.example .env
.venv\Scripts\python run.py
```

> Always use the `.venv` interpreter — a bare `python` will not have the dependencies
> installed. The backend serves the compiled Flutter SPA from `frontend/build/web`, so run
> `flutter build web --release` in `frontend/` at least once (the server will not start
> without `frontend/build/web/main.dart.js`).

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

## Project Structure

```
penrose-scholar/
├── backend/
│   ├── app/
│   │   ├── auth/          # Registration, login, tokens
│   │   ├── users/         # User profiles
│   │   ├── courses/       # Course management, enrollment, schedule
│   │   ├── ai_tutor/      # ScholarAI engine (tutor, coach, writer, research, assessment)
│   │   ├── assessments/   # Assessments, questions, submissions, marking
│   │   ├── research/      # Research projects, notes, literature search
│   │   ├── knowledge_vault/ # Document upload and search
│   │   ├── notifications/ # Notification system
│   │   ├── admin/         # Admin dashboard
│   │   ├── messaging/     # Messaging
│   │   ├── core/          # Security, errors
│   │   ├── config/        # Settings
│   │   ├── database/      # SQLAlchemy engine
│   │   ├── dependencies/  # Auth dependencies
│   │   ├── models/        # ORM models
│   │   └── schemas/       # Pydantic schemas
│   └── tests/
├── frontend/
│   ├── lib/
│   │   ├── core/theme/    # Design system
│   │   ├── config/        # App config
│   │   ├── models/        # Data models
│   │   ├── services/      # API services
│   │   ├── providers/     # State management
│   │   ├── widgets/       # Reusable components
│   │   ├── screens/
│   │   │   ├── auth/      # Login, Register
│   │   │   ├── student/   # Student Hub
│   │   │   ├── lecturer/  # Lecturer Command Centre
│   │   │   ├── ai_tutor/  # ScholarAI interface
│   │   │   ├── research/  # Research Lab
│   │   │   └── home/      # Shell/navigation
│   │   └── router/        # GoRouter routing
│   └── web/
└── docs/
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/auth/register` | POST | Register new user |
| `/api/v1/auth/login` | POST | Login |
| `/api/v1/auth/me` | GET | Get current user |
| `/api/v1/courses/` | GET/POST | List/create courses |
| `/api/v1/courses/{id}/enroll` | POST | Enroll in course |
| `/api/v1/ai/chat` | POST | Chat with ScholarAI |
| `/api/v1/ai/lesson-plan` | POST | Generate lesson plan |
| `/api/v1/ai/generate-assessment` | POST | Generate assessment |
| `/api/v1/ai/study-plan` | POST | Generate study plan |
| `/api/v1/assessments/` | GET/POST | List/create assessments |
| `/api/v1/assessments/submit` | POST | Submit answers |
| `/api/v1/research/projects` | GET/POST | Research projects |
| `/api/v1/research/literature-search` | POST | Search papers |
| `/api/v1/vault/` | GET | Knowledge vault documents |
| `/api/v1/notifications/` | GET | Notifications |
| `/api/v1/admin/dashboard` | GET | Admin stats |

## Tech Stack

- **Flutter 3.x** + Dart
- **FastAPI** + SQLAlchemy 2.0 + Alembic
- **PostgreSQL** / SQLite
- **OpenAI GPT-4o** via LangChain
- **ChromaDB** for vector search (RAG)
- **JWT** authentication with refresh tokens
- **OpenAlex API** for literature search
