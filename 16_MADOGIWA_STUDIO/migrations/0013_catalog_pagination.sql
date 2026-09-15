CREATE INDEX episodes_public_catalog ON episodes(status, display_order, created_at DESC, id);
CREATE INDEX videos_playable_catalog ON videos(episode_id, display_order, created_at DESC, id)
  WHERE status NOT IN ('archived', 'upload_pending');
CREATE INDEX videos_pickup_catalog ON videos(episode_id)
  WHERE is_featured = 1 AND status NOT IN ('archived', 'upload_pending');
