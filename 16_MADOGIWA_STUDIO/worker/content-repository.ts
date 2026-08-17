import type {
  ArticleRow,
  EditorialContentStatus,
  GalleryItem,
  GalleryItemRow,
} from "./domain";
import { HttpError } from "./http";

export type GalleryItemInput = {
  slug: string;
  title: string;
  kind: string;
  displayOrder: number;
  status: EditorialContentStatus;
};

export type ArticleInput = {
  slug: string;
  label: string;
  source: string;
  title: string;
  copy: string;
  url: string;
  action: string;
  displayOrder: number;
  status: EditorialContentStatus;
};

function withGalleryImageUrl(item: GalleryItemRow): GalleryItem {
  return {
    ...item,
    image_url: item.image_r2_key ? `/gallery-images/${item.id}?v=${encodeURIComponent(item.updated_at)}` : item.legacy_image_path,
  };
}

export async function listGalleryItems(
  db: D1Database,
  options: { publishedOnly?: boolean; includeArchived?: boolean } = {},
): Promise<GalleryItem[]> {
  const condition = options.publishedOnly
    ? "WHERE status = 'published'"
    : options.includeArchived
      ? ""
      : "WHERE status != 'archived'";
  const result = await db
    .prepare(`SELECT * FROM gallery_items ${condition} ORDER BY display_order, created_at`)
    .all<GalleryItemRow>();
  return result.results.map(withGalleryImageUrl);
}

export async function getGalleryItem(db: D1Database, id: string): Promise<GalleryItemRow | null> {
  return db.prepare("SELECT * FROM gallery_items WHERE id = ?").bind(id).first<GalleryItemRow>();
}

export async function createGalleryItem(
  db: D1Database,
  input: GalleryItemInput,
  actor: string,
): Promise<GalleryItem> {
  const id = crypto.randomUUID();
  if (input.status === "published") throw new HttpError(400, "画像を登録してから公開してください");
  try {
    await db
      .prepare(
        `INSERT INTO gallery_items
         (id, slug, title, kind, display_order, status, created_by, updated_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(id, input.slug, input.title, input.kind, input.displayOrder, input.status, actor, actor)
      .run();
  } catch (error) {
    if (error instanceof Error && error.message.includes("UNIQUE")) {
      throw new HttpError(409, "同じslugのギャラリー項目が既にあります");
    }
    throw error;
  }
  const created = await getGalleryItem(db, id);
  if (!created) throw new Error("Created gallery item could not be loaded");
  return withGalleryImageUrl(created);
}

export async function updateGalleryItem(
  db: D1Database,
  id: string,
  input: Partial<GalleryItemInput>,
  actor: string,
): Promise<GalleryItem> {
  const current = await getGalleryItem(db, id);
  if (!current) throw new HttpError(404, "ギャラリー項目が見つかりません");
  const nextStatus = input.status ?? current.status;
  if (nextStatus === "published" && !current.image_r2_key && !current.legacy_image_path) {
    throw new HttpError(400, "画像を登録してから公開してください");
  }
  try {
    await db
      .prepare(
        `UPDATE gallery_items SET slug = ?, title = ?, kind = ?, display_order = ?, status = ?, updated_by = ?,
         archived_at = CASE WHEN ? = 'archived' THEN COALESCE(archived_at, strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) ELSE NULL END,
         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?`,
      )
      .bind(
        input.slug ?? current.slug,
        input.title ?? current.title,
        input.kind ?? current.kind,
        input.displayOrder ?? current.display_order,
        nextStatus,
        actor,
        nextStatus,
        id,
      )
      .run();
  } catch (error) {
    if (error instanceof Error && error.message.includes("UNIQUE")) {
      throw new HttpError(409, "同じslugのギャラリー項目が既にあります");
    }
    throw error;
  }
  const updated = await getGalleryItem(db, id);
  if (!updated) throw new Error("Updated gallery item could not be loaded");
  return withGalleryImageUrl(updated);
}

export async function reorderGalleryItems(db: D1Database, itemIds: string[], actor: string): Promise<GalleryItem[]> {
  const uniqueIds = [...new Set(itemIds)];
  if (uniqueIds.length !== itemIds.length) throw new HttpError(400, "並び順に重複したIDがあります");
  if (uniqueIds.length) {
    await db.batch(
      uniqueIds.map((id, index) =>
        db
          .prepare(
            `UPDATE gallery_items SET display_order = ?, updated_by = ?,
             updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?`,
          )
          .bind(index, actor, id),
      ),
    );
  }
  return listGalleryItems(db, { includeArchived: true });
}

export async function listArticles(
  db: D1Database,
  options: { publishedOnly?: boolean; includeArchived?: boolean } = {},
): Promise<ArticleRow[]> {
  const condition = options.publishedOnly
    ? "WHERE status = 'published'"
    : options.includeArchived
      ? ""
      : "WHERE status != 'archived'";
  return (await db.prepare(`SELECT * FROM articles ${condition} ORDER BY display_order, created_at`).all<ArticleRow>()).results;
}

export async function getArticle(db: D1Database, id: string): Promise<ArticleRow | null> {
  return db.prepare("SELECT * FROM articles WHERE id = ?").bind(id).first<ArticleRow>();
}

export async function createArticle(db: D1Database, input: ArticleInput, actor: string): Promise<ArticleRow> {
  const id = crypto.randomUUID();
  try {
    await db
      .prepare(
        `INSERT INTO articles
         (id, slug, label, source, title, copy, url, action, display_order, status, created_by, updated_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        input.slug,
        input.label,
        input.source,
        input.title,
        input.copy,
        input.url,
        input.action,
        input.displayOrder,
        input.status,
        actor,
        actor,
      )
      .run();
  } catch (error) {
    if (error instanceof Error && error.message.includes("UNIQUE")) {
      throw new HttpError(409, "同じslugの記事が既にあります");
    }
    throw error;
  }
  const created = await getArticle(db, id);
  if (!created) throw new Error("Created article could not be loaded");
  return created;
}

export async function updateArticle(
  db: D1Database,
  id: string,
  input: Partial<ArticleInput>,
  actor: string,
): Promise<ArticleRow> {
  const current = await getArticle(db, id);
  if (!current) throw new HttpError(404, "記事が見つかりません");
  const nextStatus = input.status ?? current.status;
  try {
    await db
      .prepare(
        `UPDATE articles SET slug = ?, label = ?, source = ?, title = ?, copy = ?, url = ?, action = ?,
         display_order = ?, status = ?, updated_by = ?,
         archived_at = CASE WHEN ? = 'archived' THEN COALESCE(archived_at, strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) ELSE NULL END,
         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?`,
      )
      .bind(
        input.slug ?? current.slug,
        input.label ?? current.label,
        input.source ?? current.source,
        input.title ?? current.title,
        input.copy ?? current.copy,
        input.url ?? current.url,
        input.action ?? current.action,
        input.displayOrder ?? current.display_order,
        nextStatus,
        actor,
        nextStatus,
        id,
      )
      .run();
  } catch (error) {
    if (error instanceof Error && error.message.includes("UNIQUE")) {
      throw new HttpError(409, "同じslugの記事が既にあります");
    }
    throw error;
  }
  const updated = await getArticle(db, id);
  if (!updated) throw new Error("Updated article could not be loaded");
  return updated;
}

export async function reorderArticles(db: D1Database, itemIds: string[], actor: string): Promise<ArticleRow[]> {
  const uniqueIds = [...new Set(itemIds)];
  if (uniqueIds.length !== itemIds.length) throw new HttpError(400, "並び順に重複したIDがあります");
  if (uniqueIds.length) {
    await db.batch(
      uniqueIds.map((id, index) =>
        db
          .prepare(
            `UPDATE articles SET display_order = ?, updated_by = ?,
             updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?`,
          )
          .bind(index, actor, id),
      ),
    );
  }
  return listArticles(db, { includeArchived: true });
}
