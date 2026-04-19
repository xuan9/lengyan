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
