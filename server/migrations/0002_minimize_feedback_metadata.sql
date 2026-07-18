-- Add a random public reference. Legacy clients had no per-send diagnostic
-- opt-in, so historical device, OS, version, and build metadata are discarded.

CREATE TABLE feedback_minimized (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reference TEXT NOT NULL UNIQUE CHECK (
    length(reference) = 32
    AND reference NOT GLOB '*[^0-9a-f]*'
  ),
  content TEXT NOT NULL,
  device_family TEXT NOT NULL DEFAULT '' CHECK (
    device_family IN ('', 'iPhone', 'iPad', 'Mac')
  ),
  os_version TEXT NOT NULL DEFAULT '' CHECK (
    length(os_version) <= 10
    AND (
      os_version = ''
      OR (
        os_version NOT GLOB '*[^0-9.]*'
        AND substr(os_version, 1, 1) GLOB '[0-9]'
        AND substr(os_version, -1, 1) GLOB '[0-9]'
        AND length(os_version) - length(replace(os_version, '.', '')) <= 1
      )
    )
  ),
  app_version TEXT NOT NULL DEFAULT '' CHECK (length(app_version) <= 50),
  build TEXT NOT NULL DEFAULT '' CHECK (length(build) <= 50),
  is_read INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0, 1)),
  created_at TEXT NOT NULL CHECK (
    created_at GLOB '????-??-??T??:??:??*Z'
    AND julianday(created_at) IS NOT NULL
  )
);

INSERT INTO feedback_minimized (
  id,
  reference,
  content,
  device_family,
  os_version,
  app_version,
  build,
  is_read,
  created_at
)
SELECT
  id,
  lower(hex(randomblob(16))),
  content,
  '',
  '',
  '',
  '',
  CASE WHEN is_read = 1 THEN 1 ELSE 0 END,
  CASE
    WHEN created_at GLOB '????-??-??T??:??:??*Z' THEN created_at
    ELSE strftime('%Y-%m-%dT%H:%M:%fZ', created_at)
  END
FROM feedback
WHERE julianday(created_at) >= julianday('now', '-58 days');

DROP TABLE feedback;
ALTER TABLE feedback_minimized RENAME TO feedback;

CREATE INDEX idx_feedback_created_at
  ON feedback(created_at DESC);

CREATE INDEX idx_feedback_is_read_created_at
  ON feedback(is_read, created_at DESC);
