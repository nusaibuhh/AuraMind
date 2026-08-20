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
import sqlite3
import uuid
from datetime import datetime
import os
from datetime import datetime, timedelta
from typing import List, Dict, Optional

from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="AuraMind API")
DB_NAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), "auramind.db")
DB_NAME = str((__import__("pathlib").Path(__file__).resolve().parent / "auramind.db"))

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
def _ensure_column(cursor, table: str, column: str, column_type: str):
    """Add a column to an existing SQLite table without destroying team data."""
    cursor.execute(f"PRAGMA table_info({table})")
    columns = {row[1] for row in cursor.fetchall()}
    if column not in columns:
        cursor.execute(
            f"ALTER TABLE {table} ADD COLUMN {column} {column_type}"
        )

def connect_db():
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    # Users for simple auth
    c.execute("""CREATE TABLE IF NOT EXISTS USERS (
        id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT UNIQUE,
        password TEXT,
        token TEXT
    )""")

    # Store raw check-ins and the normalized wellbeing score used by the
    # longitudinal mood analytics feature.  The migration below keeps older
    # team databases compatible by adding the new columns when needed.
    c.execute("""CREATE TABLE IF NOT EXISTS MOOD_CHECKINS (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        answers TEXT,
        created_at TEXT
    )""")

    _ensure_column(c, "MOOD_CHECKINS", "mood_score", "REAL")
    _ensure_column(c, "MOOD_CHECKINS", "dominant_category", "TEXT")

    # Theme palettes (detailed schema expected by frontend)
    c.execute("""CREATE TABLE IF NOT EXISTS THEME_PALETTES (
        id TEXT PRIMARY KEY,
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
        user_id TEXT PRIMARY KEY,
        palette_id TEXT,
        selected_at TEXT
    )""")

    # --- Feature 2 tables ---
    c.execute("""CREATE TABLE IF NOT EXISTS GROUNDING_SESSIONS (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        created_at TEXT,
        completed INTEGER DEFAULT 0
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS GROUNDING_ENTRIES (
        id TEXT PRIMARY KEY,
        session_id TEXT,
        category TEXT,
        item_text TEXT
    )""")

    # Sleep Tracking tables
    c.execute("""CREATE TABLE IF NOT EXISTS SLEEP_LOGS (
        id TEXT PRIMARY KEY,
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
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT,
        message TEXT,
        created_at TEXT,
        is_dismissed INTEGER DEFAULT 0
    )""")

    # Breathing Exercise Sessions
    c.execute("""CREATE TABLE IF NOT EXISTS BREATHING_SESSIONS (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        technique TEXT,
        duration_seconds INTEGER,
        cycles_completed INTEGER,
        background_sound TEXT,
        mood_after TEXT,
        created_at TEXT
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


# ---------- Helper auth utilities
def _extract_token(auth_header: Optional[str]) -> Optional[str]:
    if not auth_header:
        return None
    parts = auth_header.split()
    if len(parts) == 2 and parts[0].lower() == "bearer":
        return parts[1]
    return None


def get_user_by_token(token: str) -> Optional[Dict]:
    conn = sqlite3.connect(DB_NAME)
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
    conn = sqlite3.connect(DB_NAME)
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
    conn = sqlite3.connect(DB_NAME)
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

    conn = sqlite3.connect(DB_NAME)
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
        c.execute("SELECT * FROM THEME_PALETTES ORDER BY RANDOM() LIMIT 3")
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

    cutoff = (datetime.utcnow() - timedelta(days=days)).isoformat()

    conn = sqlite3.connect(DB_NAME)
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
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute("INSERT OR REPLACE INTO USER_THEME VALUES (?, ?, ?)", (user["id"], req.palette_id, now()))
    conn.commit()
    conn.close()
    return {"response": "Theme saved"}


@app.get("/themes/selected/me")
def api_fetch_selected_theme(authorization: Optional[str] = Header(None)):
    user = require_user(authorization)
    conn = sqlite3.connect(DB_NAME)
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
    conn = sqlite3.connect(DB_NAME)
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
def start_grounding_session(req: StartSessionRequest):
    session_id = uuid.uuid4().hex
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute(
        "INSERT INTO GROUNDING_SESSIONS VALUES (?, ?, ?, 0)",
        (session_id, req.user_id, now()),
    )
    conn.commit()
    conn.close()

    return {"response": "Session started", "session_id": session_id}


# ---- 2. Submit items for one step (sight/touch/hear/smell/taste) -------
# POST /addGroundingEntries
# Body: { "session_id": "...", "category": "sight", "items": ["tree","sky","lamp","chair","phone"] }
# category must be one of: sight, touch, hear, smell, taste
@app.post("/addGroundingEntries")
def add_grounding_entries(req: AddEntriesRequest):
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    for item_text in req.items:
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
def get_grounding_session(session_id: str):
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute("SELECT * FROM GROUNDING_SESSIONS WHERE id=?", (session_id,))
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
def get_grounding_history(user_id: str):
    conn = sqlite3.connect(DB_NAME)
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
    conn = sqlite3.connect(DB_NAME)
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
    
    conn = sqlite3.connect(DB_NAME)
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
    
    conn = sqlite3.connect(DB_NAME)
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
    authorization: Optional[str] = Header(None)
):
    """Get correlation data between sleep and mood for the last N days."""
    user = require_user(authorization)
    user_id = user["id"]
    
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    
    cutoff_date = (datetime.utcnow() - __import__('datetime').timedelta(days=days)).isoformat()
    
    # Get sleep data
    c.execute(
        """SELECT date, sleep_hours, sleep_minutes FROM SLEEP_LOGS
        WHERE user_id=? AND created_at >= ? ORDER BY date""",
        (user_id, cutoff_date),
    )
    
    sleep_data = {}
    for row in c.fetchall():
        date, hours, minutes = row
        date_key = date.split('T')[0]  # Extract date only
        sleep_data[date_key] = (hours * 60 + minutes) / 60
    
    # Get mood data from checkins (assuming each checkin has mood scores)
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
            # Calculate mood score (average of all answers * 2.5 to scale to 10)
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
    """Get active wellbeing warnings for the user."""
    user = require_user(authorization)
    user_id = user["id"]
    
    conn = sqlite3.connect(DB_NAME)
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
    
    conn = sqlite3.connect(DB_NAME)
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
    
    conn = sqlite3.connect(DB_NAME)
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
    conn = sqlite3.connect(DB_NAME)
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

    conn = sqlite3.connect(DB_NAME)
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

    conn = sqlite3.connect(DB_NAME)
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

    conn = sqlite3.connect(DB_NAME)
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

    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute(
        "DELETE FROM BREATHING_SESSIONS WHERE id=? AND user_id=?",
        (session_id, user_id),
    )
    conn.commit()
    conn.close()

    return {"success": True}