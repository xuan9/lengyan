-- Rebuild the table so diagnostic fields are structurally impossible to
-- retain. Earlier migrations cleared these columns; this migration removes
-- them while preserving the minimized public App version.

CREATE TABLE feedback_minimal (
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

INSERT INTO feedback_minimal (
  id,
  reference,
  content,
  app_version,
  is_read,
  created_at
)
SELECT
  id,
  reference,
  content,
  app_version,
  CASE WHEN is_read = 1 THEN 1 ELSE 0 END,
  CASE
    WHEN created_at GLOB '????-??-??T??:??:??*Z' THEN created_at
    ELSE strftime('%Y-%m-%dT%H:%M:%fZ', created_at)
  END
FROM feedback
WHERE julianday(created_at) >= julianday('now', '-57 days');

DROP TABLE feedback;
ALTER TABLE feedback_minimal RENAME TO feedback;

CREATE INDEX idx_feedback_created_at
  ON feedback(created_at DESC);

CREATE INDEX idx_feedback_is_read_created_at
  ON feedback(is_read, created_at DESC);
