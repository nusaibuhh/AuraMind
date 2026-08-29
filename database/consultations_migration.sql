-- AuraMind consultation booking and verified payment tables.
-- The FastAPI service also creates these tables automatically and seeds demo
-- practitioners/rolling slots when it starts.

CREATE TABLE IF NOT EXISTS CONSULTATION_PRACTITIONERS (
    id VARCHAR(64) PRIMARY KEY,
    name TEXT NOT NULL,
    qualifications TEXT NOT NULL,
    specialty TEXT NOT NULL,
    consultation_minutes INTEGER NOT NULL,
    contact_no TEXT NOT NULL,
    chamber TEXT NOT NULL,
    fee_amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'BDT',
    is_demo INTEGER NOT NULL DEFAULT 1,
    is_active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS CONSULTATION_SLOTS (
    id VARCHAR(64) PRIMARY KEY,
    practitioner_id VARCHAR(64) NOT NULL,
    starts_at VARCHAR(40) NOT NULL,
    ends_at VARCHAR(40) NOT NULL,
    status VARCHAR(24) NOT NULL DEFAULT 'free',
    held_until TEXT,
    booked_by_user_id VARCHAR(64),
    booking_id VARCHAR(64),
    INDEX consultation_slots_practitioner_start_idx
        (practitioner_id, starts_at)
);

CREATE TABLE IF NOT EXISTS CONSULTATION_BOOKINGS (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL,
    practitioner_id VARCHAR(64) NOT NULL,
    slot_id VARCHAR(64) NOT NULL,
    status VARCHAR(24) NOT NULL,
    payment_timing VARCHAR(16) NOT NULL,
    payment_status VARCHAR(24) NOT NULL DEFAULT 'unpaid',
    fee_amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'BDT',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    INDEX consultation_bookings_user_created_idx (user_id, created_at)
);

CREATE TABLE IF NOT EXISTS CONSULTATION_PAYMENTS (
    id VARCHAR(64) PRIMARY KEY,
    booking_id VARCHAR(64) NOT NULL,
    user_id VARCHAR(64) NOT NULL,
    provider VARCHAR(32) NOT NULL,
    method VARCHAR(24) NOT NULL,
    status VARCHAR(24) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    transaction_id VARCHAR(64) NOT NULL UNIQUE,
    session_key VARCHAR(100),
    gateway_url TEXT,
    validation_id VARCHAR(100),
    bank_transaction_id VARCHAR(100),
    card_type TEXT,
    created_at TEXT NOT NULL,
    paid_at TEXT,
    INDEX consultation_payments_booking_created_idx (booking_id, created_at)
);
