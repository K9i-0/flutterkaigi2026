PRAGMA defer_foreign_keys = true;

ALTER TABLE episodes ADD COLUMN studio_id TEXT;
UPDATE episodes
SET studio_id = CASE
  WHEN id = '00000000-0000-4000-8000-000000000040' THEN 'MS-7K9Q2F'
  ELSE 'MS-' || upper(substr(hex(randomblob(3)), 1, 6))
END
WHERE studio_id IS NULL;
CREATE UNIQUE INDEX episodes_studio_id ON episodes(studio_id);

CREATE TABLE generations (
  id TEXT PRIMARY KEY,
  episode_id TEXT NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  version INTEGER NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  model_name TEXT,
  notes TEXT NOT NULL DEFAULT '',
  created_by TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  UNIQUE (episode_id, version)
);

INSERT INTO generations (id, episode_id, version, label, model_name, notes, created_by)
SELECT
  '20000000-0000-4000-8000-000000000040',
  id,
  1,
  '初回生成',
  'Seedance 2.0',
  '既存データから移行',
  'migration'
FROM episodes
WHERE id = '00000000-0000-4000-8000-000000000040';

ALTER TABLE prompt_versions ADD COLUMN generation_id TEXT REFERENCES generations(id);
ALTER TABLE videos ADD COLUMN generation_id TEXT REFERENCES generations(id);
ALTER TABLE input_assets ADD COLUMN generation_id TEXT REFERENCES generations(id);

UPDATE prompt_versions SET generation_id = '20000000-0000-4000-8000-000000000040'
WHERE episode_id = '00000000-0000-4000-8000-000000000040';
UPDATE videos SET generation_id = '20000000-0000-4000-8000-000000000040'
WHERE episode_id = '00000000-0000-4000-8000-000000000040';
UPDATE input_assets SET generation_id = '20000000-0000-4000-8000-000000000040'
WHERE episode_id = '00000000-0000-4000-8000-000000000040';

DROP INDEX prompt_versions_one_current;
CREATE UNIQUE INDEX prompt_versions_one_current_per_generation
  ON prompt_versions(generation_id)
  WHERE is_current = 1;

DROP INDEX videos_one_primary;
CREATE UNIQUE INDEX videos_one_primary_per_generation
  ON videos(generation_id)
  WHERE is_primary = 1;

CREATE INDEX prompt_versions_generation_id ON prompt_versions(generation_id, version DESC);
CREATE INDEX videos_generation_id ON videos(generation_id, is_primary DESC, created_at DESC);
CREATE INDEX input_assets_generation_id ON input_assets(generation_id, group_label, display_order, created_at);

CREATE TABLE members (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
);

INSERT INTO members (id, slug, name, sort_order) VALUES
  ('sobaya', 'sobaya', 'そば屋', 1),
  ('takosan', 'takosan', 'たこさん', 2),
  ('tokun', 'tokun', 'とーくん', 3),
  ('yotan', 'yotan', 'よーたん', 4),
  ('fukuchan', 'fukuchan', '福ちゃん', 5),
  ('yametaro', 'yametaro', '無職やめたろう', 6),
  ('okayaman', 'okayaman', '窓際王おかやまん', 7),
  ('yumemin', 'yumemin', 'ゆめみん', 8);

CREATE TABLE episode_members (
  episode_id TEXT NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  PRIMARY KEY (episode_id, member_id)
);
CREATE INDEX episode_members_member_id ON episode_members(member_id, episode_id);

INSERT INTO episode_members (episode_id, member_id) VALUES
  ('00000000-0000-4000-8000-000000000040', 'sobaya'),
  ('00000000-0000-4000-8000-000000000040', 'fukuchan'),
  ('00000000-0000-4000-8000-000000000040', 'yametaro');
