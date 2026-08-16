CREATE TABLE input_assets (
  id TEXT PRIMARY KEY,
  episode_id TEXT NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  r2_key TEXT NOT NULL UNIQUE,
  filename TEXT NOT NULL,
  label TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('image', 'audio', 'document', 'other')),
  reference_label TEXT,
  group_label TEXT,
  notes TEXT NOT NULL DEFAULT '',
  content_type TEXT NOT NULL DEFAULT 'application/octet-stream',
  size_bytes INTEGER,
  status TEXT NOT NULL DEFAULT 'upload_pending' CHECK (status IN ('upload_pending', 'ready', 'archived')),
  display_order INTEGER NOT NULL DEFAULT 0,
  uploaded_by TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX input_assets_episode_id
  ON input_assets(episode_id, group_label, display_order, created_at);

CREATE TABLE input_upload_tickets (
  id TEXT PRIMARY KEY,
  asset_id TEXT NOT NULL REFERENCES input_assets(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  consumed_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX input_upload_tickets_asset_id ON input_upload_tickets(asset_id);
