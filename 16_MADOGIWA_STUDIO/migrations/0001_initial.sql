PRAGMA foreign_keys = ON;

CREATE TABLE episodes (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  episode_number INTEGER,
  title TEXT NOT NULL,
  summary TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'generated', 'published', 'archived')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  published_at TEXT
);

CREATE TABLE prompt_versions (
  id TEXT PRIMARY KEY,
  episode_id TEXT NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  label TEXT NOT NULL DEFAULT 'Seedance prompt',
  body TEXT NOT NULL,
  version INTEGER NOT NULL,
  is_current INTEGER NOT NULL DEFAULT 1 CHECK (is_current IN (0, 1)),
  created_by TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  UNIQUE (episode_id, version)
);

CREATE UNIQUE INDEX prompt_versions_one_current
  ON prompt_versions(episode_id)
  WHERE is_current = 1;

CREATE TABLE videos (
  id TEXT PRIMARY KEY,
  episode_id TEXT NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  r2_key TEXT NOT NULL UNIQUE,
  filename TEXT NOT NULL,
  label TEXT NOT NULL DEFAULT 'Generated video',
  content_type TEXT NOT NULL DEFAULT 'video/mp4',
  size_bytes INTEGER,
  status TEXT NOT NULL DEFAULT 'upload_pending' CHECK (status IN ('upload_pending', 'ready', 'published', 'archived')),
  is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0, 1)),
  uploaded_by TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE UNIQUE INDEX videos_one_primary
  ON videos(episode_id)
  WHERE is_primary = 1;

CREATE INDEX videos_episode_id ON videos(episode_id, created_at DESC);

CREATE TABLE upload_tickets (
  id TEXT PRIMARY KEY,
  video_id TEXT NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  consumed_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX upload_tickets_video_id ON upload_tickets(video_id);
