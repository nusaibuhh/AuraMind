import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pytest
from fastapi.testclient import TestClient
import sqlite3
from datetime import datetime, timezone

import app as fastapi_app
from app import app


@pytest.fixture(autouse=True)
def setup_test_db(monkeypatch):
    """Use an in-memory or temporary SQLite database connection for fast, isolated tests."""
    test_conn = sqlite3.connect(":memory:", check_same_thread=False)
    
    # Enable SQLite cursor to match DatabaseCursor interface
    class SqliteTestCursor:
        def __init__(self, cursor):
            self._cursor = cursor

        def execute(self, query, params=None):
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

    class SqliteTestConnection:
        def __init__(self, connection):
            self._connection = connection

        def cursor(self):
            return SqliteTestCursor(self._connection.cursor())

        def commit(self):
            return self._connection.commit()

        def rollback(self):
            return self._connection.rollback()

        def close(self):
            pass  # keep in-memory db alive across requests in a test

    def mock_connect():
        return SqliteTestConnection(test_conn)

    monkeypatch.setattr(fastapi_app, "connect_db_connection", mock_connect)

    # Initialize tables
    c = test_conn.cursor()
    c.execute("""CREATE TABLE USERS (
        id VARCHAR(64) PRIMARY KEY,
        name TEXT,
        email VARCHAR(255) UNIQUE,
        password TEXT,
        token TEXT,
        emergency_contact TEXT
    )""")
    c.execute("""CREATE TABLE BEHAVIORAL_ACTIVITIES (
        id VARCHAR(64) PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category VARCHAR(64) NOT NULL,
        difficulty VARCHAR(32) NOT NULL DEFAULT 'tiny',
        duration_minutes INTEGER NOT NULL DEFAULT 5,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
    )""")
    c.execute("""CREATE TABLE BEHAVIORAL_DAILY_TASKS (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) NOT NULL,
        activity_id VARCHAR(64) NOT NULL,
        task_date VARCHAR(32) NOT NULL,
        status VARCHAR(32) NOT NULL DEFAULT 'pending',
        completed_at TEXT,
        mood_before INTEGER,
        mood_after INTEGER,
        created_at TEXT NOT NULL,
        UNIQUE (user_id, task_date)
    )""")
    c.execute("""CREATE TABLE MOOD_CHECKINS (
        id VARCHAR(64) PRIMARY KEY,
        user_id TEXT,
        answers TEXT,
        created_at TEXT,
        mood_score REAL,
        dominant_category TEXT
    )""")
    c.execute("""CREATE TABLE SLEEP_LOGS (
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
    test_conn.commit()

    # Seed activities
    fastapi_app.seed_behavioral_activities(SqliteTestConnection(test_conn))

    yield test_conn
    test_conn.close()


def test_behavioral_activation_flow():
    client = TestClient(app)

    # 1. Signup test user
    signup_res = client.post("/auth/signup", json={
        "name": "Alex River",
        "email": "alex@example.com",
        "password": "password123"
    })
    assert signup_res.status_code == 200
    token = signup_res.json()["access_token"]
    user_id = signup_res.json()["user_id"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Get today's task (should create one)
    today_res = client.get("/behavioral-activation/today", headers=headers)
    assert today_res.status_code == 200
    task = today_res.json()
    assert task["user_id"] == user_id
    assert task["status"] == "pending"
    assert "activity" in task
    assert task["activity"]["title"] is not None
    task_id = task["id"]
    activity_id = task["activity_id"]

    # 3. Requesting today's task again should return the exact same task
    today_res_2 = client.get("/behavioral-activation/today", headers=headers)
    assert today_res_2.status_code == 200
    task_2 = today_res_2.json()
    assert task_2["id"] == task_id
    assert task_2["activity_id"] == activity_id

    # 4. Change activity
    change_res = client.post(f"/behavioral-activation/tasks/{task_id}/change", headers=headers)
    assert change_res.status_code == 200
    changed_task = change_res.json()
    assert changed_task["id"] == task_id  # same daily task record
    assert changed_task["activity_id"] != activity_id  # different activity

    # 5. Record mood before
    mood_res = client.post(f"/behavioral-activation/tasks/{task_id}/mood", headers=headers, json={"mood_before": 3})
    assert mood_res.status_code == 200
    assert mood_res.json()["mood_before"] == 3

    # 6. Complete task
    complete_res = client.post(f"/behavioral-activation/tasks/{task_id}/complete", headers=headers)
    assert complete_res.status_code == 200
    completed_task = complete_res.json()
    assert completed_task["status"] == "completed"
    assert completed_task["completed_at"] is not None

    # 7. Record mood after
    mood_after_res = client.post(f"/behavioral-activation/tasks/{task_id}/mood", headers=headers, json={"mood_after": 4})
    assert mood_after_res.status_code == 200
    assert mood_after_res.json()["mood_after"] == 4

    # 8. Check history
    history_res = client.get("/behavioral-activation/history", headers=headers)
    assert history_res.status_code == 200
    history = history_res.json()
    assert len(history) == 1
    assert history[0]["id"] == task_id
    assert history[0]["status"] == "completed"

    # 9. Check stats
    stats_res = client.get("/behavioral-activation/stats?days=7", headers=headers)
    assert stats_res.status_code == 200
    stats = stats_res.json()
    assert stats["completed_count"] == 1
    assert stats["skipped_count"] == 0
    assert stats["completion_rate"] == 100.0
    assert stats["number_of_active_days"] == 1


def test_skip_and_authorization():
    client = TestClient(app)

    # User 1
    user1_res = client.post("/auth/signup", json={"name": "User 1", "email": "u1@example.com", "password": "pass123"})
    token1 = user1_res.json()["access_token"]
    headers1 = {"Authorization": f"Bearer {token1}"}

    # User 2
    user2_res = client.post("/auth/signup", json={"name": "User 2", "email": "u2@example.com", "password": "pass123"})
    token2 = user2_res.json()["access_token"]
    headers2 = {"Authorization": f"Bearer {token2}"}

    # User 1 gets today's task
    t1_res = client.get("/behavioral-activation/today", headers=headers1)
    task1_id = t1_res.json()["id"]

    # User 2 tries to complete User 1's task -> 403 Forbidden
    hack_res = client.post(f"/behavioral-activation/tasks/{task1_id}/complete", headers=headers2)
    assert hack_res.status_code == 403

    # User 1 skips task
    skip_res = client.post(f"/behavioral-activation/tasks/{task1_id}/skip", headers=headers1)
    assert skip_res.status_code == 200
    assert skip_res.json()["status"] == "skipped"

    # User 1 stats should reflect skip
    stats_res = client.get("/behavioral-activation/stats?days=7", headers=headers1)
    assert stats_res.status_code == 200
    stats = stats_res.json()
    assert stats["skipped_count"] == 1
    assert stats["completed_count"] == 0
    assert stats["completion_rate"] == 0.0


def test_invalid_state_transitions_and_mood_validation():
    client = TestClient(app)
    signup = client.post(
        "/auth/signup",
        json={
            "name": "State Tester",
            "email": "state@example.com",
            "password": "password123",
        },
    )
    headers = {"Authorization": f"Bearer {signup.json()['access_token']}"}
    task = client.get("/behavioral-activation/today", headers=headers).json()
    task_id = task["id"]

    # Ratings are bounded and an after-action rating is only valid after completion.
    assert client.post(
        f"/behavioral-activation/tasks/{task_id}/mood",
        headers=headers,
        json={"mood_after": 6},
    ).status_code == 422
    assert client.post(
        f"/behavioral-activation/tasks/{task_id}/mood",
        headers=headers,
        json={"mood_after": 4},
    ).status_code == 409

    completed = client.post(
        f"/behavioral-activation/tasks/{task_id}/complete", headers=headers
    )
    assert completed.status_code == 200
    completed_at = completed.json()["completed_at"]

    # Repeating a completion is idempotent: the task remains completed and its
    # original completion time is retained rather than being recorded twice.
    repeated = client.post(
        f"/behavioral-activation/tasks/{task_id}/complete", headers=headers
    )
    assert repeated.status_code == 200
    assert repeated.json()["status"] == "completed"
    assert repeated.json()["completed_at"] == completed_at

    assert client.post(
        f"/behavioral-activation/tasks/{task_id}/skip", headers=headers
    ).status_code == 409
    assert client.post(
        f"/behavioral-activation/tasks/{task_id}/change", headers=headers
    ).status_code == 409
    assert client.post(
        f"/behavioral-activation/tasks/{task_id}/mood",
        headers=headers,
        json={"mood_before": 2, "mood_after": 5},
    ).status_code == 409

    mood_after = client.post(
        f"/behavioral-activation/tasks/{task_id}/mood",
        headers=headers,
        json={"mood_after": 5},
    )
    assert mood_after.status_code == 200
    assert mood_after.json()["mood_after"] == 5
    repeated_mood = client.post(
        f"/behavioral-activation/tasks/{task_id}/mood",
        headers=headers,
        json={"mood_after": 5},
    )
    assert repeated_mood.status_code == 200
    assert repeated_mood.json()["mood_after"] == 5


def test_history_and_stats_are_scoped_to_the_authenticated_user():
    client = TestClient(app)
    first = client.post(
        "/auth/signup",
        json={"name": "First", "email": "first@example.com", "password": "password123"},
    )
    second = client.post(
        "/auth/signup",
        json={"name": "Second", "email": "second@example.com", "password": "password123"},
    )
    first_headers = {"Authorization": f"Bearer {first.json()['access_token']}"}
    second_headers = {"Authorization": f"Bearer {second.json()['access_token']}"}

    first_task = client.get("/behavioral-activation/today", headers=first_headers).json()
    client.post(
        f"/behavioral-activation/tasks/{first_task['id']}/complete",
        headers=first_headers,
    )
    client.get("/behavioral-activation/today", headers=second_headers)

    first_history = client.get("/behavioral-activation/history", headers=first_headers)
    second_history = client.get("/behavioral-activation/history", headers=second_headers)
    assert len(first_history.json()) == 1
    assert len(second_history.json()) == 1
    assert first_history.json()[0]["user_id"] == first.json()["user_id"]
    assert second_history.json()[0]["user_id"] == second.json()["user_id"]

    second_stats = client.get(
        "/behavioral-activation/stats?days=7", headers=second_headers
    ).json()
    assert second_stats["completed_count"] == 0
    assert second_stats["pending_count"] == 1


def test_daily_unique_constraint_rejects_a_second_row(setup_test_db):
    client = TestClient(app)
    signup = client.post(
        "/auth/signup",
        json={"name": "Unique", "email": "unique@example.com", "password": "pass123"},
    ).json()
    headers = {"Authorization": f"Bearer {signup['access_token']}"}
    task = client.get("/behavioral-activation/today", headers=headers).json()

    with pytest.raises(sqlite3.IntegrityError):
        setup_test_db.execute(
            """INSERT INTO BEHAVIORAL_DAILY_TASKS
               (id, user_id, activity_id, task_date, status, created_at)
               VALUES (?, ?, ?, ?, 'pending', ?)""",
            (
                "duplicate_task",
                signup["user_id"],
                task["activity_id"],
                task["task_date"],
                fastapi_app.now(),
            ),
        )


def test_missing_auth_and_unknown_task_errors():
    client = TestClient(app)
    assert client.get("/behavioral-activation/today").status_code == 401

    signup = client.post(
        "/auth/signup",
        json={"name": "Missing", "email": "missing@example.com", "password": "pass123"},
    ).json()
    headers = {"Authorization": f"Bearer {signup['access_token']}"}
    assert client.post(
        "/behavioral-activation/tasks/not-a-task/complete", headers=headers
    ).status_code == 404


def test_no_active_activity_returns_a_clear_not_found(setup_test_db):
    setup_test_db.execute("UPDATE BEHAVIORAL_ACTIVITIES SET is_active = 0")
    setup_test_db.commit()
    client = TestClient(app)
    signup = client.post(
        "/auth/signup",
        json={"name": "No Activities", "email": "none@example.com", "password": "pass123"},
    ).json()
    headers = {"Authorization": f"Bearer {signup['access_token']}"}

    response = client.get("/behavioral-activation/today", headers=headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "No behavioral activities found."


def test_change_requires_a_real_alternative(setup_test_db):
    setup_test_db.execute(
        "UPDATE BEHAVIORAL_ACTIVITIES SET is_active = CASE WHEN id = 'act_water_plant' THEN 1 ELSE 0 END"
    )
    setup_test_db.commit()
    client = TestClient(app)
    signup = client.post(
        "/auth/signup",
        json={"name": "Solo", "email": "solo@example.com", "password": "pass123"},
    ).json()
    headers = {"Authorization": f"Bearer {signup['access_token']}"}
    task = client.get("/behavioral-activation/today", headers=headers).json()

    response = client.post(
        f"/behavioral-activation/tasks/{task['id']}/change", headers=headers
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "No alternative activities available"


def test_history_filters_and_stats_validate_periods(setup_test_db):
    client = TestClient(app)
    signup = client.post(
        "/auth/signup",
        json={"name": "Ranges", "email": "ranges@example.com", "password": "pass123"},
    ).json()
    headers = {"Authorization": f"Bearer {signup['access_token']}"}
    today_task = client.get("/behavioral-activation/today", headers=headers).json()

    setup_test_db.execute(
        """INSERT INTO BEHAVIORAL_DAILY_TASKS
           (id, user_id, activity_id, task_date, status, completed_at, created_at)
           VALUES (?, ?, ?, ?, 'completed', ?, ?)""",
        (
            "old_task",
            signup["user_id"],
            today_task["activity_id"],
            "2000-01-01",
            "2000-01-01T10:00:00",
            "2000-01-01T09:00:00",
        ),
    )
    setup_test_db.commit()

    recent = client.get(
        "/behavioral-activation/history?days=7", headers=headers
    ).json()
    assert [item["id"] for item in recent] == [today_task["id"]]
    assert client.get(
        "/behavioral-activation/history?days=0", headers=headers
    ).status_code == 400
    assert client.get(
        "/behavioral-activation/stats?days=366", headers=headers
    ).status_code == 400


def test_device_timezone_offset_selects_the_user_local_day():
    near_midnight_utc = datetime(2026, 8, 28, 23, 30, tzinfo=timezone.utc)
    assert fastapi_app._local_date_for_offset(360, near_midnight_utc) == "2026-08-29"
    assert fastapi_app._local_date_for_offset(-300, near_midnight_utc) == "2026-08-28"


def test_timezone_header_is_validated():
    client = TestClient(app)
    signup = client.post(
        "/auth/signup",
        json={"name": "Timezone", "email": "timezone@example.com", "password": "pass123"},
    ).json()
    headers = {
        "Authorization": f"Bearer {signup['access_token']}",
        "X-Timezone-Offset-Minutes": "9999",
    }
    assert client.get("/behavioral-activation/today", headers=headers).status_code == 422


def test_mood_analytics_reports_descriptive_same_day_pattern(setup_test_db):
    client = TestClient(app)
    signup = client.post(
        "/auth/signup",
        json={"name": "Pattern", "email": "pattern@example.com", "password": "pass123"},
    ).json()
    headers = {"Authorization": f"Bearer {signup['access_token']}"}
    task = client.get("/behavioral-activation/today", headers=headers).json()
    client.post(
        f"/behavioral-activation/tasks/{task['id']}/complete", headers=headers
    )
    setup_test_db.execute(
        """INSERT INTO MOOD_CHECKINS
           (id, user_id, answers, created_at, mood_score, dominant_category)
           VALUES (?, ?, '{}', ?, 3.5, 'normal')""",
        ("mood_1", signup["user_id"], fastapi_app.now()),
    )
    setup_test_db.commit()

    response = client.get("/mood/analytics?days=7", headers=headers)
    assert response.status_code == 200
    summary = response.json()["behavioral_summary"]
    assert summary["completed_count"] == 1
    assert summary["days_with_recorded_mood_and_completion"] == 1
    assert "not evidence that one caused the other" in summary["pattern_message"]


def test_sleep_correlation_includes_same_day_behavioral_context(setup_test_db):
    client = TestClient(app)
    signup = client.post(
        "/auth/signup",
        json={"name": "Sleep Pattern", "email": "sleep-pattern@example.com", "password": "pass123"},
    ).json()
    headers = {"Authorization": f"Bearer {signup['access_token']}"}
    task = client.get("/behavioral-activation/today", headers=headers).json()
    client.post(
        f"/behavioral-activation/tasks/{task['id']}/complete", headers=headers
    )
    timestamp = fastapi_app.now()
    setup_test_db.execute(
        """INSERT INTO MOOD_CHECKINS
           (id, user_id, answers, created_at, mood_score, dominant_category)
           VALUES (?, ?, '{}', ?, 4.2, 'normal')""",
        ("mood_sleep", signup["user_id"], timestamp),
    )
    setup_test_db.execute(
        """INSERT INTO SLEEP_LOGS
           (id, user_id, date, sleep_hours, sleep_minutes, quality,
            post_wake_feeling, notes, created_at)
           VALUES (?, ?, ?, 7, 30, 3, 2, NULL, ?)""",
        (
            "sleep_1",
            signup["user_id"],
            f"{task['task_date']}T08:00:00",
            timestamp,
        ),
    )
    setup_test_db.commit()

    response = client.get("/sleep/correlation?days=7", headers=headers)
    assert response.status_code == 200
    point = response.json()[0]
    assert point["sleep_hours"] == 7.5
    assert point["mood_score"] == 4.2
    assert point["behavioral_status"] == "completed"
    assert point["behavioral_activity_title"] == task["activity"]["title"]
