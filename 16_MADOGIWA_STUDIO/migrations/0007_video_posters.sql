ALTER TABLE videos ADD COLUMN poster_r2_key TEXT;

CREATE UNIQUE INDEX videos_poster_r2_key
  ON videos(poster_r2_key)
  WHERE poster_r2_key IS NOT NULL;

CREATE TABLE poster_upload_tickets (
  id TEXT PRIMARY KEY,
  video_id TEXT NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  consumed_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX poster_upload_tickets_video_id
  ON poster_upload_tickets(video_id);
