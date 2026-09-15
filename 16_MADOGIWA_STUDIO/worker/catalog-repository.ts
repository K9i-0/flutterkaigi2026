import type { MemberRow } from './domain';
import { cachedPublicData } from './public-cache';
import { CATALOG_SIZE, catalogCursor, parseCatalogCursor, type CatalogOptions, type CatalogPage, type PublicCard } from '../src/lib/catalog';

// Partial indexes support the playable-video lookup and the pickup EXISTS.
// Only the selected card's poster is read; no generation or video counts.
export async function queryCatalog(db: D1Database, options: CatalogOptions = {}, paginated = true): Promise<CatalogPage> {
  const cursor = parseCatalogCursor(options.cursor);
  const where = ["e.status = 'published'", "e.title NOT LIKE '%検証%'", 'v.id IS NOT NULL'];
  const bindings: (string | number)[] = [];
  if (!options.all) where.push("EXISTS (SELECT 1 FROM videos f WHERE f.episode_id = e.id AND f.is_featured = 1 AND f.status NOT IN ('archived', 'upload_pending'))");
  if (options.member) {
    where.push('EXISTS (SELECT 1 FROM episode_members em JOIN members m ON m.id = em.member_id WHERE em.episode_id = e.id AND m.slug = ?)');
    bindings.push(options.member);
  }
  if (cursor) {
    const [order, created, id] = cursor;
    const op = options.backwards ? '<' : '>';
    const dateOp = options.backwards ? '>' : '<';
    where.push(`(e.display_order ${op} ? OR (e.display_order = ? AND e.created_at ${dateOp} ?) OR (e.display_order = ? AND e.created_at = ? AND e.id ${op} ?))`);
    bindings.push(order, order, created, order, created, id);
  }
  const sort = options.backwards ? 'e.display_order DESC, e.created_at, e.id DESC' : 'e.display_order, e.created_at DESC, e.id';
  const result = await db.prepare(`SELECT e.*, v.id AS primary_video_id,
    CASE WHEN v.poster_r2_key IS NOT NULL THEN '/posters/' || v.id ELSE NULL END AS primary_video_poster_url,
    EXISTS (SELECT 1 FROM videos f WHERE f.episode_id = e.id AND f.is_featured = 1 AND f.status NOT IN ('archived', 'upload_pending')) AS has_featured_video
    FROM episodes e LEFT JOIN videos v ON v.id = COALESCE(
      (SELECT r.id FROM videos r WHERE r.id = e.representative_video_id AND r.episode_id = e.id AND r.status NOT IN ('archived', 'upload_pending')),
      (SELECT p.id FROM videos p WHERE p.episode_id = e.id AND p.status NOT IN ('archived', 'upload_pending') ORDER BY p.display_order, p.created_at DESC, p.id LIMIT 1)
    ) WHERE ${where.join(' AND ')} ORDER BY ${sort} ${paginated ? `LIMIT ${CATALOG_SIZE + 1}` : ''}`).bind(...bindings).all<Omit<PublicCard, 'members'>>();
  const more = paginated && result.results.length > CATALOG_SIZE;
  const selected = paginated ? result.results.slice(0, CATALOG_SIZE) : result.results;
  if (options.backwards) selected.reverse();
  const episodes: PublicCard[] = selected.map(row => ({ ...row, members: [] }));
  if (episodes.length) {
    const members = await db.prepare(`SELECT em.episode_id, m.* FROM episode_members em JOIN members m ON m.id = em.member_id
      WHERE em.episode_id IN (${episodes.map(() => '?').join(',')}) ORDER BY m.sort_order, m.name`).bind(...episodes.map(e => e.id)).all<MemberRow & { episode_id: string }>();
    const byId = new Map(episodes.map(e => [e.id, e]));
    for (const { episode_id, ...member } of members.results) byId.get(episode_id)?.members.push(member);
  }
  const first = episodes[0], last = episodes.at(-1);
  return {
    episodes,
    previous: first && (options.backwards ? more : !!cursor) ? catalogCursor(first) : undefined,
    next: last && (options.backwards ? !!cursor : more) ? catalogCursor(last) : undefined,
  };
}

export function listCatalog(db: D1Database, options: CatalogOptions = {}, paginated = true) {
  parseCatalogCursor(options.cursor);
  if (options.member && !/^[a-z0-9_-]{1,80}$/.test(options.member)) throw new Error('Invalid member');
  const normalized = { all: !!options.all, member: options.member || '', cursor: options.cursor || '', backwards: !!options.backwards };
  return cachedPublicData(db, `catalog-v1:${paginated}:${JSON.stringify(normalized)}`, () => queryCatalog(db, normalized, paginated));
}
