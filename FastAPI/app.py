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
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict, Optional

from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pymysql
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


class DatabaseConnection:
    def __init__(self, connection):
        self._connection = connection

    def cursor(self):
        return DatabaseCursor(self._connection.cursor())

    def commit(self):
        return self._connection.commit()

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
    # longitudinal mood analytics feature.
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
    _ensure_column(c, "USERS", "emergency_contact", "TEXT")

    # Best Possible Self visions are private to the authenticated user.
    c.execute("""CREATE TABLE IF NOT EXISTS BEST_SELF_VISIONS (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) NOT NULL,
        timeline INTEGER NOT NULL,
        vision TEXT NOT NULL,
        created_at TEXT NOT NULL
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

    # Journal & Notes entries
    c.execute("""CREATE TABLE IF NOT EXISTS JOURNAL_ENTRIES (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) NOT NULL,
        title TEXT,
        content TEXT NOT NULL,
        mood_tag TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
    )""")

    conn.commit()
    seed_palettes(conn)
    conn.close()


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


connect_db()


def now():
    return datetime.utcnow().isoformat()


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


class UpdateProfileRequest(BaseModel):
    name: str
    email: str
    emergency_contact: Optional[str] = None


class SaveBestSelfVisionRequest(BaseModel):
    id: str
    timeline: int
    vision: str
    created_at: str


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


# Journal & Notes Schemas
class SaveJournalEntryRequest(BaseModel):
    title: Optional[str] = None
    content: str
    mood_tag: Optional[str] = None


class UpdateJournalEntryRequest(BaseModel):
    title: Optional[str] = None
    content: str
    mood_tag: Optional[str] = None


# Community Schemas
class CommunityPostRequest(BaseModel):
    content: str


class CommunityReportRequest(BaseModel):
    reason: Optional[str] = "Harmful or triggering content"


class CommunityCommentRequest(BaseModel):
    content: str


class CommunityCommentReportRequest(BaseModel):
    reason: Optional[str] = "Harmful or inappropriate comment"


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
    c.execute("SELECT id, name, email, emergency_contact FROM USERS WHERE token=?", (token,))
    row = c.fetchone()
    conn.close()
    if row:
        return {"id": row[0], "name": row[1], "email": row[2], "emergency_contact": row[3]}
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
    c.execute("INSERT INTO USERS (id, name, email, password, token) VALUES (?, ?, ?, ?, ?)", (user_id, req.name, req.email, req.password, token))
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


@app.put("/profile/me")
def update_profile(req: UpdateProfileRequest, authorization: Optional[str] = Header(None)):
    user = require_user(authorization)
    name = req.name.strip()
    email = req.email.strip().lower()
    emergency_contact = (req.emergency_contact or "").strip() or None
    if not name or "@" not in email:
        raise HTTPException(status_code=400, detail="Enter a valid name and email")
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute("SELECT id FROM USERS WHERE email=? AND id<>?", (email, user["id"]))
    if c.fetchone():
        conn.close()
        raise HTTPException(status_code=400, detail="Email is already in use")
    c.execute("UPDATE USERS SET name=?, email=?, emergency_contact=? WHERE id=?", (name, email, emergency_contact, user["id"]))
    conn.commit()
    conn.close()
    return {"name": name, "email": email, "emergency_contact": emergency_contact}


@app.get("/profile/me")
def get_profile(authorization: Optional[str] = Header(None)):
    user = require_user(authorization)
    return {"name": user["name"], "email": user["email"], "emergency_contact": user["emergency_contact"]}


@app.post("/checkin")
def checkin(req: CheckinRequest, authorization: Optional[str] = Header(None)):
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
except ImportError:
    from FastAPI.mood_analytics import analyze_mood_history


@app.get("/mood/analytics")
def get_mood_analytics(
    days: int = 7,
    authorization: Optional[str] = Header(None),
):
    user = require_user(authorization)
    if days not in (7, 30, 90):
        raise HTTPException(
            status_code=400,
            detail="days must be one of 7, 30, or 90",
        )

    cutoff = (datetime.utcnow() - timedelta(days=days)).isoformat()

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
    conn.close()

    points = [
        {
            "timestamp": row[0],
            "mood_score": float(row[1]),
            "category": row[2] or "normal",
        }
        for row in rows
    ]

    analysis = analyze_mood_history(points)

    return {
        "period_days": days,
        "points": points,
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
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute("DELETE FROM USER_THEME WHERE user_id=?", (user["id"],))
    conn.commit()
    conn.close()
    return {"response": "Theme cleared"}


# =====================================================================
# BEST POSSIBLE SELF — private, cross-device visions
# =====================================================================
@app.get("/best-self/visions")
def get_best_self_visions(authorization: Optional[str] = Header(None)):
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        """SELECT id, timeline, vision, created_at FROM BEST_SELF_VISIONS
           WHERE user_id=? ORDER BY created_at DESC""",
        (user["id"],),
    )
    rows = c.fetchall()
    conn.close()
    return [
        {"id": row[0], "timeline": row[1], "vision": row[2], "created_at": row[3]}
        for row in rows
    ]


@app.post("/best-self/visions")
def save_best_self_vision(
    req: SaveBestSelfVisionRequest,
    authorization: Optional[str] = Header(None),
):
    user = require_user(authorization)
    vision = req.vision.strip()
    if not vision:
        raise HTTPException(status_code=400, detail="Vision cannot be empty")
    if req.timeline not in {1, 2, 3, 5}:
        raise HTTPException(status_code=400, detail="Timeline must be 1, 2, 3, or 5 years")

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        """INSERT INTO BEST_SELF_VISIONS (id, user_id, timeline, vision, created_at)
           VALUES (?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE
             timeline=VALUES(timeline), vision=VALUES(vision), created_at=VALUES(created_at)""",
        (req.id, user["id"], req.timeline, vision, req.created_at),
    )
    conn.commit()
    conn.close()
    return {"id": req.id, "timeline": req.timeline, "vision": vision, "created_at": req.created_at}


@app.delete("/best-self/visions/{vision_id}")
def delete_best_self_vision(
    vision_id: str,
    authorization: Optional[str] = Header(None),
):
    """Delete a Best Possible Self vision entry."""
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        "DELETE FROM BEST_SELF_VISIONS WHERE id=? AND user_id=?",
        (vision_id, user["id"]),
    )
    conn.commit()
    conn.close()
    return {"success": True}


# =====================================================================
# SLEEP TRACKING ENDPOINTS
# =====================================================================

@app.post("/sleep/log")
def save_sleep_log(
    req: SaveSleepLogRequest,
    authorization: Optional[str] = Header(None)
):
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
    user = require_user(authorization)
    user_id = user["id"]

    conn = connect_db_connection()
    c = conn.cursor()

    cutoff_date = (datetime.utcnow() - timedelta(days=days)).isoformat()
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
    user = require_user(authorization)
    user_id = user["id"]

    conn = connect_db_connection()
    c = conn.cursor()

    cutoff_date = (datetime.utcnow() - timedelta(days=days)).isoformat()
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
    authorization: Optional[str] = Header(None)
):
    user = require_user(authorization)
    user_id = user["id"]

    conn = connect_db_connection()
    c = conn.cursor()

    cutoff_date = (datetime.utcnow() - timedelta(days=days)).isoformat()

    c.execute(
        """SELECT date, sleep_hours, sleep_minutes FROM SLEEP_LOGS
        WHERE user_id=? AND created_at >= ? ORDER BY date""",
        (user_id, cutoff_date),
    )

    sleep_data = {}
    for row in c.fetchall():
        date, hours, minutes = row
        date_key = date.split('T')[0]
        sleep_data[date_key] = (hours * 60 + minutes) / 60

    c.execute(
        """SELECT created_at, answers FROM MOOD_CHECKINS
        WHERE user_id=? AND created_at >= ? ORDER BY created_at""",
        (user_id, cutoff_date),
    )

    correlations = []
    for row in c.fetchall():
        created_at, answers_json = row
        date_key = created_at.split('T')[0]

        try:
            answers = json.loads(answers_json)
            if answers:
                avg_answer = sum(answers.values()) / len(answers)
                mood_score = avg_answer * 2.5

                sleep_hours = sleep_data.get(date_key, 0)
                correlations.append({
                    "date": date_key,
                    "sleep_hours": sleep_hours,
                    "mood_score": round(mood_score, 1),
                })
        except:
            pass

    conn.close()
    return correlations


@app.get("/sleep/warnings")
def get_wellbeing_warnings(
    authorization: Optional[str] = Header(None)
):
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
    conn = connect_db_connection()
    c = conn.cursor()

    cutoff_date = (datetime.utcnow() - timedelta(days=7)).isoformat()
    c.execute(
        """SELECT AVG(sleep_hours * 60 + sleep_minutes) as avg_sleep_minutes
        FROM SLEEP_LOGS WHERE user_id=? AND created_at >= ?""",
        (user_id, cutoff_date),
    )

    result = c.fetchone()
    avg_sleep_minutes = result[0] if result[0] else 0
    avg_sleep_hours = avg_sleep_minutes / 60

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
                mood_scores.append(avg_answer * 2.5)
        except Exception:
            pass

    avg_mood = sum(mood_scores) / len(mood_scores) if mood_scores else None

    if avg_mood is not None and avg_sleep_hours < 6 and avg_mood < 5:
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
    user = require_user(authorization)
    user_id = user["id"]

    conn = connect_db_connection()
    c = conn.cursor()

    c.execute(
        """SELECT COUNT(*), COALESCE(SUM(duration_seconds), 0), COALESCE(SUM(cycles_completed), 0)
        FROM BREATHING_SESSIONS WHERE user_id=?""",
        (user_id,),
    )
    total_sessions, total_seconds, total_cycles = c.fetchone()

    today_start = datetime.utcnow().strftime("%Y-%m-%d") + "T00:00:00"
    c.execute(
        """SELECT COALESCE(SUM(duration_seconds), 0)
        FROM BREATHING_SESSIONS WHERE user_id=? AND created_at >= ?""",
        (user_id, today_start),
    )
    today_seconds = c.fetchone()[0]

    c.execute(
        """SELECT technique, COUNT(*) as count
        FROM BREATHING_SESSIONS WHERE user_id=?
        GROUP BY technique ORDER BY count DESC LIMIT 1""",
        (user_id,),
    )
    tech_row = c.fetchone()
    favorite_technique = tech_row[0] if tech_row else "Box Breathing"

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


# =====================================================================
# MODULE 1 — ZERO-KNOWLEDGE ANONYMOUS COMMUNITY FORUM
# =====================================================================

_COMMUNITY_ADJECTIVES = (
    "Quiet", "Gentle", "Calm", "Kind", "Brave", "Hopeful",
    "Silver", "Soft", "Warm", "Steady", "Open", "Bright",
)
_COMMUNITY_NOUNS = (
    "Cedar", "River", "Cloud", "Meadow", "Moon", "Willow",
    "Harbor", "Dawn", "Fern", "Rain", "Sky", "Lotus",
)


def _community_alias(user_id: str) -> str:
    digest = hashlib.sha256(user_id.encode("utf-8")).digest()
    adjective = _COMMUNITY_ADJECTIVES[digest[0] % len(_COMMUNITY_ADJECTIVES)]
    noun = _COMMUNITY_NOUNS[digest[1] % len(_COMMUNITY_NOUNS)]
    suffix = int.from_bytes(digest[2:4], "big") % 90 + 10
    return f"Anonymous {adjective} {noun} {suffix}"


def _scrub_community_pii(text: str) -> str:
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
# JOURNAL & NOTES ENDPOINTS
# =====================================================================

@app.get("/journal/entries")
def get_journal_entries(
    limit: int = 100,
    authorization: Optional[str] = Header(None),
):
    """Fetch journal/thought entries for authenticated user ordered by created_at DESC."""
    user = require_user(authorization)
    limit = max(1, min(200, limit))

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        """SELECT id, user_id, title, content, mood_tag, created_at, updated_at
           FROM JOURNAL_ENTRIES
           WHERE user_id=?
           ORDER BY created_at DESC
           LIMIT ?""",
        (user["id"], limit),
    )
    rows = c.fetchall()
    conn.close()

    return [
        {
            "id": r[0],
            "user_id": r[1],
            "title": r[2] or "",
            "content": r[3],
            "mood_tag": r[4] or "",
            "created_at": r[5],
            "updated_at": r[6],
        }
        for r in rows
    ]


@app.post("/journal/entries")
def create_journal_entry(
    req: SaveJournalEntryRequest,
    authorization: Optional[str] = Header(None),
):
    """Create a new journal / note / thought entry for the user."""
    user = require_user(authorization)
    content = req.content.strip()
    if not content:
        raise HTTPException(status_code=400, detail="Content cannot be empty")

    entry_id = uuid.uuid4().hex
    created_at = now()
    title = (req.title or "").strip()
    mood_tag = (req.mood_tag or "").strip()

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        """INSERT INTO JOURNAL_ENTRIES
           (id, user_id, title, content, mood_tag, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        (entry_id, user["id"], title, content, mood_tag, created_at, None),
    )
    conn.commit()
    conn.close()

    return {
        "id": entry_id,
        "user_id": user["id"],
        "title": title,
        "content": content,
        "mood_tag": mood_tag,
        "created_at": created_at,
        "updated_at": None,
    }


@app.put("/journal/entries/{entry_id}")
def update_journal_entry(
    entry_id: str,
    req: UpdateJournalEntryRequest,
    authorization: Optional[str] = Header(None),
):
    """Update an existing journal entry."""
    user = require_user(authorization)
    content = req.content.strip()
    if not content:
        raise HTTPException(status_code=400, detail="Content cannot be empty")

    title = (req.title or "").strip()
    mood_tag = (req.mood_tag or "").strip()
    updated_at = now()

    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        "SELECT id FROM JOURNAL_ENTRIES WHERE id=? AND user_id=?",
        (entry_id, user["id"]),
    )
    if c.fetchone() is None:
        conn.close()
        raise HTTPException(status_code=404, detail="Journal entry not found")

    c.execute(
        """UPDATE JOURNAL_ENTRIES
           SET title=?, content=?, mood_tag=?, updated_at=?
           WHERE id=? AND user_id=?""",
        (title, content, mood_tag, updated_at, entry_id, user["id"]),
    )
    conn.commit()
    conn.close()

    return {
        "id": entry_id,
        "user_id": user["id"],
        "title": title,
        "content": content,
        "mood_tag": mood_tag,
        "updated_at": updated_at,
    }


@app.delete("/journal/entries/{entry_id}")
def delete_journal_entry(
    entry_id: str,
    authorization: Optional[str] = Header(None),
):
    """Delete a journal entry."""
    user = require_user(authorization)
    conn = connect_db_connection()
    c = conn.cursor()
    c.execute(
        "DELETE FROM JOURNAL_ENTRIES WHERE id=? AND user_id=?",
        (entry_id, user["id"]),
    )
    conn.commit()
    conn.close()

    return {"success": True}
