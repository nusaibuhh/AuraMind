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

The backend stores mood analytics data in SQLite and uses a Python analysis
pipeline to detect sustained downward mood trends.

### Mood Analytics Flow

Mood Check-in
      ↓
SQLite Storage
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
- FastAPI + SQLite persistence using the existing authenticated API

### Backend endpoints
```text
GET  /community/posts
POST /community/posts
POST /community/posts/{post_id}/report
```

Scope note: Module 1 records reports only. Automatic quarantine/hiding and the
later AI moderation engine remain outside this module.
