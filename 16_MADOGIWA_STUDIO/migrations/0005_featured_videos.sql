ALTER TABLE videos ADD COLUMN is_featured INTEGER NOT NULL DEFAULT 0 CHECK (is_featured IN (0, 1));

CREATE INDEX videos_featured_latest
  ON videos(is_featured, created_at DESC)
  WHERE is_featured = 1;
