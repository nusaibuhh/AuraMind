import os
import sqlite3
import sys

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import app as fastapi_app
from app import app


class SqliteCursor:
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


class SqliteConnection:
    def __init__(self, connection):
        self._connection = connection

    def cursor(self):
        return SqliteCursor(self._connection.cursor())

    def commit(self):
        return self._connection.commit()

    def rollback(self):
        return self._connection.rollback()

    def close(self):
        pass


@pytest.fixture(autouse=True)
def consultation_db(monkeypatch):
    raw_connection = sqlite3.connect(":memory:", check_same_thread=False)
    connection = SqliteConnection(raw_connection)
    monkeypatch.setattr(fastapi_app, "connect_db_connection", lambda: connection)

    cursor = raw_connection.cursor()
    cursor.executescript(
        """
        CREATE TABLE USERS (
            id TEXT PRIMARY KEY, name TEXT, email TEXT UNIQUE,
            password TEXT, token TEXT, emergency_contact TEXT
        );
        CREATE TABLE CONSULTATION_PRACTITIONERS (
            id TEXT PRIMARY KEY, name TEXT, qualifications TEXT,
            specialty TEXT, consultation_minutes INTEGER, contact_no TEXT,
            chamber TEXT, fee_amount DECIMAL(10,2), currency TEXT,
            is_demo INTEGER, is_active INTEGER, email TEXT,
            license_number TEXT, password TEXT, must_change_password INTEGER DEFAULT 0,
            auth_token TEXT
        );
        CREATE TABLE CONSULTATION_SLOTS (
            id TEXT PRIMARY KEY, practitioner_id TEXT, starts_at TEXT,
            ends_at TEXT, status TEXT, held_until TEXT,
            booked_by_user_id TEXT, booking_id TEXT
        );
        CREATE TABLE CONSULTATION_BOOKINGS (
            id TEXT PRIMARY KEY, user_id TEXT, practitioner_id TEXT,
            slot_id TEXT, status TEXT, payment_timing TEXT,
            payment_status TEXT, fee_amount DECIMAL(10,2), currency TEXT,
            created_at TEXT, updated_at TEXT
        );
        CREATE TABLE CONSULTATION_PAYMENTS (
            id TEXT PRIMARY KEY, booking_id TEXT, user_id TEXT,
            provider TEXT, method TEXT, status TEXT, amount DECIMAL(10,2),
            currency TEXT, transaction_id TEXT UNIQUE, session_key TEXT,
            gateway_url TEXT, validation_id TEXT, bank_transaction_id TEXT,
            card_type TEXT, created_at TEXT, paid_at TEXT
        );
        """
    )
    raw_connection.commit()
    fastapi_app.seed_consultation_catalog(connection)
    yield raw_connection
    raw_connection.close()


def _signup(client, suffix):
    response = client.post(
        "/auth/signup",
        json={
            "name": f"Booking User {suffix}",
            "email": f"booking-{suffix}@example.com",
            "password": "pass123",
        },
    )
    assert response.status_code == 200
    payload = response.json()
    return {"Authorization": f"Bearer {payload['access_token']}"}


def test_sslcommerz_uses_current_sandbox_endpoints(monkeypatch):
    monkeypatch.setenv("SSLCOMMERZ_STORE_ID", "sandbox-store")
    monkeypatch.setenv("SSLCOMMERZ_STORE_PASSWORD", "sandbox-password")
    monkeypatch.setenv("SSLCOMMERZ_SANDBOX", "true")

    settings = fastapi_app._sslcommerz_settings()

    assert settings["init_url"] == (
        "https://sandbox-gw.sslcommerz.com/gwprocess/v4/api.php"
    )
    assert settings["validation_url"].startswith(
        "https://sandbox.sslcommerz.com/validator/"
    )
    assert settings["query_url"].startswith(
        "https://sandbox.sslcommerz.com/validator/"
    )


def test_demo_catalog_and_atomic_slot_booking():
    client = TestClient(app)
    first_user = _signup(client, "one")
    second_user = _signup(client, "two")

    catalog = client.get(
        "/consultations/practitioners", headers=first_user
    ).json()
    assert len(catalog) == 5
    assert all(practitioner["is_demo"] for practitioner in catalog)
    assert all(practitioner["slots"] for practitioner in catalog)

    practitioner = catalog[0]
    slot = next(item for item in practitioner["slots"] if item["is_available"])
    booking_response = client.post(
        "/consultations/bookings",
        headers=first_user,
        json={
            "practitioner_id": practitioner["id"],
            "slot_id": slot["id"],
            "payment_timing": "after",
        },
    )
    assert booking_response.status_code == 200
    assert booking_response.json()["status"] == "pending"
    assert booking_response.json()["payment_status"] == "unpaid"

    collision = client.post(
        "/consultations/bookings",
        headers=second_user,
        json={
            "practitioner_id": practitioner["id"],
            "slot_id": slot["id"],
            "payment_timing": "after",
        },
    )
    assert collision.status_code == 409


def test_verified_payment_confirms_pay_before_booking(monkeypatch):
    client = TestClient(app)
    headers = _signup(client, "payment")
    catalog = client.get("/consultations/practitioners", headers=headers).json()
    practitioner = catalog[0]
    slot = next(item for item in practitioner["slots"] if item["is_available"])
    booking = client.post(
        "/consultations/bookings",
        headers=headers,
        json={
            "practitioner_id": practitioner["id"],
            "slot_id": slot["id"],
            "payment_timing": "before",
        },
    ).json()
    assert booking["status"] == "pending_payment"

    monkeypatch.setenv("SSLCOMMERZ_STORE_ID", "sandbox-store")
    monkeypatch.setenv("SSLCOMMERZ_STORE_PASSWORD", "sandbox-password")
    monkeypatch.setenv("SSLCOMMERZ_SANDBOX", "true")
    gateway_state = {}

    def fake_gateway(url, data=None):
        if data is not None:
            gateway_state["transaction_id"] = data["tran_id"]
            gateway_state["amount"] = data["total_amount"]
            return {
                "status": "SUCCESS",
                "sessionkey": "session-123",
                "GatewayPageURL": "https://sandbox.example/checkout",
            }
        return {
            "status": "VALID",
            "tran_id": gateway_state["transaction_id"],
            "amount": gateway_state["amount"],
            "currency": "BDT",
            "risk_level": "0",
            "bank_tran_id": "bank-123",
            "card_type": "BKASH",
        }

    monkeypatch.setattr(fastapi_app, "_sslcommerz_json", fake_gateway)
    checkout = client.post(
        f"/consultations/bookings/{booking['id']}/payments",
        headers=headers,
        json={"method": "bkash", "customer_phone": "01711111111"},
    )
    assert checkout.status_code == 200
    transaction_id = checkout.json()["transaction_id"]
    repeated_checkout = client.post(
        f"/consultations/bookings/{booking['id']}/payments",
        headers=headers,
        json={"method": "bank_card", "customer_phone": "01711111111"},
    )
    assert repeated_checkout.status_code == 200
    assert repeated_checkout.json()["transaction_id"] == transaction_id

    callback = client.post(
        "/payments/sslcommerz/success",
        data={"tran_id": transaction_id, "val_id": "validation-123"},
    )
    assert callback.status_code == 200
    assert "Payment verified" in callback.text

    bookings = client.get("/consultations/bookings/me", headers=headers).json()
    assert bookings[0]["status"] == "confirmed"
    assert bookings[0]["payment_status"] == "paid"
    assert bookings[0]["payment"]["status"] == "paid"


def test_amount_mismatch_does_not_confirm_booking(monkeypatch):
    client = TestClient(app)
    headers = _signup(client, "mismatch")
    catalog = client.get("/consultations/practitioners", headers=headers).json()
    practitioner = catalog[0]
    slot = next(item for item in practitioner["slots"] if item["is_available"])
    booking = client.post(
        "/consultations/bookings",
        headers=headers,
        json={
            "practitioner_id": practitioner["id"],
            "slot_id": slot["id"],
            "payment_timing": "before",
        },
    ).json()

    monkeypatch.setenv("SSLCOMMERZ_STORE_ID", "sandbox-store")
    monkeypatch.setenv("SSLCOMMERZ_STORE_PASSWORD", "sandbox-password")
    state = {}

    def fake_gateway(url, data=None):
        if data is not None:
            state["transaction_id"] = data["tran_id"]
            return {
                "status": "SUCCESS",
                "sessionkey": "session-mismatch",
                "GatewayPageURL": "https://sandbox.example/checkout",
            }
        return {
            "status": "VALID",
            "tran_id": state["transaction_id"],
            "amount": "10.00",
            "currency": "BDT",
            "risk_level": "0",
        }

    monkeypatch.setattr(fastapi_app, "_sslcommerz_json", fake_gateway)
    checkout = client.post(
        f"/consultations/bookings/{booking['id']}/payments",
        headers=headers,
        json={"method": "bank_card", "customer_phone": "01711111111"},
    ).json()
    callback = client.post(
        "/payments/sslcommerz/success",
        data={
            "tran_id": checkout["transaction_id"],
            "val_id": "validation-mismatch",
        },
    )
    assert "could not be verified" in callback.text

    bookings = client.get("/consultations/bookings/me", headers=headers).json()
    assert bookings[0]["status"] == "pending_payment"
    assert bookings[0]["payment_status"] == "pending"


def test_practitioner_accept_and_accept_cash():
    client = TestClient(app)
    headers = _signup(client, "practitioner_test")
    catalog = client.get("/consultations/practitioners", headers=headers).json()
    practitioner = catalog[0]
    slot = next(item for item in practitioner["slots"] if item["is_available"])

    # User books with payment_timing 'after'
    booking = client.post(
        "/consultations/bookings",
        headers=headers,
        json={
            "practitioner_id": practitioner["id"],
            "slot_id": slot["id"],
            "payment_timing": "after",
        },
    ).json()

    # Must be pending initially, not confirmed automatically
    assert booking["status"] == "pending"
    assert booking["payment_status"] == "unpaid"

    # Set auth_token for practitioner directly in test db
    conn = fastapi_app.connect_db_connection()
    c = conn.cursor()
    c.execute("UPDATE CONSULTATION_PRACTITIONERS SET auth_token='test_prac_token' WHERE id=?", (practitioner["id"],))
    conn.commit()

    prac_headers = {"Authorization": "Bearer test_prac_token"}

    # Practitioner accepts cash
    cash_action = client.patch(
        f"/practitioner/bookings/{booking['id']}",
        headers=prac_headers,
        json={"action": "accept_cash"},
    )
    assert cash_action.status_code == 200
    assert cash_action.json()["status"] == "confirmed"
    assert cash_action.json()["payment_status"] == "paid"

    # User checks booking
    user_bookings = client.get("/consultations/bookings/me", headers=headers).json()
    assert user_bookings[0]["status"] == "confirmed"
    assert user_bookings[0]["payment_status"] == "paid"
    assert user_bookings[0]["payment"]["method"] == "cash"
    assert user_bookings[0]["payment"]["status"] == "paid"

