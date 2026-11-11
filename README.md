# Aminiology EduTech

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

> Always use the `.venv` interpreter â€” a bare `python` will not have the dependencies
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
â”œâ”€â”€ backend/
â”‚   â”œâ”€â”€ app/
â”‚   â”‚   â”œâ”€â”€ auth/          # Registration, login, tokens
â”‚   â”‚   â”œâ”€â”€ users/         # User profiles
â”‚   â”‚   â”œâ”€â”€ courses/       # Course management, enrollment, schedule
â”‚   â”‚   â”œâ”€â”€ ai_tutor/      # ScholarAI engine (tutor, coach, writer, research, assessment)
â”‚   â”‚   â”œâ”€â”€ assessments/   # Assessments, questions, submissions, marking
â”‚   â”‚   â”œâ”€â”€ research/      # Research projects, notes, literature search
â”‚   â”‚   â”œâ”€â”€ knowledge_vault/ # Document upload and search
â”‚   â”‚   â”œâ”€â”€ notifications/ # Notification system
â”‚   â”‚   â”œâ”€â”€ admin/         # Admin dashboard
â”‚   â”‚   â”œâ”€â”€ messaging/     # Messaging
â”‚   â”‚   â”œâ”€â”€ core/          # Security, errors
â”‚   â”‚   â”œâ”€â”€ config/        # Settings
â”‚   â”‚   â”œâ”€â”€ database/      # SQLAlchemy engine
â”‚   â”‚   â”œâ”€â”€ dependencies/  # Auth dependencies
â”‚   â”‚   â”œâ”€â”€ models/        # ORM models
â”‚   â”‚   â””â”€â”€ schemas/       # Pydantic schemas
â”‚   â””â”€â”€ tests/
â”œâ”€â”€ frontend/
â”‚   â”œâ”€â”€ lib/
â”‚   â”‚   â”œâ”€â”€ core/theme/    # Design system
â”‚   â”‚   â”œâ”€â”€ config/        # App config
â”‚   â”‚   â”œâ”€â”€ models/        # Data models
â”‚   â”‚   â”œâ”€â”€ services/      # API services
â”‚   â”‚   â”œâ”€â”€ providers/     # State management
â”‚   â”‚   â”œâ”€â”€ widgets/       # Reusable components
â”‚   â”‚   â”œâ”€â”€ screens/
â”‚   â”‚   â”‚   â”œâ”€â”€ auth/      # Login, Register
â”‚   â”‚   â”‚   â”œâ”€â”€ student/   # Student Hub
â”‚   â”‚   â”‚   â”œâ”€â”€ lecturer/  # Lecturer Command Centre
â”‚   â”‚   â”‚   â”œâ”€â”€ ai_tutor/  # ScholarAI interface
â”‚   â”‚   â”‚   â”œâ”€â”€ research/  # Research Lab
â”‚   â”‚   â”‚   â””â”€â”€ home/      # Shell/navigation
â”‚   â”‚   â””â”€â”€ router/        # GoRouter routing
â”‚   â””â”€â”€ web/
â””â”€â”€ docs/
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
