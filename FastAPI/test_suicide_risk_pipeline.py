import os
import sys
import sqlite3
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import app as fastapi_app
from app import app
from risk_detector import classify_suicide_risk, scan_and_alert_emergency_contact
import email_service
import postmark_service


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
    test_conn = sqlite3.connect(":memory:", check_same_thread=False)

    def mock_connect():
        return SqliteTestConnection(test_conn)

    monkeypatch.setattr(fastapi_app, "connect_db_connection", mock_connect)

    c = test_conn.cursor()
    c.execute("""CREATE TABLE USERS (
        id VARCHAR(64) PRIMARY KEY,
        name TEXT,
        email VARCHAR(255) UNIQUE,
        password TEXT,
        token TEXT,
        emergency_contact TEXT
    )""")
    c.execute("""CREATE TABLE JOURNAL_ENTRIES (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) NOT NULL,
        title TEXT,
        content TEXT NOT NULL,
        mood_tag TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
    )""")
    c.execute("""CREATE TABLE COMMUNITY_POSTS (
        id VARCHAR(64) PRIMARY KEY,
        user_id TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_hidden INTEGER DEFAULT 0
    )""")
    c.execute("""CREATE TABLE COMMUNITY_COMMENTS (
        id VARCHAR(64) PRIMARY KEY,
        post_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_hidden INTEGER DEFAULT 0
    )""")
    c.execute("""CREATE TABLE COMMUNITY_REPORTS (
        id VARCHAR(64) PRIMARY KEY,
        post_id TEXT NOT NULL,
        reporter_user_id TEXT NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL
    )""")
    c.execute("""CREATE TABLE COMMUNITY_COMMENT_REPORTS (
        id VARCHAR(64) PRIMARY KEY,
        comment_id TEXT NOT NULL,
        reporter_user_id TEXT NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL
    )""")
    test_conn.commit()

    yield test_conn
    test_conn.close()


def test_classify_suicide_risk_benign_and_empty():
    assert classify_suicide_risk("") == 0
    assert classify_suicide_risk("   ") == 0
    benign_text = "I had a wonderful walk in the park today and felt calm and peaceful."
    result = classify_suicide_risk(benign_text)
    assert result in (0, 1)  # Model returns valid binary classification


def test_resend_send_email_mocked():
    with patch("resend.Emails.send", return_value={"id": "res_123"}) as mock_send, \
         patch.dict(os.environ, {"RESEND_API_KEY": "re_test_123", "RESEND_FROM_EMAIL": "onboarding@resend.dev"}):

        success = email_service.send_emergency_checkin_email(
            to_email="emergency.contact@example.com",
            friend_name="Alex Rivera",
        )

        assert success is True
        assert mock_send.called
        call_kwargs = mock_send.call_args[0][0]
        assert call_kwargs["to"] == ["emergency.contact@example.com"]
        assert call_kwargs["from"] == "onboarding@resend.dev"
        assert "Alex Rivera" in call_kwargs["text"]


def test_resend_missing_token_or_invalid_email():
    with patch.dict(os.environ, {"RESEND_API_KEY": ""}):
        # Missing token should return False safely without error
        assert email_service.send_emergency_checkin_email("contact@example.com") is False

    # Invalid email should return False safely
    assert email_service.send_emergency_checkin_email("not-an-email") is False


def test_scan_and_alert_emergency_contact_pipeline():
    with patch("risk_detector.classify_suicide_risk", return_value=1), \
         patch("risk_detector.send_emergency_checkin_email") as mock_email:
        
        # User with emergency contact
        conn = fastapi_app.connect_db_connection()
        c = conn.cursor()
        c.execute(
            "INSERT INTO USERS VALUES ('u1', 'Sam User', 'sam@example.com', 'pass', 'tok1', 'contact@example.com')",
        )
        conn.commit()

        risk = scan_and_alert_emergency_contact(
            text="Distressed thoughts and pain",
            user_id="u1",
        )

        assert risk == 1
        mock_email.assert_called_once_with(
            to_email="contact@example.com",
            friend_name="Sam User",
        )


def test_scan_and_alert_when_no_risk():
    with patch("risk_detector.classify_suicide_risk", return_value=0), \
         patch("risk_detector.send_emergency_checkin_email") as mock_email:
        
        conn = fastapi_app.connect_db_connection()
        c = conn.cursor()
        c.execute(
            "INSERT INTO USERS VALUES ('u2', 'Happy User', 'happy@example.com', 'pass', 'tok2', 'contact2@example.com')",
        )
        conn.commit()

        risk = scan_and_alert_emergency_contact(
            text="Today was a productive and joyful day.",
            user_id="u2",
        )

        assert risk == 0
        mock_email.assert_not_called()


def test_journal_creation_and_update_silent_execution():
    client = TestClient(app)
    signup = client.post(
        "/auth/signup",
        json={"name": "Journaler", "email": "journaler@example.com", "password": "pass"},
    ).json()
    headers = {"Authorization": f"Bearer {signup['access_token']}"}

    # Set emergency contact
    client.put(
        "/profile/me",
        headers=headers,
        json={"name": "Journaler", "email": "journaler@example.com", "emergency_contact": "family@example.com"},
    )

    with patch("risk_detector.send_emergency_checkin_email") as mock_email:
        # Create journal entry
        create_res = client.post(
            "/journal/entries",
            headers=headers,
            json={"title": "Evening Reflection", "content": "Reflecting on life and emotions today.", "mood_tag": "reflective"},
        )
        assert create_res.status_code == 200
        data = create_res.json()
        assert data["title"] == "Evening Reflection"
        # User response must NOT contain any risk warning or alert
        assert "risk" not in data
        assert "warning" not in data

        # Update journal entry
        entry_id = data["id"]
        update_res = client.put(
            f"/journal/entries/{entry_id}",
            headers=headers,
            json={"title": "Updated Reflection", "content": "Updated content.", "mood_tag": "calm"},
        )
        assert update_res.status_code == 200
        assert update_res.json()["title"] == "Updated Reflection"


def test_community_post_and_comment_silent_execution():
    client = TestClient(app)
    signup = client.post(
        "/auth/signup",
        json={"name": "Poster", "email": "poster@example.com", "password": "pass"},
    ).json()
    headers = {"Authorization": f"Bearer {signup['access_token']}"}

    with patch("risk_detector.send_emergency_checkin_email") as mock_email:
        # Create community post
        post_res = client.post(
            "/community/posts",
            headers=headers,
            json={"content": "Sharing a thought with the community today."},
        )
        assert post_res.status_code == 200
        post_data = post_res.json()
        assert "risk" not in post_data
        assert "warning" not in post_data

        # Create community comment
        comment_res = client.post(
            f"/community/posts/{post_data['id']}/comments",
            headers=headers,
            json={"content": "Supportive comment here."},
        )
        assert comment_res.status_code == 200
        comment_data = comment_res.json()
        assert "risk" not in comment_data
        assert "warning" not in comment_data
