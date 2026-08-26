# AuraMind

Interactive Mental Health App built with Flutter.

## Features

- **Login & Signup** — local in-memory auth (no backend required)
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

The backend stores mood analytics data in MySQL and uses a Python analysis
pipeline to detect sustained downward mood trends.

### Mood Analytics Flow

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

<<<<<<< Updated upstream
=======
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
>>>>>>> Stashed changes
