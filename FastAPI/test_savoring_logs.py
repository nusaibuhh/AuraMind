import os
import sqlite3
import sys

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import app as fastapi_app
from app import app


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
        pass


@pytest.fixture(autouse=True)
def setup_test_db(monkeypatch):
    connection = sqlite3.connect(":memory:", check_same_thread=False)
    monkeypatch.setattr(
        fastapi_app,
        "connect_db_connection",
        lambda: SqliteTestConnection(connection),
    )
    connection.executescript(
        """
        CREATE TABLE USERS (
            id VARCHAR(64) PRIMARY KEY,
            name TEXT,
            email VARCHAR(255) UNIQUE,
            password TEXT,
            token TEXT
        );
        CREATE TABLE SAVORING_LOGS (
            id VARCHAR(64) PRIMARY KEY,
            user_id VARCHAR(64) NOT NULL,
            log_date VARCHAR(32) NOT NULL,
            status VARCHAR(16) NOT NULL DEFAULT 'draft',
            completed_at TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE (user_id, log_date)
        );
        CREATE TABLE SAVORING_ENTRIES (
            id VARCHAR(64) PRIMARY KEY,
            log_id VARCHAR(64) NOT NULL,
            entry_order INTEGER NOT NULL,
            positive_event TEXT NOT NULL,
            why_happened TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE (log_id, entry_order)
        );
        """
    )
    connection.commit()
    yield connection
    connection.close()


def _signup(client, suffix):
    response = client.post(
        "/auth/signup",
        json={
            "name": f"Savoring {suffix}",
            "email": f"savoring-{suffix}@example.com",
            "password": "password123",
        },
    )
    assert response.status_code == 200
    body = response.json()
    return body, {"Authorization": f"Bearer {body['access_token']}"}


def _complete_payload(prefix="Moment"):
    return {
        "entries": [
            {
                "position": position,
                "positive_event": f"{prefix} {position}",
                "why_happened": f"Reason {position}",
            }
            for position in range(1, 4)
        ]
    }


def test_today_creates_exactly_three_slots_and_reuses_daily_log(setup_test_db):
    client = TestClient(app)
    user, headers = _signup(client, "today")

    first = client.get("/savoring/today", headers=headers)
    second = client.get("/savoring/today", headers=headers)

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["id"] == second.json()["id"]
    assert first.json()["user_id"] == user["user_id"]
    assert first.json()["status"] == "draft"
    assert [entry["position"] for entry in first.json()["entries"]] == [1, 2, 3]
    assert all(entry["positive_event"] == "" for entry in first.json()["entries"])
    assert setup_test_db.execute("SELECT COUNT(*) FROM SAVORING_LOGS").fetchone()[0] == 1
    assert setup_test_db.execute("SELECT COUNT(*) FROM SAVORING_ENTRIES").fetchone()[0] == 3


def test_partial_draft_saves_and_survives_refresh():
    client = TestClient(app)
    _, headers = _signup(client, "draft")
    log = client.get("/savoring/today", headers=headers).json()
    payload = {
        "entries": [
            {
                "position": 1,
                "positive_event": "A warm cup of tea",
                "why_happened": "I paused to make it",
            },
            {"position": 2, "positive_event": "", "why_happened": ""},
            {"position": 3, "positive_event": "A kind message", "why_happened": ""},
        ]
    }

    saved = client.put(f"/savoring/logs/{log['id']}", headers=headers, json=payload)
    refreshed = client.get("/savoring/today", headers=headers)

    assert saved.status_code == 200
    assert saved.json()["status"] == "draft"
    assert refreshed.json()["entries"] == saved.json()["entries"]


def test_completion_requires_all_three_event_and_reason_pairs():
    client = TestClient(app)
    _, headers = _signup(client, "validation")
    log_id = client.get("/savoring/today", headers=headers).json()["id"]
    incomplete = _complete_payload()
    incomplete["entries"][1]["why_happened"] = "   "

    response = client.post(
        f"/savoring/logs/{log_id}/complete",
        headers=headers,
        json=incomplete,
    )

    assert response.status_code == 422
    assert "all three cards" in response.json()["detail"]
    assert client.get("/savoring/today", headers=headers).json()["status"] == "draft"


def test_completion_is_persistent_idempotent_and_read_only():
    client = TestClient(app)
    _, headers = _signup(client, "complete")
    log_id = client.get("/savoring/today", headers=headers).json()["id"]
    first = client.post(
        f"/savoring/logs/{log_id}/complete",
        headers=headers,
        json=_complete_payload("First"),
    )
    repeated = client.post(
        f"/savoring/logs/{log_id}/complete",
        headers=headers,
        json=_complete_payload("Changed"),
    )

    assert first.status_code == 200
    assert first.json()["status"] == "completed"
    assert first.json()["completed_at"] is not None
    assert repeated.status_code == 200
    assert repeated.json()["completed_at"] == first.json()["completed_at"]
    assert repeated.json()["entries"] == first.json()["entries"]
    assert client.put(
        f"/savoring/logs/{log_id}",
        headers=headers,
        json=_complete_payload("Edit"),
    ).status_code == 409


def test_logs_are_owner_scoped_and_history_excludes_drafts():
    client = TestClient(app)
    first_user, first_headers = _signup(client, "owner-one")
    second_user, second_headers = _signup(client, "owner-two")
    first_log = client.get("/savoring/today", headers=first_headers).json()
    second_log = client.get("/savoring/today", headers=second_headers).json()

    assert client.put(
        f"/savoring/logs/{first_log['id']}",
        headers=second_headers,
        json=_complete_payload(),
    ).status_code == 403

    completed = client.post(
        f"/savoring/logs/{first_log['id']}/complete",
        headers=first_headers,
        json=_complete_payload("Owner"),
    )
    assert completed.status_code == 200
    first_history = client.get("/savoring/history", headers=first_headers).json()
    second_history = client.get("/savoring/history", headers=second_headers).json()

    assert len(first_history) == 1
    assert first_history[0]["user_id"] == first_user["user_id"]
    assert second_history == []
    assert second_log["user_id"] == second_user["user_id"]


def test_request_shape_auth_and_history_ranges_are_validated():
    client = TestClient(app)
    assert client.get("/savoring/today").status_code == 401
    _, headers = _signup(client, "errors")
    log_id = client.get("/savoring/today", headers=headers).json()["id"]

    duplicate_positions = {
        "entries": [
            {"position": 1, "positive_event": "A", "why_happened": "B"},
            {"position": 1, "positive_event": "C", "why_happened": "D"},
            {"position": 3, "positive_event": "E", "why_happened": "F"},
        ]
    }
    assert client.put(
        f"/savoring/logs/{log_id}", headers=headers, json=duplicate_positions
    ).status_code == 422
    assert client.get("/savoring/history?days=0", headers=headers).status_code == 400
    assert client.get("/savoring/history?limit=101", headers=headers).status_code == 400
    assert client.put(
        "/savoring/logs/not-a-log", headers=headers, json=_complete_payload()
    ).status_code == 404


def test_history_days_filter_uses_user_local_date(setup_test_db):
    client = TestClient(app)
    user, headers = _signup(client, "history-filter")
    today = client.get("/savoring/today", headers=headers).json()
    client.post(
        f"/savoring/logs/{today['id']}/complete",
        headers=headers,
        json=_complete_payload("Today"),
    )
    timestamp = "2000-01-01T10:00:00"
    setup_test_db.execute(
        """INSERT INTO SAVORING_LOGS
           (id, user_id, log_date, status, completed_at, created_at, updated_at)
           VALUES (?, ?, '2000-01-01', 'completed', ?, ?, ?)""",
        ("old-log", user["user_id"], timestamp, timestamp, timestamp),
    )
    for position in range(1, 4):
        setup_test_db.execute(
            """INSERT INTO SAVORING_ENTRIES
               (id, log_id, entry_order, positive_event, why_happened,
                created_at, updated_at)
               VALUES (?, 'old-log', ?, 'Old moment', 'Old reason', ?, ?)""",
            (f"old-entry-{position}", position, timestamp, timestamp),
        )
    setup_test_db.commit()

    recent = client.get("/savoring/history?days=7", headers=headers).json()
    all_logs = client.get("/savoring/history", headers=headers).json()
    assert [item["id"] for item in recent] == [today["id"]]
    assert [item["id"] for item in all_logs] == [today["id"], "old-log"]
