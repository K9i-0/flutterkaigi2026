-- Preserve the current order at migration; new MCP registrations go first.
ALTER TABLE episodes ADD COLUMN display_order INTEGER NOT NULL DEFAULT -1;
ALTER TABLE episodes ADD COLUMN representative_video_id TEXT;
ALTER TABLE videos ADD COLUMN display_order INTEGER NOT NULL DEFAULT -1;
WITH ranked AS (SELECT id, ROW_NUMBER() OVER (ORDER BY updated_at DESC, created_at DESC, id) AS position FROM episodes)
UPDATE episodes SET display_order = (SELECT position FROM ranked WHERE ranked.id = episodes.id);
WITH ranked AS (SELECT id, ROW_NUMBER() OVER (PARTITION BY episode_id ORDER BY is_featured DESC, created_at DESC, id) AS position FROM videos)
UPDATE videos SET display_order = (SELECT position FROM ranked WHERE ranked.id = videos.id);
CREATE INDEX episodes_display_order ON episodes(display_order, created_at DESC);
CREATE INDEX videos_display_order ON videos(episode_id, display_order, created_at DESC);
-- A failed guard aborts the whole D1 batch when content changes during a save.
CREATE TABLE admin_write_guards (id TEXT PRIMARY KEY, valid INTEGER NOT NULL CHECK(valid = 1));
