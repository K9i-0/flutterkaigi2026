CREATE TABLE gallery_items (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  kind TEXT NOT NULL,
  legacy_image_path TEXT NOT NULL DEFAULT '',
  image_r2_key TEXT,
  image_content_type TEXT,
  image_size_bytes INTEGER,
  display_order INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  created_by TEXT,
  updated_by TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  archived_at TEXT
);

CREATE UNIQUE INDEX gallery_items_image_r2_key
  ON gallery_items(image_r2_key)
  WHERE image_r2_key IS NOT NULL;

CREATE INDEX gallery_items_public_order
  ON gallery_items(status, display_order, created_at);

CREATE TABLE gallery_image_upload_tickets (
  id TEXT PRIMARY KEY,
  gallery_item_id TEXT NOT NULL REFERENCES gallery_items(id) ON DELETE CASCADE,
  r2_key TEXT NOT NULL UNIQUE,
  filename TEXT NOT NULL,
  content_type TEXT NOT NULL,
  token_hash TEXT NOT NULL,
  uploaded_by TEXT,
  expires_at TEXT NOT NULL,
  consumed_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX gallery_image_upload_tickets_item_id
  ON gallery_image_upload_tickets(gallery_item_id, created_at DESC);

CREATE TABLE articles (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  source TEXT NOT NULL,
  title TEXT NOT NULL,
  copy TEXT NOT NULL DEFAULT '',
  url TEXT NOT NULL,
  action TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  created_by TEXT,
  updated_by TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  archived_at TEXT
);

CREATE INDEX articles_public_order
  ON articles(status, display_order, created_at);

INSERT INTO gallery_items
  (id, slug, title, kind, legacy_image_path, display_order, status, created_by, updated_by)
VALUES
  ('30000000-0000-4000-8000-000000000001', 'regulation-team', '規制チーム、出動。', 'KEY VISUAL', '/site/gallery/regulation-team.webp', 0, 'published', 'migration', 'migration'),
  ('30000000-0000-4000-8000-000000000002', 'soba-shark', 'Soba Shark', 'SPECIAL ART', '/site/gallery/soba-shark.webp', 1, 'published', 'migration', 'migration'),
  ('30000000-0000-4000-8000-000000000003', 'takosan-homeworld', 'タコさんの故郷', 'WORLD ART', '/site/gallery/takosan-homeworld.webp', 2, 'published', 'migration', 'migration'),
  ('30000000-0000-4000-8000-000000000004', 'ichiban-kuji', '窓際族物語 一番くじ', 'COLLABORATION', '/site/gallery/ichiban-kuji.webp', 3, 'published', 'migration', 'migration');

INSERT INTO articles
  (id, slug, label, source, title, copy, url, action, display_order, status, created_by, updated_by)
VALUES
  ('40000000-0000-4000-8000-000000000001', 'original-comic', 'ORIGINAL', 'NOTE', '窓際族物語', 'そば屋の入社と、窓際から始まった物語。全14話の原作漫画をnoteで読む。', 'https://note.com/sobaya/n/nb138c222aea0', '原作を読む', 0, 'published', 'migration', 'migration'),
  ('40000000-0000-4000-8000-000000000002', 'character-introduction', 'CHARACTER', 'NOTE', '窓際族物語〜登場人物紹介〜', 'そば屋、無職やめ太郎、とーくん、福ちゃん、よーたん。物語を彩る窓際社員たちの人物紹介。', 'https://note.com/sobaya/n/n9b1ba408a198', '記事を読む', 1, 'published', 'migration', 'migration'),
  ('40000000-0000-4000-8000-000000000003', 'low-cost-video-making', 'MAKING', 'ZENN', '高性能なPCが無くても格安で窓際動画を作る', 'クラウドサービスを活用し、高性能なPCに頼らず窓際動画を低コストで制作する実践的な方法。', 'https://zenn.dev/yumemi_inc/articles/8dfa5814286ad6', '記事を読む', 2, 'published', 'migration', 'migration'),
  ('40000000-0000-4000-8000-000000000004', 'how-to-make-madogiwa', 'SLIDES', 'GOOGLE SLIDES', '窓際族物語の作り方', '「大企業の中でスタートアップするって実際どうなの会」で紹介した、窓際族物語の制作スライド。', 'https://docs.google.com/presentation/d/1Uo4ZKENR104i6vHdstXbLlBIpv3jFyLY_fyOdujchec/edit?usp=sharing', 'スライドを見る', 3, 'published', 'migration', 'migration');
