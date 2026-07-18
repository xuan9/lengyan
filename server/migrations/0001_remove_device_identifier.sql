-- Rebuild the existing table without device_id. Intentionally do not copy
-- that legacy column so previously stored device identifiers are deleted.
-- Wrangler applies each D1 migration atomically and records it once applied.

CREATE TABLE feedback_without_device_identifier (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  content TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'feedback' CHECK (type IN ('feedback', 'bug', 'suggestion')),
  device TEXT NOT NULL DEFAULT '',
  os TEXT NOT NULL DEFAULT '',
  app_version TEXT NOT NULL DEFAULT '',
  is_read INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0, 1)),
  created_at TEXT NOT NULL
);

INSERT INTO feedback_without_device_identifier (
  id,
  content,
  type,
  device,
  os,
  app_version,
  is_read,
  created_at
)
SELECT
  id,
  content,
  CASE
    WHEN type IN ('feedback', 'bug', 'suggestion') THEN type
    ELSE 'feedback'
  END,
  COALESCE(device, ''),
  COALESCE(os, ''),
  COALESCE(app_version, ''),
  CASE WHEN is_read = 1 THEN 1 ELSE 0 END,
  created_at
FROM feedback;

DROP TABLE feedback;
ALTER TABLE feedback_without_device_identifier RENAME TO feedback;

CREATE INDEX idx_feedback_created_at
  ON feedback(created_at DESC);

CREATE INDEX idx_feedback_is_read_created_at
  ON feedback(is_read, created_at DESC);
