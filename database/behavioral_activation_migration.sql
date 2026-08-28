-- AuraMind Behavioral Activation Planner migration (MySQL 8+)
-- Run once against the existing central `auramind` database.
-- This follows the existing schema convention of application-managed IDs
-- and does not alter or remove any existing user, mood, or sleep data.

CREATE TABLE IF NOT EXISTS behavioral_activities (
  id VARCHAR(64) NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category VARCHAR(64) NOT NULL,
  difficulty VARCHAR(32) NOT NULL DEFAULT 'tiny',
  duration_minutes INT NOT NULL DEFAULT 5,
  is_active TINYINT NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  PRIMARY KEY (id),
  KEY behavioral_activities_active_difficulty_duration_idx
    (is_active, difficulty, duration_minutes),
  CONSTRAINT behavioral_activities_difficulty_check
    CHECK (difficulty IN ('tiny', 'easy', 'moderate')),
  CONSTRAINT behavioral_activities_duration_check
    CHECK (duration_minutes > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS behavioral_daily_tasks (
  id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  activity_id VARCHAR(64) NOT NULL,
  task_date VARCHAR(32) NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'pending',
  completed_at TEXT NULL,
  mood_before TINYINT NULL,
  mood_after TINYINT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY behavioral_daily_tasks_user_date_unique (user_id, task_date),
  KEY behavioral_daily_tasks_user_status_date_idx (user_id, status, task_date),
  CONSTRAINT behavioral_daily_tasks_status_check
    CHECK (status IN ('pending', 'completed', 'skipped')),
  CONSTRAINT behavioral_daily_tasks_mood_before_check
    CHECK (mood_before IS NULL OR mood_before BETWEEN 1 AND 5),
  CONSTRAINT behavioral_daily_tasks_mood_after_check
    CHECK (mood_after IS NULL OR mood_after BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO behavioral_activities
  (id, title, description, category, difficulty, duration_minutes, is_active, created_at)
VALUES
  ('act_water_plant', 'Water a plant', 'Give a plant some water or notice a plant nearby.', 'Self-care', 'tiny', 2, 1, UTC_TIMESTAMP()),
  ('act_walk_5min', 'Walk for 5 minutes', 'Step outside or walk around your room for just 5 minutes.', 'Physical', 'tiny', 5, 1, UTC_TIMESTAMP()),
  ('act_drink_water', 'Drink a glass of water', 'Slowly sip a fresh glass of water to refresh yourself.', 'Self-care', 'tiny', 2, 1, UTC_TIMESTAMP()),
  ('act_favorite_song', 'Listen to one favorite song', 'Put on one song you love and simply listen.', 'Enjoyment', 'tiny', 4, 1, UTC_TIMESTAMP()),
  ('act_message_friend', 'Send a message to a friend', 'Say hello or send a simple note or emoji to someone.', 'Social', 'tiny', 2, 1, UTC_TIMESTAMP()),
  ('act_sit_outside', 'Sit outside for 5 minutes', 'Feel the fresh air, warmth, or breeze for 5 minutes.', 'Outdoor', 'tiny', 5, 1, UTC_TIMESTAMP()),
  ('act_tidy_area', 'Tidy one small area', 'Organize one spot like your desk or a single drawer.', 'Productivity', 'tiny', 3, 1, UTC_TIMESTAMP()),
  ('act_take_shower', 'Take a warm shower', 'Enjoy a warm and refreshing shower with no rush.', 'Self-care', 'easy', 10, 1, UTC_TIMESTAMP()),
  ('act_gratitude', 'Write down one thing you are grateful for', 'Note down one small thing that brought you comfort or peace.', 'Relaxation', 'tiny', 3, 1, UTC_TIMESTAMP()),
  ('act_stretch', 'Gentle 3-minute stretch', 'Do a few easy shoulder rolls and gentle body stretches.', 'Physical', 'tiny', 3, 1, UTC_TIMESTAMP()),
  ('act_deep_breaths', 'Take 5 slow, deep breaths', 'Inhale deeply, hold gently, and exhale fully.', 'Relaxation', 'tiny', 2, 1, UTC_TIMESTAMP()),
  ('act_look_sky', 'Look at the sky or trees', 'Spend a moment watching the clouds, trees, or sky.', 'Outdoor', 'tiny', 3, 1, UTC_TIMESTAMP()),
  ('act_read_page', 'Read 2 pages of a book', 'Read just a couple of pages of any book or article you like.', 'Enjoyment', 'tiny', 5, 1, UTC_TIMESTAMP()),
  ('act_mindful_tea', 'Mindful tea or warm drink', 'Make a warm drink and focus on the aroma and warmth.', 'Relaxation', 'easy', 7, 1, UTC_TIMESTAMP()),
  ('act_kind_thought', 'Think of one kind thought for yourself', 'Remind yourself that doing your best each day is enough.', 'Self-care', 'tiny', 2, 1, UTC_TIMESTAMP())
ON DUPLICATE KEY UPDATE
  title = VALUES(title),
  description = VALUES(description),
  category = VALUES(category),
  difficulty = VALUES(difficulty),
  duration_minutes = VALUES(duration_minutes),
  is_active = VALUES(is_active);
