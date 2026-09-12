-- One indexed revision read replaces repeated public-page aggregation.
-- Content writes invalidate all colos, including writes from MCP and uploads.
CREATE TABLE public_content_revision (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  revision TEXT NOT NULL
);
INSERT INTO public_content_revision VALUES (1, lower(hex(randomblob(16))));

CREATE TRIGGER public_revision_episodes_insert
AFTER INSERT ON episodes
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_episodes_update
AFTER UPDATE ON episodes
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_episodes_delete
AFTER DELETE ON episodes
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_generations_insert
AFTER INSERT ON generations
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_generations_update
AFTER UPDATE ON generations
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_generations_delete
AFTER DELETE ON generations
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_videos_insert
AFTER INSERT ON videos
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_videos_update
AFTER UPDATE ON videos
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_videos_delete
AFTER DELETE ON videos
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_members_insert
AFTER INSERT ON members
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_members_update
AFTER UPDATE ON members
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_members_delete
AFTER DELETE ON members
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_episode_members_insert
AFTER INSERT ON episode_members
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_episode_members_update
AFTER UPDATE ON episode_members
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_episode_members_delete
AFTER DELETE ON episode_members
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_prompt_versions_insert
AFTER INSERT ON prompt_versions
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_prompt_versions_update
AFTER UPDATE ON prompt_versions
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_prompt_versions_delete
AFTER DELETE ON prompt_versions
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_input_assets_insert
AFTER INSERT ON input_assets
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_input_assets_update
AFTER UPDATE ON input_assets
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_input_assets_delete
AFTER DELETE ON input_assets
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_gallery_items_insert
AFTER INSERT ON gallery_items
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_gallery_items_update
AFTER UPDATE ON gallery_items
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_gallery_items_delete
AFTER DELETE ON gallery_items
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_articles_insert
AFTER INSERT ON articles
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_articles_update
AFTER UPDATE ON articles
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

CREATE TRIGGER public_revision_articles_delete
AFTER DELETE ON articles
BEGIN
  UPDATE public_content_revision SET revision = lower(hex(randomblob(16))) WHERE id = 1;
END;

