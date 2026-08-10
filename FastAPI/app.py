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
from typing import List, Dict, Optional

from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="AuraMind API")
DB_NAME = "auramind.db"

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

    # Store raw checkins
    c.execute("""CREATE TABLE IF NOT EXISTS MOOD_CHECKINS (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        answers TEXT,
        created_at TEXT
    )""")

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
    c.execute("SELECT id, name, password FROM USERS WHERE email=?", (req.email,))
    row = c.fetchone()
    if not row or row[2] != req.password:
        conn.close()
        raise HTTPException(status_code=401, detail="Invalid credentials")

    user_id, name = row[0], row[1]
    token = uuid.uuid4().hex
    c.execute("UPDATE USERS SET token=? WHERE id=?", (token, user_id))
    conn.commit()
    conn.close()

    return {"user_id": user_id, "name": name, "email": req.email, "access_token": token}


@app.post("/checkin")
def checkin(req: CheckinRequest, authorization: Optional[str] = Header(None)):
    user = require_user(authorization)

    # Scoring: distribute question indices into three buckets
    depression = 0
    anxiety = 0
    stress = 0
    for k, v in req.answers.items():
        try:
            idx = int(k)
        except Exception:
            # non-numeric keys -> put into stress by default
            stress += int(v)
            continue
        if idx % 3 == 1:
            depression += int(v)
        elif idx % 3 == 2:
            anxiety += int(v)
        else:
            stress += int(v)

    # Determine dominant category
    scores = {"depression": depression, "anxiety": anxiety, "stress": stress}
    dominant = max(scores, key=scores.get)
    if scores[dominant] == 0:
        dominant = "normal"

    # Persist raw answers — adapt to existing DB schema (4 or 5 columns)
    checkin_id = uuid.uuid4().hex
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    # inspect table columns
    c.execute("PRAGMA table_info(MOOD_CHECKINS)")
    cols = c.fetchall()
    col_names = [r[1] for r in cols]
    if 'mood_result' in col_names:
        # older schema: id, user_id, answers, mood_result, created_at
        c.execute("INSERT INTO MOOD_CHECKINS VALUES (?, ?, ?, ?, ?)", (checkin_id, user["id"], json.dumps(req.answers), dominant, now()))
    else:
        # newer schema: id, user_id, answers, created_at
        c.execute("INSERT INTO MOOD_CHECKINS VALUES (?, ?, ?, ?)", (checkin_id, user["id"], json.dumps(req.answers), now()))
    conn.commit()

    # Recommend palettes
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
        "depression_score": depression,
        "anxiety_score": anxiety,
        "stress_score": stress,
        "dominant_category": dominant,
        "recommended_palettes": recommended,
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