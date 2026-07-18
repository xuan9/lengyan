-- Baseline for a brand-new D1 database. CREATE IF NOT EXISTS also makes this
-- safe when an existing database recorded 0001 before this baseline was added.

CREATE TABLE IF NOT EXISTS feedback (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  content TEXT NOT NULL,
  type TEXT DEFAULT 'feedback',
  device TEXT DEFAULT '',
  os TEXT DEFAULT '',
  app_version TEXT DEFAULT '',
  is_read INTEGER DEFAULT 0,
  created_at TEXT NOT NULL
);
