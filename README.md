# AuraMind

Interactive Mental Health App built with Flutter.

## Features

- **Login & Signup** — FastAPI-backed bearer-token authentication
- **12-question mental health check-in** covering Depression, Anxiety, and Stress
- **Smart scoring** — highest category wins if score ≥ 8; otherwise "normal"
- **Dynamic theme selection** — 3 curated palettes per category, or 3 random themes when balanced
- **Live theme switching** — the entire app UI updates when a palette is chosen

## Scoring Logic

Each answer is scored: Never = 0, Almost never = 1, Sometimes = 2, Fairly often = 3, Very often = 4.

| Category   | Questions |
|------------|-----------|
| Depression | 1–4       |
| Anxiety    | 5–8       |
| Stress     | 9–12      |

The category with the highest total score is selected **only if it reaches 8 or above**. Otherwise, the user is considered balanced and gets 3 random themes to choose from.

## Theme Palettes

| Category   | Themes                                      |
|------------|---------------------------------------------|
| Anxiety    | Ocean Calm, Sage Forest, Lavender Air       |
| Depression | Sunrise, Peach Light, Coral Soft            |
| Stress     | Mint Breeze, Aqua, Soft Green               |

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.0+)
- Python 3.12+
- MySQL 8+
- Android Studio or VS Code with Flutter extension

### Run the app

```bash
cd AuraMind
flutter pub get
flutter run
```

### Run the backend with MySQL

AuraMind uses a local MySQL database named `auramind`. After installing MySQL
and creating the `auramind` user, configure the backend credentials:

```bash
cp FastAPI/.env.example FastAPI/.env
```

Open `FastAPI/.env` and replace `MYSQL_PASSWORD` with the password you chose
for the `auramind` MySQL user. The credentials file is ignored by Git.

Install backend dependencies and start the API:

```bash
pip install -r FastAPI/requirements.txt
cd FastAPI
uvicorn app:app --reload --port 8000
```

Alternatively, start MySQL and FastAPI together with Docker Compose:

```bash
docker compose up --build
```

For anything beyond local development, set `MYSQL_ROOT_PASSWORD` and
`MYSQL_PASSWORD` in the shell or a root `.env` file before starting Compose.

## Project Structure

```
lib/
├── main.dart
├── app.dart
├── models/          # Question & theme palette data
├── providers/       # Auth, questionnaire & theme state
├── screens/
│   ├── auth/        # Login & signup
│   ├── checkin/     # Intro, questionnaire, analyzing, theme picker
│   └── home/        # Post check-in home screen
├── utils/           # Scoring logic
└── widgets/         # Reusable UI components
```

## User Flow

1. Sign up or log in
2. See the check-in intro screen
3. Answer 12 MCQ questions (5 answer options each)
4. View the "Analyzing..." transition screen
5. Pick a recommended colour theme
6. Land on the themed home screen



## Module 1 — Longitudinal Mood Analytics

Module 1 provides longitudinal mood analytics and trend tracking based on
timestamped mental-health check-ins.

### Features

- Timestamped mood check-in storage
- Rolling 7-day, 30-day and 90-day analytics
- Interactive mood trend visualization
- Downward mood trajectory detection
- Progressive intervention-tier escalation
- Wellbeing exercise suggestions

### Backend

The analytics endpoint is:

```text
GET /mood/analytics?days=7
GET /mood/analytics?days=30
GET /mood/analytics?days=90
```

The backend stores mood analytics data in MySQL and uses a Python analysis
pipeline to detect sustained downward mood trends.

### Mood Analytics Flow

```text
Mood Check-in
      ↓
MySQL Storage
      ↓
FastAPI /mood/analytics
      ↓
Mood Analytics Python Pipeline
      ↓
Trend Detection
      ↓
Intervention Tier
      ↓
Flutter Mood Analytics Screen
```

## Module 1 — Zero-Knowledge Anonymous Community Forum

AuraMind includes a privacy-first peer-support forum where authenticated users
can participate without exposing their real identity in the public feed.

### Features
- Pseudonymous public identities generated from private user IDs
- Public responses never expose name, email, phone number or user ID
- Email and phone patterns are scrubbed before public display
- Anonymous post creation and chronological community feed
- User-driven reporting with duplicate-report prevention
- Flutter screen integrated with the AuraMind home screen
- FastAPI + MySQL persistence using the existing authenticated API

### Backend endpoints
```text
GET  /community/posts
POST /community/posts
POST /community/posts/{post_id}/report
```

Scope note: Module 1 records reports only. Automatic quarantine/hiding and the
later AI moderation engine remain outside this module.

## Module 2 — Audio-Guided Progressive Muscle Relaxation

AuraMind includes a guided stress-relief exercise that walks the user through
gentle tense-and-release cycles from the face down to the feet.

### Features
- Audio guidance using device text-to-speech
- Head-to-toe muscle group sequence
- Play/pause, previous and next controls
- Session progress and elapsed time
- Step-by-step written guidance alongside voice instructions
- Safety reminder to stop if pain or unusual discomfort occurs
- Direct access from the AuraMind home screen
### Module 1 Community Interaction Enhancement
- Anonymous comments on community posts
- Comment counts on each post
- Pseudonymous commenter identities
- Email and phone-number scrubbing in comments
- Comment reporting for moderation review

## Mood Momentum Walk

The **Mood Momentum Walk** is a 5–10 minute interactive physical movement feature designed to help users break periods of low activity and depressive lethargy through short, guided walking sessions.

### Features

- 5-minute and 10-minute walking sessions
- Countdown timer for the selected session duration
- Real-time step tracking using the device's native activity/step-counting capabilities
- Dynamic progress ring based on the user's walking progress
- Pause and resume functionality
- Step goal tracking
- Grounding voice guidance using text-to-speech
- Session completion feedback
- Integration with the main AuraMind home screen

### Workflow

```text
User opens AuraMind Home
        ↓
Selects "Mood Momentum Walk"
        ↓
Chooses session duration
   ┌───────────────┐
   │  5 minutes    │
   │      OR       │
   │  10 minutes   │
   └───────────────┘
        ↓
Grants activity recognition permission
        ↓
Walking session starts
        ↓
Native step counter tracks movement
        ↓
Steps are calculated relative to the
session starting baseline
        ↓
Progress ring updates in real time
        ↓
Grounding voice guidance provides
sensory grounding instructions
        ↓
User can Pause / Resume the session
        ↓
Timer reaches zero
        ↓
Session completion feedback
```

## Behavioral Activation Planner

Behavioral Activation offers one small, optional wellbeing action per day. It
is designed as a low-pressure support tool, not a diagnostic or treatment
feature. Users can always skip an action; task completion and recorded mood
ratings are shown only as descriptive patterns, never as proof of causation.

### Flutter integration

- Home dashboard card: **Today's Tiny Step**
- Main screen: `lib/screens/behavioral_activation/behavioral_activation_screen.dart`
- History screen: `lib/screens/behavioral_activation/behavioral_activation_history_screen.dart`
- State: the existing Provider architecture through `BehavioralActivationProvider`
- Auth: the existing shared bearer-token `ApiService`; planner state clears when
  a different user logs in.

### Central MySQL migration

Run this once against the existing `auramind` MySQL database before deploying
the backend:

```bash
mysql -u auramind -p auramind < database/behavioral_activation_migration.sql
```

It adds `behavioral_activities` and `behavioral_daily_tasks`, including the
unique `(user_id, task_date)` constraint, lookup indexes, valid status/mood
checks, and low-friction seed activities. `database/auramind.sql` also
contains the new tables for a fresh database import. The FastAPI startup check
creates missing planner tables and indexes as an additional compatibility
safeguard; it does not replace running the migration in production.

### API endpoints

All planner endpoints require the existing `Authorization: Bearer <token>`
header and only return the current user's data. Flutter also sends
`X-Timezone-Offset-Minutes`, allowing the backend to assign one task for the
user's local calendar day instead of the server's day.

```text
GET  /behavioral-activation/today
POST /behavioral-activation/tasks/{task_id}/complete
POST /behavioral-activation/tasks/{task_id}/skip
POST /behavioral-activation/tasks/{task_id}/change
POST /behavioral-activation/tasks/{task_id}/mood
GET  /behavioral-activation/history?days=30&limit=30
GET  /behavioral-activation/stats?days=7
```

`POST /behavioral-activation/tasks/{task_id}/mood` accepts optional
`mood_before` and `mood_after` values from 1 through 5. After-action ratings
are only accepted for a completed task. The mood analytics response now also
contains an optional `behavioral_summary` describing recorded same-day
co-occurrence of mood check-ins and completed activities. The existing
`GET /sleep/correlation` response includes optional `behavioral_status` and
`behavioral_activity_title` fields for the same descriptive purpose. Neither
view presents those records as evidence of cause or treatment effect.

`Change Activity` updates the existing pending daily row in place. Complete,
skip, change, and mood routes enforce ownership and valid state transitions;
repeating a completed request remains idempotent.

### Configuration and assumptions

- No new application environment variables are required. The backend continues
  `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, and
  `MYSQL_DATABASE` from `FastAPI/.env`. Docker Compose accepts optional
  `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` overrides for its containers.
- The existing auth, Provider state management, theme, mood-check-in, sleep,
  and navigation architectures are reused.
- The optional 1–5 post-activity feeling is stored on the daily task because
  the existing questionnaire mood score uses a different 0–10 model.
- AuraMind currently has no reusable notification/reminder infrastructure, so
  this implementation intentionally does not add a second notification system.
- The SQL migration must be applied to the deployment MySQL database; tests use
  isolated SQLite-compatible fixtures and do not mutate production data.

### Run and test

```bash
cp FastAPI/.env.example FastAPI/.env
# Set MYSQL_PASSWORD in FastAPI/.env, then apply the migration above.
pip install -r FastAPI/requirements.txt pytest httpx
cd FastAPI
uvicorn app:app --reload --port 8000
```

From the repository root, run the backend tests with:

```bash
pytest FastAPI/test_behavioral_activation.py -q
```

Run the Flutter application and its tests with:

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

## Savoring Logs — Three Good Things

The optimism module offers a private, low-pressure daily reflection. Users can
swipe through three cards, record one specific positive or meaningful moment
on each card, and note what helped it happen. The copy intentionally presents
this as a reflection practice rather than promising a neurological or clinical
outcome.

### Behavior and privacy

- One log is created per authenticated user and local calendar day.
- A draft can be saved with unfinished cards and continued later.
- Finishing requires a positive event and an explanation on all three cards.
- Completed logs are read-only and appear in the private history screen.
- Every read and write is scoped to the bearer-token user.
- State clears when the authenticated account changes.
- The feature does not use scores, streaks, diagnoses, or treatment claims.

### Central MySQL migration

Apply the migration once to an existing deployment database:

```bash
mysql -u auramind -p auramind < database/savoring_logs_migration.sql
```

This creates `savoring_logs` and `savoring_entries`, including a unique
`(user_id, log_date)` constraint, three-slot ordering checks, and history
indexes. Fresh installations receive the same schema from
`database/auramind.sql`; the FastAPI startup schema check also creates missing
tables and indexes for development compatibility.

### API endpoints

All endpoints require `Authorization: Bearer <token>`. The today and filtered
history routes use Flutter's `X-Timezone-Offset-Minutes` header.

```text
GET  /savoring/today
PUT  /savoring/logs/{log_id}
POST /savoring/logs/{log_id}/complete
GET  /savoring/history?days=30&limit=30
```

Run the focused regression tests with:

```bash
pytest FastAPI/test_savoring_logs.py -q
flutter test test/savoring_test.dart
```

