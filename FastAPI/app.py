"""AuraMind backend (FastAPI)

This file implements a small backend compatible with the Flutter frontend
in this workspace. It provides simple signup/login token auth, a `/checkin`
endpoint that returns multiple mental-health category scores and recommended
theme palettes, plus theme selection endpoints.

Run during development:
    pip install fastapi uvicorn
    uvicorn app:app --reload --port 8000

The Flutter app expects `http://localhost:8000` (or `10.0.2.2:8000` on Android
emulator) by default.
"""

import json
import hashlib
import re
import sqlite3
import uuid
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Dict, Optional

from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, model_validator
import pymysql
from pymysql.err import IntegrityError
from dotenv import load_dotenv

app = FastAPI(title="AuraMind API")
load_dotenv(Path(__file__).resolve().parent / ".env")

MYSQL_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "user": os.getenv("MYSQL_USER", "auramind"),
    "password": os.getenv("MYSQL_PASSWORD", ""),
    "database": os.getenv("MYSQL_DATABASE", "auramind"),
    "charset": "utf8mb4",
}

# Allow CORS for development (adjust in production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =====================================================================
# DATABASE SETUP
# =====================================================================
class DatabaseCursor:
    """Keep the existing SQLite-style queries compatible with MySQL."""

    def __init__(self, cursor):
        self._cursor = cursor

    def execute(self, query, params=None):
        query = query.replace("?", "%s")
        if params is None:
            return self._cursor.execute(query)
        return self._cursor.execute(query, params)

    def fetchone(self):
        return self._cursor.fetchone()

    def fetchall(self):
        return self._cursor.fetchall()

    @property
    def rowcount(self):
        return self._cursor.rowcount


class DatabaseConnection:
    def __init__(self, connection):
        self._connection = connection

    def cursor(self):
        return DatabaseCursor(self._connection.cursor())

    def commit(self):
        return self._connection.commit()

    def rollback(self):
        return self._connection.rollback()

    def close(self):
        return self._connection.close()


def connect_db_connection():
    """Open a MySQL connection for a single request."""
    return DatabaseConnection(pymysql.connect(**MYSQL_CONFIG))


def _ensure_column(cursor, table: str, column: str, column_type: str):
    """Add a column to an existing MySQL table without losing data."""
    cursor.execute(
        """SELECT COLUMN_NAME FROM information_schema.columns
           WHERE table_schema = DATABASE() AND LOWER(table_name) = %s""",
        (table.lower(),),
    )
    columns = {row[0] for row in cursor.fetchall()}
    if column not in columns:
        cursor.execute(
            f"ALTER TABLE {table} ADD COLUMN {column} {column_type}"
        )


def _ensure_index(cursor, table: str, index_name: str, columns: str):
    """Create a named index once, without altering existing data."""
    cursor.execute(
        """SELECT INDEX_NAME FROM information_schema.statistics
           WHERE table_schema = DATABASE() AND LOWER(table_name) = %s""",
        (table.lower(),),
    )
    existing = {row[0] for row in cursor.fetchall()}
    if index_name not in existing:
        cursor.execute(f"CREATE INDEX {index_name} ON {table} ({columns})")

def connect_db():
    conn = connect_db_connection()
    c = conn.cursor()
    # Users for simple auth
    c.execute("""CREATE TABLE IF NOT EXISTS USERS (
        id VARCHAR(64) PRIMARY KEY,
        name TEXT,
        email VARCHAR(255) UNIQUE,
        password TEXT,
        token TEXT
    )""")

    # Store raw check-ins and the normalized wellbeing score used by the
    # longitudinal mood analytics feature.  The migration below keeps older
    # team databases compatible by adding the new columns when needed.
    c.execute("""CREATE TABLE IF NOT EXISTS MOOD_CHECKINS (
        id VARCHAR(64) PRIMARY KEY,
        user_id TEXT,
        answers TEXT,
        created_at TEXT
    )""")

    _ensure_column(c, "MOOD_CHECKINS", "mood_score", "REAL")
    _ensure_column(c, "MOOD_CHECKINS", "dominant_category", "TEXT")

    # Theme palettes (detailed schema expected by frontend)
    c.execute("""CREATE TABLE IF NOT EXISTS THEME_PALETTES (
        id VARCHAR(64) PRIMARY KEY,
        name TEXT,
        category TEXT,
        primary_color TEXT,
        secondary_color TEXT,
        accent_color TEXT,
        background_color TEXT,
        surface_color TEXT,
        on_primary TEXT,
        on_background TEXT,
        thumbnail_gradient TEXT
    )""")

    # User selected theme
    c.execute("""CREATE TABLE IF NOT EXISTS USER_THEME (
        user_id VARCHAR(64) PRIMARY KEY,
        palette_id TEXT,
        selected_at TEXT
    )""")

    # --- Feature 2 tables ---
    c.execute("""CREATE TABLE IF NOT EXISTS GROUNDING_SESSIONS (
        id VARCHAR(64) PRIMARY KEY,
        user_id TEXT,
        created_at TEXT,
        completed INTEGER DEFAULT 0
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS GROUNDING_ENTRIES (
        id VARCHAR(64) PRIMARY KEY,
        session_id TEXT,
        category TEXT,
        item_text TEXT
    )""")

    # Sleep Tracking tables
    c.execute("""CREATE TABLE IF NOT EXISTS SLEEP_LOGS (
        id VARCHAR(64) PRIMARY KEY,
        user_id TEXT,
        date TEXT,
        sleep_hours INTEGER,
        sleep_minutes INTEGER,
        quality INTEGER,
        post_wake_feeling INTEGER,
        notes TEXT,
        created_at TEXT
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS WELLBEING_WARNINGS (
        id VARCHAR(64) PRIMARY KEY,
        user_id TEXT,
        title TEXT,
        message TEXT,
        created_at TEXT,
        is_dismissed INTEGER DEFAULT 0
    )""")

    # Breathing Exercise Sessions
    c.execute("""CREATE TABLE IF NOT EXISTS BREATHING_SESSIONS (
        id VARCHAR(64) PRIMARY KEY,
        user_id TEXT,
        technique TEXT,
        duration_seconds INTEGER,
        cycles_completed INTEGER,
        background_sound TEXT,
        mood_after TEXT,
        created_at TEXT
    )""")

    # Module 1: Zero-Knowledge Anonymous Community Forum
    c.execute("""CREATE TABLE IF NOT EXISTS COMMUNITY_POSTS (
        id VARCHAR(64) PRIMARY KEY,
        user_id TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_hidden INTEGER DEFAULT 0
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS COMMUNITY_REPORTS (
        id VARCHAR(64) PRIMARY KEY,
        post_id TEXT NOT NULL,
        reporter_user_id TEXT NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS COMMUNITY_COMMENTS (
        id VARCHAR(64) PRIMARY KEY,
        post_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_hidden INTEGER DEFAULT 0
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS COMMUNITY_COMMENT_REPORTS (
        id VARCHAR(64) PRIMARY KEY,
        comment_id TEXT NOT NULL,
        reporter_user_id TEXT NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL
    )""")

    # --- Behavioral Activation Planner tables ---
    c.execute("""CREATE TABLE IF NOT EXISTS BEHAVIORAL_ACTIVITIES (
        id VARCHAR(64) PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category VARCHAR(64) NOT NULL,
        difficulty VARCHAR(32) NOT NULL DEFAULT 'tiny',
        duration_minutes INTEGER NOT NULL DEFAULT 5,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        CONSTRAINT behavioral_activities_difficulty_check
            CHECK (difficulty IN ('tiny', 'easy', 'moderate')),
        CONSTRAINT behavioral_activities_duration_check
            CHECK (duration_minutes > 0)
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS BEHAVIORAL_DAILY_TASKS (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) NOT NULL,
        activity_id VARCHAR(64) NOT NULL,
        task_date VARCHAR(32) NOT NULL,
        status VARCHAR(32) NOT NULL DEFAULT 'pending',
        completed_at TEXT,
        mood_before INTEGER,
        mood_after INTEGER,
        created_at TEXT NOT NULL,
        UNIQUE KEY behavioral_daily_tasks_user_date_unique (user_id, task_date),
        CONSTRAINT behavioral_daily_tasks_status_check
            CHECK (status IN ('pending', 'completed', 'skipped')),
        CONSTRAINT behavioral_daily_tasks_mood_before_check
            CHECK (mood_before IS NULL OR mood_before BETWEEN 1 AND 5),
        CONSTRAINT behavioral_daily_tasks_mood_after_check
            CHECK (mood_after IS NULL OR mood_after BETWEEN 1 AND 5)
    )""")

    # Existing installations may already have these tables, so create the
    # non-unique lookup indexes separately and leave all existing rows intact.
    _ensure_index(
        c,
        "BEHAVIORAL_ACTIVITIES",
        "behavioral_activities_active_difficulty_duration_idx",
        "is_active, difficulty, duration_minutes",
    )
    _ensure_index(
        c,
        "BEHAVIORAL_DAILY_TASKS",
        "behavioral_daily_tasks_user_status_date_idx",
        "user_id, status, task_date",
    )

    # Optimism Module: private daily "Three Good Things" savoring logs.
    c.execute("""CREATE TABLE IF NOT EXISTS SAVORING_LOGS (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) NOT NULL,
        log_date VARCHAR(32) NOT NULL,
        status VARCHAR(16) NOT NULL DEFAULT 'draft',
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE KEY savoring_logs_user_date_unique (user_id, log_date),
        CONSTRAINT savoring_logs_status_check
            CHECK (status IN ('draft', 'completed'))
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS SAVORING_ENTRIES (
        id VARCHAR(64) PRIMARY KEY,
        log_id VARCHAR(64) NOT NULL,
        entry_order INTEGER NOT NULL,
        positive_event TEXT NOT NULL,
        why_happened TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE KEY savoring_entries_log_order_unique (log_id, entry_order),
        CONSTRAINT savoring_entries_order_check
            CHECK (entry_order BETWEEN 1 AND 3)
    )""")

    _ensure_index(
        c,
        "SAVORING_LOGS",
        "savoring_logs_user_status_date_idx",
        "user_id, status, log_date",
    )
    _ensure_index(
        c,
        "SAVORING_ENTRIES",
        "savoring_entries_log_idx",
        "log_id",
    )

    conn.commit()
    seed_palettes(conn)
    seed_behavioral_activities(conn)
    conn.close()


def seed_behavioral_activities(conn):
    """Pre-loads positive, low-friction activities for behavioral activation."""
    c = conn.cursor()
    c.execute("SELECT COUNT(*) FROM BEHAVIORAL_ACTIVITIES")
    if c.fetchone()[0] > 0:
        return  # already seeded

    activities = [
        ("act_water_plant", "Water a plant", "Give a plant some water or notice a plant nearby.", "Self-care", "tiny", 2),
        ("act_walk_5min", "Walk for 5 minutes", "Step outside or walk around your room for just 5 minutes.", "Physical", "tiny", 5),
        ("act_drink_water", "Drink a glass of water", "Slowly sip a fresh glass of water to refresh yourself.", "Self-care", "tiny", 2),
        ("act_favorite_song", "Listen to one favorite song", "Put on one song you love and simply listen.", "Enjoyment", "tiny", 4),
        ("act_message_friend", "Send a message to a friend", "Say hello or send a simple note or emoji to someone.", "Social", "tiny", 2),
        ("act_sit_outside", "Sit outside for 5 minutes", "Feel the fresh air, warmth, or breeze for 5 minutes.", "Outdoor", "tiny", 5),
        ("act_tidy_area", "Tidy one small area", "Organize one spot like your desk or a single drawer.", "Productivity", "tiny", 3),
        ("act_take_shower", "Take a warm shower", "Enjoy a warm and refreshing shower with no rush.", "Self-care", "easy", 10),
        ("act_gratitude", "Write down one thing you are grateful for", "Note down one small thing that brought you comfort or peace.", "Relaxation", "tiny", 3),
        ("act_stretch", "Gentle 3-minute stretch", "Do a few easy shoulder rolls and gentle body stretches.", "Physical", "tiny", 3),
        ("act_deep_breaths", "Take 5 slow, deep breaths", "Inhale deeply, hold gently, and exhale fully.", "Relaxation", "tiny", 2),
        ("act_look_sky", "Look at the sky or trees", "Spend a moment watching the clouds, trees, or sky.", "Outdoor", "tiny", 3),
        ("act_read_page", "Read 2 pages of a book", "Read just a couple of pages of any book or article you like.", "Enjoyment", "tiny", 5),
        ("act_mindful_tea", "Mindful tea or warm drink", "Make a warm drink and focus on the aroma and warmth.", "Relaxation", "easy", 7),
        ("act_kind_thought", "Think of one kind thought for yourself", "Remind yourself that doing your best each day is enough.", "Self-care", "tiny", 2),
    ]

    created_timestamp = datetime.now(timezone.utc).replace(tzinfo=None).isoformat()
    for act in activities:
        c.execute(
            """INSERT INTO BEHAVIORAL_ACTIVITIES
            (id, title, description, category, difficulty, duration_minutes, is_active, created_at)
            VALUES (?, ?, ?, ?, ?, ?, 1, ?)""",
            (act[0], act[1], act[2], act[3], act[4], act[5], created_timestamp),
        )
    conn.commit()


def seed_palettes(conn):
    """Pre-loads a few starter palettes per mood so Feature 1 has data to return."""
    c = conn.cursor()
    c.execute("SELECT COUNT(*) FROM THEME_PALETTES")
    if c.fetchone()[0] > 0:
        return  # already seeded

    palettes = [
        ("ocean_calm", "Ocean Calm", "anxiety", "#4A90D9", "#E8F4FD", "#87CEEB", "#F5FAFF", "#FFFFFF", "#FFFFFF", "#1A3A5C", ["#87CEEB", "#4A90D9", "#E8F4FD"]),
        ("sage_forest", "Sage Forest", "anxiety", "#6B8F71", "#F5F0E8", "#9CAF88", "#F8FAF5", "#FFFFFF", "#FFFFFF", "#2D4A32", ["#9CAF88", "#6B8F71", "#F5F0E8"]),
        ("lavender_air", "Lavender Air", "anxiety", "#9B8EC4", "#E8E4EF", "#B8A9D9", "#F9F7FC", "#FFFFFF", "#FFFFFF", "#3D3555", ["#B8A9D9", "#9B8EC4", "#E8E4EF"]),
        ("sunrise", "Sunrise", "depression", "#E8A838", "#FDF6E8", "#F5C563", "#FFFBF5", "#FFFFFF", "#FFFFFF", "#5C4A1A", ["#F5C563", "#E8A838", "#FDF6E8"]),
        ("peach_light", "Peach Light", "depression", "#E8A090", "#F5EDE8", "#F0C4B8", "#FFFAF8", "#FFFFFF", "#FFFFFF", "#5C3D35", ["#F0C4B8", "#E8A090", "#F5EDE8"]),
        ("coral_soft", "Coral Soft", "depression", "#E8786A", "#FFFFFF", "#F0A090", "#FFF8F7", "#FFFFFF", "#FFFFFF", "#5C2D28", ["#F0A090", "#E8786A", "#FFFFFF"]),
        ("mint_breeze", "Mint Breeze", "stress", "#5CB8A8", "#FFFFFF", "#8DD4C8", "#F5FFFC", "#FFFFFF", "#FFFFFF", "#1A4A42", ["#8DD4C8", "#5CB8A8", "#FFFFFF"]),
        ("aqua", "Aqua", "stress", "#4ABFBF", "#E0E8E8", "#7DD4D4", "#F5FAFA", "#FFFFFF", "#FFFFFF", "#1A4545", ["#7DD4D4", "#4ABFBF", "#E0E8E8"]),
        ("soft_green", "Soft Green", "stress", "#6BAF7A", "#F5F0E8", "#9DD4A8", "#F8FAF5", "#FFFFFF", "#FFFFFF", "#2D4A35", ["#9DD4A8", "#6BAF7A", "#F5F0E8"]),
    ]

    for p in palettes:
        c.execute(
            "INSERT INTO THEME_PALETTES VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], json.dumps(p[10])),
        )
    conn.commit()


try:
    connect_db()
except Exception as e:
    print(f"Database initialization deferred or failed: {e}")


def now():
    return datetime.now(timezone.utc).replace(tzinfo=None).isoformat()


def _utc_naive(value: datetime) -> datetime:
    """Normalize an aware or naive datetime to AuraMind's UTC-naive format."""
    if value.tzinfo is None:
        return value
    return value.astimezone(timezone.utc).replace(tzinfo=None)


def _local_date_for_offset(
    timezone_offset_minutes: int = 0,
    utc_value: Optional[datetime] = None,
) -> str:
    """Return a YYYY-MM-DD date in the device-reported local timezone."""
    utc_now = _utc_naive(
        utc_value or datetime.now(timezone.utc).replace(tzinfo=None)
    )
    return (utc_now + timedelta(minutes=timezone_offset_minutes)).strftime(
        "%Y-%m-%d"
    )


def _local_date_from_iso(value: str, timezone_offset_minutes: int = 0) -> str:
    """Map an AuraMind UTC timestamp to the same local-day convention as tasks."""
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return value[:10]
    return _local_date_for_offset(timezone_offset_minutes, parsed)


# =====================================================================
# REQUEST BODY SCHEMAS (FastAPI validates these automatically)
# =====================================================================


class SignupRequest(BaseModel):
    name: str
    email: str
    password: str


class LoginRequest(BaseModel):
    email: str
    password: str


class CheckinRequest(BaseModel):
    answers: Dict[str, int]


class SelectThemeRequest(BaseModel):
    palette_id: str


class StartSessionRequest(BaseModel):
    user_id: str


class AddEntriesRequest(BaseModel):
    session_id: str
    category: str  # sight | touch | hear | smell | taste
    items: List[str]


# Sleep Tracking Schemas
class SaveSleepLogRequest(BaseModel):
    date: str
    sleep_hours: int
    sleep_minutes: int
    quality: int  # 0-4 (poor, fair, okay, good, excellent)
    post_wake_feeling: int  # 0-2 (tired, normal, refreshed)
    notes: Optional[str] = None


# Breathing Exercise Schemas
class SaveBreathingSessionRequest(BaseModel):
    technique: str
    duration_seconds: int
    cycles_completed: int
    background_sound: Optional[str] = "Ocean Waves"
    mood_after: Optional[str] = None


# Behavioral Activation Schemas
class BehavioralMoodRequest(BaseModel):
    mood_before: Optional[int] = Field(default=None, ge=1, le=5)
    mood_after: Optional[int] = Field(default=None, ge=1, le=5)

    @model_validator(mode="after")
    def requires_a_rating(self):
        if self.mood_before is None and self.mood_after is None:
            raise ValueError("Provide a mood rating from 1 to 5.")
        return self


class SavoringEntryRequest(BaseModel):
    position: int = Field(ge=1, le=3)
    positive_event: str = Field(default="", max_length=1000)
    why_happened: str = Field(default="", max_length=1000)


class SaveSavoringLogRequest(BaseModel):
    entries: List[SavoringEntryRequest] = Field(min_length=3, max_length=3)

    @model_validator(mode="after")
    def requires_three_distinct_positions(self):
        if {entry.position for entry in self.entries} != {1, 2, 3}:
            raise ValueError("Entries must contain positions 1, 2, and 3 exactly once.")
        return self


# ---------- Helper auth utilities
def _extract_token(auth_header: Optional[str]) -> Optional[str]:
    if not auth_header:
        return None
    parts = auth_header.split()
    if len(parts) == 2 and parts[0].lower() == "bearer":
        return parts[1]
    return None


def get_user_by_token(token: str) -> Optional[Dict]:
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute("SELECT id, name, email FROM USERS WHERE token=?", (token,))
    row = c.fetchone()
    conn.close()
    if row:
        return {"id": row[0], "name": row[1], "email": row[2]}
    return None


def require_user(auth_header: Optional[str]):
    token = _extract_token(auth_header)
    if not token:
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    user = get_user_by_token(token)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user


# =====================================================================
# FEATURE 1 — Auth, Adaptive UI and Theme endpoints (for Flutter)
# =====================================================================


@app.post("/auth/signup")
def signup(req: SignupRequest):
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute("SELECT id FROM USERS WHERE email=?", (req.email,))
    if c.fetchone():
        conn.close()
        raise HTTPException(status_code=400, detail="Email already registered")

    user_id = uuid.uuid4().hex
    token = uuid.uuid4().hex
    c.execute("INSERT INTO USERS VALUES (?, ?, ?, ?, ?)", (user_id, req.name, req.email, req.password, token))
    conn.commit()
    conn.close()

    return {"user_id": user_id, "name": req.name, "email": req.email, "access_token": token}


@app.post("/auth/login")
def login(req: LoginRequest):
    conn = connect_db_connection()
    c = conn.cursor()
    email_clean = req.email.strip().lower()
    pw_clean = req.password.strip()

    c.execute("SELECT id, name, password, email FROM USERS WHERE LOWER(TRIM(email))=?", (email_clean,))
    row = c.fetchone()
    
    # Check password match (or fallback for jt@gmail.com)
    valid = False
    if row:
        db_pw = row[2].strip() if row[2] else ""
        if db_pw == pw_clean:
            valid = True
        elif email_clean == "jt@gmail.com" and pw_clean in ["jt1234", "jarin1234"]:
            valid = True

    if not row or not valid:
        conn.close()
        raise HTTPException(status_code=401, detail="Invalid credentials")

    user_id, name = row[0], row[1]
    token = uuid.uuid4().hex
    c.execute("UPDATE USERS SET token=? WHERE id=?", (token, user_id))
    conn.commit()
    conn.close()

    return {"user_id": user_id, "name": name, "email": row[3], "access_token": token}


@app.post("/checkin")
def checkin(req: CheckinRequest, authorization: Optional[str] = Header(None)):
    """Score and persist a completed mood check-in.

    The existing questionnaire contains 12 questions: 1-4 depression,
    5-8 anxiety and 9-12 stress. Each answer is 0-4.  We also normalize
    the complete response to a 0-10 wellbeing score where higher is better.
    The normalized score is what the longitudinal analytics graph uses.
    """
    user = require_user(authorization)

    depression = 0
    anxiety = 0
    stress = 0

    for key, value in req.answers.items():
        idx = int(key)
        value = max(0, min(4, int(value)))
        if 1 <= idx <= 4:
            depression += value
        elif 5 <= idx <= 8:
            anxiety += value
        elif 9 <= idx <= 12:
            stress += value

    scores = {"depression": depression, "anxiety": anxiety, "stress": stress}
    dominant = max(scores, key=scores.get)
    if scores[dominant] == 0:
        dominant = "normal"

    # 0 = highest symptom burden, 48 = maximum burden for 12 questions.
    # Convert that to an intuitive wellbeing score: 10 = best, 0 = worst.
    answered_count = max(1, len(req.answers))
    maximum_possible = answered_count * 4
    raw_total = depression + anxiety + stress
    mood_score = round(10.0 - (raw_total / maximum_possible) * 10.0, 2)
    mood_score = max(0.0, min(10.0, mood_score))

    checkin_id = uuid.uuid4().hex
    created_at = now()

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        """INSERT INTO MOOD_CHECKINS
        (id, user_id, answers, mood_score, dominant_category, created_at)
        VALUES (?, ?, ?, ?, ?, ?)""",
        (
            checkin_id,
            user["id"],
            json.dumps(req.answers),
            mood_score,
            dominant,
            created_at,
        ),
    )
    conn.commit()

    if dominant == "normal":
        c.execute("SELECT * FROM THEME_PALETTES ORDER BY RAND() LIMIT 3")
    else:
        c.execute("SELECT * FROM THEME_PALETTES WHERE category=?", (dominant,))
    rows = c.fetchall()
    conn.close()

    def palette_from_row(r):
        return {
            "id": r[0],
            "name": r[1],
            "category": r[2],
            "primary": r[3],
            "secondary": r[4],
            "accent": r[5],
            "background": r[6],
            "surface": r[7],
            "onPrimary": r[8],
            "onBackground": r[9],
            "thumbnailGradient": json.loads(r[10]),
        }

    recommended = [palette_from_row(r) for r in rows]

    return {
        "checkin_id": checkin_id,
        "created_at": created_at,
        "depression_score": depression,
        "anxiety_score": anxiety,
        "stress_score": stress,
        "mood_score": mood_score,
        "dominant_category": dominant,
        "recommended_palettes": recommended,
    }


# =====================================================================
# MODULE 1 — LONGITUDINAL MOOD ANALYTICS & TREND TRACKING
# =====================================================================
try:
    from mood_analytics import analyze_mood_history
except ImportError:  # supports `uvicorn FastAPI.app:app` from repo root
    from FastAPI.mood_analytics import analyze_mood_history


@app.get("/mood/analytics")
def get_mood_analytics(
    days: int = 7,
    authorization: Optional[str] = Header(None),
    x_timezone_offset_minutes: int = Header(0, ge=-840, le=840),
):
    """Return timestamped mood points, trend state and intervention tier.

    Supported rolling windows are 7, 30 and 90 days. The authenticated
    user's data is always isolated by user_id.
    """
    user = require_user(authorization)
    if days not in (7, 30, 90):
        raise HTTPException(
            status_code=400,
            detail="days must be one of 7, 30, or 90",
        )

    cutoff = (
        datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=days)
    ).isoformat()

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        """SELECT created_at, mood_score, dominant_category
        FROM MOOD_CHECKINS
        WHERE user_id = ?
          AND created_at >= ?
          AND mood_score IS NOT NULL
        ORDER BY created_at ASC""",
        (user["id"], cutoff),
    )
    rows = c.fetchall()

    # Keep behavioral activation in the existing wellbeing dashboard as
    # descriptive context only. A completed task and a mood check-in occurring
    # on the same date are a recorded co-occurrence, not proof of causation.
    local_today = datetime.strptime(
        _local_date_for_offset(x_timezone_offset_minutes), "%Y-%m-%d"
    )
    cutoff_date = (local_today - timedelta(days=days - 1)).strftime("%Y-%m-%d")
    c.execute(
        """SELECT task_date, status
           FROM BEHAVIORAL_DAILY_TASKS
           WHERE user_id = ? AND task_date >= ?""",
        (user["id"], cutoff_date),
    )
    behavioral_rows = c.fetchall()
    conn.close()

    behavioral_status_by_date = {row[0]: row[1] for row in behavioral_rows}

    points = []
    for row in rows:
        recorded_local_date = _local_date_from_iso(
            row[0], x_timezone_offset_minutes
        )
        points.append(
            {
                "timestamp": row[0],
                "mood_score": float(row[1]),
                "category": row[2] or "normal",
                "behavioral_status": behavioral_status_by_date.get(
                    recorded_local_date
                ),
            }
        )

    completed_dates = {
        row[0] for row in behavioral_rows if row[1] == "completed"
    }
    mood_dates = {
        _local_date_from_iso(point["timestamp"], x_timezone_offset_minutes)
        for point in points
    }
    co_recorded_days = len(completed_dates.intersection(mood_dates))
    behavioral_summary = {
        "period_days": days,
        "completed_count": sum(1 for row in behavioral_rows if row[1] == "completed"),
        "skipped_count": sum(1 for row in behavioral_rows if row[1] == "skipped"),
        "pending_count": sum(1 for row in behavioral_rows if row[1] == "pending"),
        "active_days": len(completed_dates),
        "days_with_recorded_mood_and_completion": co_recorded_days,
        "pattern_message": (
            f"On {co_recorded_days} day"
            f"{'s' if co_recorded_days != 1 else ''}, a recorded mood check-in "
            "and a completed tiny step occurred together. This is a pattern in "
            "your records, not evidence that one caused the other."
            if co_recorded_days
            else None
        ),
    }

    analysis = analyze_mood_history(points)

    return {
        "period_days": days,
        "points": points,
        "behavioral_summary": behavioral_summary,
        **analysis,
    }


@app.post("/themes/select")
def api_select_theme(req: SelectThemeRequest, authorization: Optional[str] = Header(None)):
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        """INSERT INTO USER_THEME (user_id, palette_id, selected_at) VALUES (?, ?, ?)
           ON DUPLICATE KEY UPDATE
             palette_id = VALUES(palette_id),
             selected_at = VALUES(selected_at)""",
        (user["id"], req.palette_id, now()),
    )
    conn.commit()
    conn.close()
    return {"response": "Theme saved"}


@app.get("/themes/selected/me")
def api_fetch_selected_theme(authorization: Optional[str] = Header(None)):
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute("SELECT p.* FROM USER_THEME u JOIN THEME_PALETTES p ON u.palette_id = p.id WHERE u.user_id=?", (user["id"],))
    row = c.fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="No theme selected")

    return {
        "id": row[0],
        "name": row[1],
        "category": row[2],
        "primary": row[3],
        "secondary": row[4],
        "accent": row[5],
        "background": row[6],
        "surface": row[7],
        "onPrimary": row[8],
        "onBackground": row[9],
        "thumbnailGradient": json.loads(row[10]),
    }


@app.post("/themes/clear")
def api_clear_selected_theme(authorization: Optional[str] = Header(None)):
    """Clears the user's selected theme. Used on logout so a returning user
    doesn't automatically get the previously selected theme until they
    re-do the check-in."""
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute("DELETE FROM USER_THEME WHERE user_id=?", (user["id"],))
    conn.commit()
    conn.close()
    return {"response": "Theme cleared"}



# =====================================================================
# FEATURE 2 — Somatic 5-4-3-2-1 Grounding Interface
# =====================================================================

# ---- 1. Start a new grounding session ----------------------------------
# POST /startGroundingSession
# Body: { "user_id": "u1" }
@app.post("/startGroundingSession")
def start_grounding_session(
    req: StartSessionRequest,
    authorization: Optional[str] = Header(None),
):
    user = require_user(authorization)
    session_id = uuid.uuid4().hex
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        "INSERT INTO GROUNDING_SESSIONS VALUES (?, ?, ?, 0)",
        (session_id, user["id"], now()),
    )
    conn.commit()
    conn.close()

    return {"response": "Session started", "session_id": session_id}


# ---- 2. Submit items for one step (sight/touch/hear/smell/taste) -------
# POST /addGroundingEntries
# Body: { "session_id": "...", "category": "sight", "items": ["tree","sky","lamp","chair","phone"] }
# category must be one of: sight, touch, hear, smell, taste
@app.post("/addGroundingEntries")
def add_grounding_entries(
    req: AddEntriesRequest,
    authorization: Optional[str] = Header(None),
):
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT id FROM GROUNDING_SESSIONS WHERE id=? AND user_id=?",
        (req.session_id, user["id"]),
    )
    if c.fetchone() is None:
        conn.close()
        raise HTTPException(status_code=404, detail="Grounding session not found")
    if req.category not in {"sight", "touch", "hear", "smell", "taste"}:
        conn.close()
        raise HTTPException(status_code=400, detail="Invalid grounding category")
    expected_count = {"sight": 5, "touch": 4, "hear": 3, "smell": 2, "taste": 1}[req.category]
    items = [item.strip() for item in req.items if item.strip()]
    if len(items) != expected_count:
        conn.close()
        raise HTTPException(
            status_code=400,
            detail=f"{req.category} requires exactly {expected_count} entries",
        )
    for item_text in items:
        c.execute(
            "INSERT INTO GROUNDING_ENTRIES VALUES (?, ?, ?, ?)",
            (uuid.uuid4().hex, req.session_id, req.category, item_text),
        )

    # mark session completed once taste (the last step) is submitted
    if req.category == "taste":
        c.execute("UPDATE GROUNDING_SESSIONS SET completed=1 WHERE id=?", (req.session_id,))

    conn.commit()
    conn.close()

    return {"response": f"{req.category} entries saved"}


# ---- 3. Get a full session with all its entries -------------------------
# GET /getGroundingSession/<session_id>
@app.get("/getGroundingSession/{session_id}")
def get_grounding_session(
    session_id: str,
    authorization: Optional[str] = Header(None),
):
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT * FROM GROUNDING_SESSIONS WHERE id=? AND user_id=?",
        (session_id, user["id"]),
    )
    session_row = c.fetchone()

    if session_row is None:
        conn.close()
        raise HTTPException(status_code=404, detail="Session not found")

    c.execute("SELECT category, item_text FROM GROUNDING_ENTRIES WHERE session_id=?", (session_id,))
    entry_rows = c.fetchall()
    conn.close()

    entries_by_category = {}
    for category, item_text in entry_rows:
        entries_by_category.setdefault(category, []).append(item_text)

    return {
        "session_id": session_row[0],
        "user_id": session_row[1],
        "created_at": session_row[2],
        "completed": bool(session_row[3]),
        "entries": entries_by_category,
    }


# ---- 4. Get a user's past grounding sessions -----------------------------
# GET /getGroundingHistory/<user_id>
@app.get("/getGroundingHistory/{user_id}")
def get_grounding_history(
    user_id: str,
    authorization: Optional[str] = Header(None),
):
    user = require_user(authorization)
    if user_id != user["id"]:
        raise HTTPException(status_code=403, detail="You can only view your own history")
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT id, created_at, completed FROM GROUNDING_SESSIONS WHERE user_id=? ORDER BY created_at DESC",
        (user_id,),
    )
    rows = c.fetchall()
    conn.close()

    return [
        {"session_id": r[0], "created_at": r[1], "completed": bool(r[2])}
        for r in rows
    ]


# =====================================================================
# SLEEP TRACKING ENDPOINTS
# =====================================================================

@app.post("/sleep/log")
def save_sleep_log(
    req: SaveSleepLogRequest,
    authorization: Optional[str] = Header(None)
):
    """Save a sleep log entry for the authenticated user."""
    user = require_user(authorization)
    user_id = user["id"]
    
    sleep_id = str(uuid.uuid4())
    conn = connect_db_connection()
    c = conn.cursor()
    
    c.execute(
        """INSERT INTO SLEEP_LOGS 
        (id, user_id, date, sleep_hours, sleep_minutes, quality, post_wake_feeling, notes, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            sleep_id,
            user_id,
            req.date,
            req.sleep_hours,
            req.sleep_minutes,
            req.quality,
            req.post_wake_feeling,
            req.notes,
            now(),
        ),
    )
    
    conn.commit()
    conn.close()
    
    # Check for warnings after saving
    _check_wellbeing_warnings(user_id)
    
    return {
        "id": sleep_id,
        "user_id": user_id,
        "date": req.date,
        "sleep_hours": req.sleep_hours,
        "sleep_minutes": req.sleep_minutes,
        "quality": req.quality,
        "post_wake_feeling": req.post_wake_feeling,
        "notes": req.notes,
        "created_at": now(),
    }


@app.get("/sleep/logs")
def get_sleep_logs(
    days: int = 7,
    authorization: Optional[str] = Header(None)
):
    """Get sleep logs for the authenticated user from the last N days."""
    user = require_user(authorization)
    user_id = user["id"]
    
    conn = connect_db_connection()
    c = conn.cursor()
    
    # Get logs from last N days
    cutoff_date = (datetime.utcnow() - __import__('datetime').timedelta(days=days)).isoformat()
    c.execute(
        """SELECT id, user_id, date, sleep_hours, sleep_minutes, quality, post_wake_feeling, notes, created_at
        FROM SLEEP_LOGS WHERE user_id=? AND created_at >= ? ORDER BY date DESC""",
        (user_id, cutoff_date),
    )
    
    logs = []
    for row in c.fetchall():
        logs.append({
            "id": row[0],
            "user_id": row[1],
            "date": row[2],
            "sleep_hours": row[3],
            "sleep_minutes": row[4],
            "quality": row[5],
            "post_wake_feeling": row[6],
            "notes": row[7],
            "created_at": row[8],
        })
    
    conn.close()
    return logs


@app.get("/sleep/metrics")
def get_sleep_metrics(
    days: int = 7,
    authorization: Optional[str] = Header(None)
):
    """Get aggregated sleep metrics for the last N days."""
    user = require_user(authorization)
    user_id = user["id"]
    
    conn = connect_db_connection()
    c = conn.cursor()
    
    cutoff_date = (datetime.utcnow() - __import__('datetime').timedelta(days=days)).isoformat()
    c.execute(
        """SELECT id, user_id, date, sleep_hours, sleep_minutes, quality,
        post_wake_feeling, notes, created_at FROM SLEEP_LOGS
        WHERE user_id=? AND created_at >= ? ORDER BY date ASC""",
        (user_id, cutoff_date),
    )
    
    entries = []
    total_sleep_minutes = 0
    total_quality = 0
    count = 0
    
    for row in c.fetchall():
        (log_id, log_user_id, date, sleep_hours, sleep_minutes, quality,
         post_wake_feeling, notes, created_at) = row
        total_sleep_minutes += sleep_hours * 60 + sleep_minutes
        total_quality += quality
        count += 1
        
        entries.append({
            "id": log_id,
            "user_id": log_user_id,
            "date": date,
            "sleep_hours": sleep_hours,
            "sleep_minutes": sleep_minutes,
            "quality": quality,
            "post_wake_feeling": post_wake_feeling,
            "notes": notes,
            "created_at": created_at,
        })
    
    conn.close()
    
    avg_sleep = total_sleep_minutes / 60 / max(count, 1)
    avg_quality = total_quality / max(count, 1)
    
    return {
        "average_sleep": round(avg_sleep, 2),
        "average_quality": round(avg_quality, 2),
        "total_entries": count,
        "entries": entries,
    }


@app.get("/sleep/correlation")
def get_sleep_mood_correlation(
    days: int = 7,
    authorization: Optional[str] = Header(None),
    x_timezone_offset_minutes: int = Header(0, ge=-840, le=840),
):
    """Return same-day sleep, mood, and optional tiny-step records."""
    user = require_user(authorization)
    user_id = user["id"]
    if not 1 <= days <= 365:
        raise HTTPException(status_code=400, detail="days must be between 1 and 365")

    conn = connect_db_connection()
    c = conn.cursor()

    cutoff_date = (
        datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=days)
    ).isoformat()

    # Get sleep data
    c.execute(
        """SELECT date, sleep_hours, sleep_minutes FROM SLEEP_LOGS
        WHERE user_id=? AND created_at >= ? ORDER BY date""",
        (user_id, cutoff_date),
    )

    sleep_data = {}
    for row in c.fetchall():
        recorded_date, hours, minutes = row
        date_key = recorded_date.split("T")[0]
        sleep_data[date_key] = (hours * 60 + minutes) / 60

    # Mood scores use the same normalized 0-10 value as Mood Insights. Older
    # rows without that column populated retain the existing answer fallback.
    c.execute(
        """SELECT created_at, mood_score, answers FROM MOOD_CHECKINS
        WHERE user_id=? AND created_at >= ? ORDER BY created_at""",
        (user_id, cutoff_date),
    )
    mood_rows = c.fetchall()

    local_today = datetime.strptime(
        _local_date_for_offset(x_timezone_offset_minutes), "%Y-%m-%d"
    )
    task_cutoff = (local_today - timedelta(days=days - 1)).strftime("%Y-%m-%d")
    c.execute(
        """SELECT t.task_date, t.status, a.title
           FROM BEHAVIORAL_DAILY_TASKS t
           JOIN BEHAVIORAL_ACTIVITIES a ON a.id = t.activity_id
           WHERE t.user_id = ? AND t.task_date >= ?""",
        (user_id, task_cutoff),
    )
    behavioral_by_date = {
        row[0]: {"status": row[1], "title": row[2]} for row in c.fetchall()
    }

    correlations = []
    for row in mood_rows:
        created_at, stored_mood_score, answers_json = row
        date_key = _local_date_from_iso(created_at, x_timezone_offset_minutes)
        if date_key not in sleep_data:
            continue

        try:
            mood_score = (
                float(stored_mood_score)
                if stored_mood_score is not None
                else None
            )
            if mood_score is None:
                answers = json.loads(answers_json)
                if not answers:
                    continue
                avg_answer = sum(answers.values()) / len(answers)
                mood_score = avg_answer * 2.5

            behavioral = behavioral_by_date.get(date_key)
            correlations.append(
                {
                    "date": date_key,
                    "sleep_hours": sleep_data[date_key],
                    "mood_score": round(mood_score, 1),
                    "behavioral_status": (
                        behavioral["status"] if behavioral else None
                    ),
                    "behavioral_activity_title": (
                        behavioral["title"] if behavioral else None
                    ),
                }
            )
        except (TypeError, ValueError, json.JSONDecodeError):
            continue

    conn.close()
    return correlations


@app.get("/sleep/warnings")
def get_wellbeing_warnings(
    authorization: Optional[str] = Header(None)
):
    """Get active wellbeing warnings for the user."""
    user = require_user(authorization)
    user_id = user["id"]
    
    conn = connect_db_connection()
    c = conn.cursor()
    
    c.execute(
        """SELECT id, title, message, created_at, is_dismissed FROM WELLBEING_WARNINGS
        WHERE user_id=? AND is_dismissed=0 ORDER BY created_at DESC""",
        (user_id,),
    )
    
    warnings = []
    for row in c.fetchall():
        warnings.append({
            "id": row[0],
            "title": row[1],
            "message": row[2],
            "created_at": row[3],
            "is_dismissed": bool(row[4]),
        })
    
    conn.close()
    return warnings


@app.post("/sleep/warnings/{warning_id}/dismiss")
def dismiss_warning(
    warning_id: str,
    authorization: Optional[str] = Header(None)
):
    """Dismiss a wellbeing warning."""
    user = require_user(authorization)
    user_id = user["id"]
    
    conn = connect_db_connection()
    c = conn.cursor()
    
    c.execute(
        "UPDATE WELLBEING_WARNINGS SET is_dismissed=1 WHERE id=? AND user_id=?",
        (warning_id, user_id),
    )
    
    conn.commit()
    conn.close()
    
    return {"success": True}


@app.delete("/sleep/log/{log_id}")
def delete_sleep_log(
    log_id: str,
    authorization: Optional[str] = Header(None)
):
    """Delete a sleep log entry."""
    user = require_user(authorization)
    user_id = user["id"]
    
    conn = connect_db_connection()
    c = conn.cursor()
    
    c.execute(
        "DELETE FROM SLEEP_LOGS WHERE id=? AND user_id=?",
        (log_id, user_id),
    )
    
    conn.commit()
    conn.close()
    
    return {"success": True}


def _check_wellbeing_warnings(user_id: str):
    """Check sleep-mood correlation and create warnings if needed."""
    conn = connect_db_connection()
    c = conn.cursor()
    
    # Get last 7 days of sleep data
    cutoff_date = (datetime.utcnow() - __import__('datetime').timedelta(days=7)).isoformat()
    c.execute(
        """SELECT AVG(sleep_hours * 60 + sleep_minutes) as avg_sleep_minutes
        FROM SLEEP_LOGS WHERE user_id=? AND created_at >= ?""",
        (user_id, cutoff_date),
    )
    
    result = c.fetchone()
    avg_sleep_minutes = result[0] if result[0] else 0
    avg_sleep_hours = avg_sleep_minutes / 60
    
    # Get last 7 days of mood data. `answers` is stored as a JSON string
    # (e.g. '{"0": 4, "1": 3}'), so it must be parsed in Python rather than
    # cast directly in SQL — CAST(answers AS REAL) on a JSON string always
    # evaluates to 0, which made avg_mood < 5 trivially true and meant
    # warnings were really only checking sleep, never actual mood decline.
    c.execute(
        """SELECT answers FROM MOOD_CHECKINS
        WHERE user_id=? AND created_at >= ?""",
        (user_id, cutoff_date),
    )

    mood_scores = []
    for (answers_json,) in c.fetchall():
        try:
            answers = json.loads(answers_json)
            if answers:
                avg_answer = sum(answers.values()) / len(answers)
                mood_scores.append(avg_answer * 2.5)  # scale to 0-10, same as /sleep/correlation
        except Exception:
            pass

    avg_mood = sum(mood_scores) / len(mood_scores) if mood_scores else None

    # Check conditions for warnings. Require actual mood data to exist —
    # otherwise there's nothing to correlate sleep against yet.
    if avg_mood is not None and avg_sleep_hours < 6 and avg_mood < 5:
        # Avoid spamming duplicate warnings: only create one if the user
        # doesn't already have an active (undismissed) alert of this kind.
        c.execute(
            """SELECT id FROM WELLBEING_WARNINGS
            WHERE user_id=? AND title=? AND is_dismissed=0""",
            (user_id, "Sleep & Mood Alert"),
        )
        if c.fetchone() is None:
            warning_id = str(uuid.uuid4())
            c.execute(
                """INSERT INTO WELLBEING_WARNINGS
                (id, user_id, title, message, created_at, is_dismissed)
                VALUES (?, ?, ?, ?, ?, ?)""",
                (
                    warning_id,
                    user_id,
                    "Sleep & Mood Alert",
                    f"Your sleep has been lower than usual, and your mood score has also decreased recently. "
                    f"Consider getting more rest tonight.",
                    now(),
                    0,
                ),
            )
            conn.commit()

    conn.close()


# =====================================================================
# FEATURE 3 — Interactive Breathing Exercise Endpoints
# =====================================================================

@app.post("/breathing/session")
def save_breathing_session(
    req: SaveBreathingSessionRequest,
    authorization: Optional[str] = Header(None)
):
    """Save a completed or stopped breathing exercise session for the authenticated user."""
    user = require_user(authorization)
    user_id = user["id"]
    session_id = str(uuid.uuid4())
    created_timestamp = now()

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        """INSERT INTO BREATHING_SESSIONS 
        (id, user_id, technique, duration_seconds, cycles_completed, background_sound, mood_after, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            session_id,
            user_id,
            req.technique,
            req.duration_seconds,
            req.cycles_completed,
            req.background_sound,
            req.mood_after,
            created_timestamp,
        ),
    )
    conn.commit()
    conn.close()

    return {
        "id": session_id,
        "user_id": user_id,
        "technique": req.technique,
        "duration_seconds": req.duration_seconds,
        "cycles_completed": req.cycles_completed,
        "background_sound": req.background_sound,
        "mood_after": req.mood_after,
        "created_at": created_timestamp,
    }


@app.get("/breathing/history")
def get_breathing_history(
    limit: int = 30,
    authorization: Optional[str] = Header(None)
):
    """Get breathing exercise history for the authenticated user."""
    user = require_user(authorization)
    user_id = user["id"]

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        """SELECT id, user_id, technique, duration_seconds, cycles_completed, background_sound, mood_after, created_at
        FROM BREATHING_SESSIONS WHERE user_id=? ORDER BY created_at DESC LIMIT ?""",
        (user_id, limit),
    )

    rows = c.fetchall()
    conn.close()

    sessions = []
    for r in rows:
        sessions.append({
            "id": r[0],
            "user_id": r[1],
            "technique": r[2],
            "duration_seconds": r[3],
            "cycles_completed": r[4],
            "background_sound": r[5],
            "mood_after": r[6],
            "created_at": r[7],
        })

    return sessions


@app.get("/breathing/metrics")
def get_breathing_metrics(
    authorization: Optional[str] = Header(None)
):
    """Get aggregated breathing exercise metrics for the authenticated user."""
    user = require_user(authorization)
    user_id = user["id"]

    conn = connect_db_connection()
    c = conn.cursor()

    # Total sessions, total seconds, total cycles
    c.execute(
        """SELECT COUNT(*), COALESCE(SUM(duration_seconds), 0), COALESCE(SUM(cycles_completed), 0)
        FROM BREATHING_SESSIONS WHERE user_id=?""",
        (user_id,),
    )
    total_sessions, total_seconds, total_cycles = c.fetchone()

    # Today's minutes
    today_start = datetime.utcnow().strftime("%Y-%m-%d") + "T00:00:00"
    c.execute(
        """SELECT COALESCE(SUM(duration_seconds), 0)
        FROM BREATHING_SESSIONS WHERE user_id=? AND created_at >= ?""",
        (user_id, today_start),
    )
    today_seconds = c.fetchone()[0]

    # Most frequent technique
    c.execute(
        """SELECT technique, COUNT(*) as count
        FROM BREATHING_SESSIONS WHERE user_id=?
        GROUP BY technique ORDER BY count DESC LIMIT 1""",
        (user_id,),
    )
    tech_row = c.fetchone()
    favorite_technique = tech_row[0] if tech_row else "Box Breathing"

    # Most frequent sound
    c.execute(
        """SELECT background_sound, COUNT(*) as count
        FROM BREATHING_SESSIONS WHERE user_id=? AND background_sound IS NOT NULL
        GROUP BY background_sound ORDER BY count DESC LIMIT 1""",
        (user_id,),
    )
    sound_row = c.fetchone()
    favorite_sound = sound_row[0] if sound_row else "Ocean Waves"

    conn.close()

    return {
        "total_sessions": total_sessions,
        "total_seconds": total_seconds,
        "total_minutes": round(total_seconds / 60, 1),
        "total_cycles": total_cycles,
        "today_minutes": round(today_seconds / 60, 1),
        "favorite_technique": favorite_technique,
        "favorite_sound": favorite_sound,
    }


@app.delete("/breathing/session/{session_id}")
def delete_breathing_session(
    session_id: str,
    authorization: Optional[str] = Header(None)
):
    """Delete a breathing session entry."""
    user = require_user(authorization)
    user_id = user["id"]

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        "DELETE FROM BREATHING_SESSIONS WHERE id=? AND user_id=?",
        (session_id, user_id),
    )
    conn.commit()
    conn.close()

    return {"success": True}
    return {"success": True}

# =====================================================================
# MODULE 1 — ZERO-KNOWLEDGE ANONYMOUS COMMUNITY FORUM
# =====================================================================

class CommunityPostRequest(BaseModel):
    content: str


class CommunityReportRequest(BaseModel):
    reason: Optional[str] = "Harmful or triggering content"

class CommunityCommentRequest(BaseModel):
    content: str


class CommunityCommentReportRequest(BaseModel):
    reason: Optional[str] = "Harmful or inappropriate comment"


_COMMUNITY_ADJECTIVES = (
    "Quiet", "Gentle", "Calm", "Kind", "Brave", "Hopeful",
    "Silver", "Soft", "Warm", "Steady", "Open", "Bright",
)
_COMMUNITY_NOUNS = (
    "Cedar", "River", "Cloud", "Meadow", "Moon", "Willow",
    "Harbor", "Dawn", "Fern", "Rain", "Sky", "Lotus",
)


def _community_alias(user_id: str) -> str:
    """Generate a deterministic pseudonym without exposing user PII."""
    digest = hashlib.sha256(user_id.encode("utf-8")).digest()
    adjective = _COMMUNITY_ADJECTIVES[digest[0] % len(_COMMUNITY_ADJECTIVES)]
    noun = _COMMUNITY_NOUNS[digest[1] % len(_COMMUNITY_NOUNS)]
    suffix = int.from_bytes(digest[2:4], "big") % 90 + 10
    return f"Anonymous {adjective} {noun} {suffix}"


def _scrub_community_pii(text: str) -> str:
    """Remove common contact PII before public storage/rendering."""
    value = " ".join(text.strip().split())
    value = re.sub(
        r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b",
        "[email removed]",
        value,
    )
    value = re.sub(
        r"(?<!\w)(?:\+?880[\s-]?)?01[3-9](?:[\s-]?\d){8}(?!\w)",
        "[phone removed]",
        value,
    )
    value = re.sub(
        r"(?<!\w)\+?\d[\d\s().-]{8,}\d(?!\w)",
        "[phone removed]",
        value,
    )
    return value[:1000].strip()


def _public_community_post(
    row,
    report_count: int = 0,
    comment_count: int = 0,
):
    return {
        "id": row[0],
        "author_alias": _community_alias(row[1]),
        "content": row[2],
        "created_at": row[3],
        "report_count": report_count,
        "comment_count": comment_count,
    }


def _public_community_comment(row, report_count: int = 0):
    return {
        "id": row[0],
        "post_id": row[1],
        "author_alias": _community_alias(row[2]),
        "content": row[3],
        "created_at": row[4],
        "report_count": report_count,
    }


@app.get("/community/posts")
def get_community_posts(
    limit: int = 50,
    authorization: Optional[str] = Header(None),
):
    require_user(authorization)
    limit = max(1, min(100, limit))

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        """SELECT p.id, p.user_id, p.body, p.created_at,
                  (SELECT COUNT(*) FROM COMMUNITY_REPORTS r
                   WHERE r.post_id = p.id) AS report_count,
                  (SELECT COUNT(*) FROM COMMUNITY_COMMENTS cc
                   WHERE cc.post_id = p.id AND cc.is_hidden = 0) AS comment_count
           FROM COMMUNITY_POSTS p
           WHERE p.is_hidden = 0
           ORDER BY p.created_at DESC
           LIMIT ?""",
        (limit,),
    )
    rows = c.fetchall()
    conn.close()
    return [
        _public_community_post(
            row[:4],
            int(row[4] or 0),
            int(row[5] or 0),
        )
        for row in rows
    ]


@app.post("/community/posts")
def create_community_post(
    req: CommunityPostRequest,
    authorization: Optional[str] = Header(None),
):
    user = require_user(authorization)
    cleaned = _scrub_community_pii(req.content)
    if len(cleaned) < 2:
        raise HTTPException(status_code=400, detail="Post is too short")

    post_id = uuid.uuid4().hex
    created_at = now()

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        """INSERT INTO COMMUNITY_POSTS
           (id, user_id, body, created_at, is_hidden)
           VALUES (?, ?, ?, ?, 0)""",
        (post_id, user["id"], cleaned, created_at),
    )
    conn.commit()
    conn.close()

    return {
        "id": post_id,
        "author_alias": _community_alias(user["id"]),
        "content": cleaned,
        "created_at": created_at,
        "report_count": 0,
        "comment_count": 0,
    }


@app.post("/community/posts/{post_id}/report")
def report_community_post(
    post_id: str,
    req: CommunityReportRequest,
    authorization: Optional[str] = Header(None),
):
    """Module 1 records reports only; later modules handle AI/quarantine."""
    user = require_user(authorization)
    reason = _scrub_community_pii(req.reason or "")[:200] or "Community report"

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT id FROM COMMUNITY_POSTS WHERE id=? AND is_hidden=0",
        (post_id,),
    )
    if c.fetchone() is None:
        conn.close()
        raise HTTPException(status_code=404, detail="Community post not found")

    c.execute(
        """SELECT id FROM COMMUNITY_REPORTS
           WHERE post_id=? AND reporter_user_id=?""",
        (post_id, user["id"]),
    )
    if c.fetchone() is not None:
        conn.close()
        return {
            "success": True,
            "already_reported": True,
            "message": "You already reported this post.",
        }

    c.execute(
        """INSERT INTO COMMUNITY_REPORTS
           (id, post_id, reporter_user_id, reason, created_at)
           VALUES (?, ?, ?, ?, ?)""",
        (uuid.uuid4().hex, post_id, user["id"], reason, now()),
    )
    conn.commit()
    conn.close()
    return {
        "success": True,
        "already_reported": False,
        "message": "Report received for review.",
    }

@app.get("/community/posts/{post_id}/comments")
def get_community_comments(
    post_id: str,
    limit: int = 100,
    authorization: Optional[str] = Header(None),
):
    require_user(authorization)
    limit = max(1, min(200, limit))

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT id FROM COMMUNITY_POSTS WHERE id=? AND is_hidden=0",
        (post_id,),
    )
    if c.fetchone() is None:
        conn.close()
        raise HTTPException(status_code=404, detail="Community post not found")

    c.execute(
        """SELECT cc.id, cc.post_id, cc.user_id, cc.body, cc.created_at,
                  (SELECT COUNT(*) FROM COMMUNITY_COMMENT_REPORTS cr
                   WHERE cr.comment_id = cc.id) AS report_count
           FROM COMMUNITY_COMMENTS cc
           WHERE cc.post_id=? AND cc.is_hidden=0
           ORDER BY cc.created_at ASC
           LIMIT ?""",
        (post_id, limit),
    )
    rows = c.fetchall()
    conn.close()
    return [
        _public_community_comment(row[:5], int(row[5] or 0))
        for row in rows
    ]


@app.post("/community/posts/{post_id}/comments")
def create_community_comment(
    post_id: str,
    req: CommunityCommentRequest,
    authorization: Optional[str] = Header(None),
):
    user = require_user(authorization)
    cleaned = _scrub_community_pii(req.content)
    if len(cleaned) < 1:
        raise HTTPException(status_code=400, detail="Comment is too short")

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT id FROM COMMUNITY_POSTS WHERE id=? AND is_hidden=0",
        (post_id,),
    )
    if c.fetchone() is None:
        conn.close()
        raise HTTPException(status_code=404, detail="Community post not found")

    comment_id = uuid.uuid4().hex
    created_at = now()
    c.execute(
        """INSERT INTO COMMUNITY_COMMENTS
           (id, post_id, user_id, body, created_at, is_hidden)
           VALUES (?, ?, ?, ?, ?, 0)""",
        (comment_id, post_id, user["id"], cleaned, created_at),
    )
    conn.commit()
    conn.close()

    return {
        "id": comment_id,
        "post_id": post_id,
        "author_alias": _community_alias(user["id"]),
        "content": cleaned,
        "created_at": created_at,
        "report_count": 0,
    }


@app.post("/community/comments/{comment_id}/report")
def report_community_comment(
    comment_id: str,
    req: CommunityCommentReportRequest,
    authorization: Optional[str] = Header(None),
):
    user = require_user(authorization)
    reason = _scrub_community_pii(req.reason or "")[:200] or "Community comment report"

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT id FROM COMMUNITY_COMMENTS WHERE id=? AND is_hidden=0",
        (comment_id,),
    )
    if c.fetchone() is None:
        conn.close()
        raise HTTPException(status_code=404, detail="Community comment not found")

    c.execute(
        """SELECT id FROM COMMUNITY_COMMENT_REPORTS
           WHERE comment_id=? AND reporter_user_id=?""",
        (comment_id, user["id"]),
    )
    if c.fetchone() is not None:
        conn.close()
        return {
            "success": True,
            "already_reported": True,
            "message": "You already reported this comment.",
        }

    c.execute(
        """INSERT INTO COMMUNITY_COMMENT_REPORTS
           (id, comment_id, reporter_user_id, reason, created_at)
           VALUES (?, ?, ?, ?, ?)""",
        (uuid.uuid4().hex, comment_id, user["id"], reason, now()),
    )
    conn.commit()
    conn.close()
    return {
        "success": True,
        "already_reported": False,
        "message": "Comment report received for review.",
    }


# =====================================================================
# FEATURE: Behavioral Activation Planner — Depression / Wellbeing Module
# =====================================================================

def _format_task_response(row):
    return {
        "id": row[0],
        "user_id": row[1],
        "activity_id": row[2],
        "task_date": row[3],
        "status": row[4],
        "completed_at": row[5],
        "mood_before": row[6],
        "mood_after": row[7],
        "created_at": row[8],
        "activity": {
            "id": row[2],
            "title": row[9],
            "description": row[10],
            "category": row[11],
            "difficulty": row[12],
            "duration_minutes": row[13],
        },
    }


def _fetch_behavioral_task_row(c, task_id: str):
    c.execute(
        """SELECT t.id, t.user_id, t.activity_id, t.task_date, t.status,
                  t.completed_at, t.mood_before, t.mood_after, t.created_at,
                  a.title, a.description, a.category, a.difficulty, a.duration_minutes
           FROM BEHAVIORAL_DAILY_TASKS t
           JOIN BEHAVIORAL_ACTIVITIES a ON t.activity_id = a.id
           WHERE t.id = ?""",
        (task_id,),
    )
    return c.fetchone()


def _get_owned_behavioral_task(c, task_id: str, user_id: str):
    """Fetch a task and enforce that the signed-in user owns it."""
    c.execute(
        """SELECT user_id, activity_id, task_date, status
           FROM BEHAVIORAL_DAILY_TASKS WHERE id = ?""",
        (task_id,),
    )
    row = c.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Task not found")
    if row[0] != user_id:
        raise HTTPException(status_code=403, detail="Unauthorized task access")
    return {
        "user_id": row[0],
        "activity_id": row[1],
        "task_date": row[2],
        "status": row[3],
    }


def _select_activity_for_user(
    c,
    user_id: str,
    exclude_activity_ids: Optional[List[str]] = None,
    today_str: Optional[str] = None,
) -> Optional[Dict]:
    """Selects an appropriate tiny/low-friction activity for today.

    1. Check recently assigned activities in the last 7 days.
    2. Check recent skips: if the user skipped recent tasks, prioritize 'tiny' difficulty with lowest duration.
    3. Exclude recently assigned activities and any excluded activity IDs.
    4. Pick from available eligible candidates.
    5. Fallback gracefully to any active activity if pool exhausted.
    """
    if exclude_activity_ids is None:
        exclude_activity_ids = []

    # Get the current local day plus the previous six calendar days.
    local_today = datetime.strptime(
        today_str or _local_date_for_offset(), "%Y-%m-%d"
    )
    seven_days_ago = (local_today - timedelta(days=6)).strftime("%Y-%m-%d")
    c.execute(
        """SELECT activity_id, status FROM BEHAVIORAL_DAILY_TASKS
        WHERE user_id = ? AND task_date >= ?
        ORDER BY task_date DESC""",
        (user_id, seven_days_ago),
    )
    recent_rows = c.fetchall()
    recent_assigned_ids = {row[0] for row in recent_rows}

    # Check if recent tasks were skipped
    recent_skips = sum(1 for row in recent_rows if row[1] == "skipped")
    prefer_ultra_easy = recent_skips >= 2

    # Fetch all active activities
    c.execute(
        """SELECT id, title, description, category, difficulty, duration_minutes, is_active, created_at
        FROM BEHAVIORAL_ACTIVITIES
        WHERE is_active = 1"""
    )
    all_activities = [
        {
            "id": r[0],
            "title": r[1],
            "description": r[2],
            "category": r[3],
            "difficulty": r[4],
            "duration_minutes": r[5],
            "is_active": bool(r[6]),
            "created_at": r[7],
        }
        for r in c.fetchall()
    ]

    if not all_activities:
        return None

    # Filter candidates: exclude explicitly excluded and recently assigned
    filtered = [
        a for a in all_activities
        if a["id"] not in exclude_activity_ids and a["id"] not in recent_assigned_ids
    ]

    # If too few, relax recent_assigned_ids constraint but keep exclude_activity_ids
    if not filtered:
        filtered = [a for a in all_activities if a["id"] not in exclude_activity_ids]

    # An explicit exclusion (used by Change Activity) must never be relaxed.
    # With no exclusion, reusing an older activity remains a safe fallback.
    if not filtered and not exclude_activity_ids:
        filtered = all_activities

    if not filtered:
        return None

    # Sort by a transparent, stable preference order. This deliberately avoids
    # an opaque recommender or random assignment: tiny, shorter options come first.
    if prefer_ultra_easy:
        filtered.sort(
            key=lambda x: (
                0 if x["difficulty"] == "tiny" else 1,
                x["duration_minutes"],
                x["id"],
            )
        )
    else:
        filtered.sort(
            key=lambda x: (
                0
                if x["difficulty"] == "tiny"
                else (1 if x["difficulty"] == "easy" else 2),
                x["duration_minutes"],
                x["id"],
            )
        )

    return filtered[0]


@app.get("/behavioral-activation/today")
def get_today_behavioral_task(
    authorization: Optional[str] = Header(None),
    x_timezone_offset_minutes: int = Header(0, ge=-840, le=840),
):
    """Returns today's single assigned task for the authenticated user, or creates one deterministically."""
    user = require_user(authorization)
    user_id = user["id"]
    today_str = _local_date_for_offset(x_timezone_offset_minutes)

    conn = connect_db_connection()
    c = conn.cursor()

    # Look for existing task for today
    c.execute(
        """SELECT t.id, t.user_id, t.activity_id, t.task_date, t.status,
                  t.completed_at, t.mood_before, t.mood_after, t.created_at,
                  a.title, a.description, a.category, a.difficulty, a.duration_minutes
           FROM BEHAVIORAL_DAILY_TASKS t
           JOIN BEHAVIORAL_ACTIVITIES a ON t.activity_id = a.id
           WHERE t.user_id = ? AND t.task_date = ?""",
        (user_id, today_str),
    )
    row = c.fetchone()
    if row:
        conn.close()
        return _format_task_response(row)

    # Need to assign a new task
    activity = _select_activity_for_user(c, user_id, today_str=today_str)
    if not activity:
        conn.close()
        raise HTTPException(status_code=404, detail="No behavioral activities found.")

    task_id = uuid.uuid4().hex
    created_at = now()
    try:
        c.execute(
            """INSERT INTO BEHAVIORAL_DAILY_TASKS
            (id, user_id, activity_id, task_date, status, created_at)
            VALUES (?, ?, ?, ?, 'pending', ?)""",
            (task_id, user_id, activity["id"], today_str, created_at),
        )
        conn.commit()
    except (IntegrityError, sqlite3.IntegrityError):
        # The unique key is the final safeguard if two requests arrive at once.
        # Roll back the failed insert, then return the assignment that won.
        conn.rollback()
        c.execute(
            """SELECT t.id, t.user_id, t.activity_id, t.task_date, t.status,
                      t.completed_at, t.mood_before, t.mood_after, t.created_at,
                      a.title, a.description, a.category, a.difficulty, a.duration_minutes
               FROM BEHAVIORAL_DAILY_TASKS t
               JOIN BEHAVIORAL_ACTIVITIES a ON t.activity_id = a.id
               WHERE t.user_id = ? AND t.task_date = ?""",
            (user_id, today_str),
        )
        row = c.fetchone()
        conn.close()
        if row:
            return _format_task_response(row)
        raise

    row = _fetch_behavioral_task_row(c, task_id)
    conn.close()
    return _format_task_response(row)


@app.post("/behavioral-activation/tasks/{task_id}/complete")
def complete_behavioral_task(
    task_id: str,
    authorization: Optional[str] = Header(None),
):
    """Mark a pending task complete, preserving an existing completion."""
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()

    try:
        task = _get_owned_behavioral_task(c, task_id, user["id"])
    except HTTPException:
        conn.close()
        raise

    if task["status"] == "completed":
        row = _fetch_behavioral_task_row(c, task_id)
        conn.close()
        return _format_task_response(row)
    if task["status"] != "pending":
        conn.close()
        raise HTTPException(
            status_code=409,
            detail="Only a pending task can be completed.",
        )

    completed_time = now()
    c.execute(
        """UPDATE BEHAVIORAL_DAILY_TASKS
           SET status = 'completed', completed_at = ?
           WHERE id = ? AND user_id = ? AND status = 'pending'""",
        (completed_time, task_id, user["id"]),
    )
    changed = c.rowcount
    conn.commit()

    updated_row = _fetch_behavioral_task_row(c, task_id)
    conn.close()
    if changed == 0 and updated_row[4] != "completed":
        raise HTTPException(
            status_code=409,
            detail="Only a pending task can be completed.",
        )
    return _format_task_response(updated_row)


@app.post("/behavioral-activation/tasks/{task_id}/skip")
def skip_behavioral_task(
    task_id: str,
    authorization: Optional[str] = Header(None),
):
    """Marks the given task as skipped without shaming or penalty."""
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()

    try:
        task = _get_owned_behavioral_task(c, task_id, user["id"])
    except HTTPException:
        conn.close()
        raise

    if task["status"] == "skipped":
        row = _fetch_behavioral_task_row(c, task_id)
        conn.close()
        return _format_task_response(row)
    if task["status"] != "pending":
        conn.close()
        raise HTTPException(
            status_code=409,
            detail="A completed task cannot be skipped.",
        )

    c.execute(
        """UPDATE BEHAVIORAL_DAILY_TASKS
           SET status = 'skipped'
           WHERE id = ? AND user_id = ? AND status = 'pending'""",
        (task_id, user["id"]),
    )
    changed = c.rowcount
    conn.commit()

    updated_row = _fetch_behavioral_task_row(c, task_id)
    conn.close()
    if changed == 0 and updated_row[4] != "skipped":
        raise HTTPException(
            status_code=409,
            detail="Only a pending task can be skipped.",
        )
    return _format_task_response(updated_row)


@app.post("/behavioral-activation/tasks/{task_id}/mood")
def record_behavioral_task_mood(
    task_id: str,
    req: BehavioralMoodRequest,
    authorization: Optional[str] = Header(None),
):
    """Record an optional 1–5 feeling rating around an owned task."""
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()

    try:
        task = _get_owned_behavioral_task(c, task_id, user["id"])
    except HTTPException:
        conn.close()
        raise

    if req.mood_before is not None and task["status"] != "pending":
        conn.close()
        raise HTTPException(
            status_code=409,
            detail="A before-action rating can only be added while the task is pending.",
        )
    if req.mood_after is not None and task["status"] != "completed":
        conn.close()
        raise HTTPException(
            status_code=409,
            detail="Complete the task before adding an after-action rating.",
        )

    if req.mood_before is not None:
        c.execute(
            """UPDATE BEHAVIORAL_DAILY_TASKS SET mood_before = ?
               WHERE id = ? AND user_id = ? AND status = 'pending'""",
            (req.mood_before, task_id, user["id"]),
        )
    elif req.mood_after is not None:
        c.execute(
            """UPDATE BEHAVIORAL_DAILY_TASKS SET mood_after = ?
               WHERE id = ? AND user_id = ? AND status = 'completed'""",
            (req.mood_after, task_id, user["id"]),
        )

    changed = c.rowcount
    conn.commit()

    updated_row = _fetch_behavioral_task_row(c, task_id)
    conn.close()
    if changed == 0:
        rating_already_saved = (
            req.mood_before is not None
            and updated_row[4] == "pending"
            and updated_row[6] == req.mood_before
        ) or (
            req.mood_after is not None
            and updated_row[4] == "completed"
            and updated_row[7] == req.mood_after
        )
        if rating_already_saved:
            return _format_task_response(updated_row)
        raise HTTPException(
            status_code=409,
            detail="The task changed before the mood rating could be saved.",
        )
    return _format_task_response(updated_row)


@app.post("/behavioral-activation/tasks/{task_id}/change")
def change_behavioral_task(
    task_id: str,
    authorization: Optional[str] = Header(None),
    x_timezone_offset_minutes: int = Header(0, ge=-840, le=840),
):
    """Swaps today's assigned activity with another suitable one without creating multiple daily rows."""
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()

    try:
        task = _get_owned_behavioral_task(c, task_id, user["id"])
    except HTTPException:
        conn.close()
        raise

    today_str = _local_date_for_offset(x_timezone_offset_minutes)
    if task["status"] != "pending" or task["task_date"] != today_str:
        conn.close()
        raise HTTPException(
            status_code=409,
            detail="Only today's pending task can be changed.",
        )

    current_activity_id = task["activity_id"]
    # Pick a new activity excluding current one
    new_activity = _select_activity_for_user(
        c,
        user["id"],
        exclude_activity_ids=[current_activity_id],
        today_str=today_str,
    )
    if not new_activity:
        conn.close()
        raise HTTPException(status_code=400, detail="No alternative activities available")

    # Update existing record in place
    c.execute(
        """UPDATE BEHAVIORAL_DAILY_TASKS
           SET activity_id = ?
           WHERE id = ? AND user_id = ? AND status = 'pending' AND task_date = ?""",
        (new_activity["id"], task_id, user["id"], today_str),
    )
    changed = c.rowcount
    conn.commit()

    updated_row = _fetch_behavioral_task_row(c, task_id)
    conn.close()
    if changed == 0:
        raise HTTPException(
            status_code=409,
            detail="Only today's pending task can be changed.",
        )
    return _format_task_response(updated_row)


@app.get("/behavioral-activation/history")
def get_behavioral_history(
    days: Optional[int] = None,
    limit: int = 30,
    authorization: Optional[str] = Header(None),
    x_timezone_offset_minutes: int = Header(0, ge=-840, le=840),
):
    """Returns task history for the authenticated user."""
    user = require_user(authorization)
    if days is not None and not 1 <= days <= 365:
        raise HTTPException(status_code=400, detail="days must be between 1 and 365")
    if not 1 <= limit <= 100:
        raise HTTPException(status_code=400, detail="limit must be between 1 and 100")
    conn = connect_db_connection()
    c = conn.cursor()

    if days:
        local_today = datetime.strptime(
            _local_date_for_offset(x_timezone_offset_minutes), "%Y-%m-%d"
        )
        cutoff = (local_today - timedelta(days=days - 1)).strftime("%Y-%m-%d")
        c.execute(
            """SELECT t.id, t.user_id, t.activity_id, t.task_date, t.status,
                      t.completed_at, t.mood_before, t.mood_after, t.created_at,
                      a.title, a.description, a.category, a.difficulty, a.duration_minutes
               FROM BEHAVIORAL_DAILY_TASKS t
               JOIN BEHAVIORAL_ACTIVITIES a ON t.activity_id = a.id
               WHERE t.user_id = ? AND t.task_date >= ?
               ORDER BY t.task_date DESC, t.created_at DESC LIMIT ?""",
            (user["id"], cutoff, limit),
        )
    else:
        c.execute(
            """SELECT t.id, t.user_id, t.activity_id, t.task_date, t.status,
                      t.completed_at, t.mood_before, t.mood_after, t.created_at,
                      a.title, a.description, a.category, a.difficulty, a.duration_minutes
               FROM BEHAVIORAL_DAILY_TASKS t
               JOIN BEHAVIORAL_ACTIVITIES a ON t.activity_id = a.id
               WHERE t.user_id = ?
               ORDER BY t.task_date DESC, t.created_at DESC LIMIT ?""",
            (user["id"], limit),
        )

    rows = c.fetchall()
    conn.close()
    return [_format_task_response(r) for r in rows]


@app.get("/behavioral-activation/stats")
def get_behavioral_stats(
    days: int = 7,
    authorization: Optional[str] = Header(None),
    x_timezone_offset_minutes: int = Header(0, ge=-840, le=840),
):
    """Returns lightweight completion stats and pattern insights."""
    user = require_user(authorization)
    if not 1 <= days <= 365:
        raise HTTPException(status_code=400, detail="days must be between 1 and 365")
    conn = connect_db_connection()
    c = conn.cursor()

    local_today = datetime.strptime(
        _local_date_for_offset(x_timezone_offset_minutes), "%Y-%m-%d"
    )
    cutoff = (local_today - timedelta(days=days - 1)).strftime("%Y-%m-%d")
    c.execute(
        """SELECT status, task_date FROM BEHAVIORAL_DAILY_TASKS
        WHERE user_id = ? AND task_date >= ?""",
        (user["id"], cutoff),
    )
    rows = c.fetchall()

    # Active days are scoped to the selected period so the value matches the
    # weekly/monthly summary shown to the user.
    c.execute(
        """SELECT COUNT(DISTINCT task_date) FROM BEHAVIORAL_DAILY_TASKS
        WHERE user_id = ? AND status = 'completed' AND task_date >= ?""",
        (user["id"], cutoff),
    )
    total_active_days_row = c.fetchone()
    total_active_days = total_active_days_row[0] if total_active_days_row else 0

    conn.close()

    completed_count = sum(1 for r in rows if r[0] == "completed")
    skipped_count = sum(1 for r in rows if r[0] == "skipped")
    pending_count = sum(1 for r in rows if r[0] == "pending")
    total_period = len(rows)

    completion_rate = round((completed_count / max(1, completed_count + skipped_count)) * 100, 1) if (completed_count + skipped_count) > 0 else 0.0

    return {
        "period_days": days,
        "completed_count": completed_count,
        "skipped_count": skipped_count,
        "pending_count": pending_count,
        "total_tasks": total_period,
        "completion_rate": completion_rate,
        "number_of_active_days": total_active_days,
        "days_in_period": days,
    }


# =====================================================================
# FEATURE: Savoring Logs — "Three Good Things" Optimism Module
# =====================================================================

def _fetch_savoring_log_row(c, log_id: str):
    c.execute(
        """SELECT id, user_id, log_date, status, completed_at,
                  created_at, updated_at
           FROM SAVORING_LOGS WHERE id = ?""",
        (log_id,),
    )
    return c.fetchone()


def _get_owned_savoring_log(c, log_id: str, user_id: str):
    row = _fetch_savoring_log_row(c, log_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Savoring log not found.")
    if row[1] != user_id:
        raise HTTPException(status_code=403, detail="You cannot access this savoring log.")
    return row


def _format_savoring_log(c, row):
    c.execute(
        """SELECT entry_order, positive_event, why_happened
           FROM SAVORING_ENTRIES
           WHERE log_id = ?
           ORDER BY entry_order ASC""",
        (row[0],),
    )
    entries = [
        {
            "position": entry[0],
            "positive_event": entry[1],
            "why_happened": entry[2],
        }
        for entry in c.fetchall()
    ]
    return {
        "id": row[0],
        "user_id": row[1],
        "log_date": row[2],
        "status": row[3],
        "completed_at": row[4],
        "created_at": row[5],
        "updated_at": row[6],
        "entries": entries,
    }


def _write_savoring_entries(c, log_id: str, entries, timestamp: str):
    for entry in sorted(entries, key=lambda item: item.position):
        c.execute(
            """UPDATE SAVORING_ENTRIES
               SET positive_event = ?, why_happened = ?, updated_at = ?
               WHERE log_id = ? AND entry_order = ?""",
            (
                entry.positive_event.strip(),
                entry.why_happened.strip(),
                timestamp,
                log_id,
                entry.position,
            ),
        )


@app.get("/savoring/today")
def get_today_savoring_log(
    authorization: Optional[str] = Header(None),
    x_timezone_offset_minutes: int = Header(0, ge=-840, le=840),
):
    """Return today's private log, creating its three blank slots when needed."""
    user = require_user(authorization)
    log_date = _local_date_for_offset(x_timezone_offset_minutes)
    conn = connect_db_connection()
    c = conn.cursor()

    c.execute(
        """SELECT id, user_id, log_date, status, completed_at,
                  created_at, updated_at
           FROM SAVORING_LOGS
           WHERE user_id = ? AND log_date = ?""",
        (user["id"], log_date),
    )
    row = c.fetchone()

    if row is None:
        log_id = uuid.uuid4().hex
        timestamp = now()
        try:
            c.execute(
                """INSERT INTO SAVORING_LOGS
                   (id, user_id, log_date, status, completed_at, created_at, updated_at)
                   VALUES (?, ?, ?, 'draft', NULL, ?, ?)""",
                (log_id, user["id"], log_date, timestamp, timestamp),
            )
            for position in range(1, 4):
                c.execute(
                    """INSERT INTO SAVORING_ENTRIES
                       (id, log_id, entry_order, positive_event, why_happened,
                        created_at, updated_at)
                       VALUES (?, ?, ?, '', '', ?, ?)""",
                    (
                        uuid.uuid4().hex,
                        log_id,
                        position,
                        timestamp,
                        timestamp,
                    ),
                )
            conn.commit()
            row = _fetch_savoring_log_row(c, log_id)
        except (IntegrityError, sqlite3.IntegrityError):
            # A simultaneous request may have created today's unique row first.
            conn.rollback()
            c.execute(
                """SELECT id, user_id, log_date, status, completed_at,
                          created_at, updated_at
                   FROM SAVORING_LOGS
                   WHERE user_id = ? AND log_date = ?""",
                (user["id"], log_date),
            )
            row = c.fetchone()

    if row is None:
        conn.close()
        raise HTTPException(status_code=500, detail="Could not load today's savoring log.")
    response = _format_savoring_log(c, row)
    conn.close()
    return response


@app.put("/savoring/logs/{log_id}")
def save_savoring_log(
    log_id: str,
    req: SaveSavoringLogRequest,
    authorization: Optional[str] = Header(None),
):
    """Save an unfinished private log without requiring every field yet."""
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()
    try:
        row = _get_owned_savoring_log(c, log_id, user["id"])
    except HTTPException:
        conn.close()
        raise

    if row[3] == "completed":
        conn.close()
        raise HTTPException(status_code=409, detail="A completed log cannot be edited.")

    timestamp = now()
    c.execute(
        """UPDATE SAVORING_LOGS SET updated_at = ?
           WHERE id = ? AND user_id = ? AND status = 'draft'""",
        (timestamp, log_id, user["id"]),
    )
    changed = c.rowcount
    if changed == 0:
        conn.rollback()
        conn.close()
        raise HTTPException(status_code=409, detail="A completed log cannot be edited.")
    # The conditional parent update holds the row for this transaction before
    # any entry is changed, so a simultaneous completion cannot be overwritten.
    _write_savoring_entries(c, log_id, req.entries, timestamp)
    conn.commit()
    updated = _fetch_savoring_log_row(c, log_id)
    response = _format_savoring_log(c, updated)
    conn.close()
    return response


@app.post("/savoring/logs/{log_id}/complete")
def complete_savoring_log(
    log_id: str,
    req: SaveSavoringLogRequest,
    authorization: Optional[str] = Header(None),
):
    """Complete a log only when all three event-and-reason pairs are present."""
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()
    try:
        row = _get_owned_savoring_log(c, log_id, user["id"])
    except HTTPException:
        conn.close()
        raise

    if row[3] == "completed":
        response = _format_savoring_log(c, row)
        conn.close()
        return response

    missing_positions = [
        entry.position
        for entry in req.entries
        if not entry.positive_event.strip() or not entry.why_happened.strip()
    ]
    if missing_positions:
        conn.close()
        raise HTTPException(
            status_code=422,
            detail="Add both a good thing and why it happened for all three cards.",
        )

    timestamp = now()
    c.execute(
        """UPDATE SAVORING_LOGS
           SET status = 'completed', completed_at = ?, updated_at = ?
           WHERE id = ? AND user_id = ? AND status = 'draft'""",
        (timestamp, timestamp, log_id, user["id"]),
    )
    changed = c.rowcount
    if changed == 0:
        conn.rollback()
        updated = _fetch_savoring_log_row(c, log_id)
        if updated is not None and updated[3] == "completed":
            response = _format_savoring_log(c, updated)
            conn.close()
            return response
        conn.close()
        raise HTTPException(status_code=409, detail="This savoring log changed before it could be completed.")
    # Claim the draft state first, then persist the entries in the same
    # transaction so completion and its content are atomic.
    _write_savoring_entries(c, log_id, req.entries, timestamp)
    conn.commit()
    updated = _fetch_savoring_log_row(c, log_id)
    response = _format_savoring_log(c, updated)
    conn.close()
    return response


@app.get("/savoring/history")
def get_savoring_history(
    days: Optional[int] = None,
    limit: int = 30,
    authorization: Optional[str] = Header(None),
    x_timezone_offset_minutes: int = Header(0, ge=-840, le=840),
):
    """Return only this user's completed savoring logs, newest first."""
    user = require_user(authorization)
    if days is not None and not 1 <= days <= 365:
        raise HTTPException(status_code=400, detail="days must be between 1 and 365")
    if not 1 <= limit <= 100:
        raise HTTPException(status_code=400, detail="limit must be between 1 and 100")

    conn = connect_db_connection()
    c = conn.cursor()
    params = [user["id"]]
    where = "WHERE user_id = ? AND status = 'completed'"
    if days is not None:
        local_today = datetime.strptime(
            _local_date_for_offset(x_timezone_offset_minutes), "%Y-%m-%d"
        )
        cutoff = (local_today - timedelta(days=days - 1)).strftime("%Y-%m-%d")
        where += " AND log_date >= ?"
        params.append(cutoff)
    params.append(limit)
    c.execute(
        f"""SELECT id, user_id, log_date, status, completed_at,
                   created_at, updated_at
            FROM SAVORING_LOGS {where}
            ORDER BY log_date DESC, created_at DESC LIMIT ?""",
        tuple(params),
    )
    rows = c.fetchall()
    response = [_format_savoring_log(c, row) for row in rows]
    conn.close()
    return response
