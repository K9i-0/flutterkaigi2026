UPDATE episodes
SET status = 'published',
    published_at = COALESCE(published_at, strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
WHERE status IN ('draft', 'generated');
