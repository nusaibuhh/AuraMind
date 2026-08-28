-- AuraMind "Three Good Things" savoring logs migration (MySQL 8+)
-- Run once against the existing central `auramind` database.
-- Logs are private, user-owned, and limited to one record per local calendar day.

CREATE TABLE IF NOT EXISTS savoring_logs (
  id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  log_date VARCHAR(32) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'draft',
  completed_at TEXT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY savoring_logs_user_date_unique (user_id, log_date),
  KEY savoring_logs_user_status_date_idx (user_id, status, log_date),
  CONSTRAINT savoring_logs_status_check
    CHECK (status IN ('draft', 'completed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS savoring_entries (
  id VARCHAR(64) NOT NULL,
  log_id VARCHAR(64) NOT NULL,
  entry_order INT NOT NULL,
  positive_event TEXT NOT NULL,
  why_happened TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY savoring_entries_log_order_unique (log_id, entry_order),
  KEY savoring_entries_log_idx (log_id),
  CONSTRAINT savoring_entries_order_check
    CHECK (entry_order BETWEEN 1 AND 3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
