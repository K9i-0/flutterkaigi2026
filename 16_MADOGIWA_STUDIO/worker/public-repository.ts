import type { EpisodeRow, EpisodeSummary, MemberRow, VideoRow } from "./domain";
import { cachedPublicData } from "./public-cache";

// Batch each relation once instead of running eight correlated subqueries for
// every episode. No prompt history or input-asset counts on public list pages.
export const PUBLIC_EPISODE_QUERIES = {
  episodes: `SELECT e.*, COUNT(g.id) AS generation_count
    FROM episodes e LEFT JOIN generations g ON g.episode_id = e.id
    WHERE e.status = 'published' GROUP BY e.id
    ORDER BY e.display_order, e.created_at DESC, e.id`,
  videos: `SELECT v.id, v.episode_id, v.status, v.poster_r2_key, v.is_featured, v.created_at
    FROM videos v JOIN generations g ON g.id = v.generation_id
    JOIN episodes e ON e.id = g.episode_id
    WHERE e.status = 'published' AND v.status != 'archived'
    ORDER BY v.display_order, v.created_at DESC, v.id`,
  members: `SELECT em.episode_id, m.* FROM episode_members em
    JOIN episodes e ON e.id = em.episode_id JOIN members m ON m.id = em.member_id
    WHERE e.status = 'published' ORDER BY m.sort_order, m.name`,
};

export async function queryPublicEpisodes(db: D1Database): Promise<EpisodeSummary[]> {
  const [episodes, videos, members] = await Promise.all([
    db.prepare(PUBLIC_EPISODE_QUERIES.episodes).all<EpisodeRow & { generation_count: number }>(),
    db.prepare(PUBLIC_EPISODE_QUERIES.videos).all<Pick<VideoRow, "id" | "episode_id" | "status" | "poster_r2_key" | "is_featured" | "created_at">>(),
    db.prepare(PUBLIC_EPISODE_QUERIES.members).all<MemberRow & { episode_id: string }>(),
  ]);
  const byId = new Map<string, EpisodeSummary>(episodes.results.map((episode) => [episode.id, {
    ...episode, video_count: 0, input_count: 0, prompt_label: null,
    primary_video_id: null, primary_video_poster_url: null,
    has_featured_video: 0, featured_video_created_at: null, members: [],
  }]));
  for (const video of videos.results) {
    const episode = byId.get(video.episode_id);
    if (!episode) continue;
    episode.video_count++;
    if (video.status === "upload_pending") continue;
    if (!episode.primary_video_id || video.id === episode.representative_video_id) {
      episode.primary_video_id = video.id;
      episode.primary_video_poster_url = video.poster_r2_key ? `/posters/${video.id}` : null;
    }
    if (video.is_featured && (!episode.featured_video_created_at || video.created_at > episode.featured_video_created_at)) {
      episode.has_featured_video = 1;
      episode.featured_video_created_at = video.created_at;
    }
  }
  for (const { episode_id, ...member } of members.results) byId.get(episode_id)?.members.push(member);
  return [...byId.values()];
}

export function listPublicEpisodes(db: D1Database): Promise<EpisodeSummary[]> {
  return cachedPublicData(db, "episodes", () => queryPublicEpisodes(db));
}

export function listPublicSitemapEntries(db: D1Database) {
  return cachedPublicData(db, "sitemap", async () => {
    const result = await db.prepare(`SELECT '/episodes/' || slug AS path, updated_at FROM episodes WHERE status = 'published'
      UNION ALL SELECT '/gallery/' || slug AS path, updated_at FROM gallery_items WHERE status = 'published'`).all<{ path: string; updated_at: string }>();
    return result.results;
  });
}
