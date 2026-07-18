CREATE TABLE IF NOT EXISTS feedback (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reference TEXT NOT NULL UNIQUE CHECK (
    length(reference) = 32
    AND reference NOT GLOB '*[^0-9a-f]*'
  ),
  content TEXT NOT NULL,
  app_version TEXT NOT NULL DEFAULT '' CHECK (length(app_version) <= 50),
  is_read INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0, 1)),
  created_at TEXT NOT NULL CHECK (
    created_at GLOB '????-??-??T??:??:??*Z'
    AND julianday(created_at) IS NOT NULL
  )
);

CREATE INDEX IF NOT EXISTS idx_feedback_created_at
  ON feedback(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_feedback_is_read_created_at
  ON feedback(is_read, created_at DESC);
