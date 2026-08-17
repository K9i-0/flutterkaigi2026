import type {
  EpisodeDetail,
  EpisodeRow,
  EpisodeStatus,
  EpisodeSummary,
  GenerationDetail,
  GenerationRow,
  InputAssetKind,
  InputAssetRow,
  MemberRow,
  PromptRow,
  VideoRow,
  VideoStatus,
} from "./domain";
import { HttpError } from "./http";

export type CreateEpisodeInput = {
  slug: string;
  title: string;
  summary?: string;
  status?: EpisodeStatus;
  memberIds?: string[];
};

export type CreateVideoInput = {
  generationId: string;
  filename: string;
  label: string;
  contentType: string;
  uploadedBy: string;
  featured?: boolean;
};

export type CreateInputAssetInput = {
  generationId: string;
  filename: string;
  label: string;
  kind: InputAssetKind;
  referenceLabel?: string | null;
  groupLabel?: string | null;
  notes?: string;
  contentType: string;
  displayOrder?: number;
  uploadedBy: string;
};

type EpisodeSummaryBase = Omit<EpisodeSummary, "members" | "primary_video_poster_url"> & {
  primary_video_poster_r2_key: string | null;
};
type EpisodeMemberJoin = MemberRow & { episode_id: string };

function createStudioId(): string {
  const alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  return `MS-${Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("")}`;
}

export async function listMembers(db: D1Database): Promise<MemberRow[]> {
  return (await db.prepare("SELECT * FROM members ORDER BY sort_order, name").all<MemberRow>()).results;
}

export async function listEpisodes(db: D1Database, options?: { featuredOnly?: boolean }): Promise<EpisodeSummary[]> {
  const [episodeResult, memberResult] = await Promise.all([
    db
      .prepare(
        `SELECT e.*,
          (SELECT COUNT(*) FROM generations g WHERE g.episode_id = e.id) AS generation_count,
          (SELECT COUNT(*) FROM videos v JOIN generations g ON g.id = v.generation_id
            WHERE g.episode_id = e.id AND v.status != 'archived') AS video_count,
          (SELECT COUNT(*) FROM input_assets a JOIN generations g ON g.id = a.generation_id
            WHERE g.episode_id = e.id AND a.status != 'archived') AS input_count,
          (SELECT v.id FROM videos v JOIN generations g ON g.id = v.generation_id
            WHERE g.episode_id = e.id AND v.status NOT IN ('archived', 'upload_pending')
            ORDER BY v.is_featured DESC, v.created_at DESC, g.version DESC, v.is_primary DESC LIMIT 1) AS primary_video_id,
          (SELECT v.poster_r2_key FROM videos v JOIN generations g ON g.id = v.generation_id
            WHERE g.episode_id = e.id AND v.status NOT IN ('archived', 'upload_pending')
            ORDER BY v.is_featured DESC, v.created_at DESC, g.version DESC, v.is_primary DESC LIMIT 1) AS primary_video_poster_r2_key,
          EXISTS(SELECT 1 FROM videos v JOIN generations g ON g.id = v.generation_id
            WHERE g.episode_id = e.id AND v.is_featured = 1
              AND v.status NOT IN ('archived', 'upload_pending')) AS has_featured_video,
          (SELECT MAX(v.created_at) FROM videos v JOIN generations g ON g.id = v.generation_id
            WHERE g.episode_id = e.id AND v.is_featured = 1
              AND v.status NOT IN ('archived', 'upload_pending')) AS featured_video_created_at,
          (SELECT p.label FROM prompt_versions p JOIN generations g ON g.id = p.generation_id
            WHERE g.episode_id = e.id AND p.is_current = 1
            ORDER BY g.version DESC LIMIT 1) AS prompt_label
         FROM episodes e
         ORDER BY e.updated_at DESC, e.created_at DESC`,
      )
      .all<EpisodeSummaryBase>(),
    db
      .prepare(
        `SELECT em.episode_id, m.* FROM episode_members em
         JOIN members m ON m.id = em.member_id ORDER BY m.sort_order, m.name`,
      )
      .all<EpisodeMemberJoin>(),
  ]);
  const episodes = episodeResult.results.map((row) => {
    const { primary_video_poster_r2_key, ...episode } = row;
    return {
      ...episode,
      primary_video_poster_url:
        episode.primary_video_id && primary_video_poster_r2_key ? `/posters/${episode.primary_video_id}` : null,
      members: memberResult.results.filter((member) => member.episode_id === episode.id),
    };
  });
  return options?.featuredOnly ? episodes.filter((episode) => episode.has_featured_video === 1) : episodes;
}

export async function getEpisodeBySlug(db: D1Database, slug: string): Promise<EpisodeDetail | null> {
  const episode = await db.prepare("SELECT * FROM episodes WHERE slug = ?").bind(slug).first<EpisodeRow>();
  return episode ? getEpisodeById(db, episode.id) : null;
}

export async function getEpisodeById(db: D1Database, id: string): Promise<EpisodeDetail | null> {
  const [episode, generations, prompts, videos, inputAssets, members] = await Promise.all([
    db.prepare("SELECT * FROM episodes WHERE id = ?").bind(id).first<EpisodeRow>(),
    db.prepare("SELECT * FROM generations WHERE episode_id = ? ORDER BY version DESC").bind(id).all<GenerationRow>(),
    db.prepare("SELECT * FROM prompt_versions WHERE episode_id = ? ORDER BY version DESC").bind(id).all<PromptRow>(),
    db.prepare("SELECT * FROM videos WHERE episode_id = ? ORDER BY is_primary DESC, created_at DESC").bind(id).all<VideoRow>(),
    db
      .prepare("SELECT * FROM input_assets WHERE episode_id = ? ORDER BY COALESCE(group_label, ''), display_order, created_at")
      .bind(id)
      .all<InputAssetRow>(),
    db
      .prepare(
        `SELECT m.* FROM episode_members em JOIN members m ON m.id = em.member_id
         WHERE em.episode_id = ? ORDER BY m.sort_order, m.name`,
      )
      .bind(id)
      .all<MemberRow>(),
  ]);
  if (!episode) return null;
  const generationDetails: GenerationDetail[] = generations.results.map((generation) => {
    const promptHistory = prompts.results.filter((prompt) => prompt.generation_id === generation.id);
    return {
      ...generation,
      prompt: promptHistory.find((prompt) => prompt.is_current === 1) ?? null,
      promptHistory,
      videos: videos.results.filter((video) => video.generation_id === generation.id),
      inputAssets: inputAssets.results.filter((asset) => asset.generation_id === generation.id),
    };
  });
  return { episode, members: members.results, generations: generationDetails };
}

export async function createEpisode(db: D1Database, input: CreateEpisodeInput, actor: string): Promise<EpisodeRow> {
  const id = crypto.randomUUID();
  const generationId = crypto.randomUUID();
  const studioId = createStudioId();
  const memberIds = [...new Set(input.memberIds ?? [])];
  try {
    await db.batch([
      db
        .prepare(
          `INSERT INTO episodes (id, studio_id, slug, title, summary, status, published_at)
           VALUES (?, ?, ?, ?, ?, ?, CASE WHEN ? = 'published' THEN strftime('%Y-%m-%dT%H:%M:%fZ', 'now') END)`,
        )
        .bind(id, studioId, input.slug, input.title, input.summary ?? "", input.status ?? "published", input.status ?? "published"),
      db
        .prepare(
          `INSERT INTO generations (id, episode_id, version, label, created_by)
           VALUES (?, ?, 1, '初回生成', ?)`,
        )
        .bind(generationId, id, actor),
      ...memberIds.map((memberId) =>
        db.prepare("INSERT INTO episode_members (episode_id, member_id) VALUES (?, ?)").bind(id, memberId),
      ),
    ]);
  } catch (error) {
    if (error instanceof Error && error.message.includes("UNIQUE")) {
      throw new HttpError(409, "同じslugのエピソードが既にあります");
    }
    throw error;
  }
  const created = await db.prepare("SELECT * FROM episodes WHERE id = ?").bind(id).first<EpisodeRow>();
  if (!created) throw new Error("Created episode could not be loaded");
  return created;
}

export async function createGeneration(
  db: D1Database,
  episodeId: string,
  label: string,
  modelName: string | null | undefined,
  notes: string,
  actor: string,
): Promise<GenerationRow> {
  const latest = await db
    .prepare("SELECT COALESCE(MAX(version), 0) AS version FROM generations WHERE episode_id = ?")
    .bind(episodeId)
    .first<{ version: number }>();
  const id = crypto.randomUUID();
  const version = (latest?.version ?? 0) + 1;
  await db
    .prepare("INSERT INTO generations (id, episode_id, version, label, model_name, notes, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)")
    .bind(id, episodeId, version, label || `生成 v${version}`, modelName || null, notes, actor)
    .run();
  const generation = await db.prepare("SELECT * FROM generations WHERE id = ?").bind(id).first<GenerationRow>();
  if (!generation) throw new Error("Created generation could not be loaded");
  return generation;
}

export async function updateGeneration(
  db: D1Database,
  id: string,
  input: { label?: string; modelName?: string | null; notes?: string },
): Promise<GenerationRow> {
  const current = await db.prepare("SELECT * FROM generations WHERE id = ?").bind(id).first<GenerationRow>();
  if (!current) throw new HttpError(404, "生成バージョンが見つかりません");
  await db
    .prepare(
      `UPDATE generations SET label = ?, model_name = ?, notes = ?,
       updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?`,
    )
    .bind(
      input.label ?? current.label,
      input.modelName === undefined ? current.model_name : input.modelName || null,
      input.notes ?? current.notes,
      id,
    )
    .run();
  const updated = await db.prepare("SELECT * FROM generations WHERE id = ?").bind(id).first<GenerationRow>();
  if (!updated) throw new Error("Updated generation could not be loaded");
  return updated;
}

export async function updateEpisode(
  db: D1Database,
  id: string,
  input: Partial<CreateEpisodeInput>,
): Promise<EpisodeRow> {
  const current = await db.prepare("SELECT * FROM episodes WHERE id = ?").bind(id).first<EpisodeRow>();
  if (!current) throw new HttpError(404, "エピソードが見つかりません");
  await db
    .prepare(
      `UPDATE episodes SET slug = ?, title = ?, summary = ?, status = ?,
       published_at = CASE WHEN ? = 'published' THEN COALESCE(published_at, strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) ELSE published_at END,
       updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?`,
    )
    .bind(
      input.slug ?? current.slug,
      input.title ?? current.title,
      input.summary ?? current.summary,
      input.status ?? current.status,
      input.status ?? current.status,
      id,
    )
    .run();
  const updated = await db.prepare("SELECT * FROM episodes WHERE id = ?").bind(id).first<EpisodeRow>();
  if (!updated) throw new Error("Updated episode could not be loaded");
  return updated;
}

export async function updateEpisodeMembers(db: D1Database, episodeId: string, memberIds: string[]): Promise<MemberRow[]> {
  const uniqueIds = [...new Set(memberIds)];
  await db.batch([
    db.prepare("DELETE FROM episode_members WHERE episode_id = ?").bind(episodeId),
    ...uniqueIds.map((memberId) =>
      db.prepare("INSERT INTO episode_members (episode_id, member_id) VALUES (?, ?)").bind(episodeId, memberId),
    ),
    db.prepare("UPDATE episodes SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?").bind(episodeId),
  ]);
  return (
    await db
      .prepare(
        `SELECT m.* FROM episode_members em JOIN members m ON m.id = em.member_id
         WHERE em.episode_id = ? ORDER BY m.sort_order, m.name`,
      )
      .bind(episodeId)
      .all<MemberRow>()
  ).results;
}

export async function upsertPrompt(
  db: D1Database,
  generationId: string,
  label: string,
  body: string,
  createdBy: string,
): Promise<PromptRow> {
  const generation = await db.prepare("SELECT episode_id FROM generations WHERE id = ?").bind(generationId).first<{ episode_id: string }>();
  if (!generation) throw new HttpError(404, "生成バージョンが見つかりません");
  const latest = await db
    .prepare("SELECT COALESCE(MAX(version), 0) AS version FROM prompt_versions WHERE episode_id = ?")
    .bind(generation.episode_id)
    .first<{ version: number }>();
  const id = crypto.randomUUID();
  const version = (latest?.version ?? 0) + 1;
  await db.batch([
    db.prepare("UPDATE prompt_versions SET is_current = 0 WHERE generation_id = ?").bind(generationId),
    db
      .prepare(
        `INSERT INTO prompt_versions (id, episode_id, generation_id, label, body, version, is_current, created_by)
         VALUES (?, ?, ?, ?, ?, ?, 1, ?)`,
      )
      .bind(id, generation.episode_id, generationId, label, body, version, createdBy),
    db.prepare("UPDATE generations SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?").bind(generationId),
    db.prepare("UPDATE episodes SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?").bind(generation.episode_id),
  ]);
  const prompt = await db.prepare("SELECT * FROM prompt_versions WHERE id = ?").bind(id).first<PromptRow>();
  if (!prompt) throw new Error("Created prompt could not be loaded");
  return prompt;
}

export async function createVideo(db: D1Database, input: CreateVideoInput): Promise<VideoRow> {
  const generation = await db.prepare("SELECT episode_id FROM generations WHERE id = ?").bind(input.generationId).first<{ episode_id: string }>();
  if (!generation) throw new HttpError(404, "生成バージョンが見つかりません");
  const id = crypto.randomUUID();
  const safeFilename = input.filename.replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "") || "video.mp4";
  const r2Key = `episodes/${generation.episode_id}/generations/${input.generationId}/videos/${id}/${safeFilename}`;
  const existingCount = await db
    .prepare("SELECT COUNT(*) AS count FROM videos WHERE generation_id = ? AND status != 'archived'")
    .bind(input.generationId)
    .first<{ count: number }>();
  await db
    .prepare(
      `INSERT INTO videos
       (id, episode_id, generation_id, r2_key, filename, label, content_type, status, is_primary, is_featured, uploaded_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'upload_pending', ?, ?, ?)`,
    )
    .bind(
      id,
      generation.episode_id,
      input.generationId,
      r2Key,
      input.filename,
      input.label,
      input.contentType,
      (existingCount?.count ?? 0) === 0 ? 1 : 0,
      input.featured ? 1 : 0,
      input.uploadedBy,
    )
    .run();
  const video = await getVideo(db, id);
  if (!video) throw new Error("Created video could not be loaded");
  return video;
}

export async function getVideo(db: D1Database, id: string): Promise<VideoRow | null> {
  return db.prepare("SELECT * FROM videos WHERE id = ?").bind(id).first<VideoRow>();
}

export async function createInputAsset(db: D1Database, input: CreateInputAssetInput): Promise<InputAssetRow> {
  const generation = await db.prepare("SELECT episode_id FROM generations WHERE id = ?").bind(input.generationId).first<{ episode_id: string }>();
  if (!generation) throw new HttpError(404, "生成バージョンが見つかりません");
  const id = crypto.randomUUID();
  const safeFilename = input.filename.replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "") || "input.bin";
  const r2Key = `episodes/${generation.episode_id}/generations/${input.generationId}/inputs/${id}/${safeFilename}`;
  await db
    .prepare(
      `INSERT INTO input_assets
       (id, episode_id, generation_id, r2_key, filename, label, kind, reference_label, group_label, notes,
        content_type, display_order, uploaded_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
    .bind(
      id,
      generation.episode_id,
      input.generationId,
      r2Key,
      input.filename,
      input.label,
      input.kind,
      input.referenceLabel || null,
      input.groupLabel || null,
      input.notes ?? "",
      input.contentType,
      input.displayOrder ?? 0,
      input.uploadedBy,
    )
    .run();
  const asset = await getInputAsset(db, id);
  if (!asset) throw new Error("Created input asset could not be loaded");
  return asset;
}

export async function getInputAsset(db: D1Database, id: string): Promise<InputAssetRow | null> {
  return db.prepare("SELECT * FROM input_assets WHERE id = ?").bind(id).first<InputAssetRow>();
}

export async function setVideoStatus(db: D1Database, id: string, status: VideoStatus): Promise<VideoRow> {
  await db
    .prepare("UPDATE videos SET status = ?, updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?")
    .bind(status, id)
    .run();
  const video = await getVideo(db, id);
  if (!video) throw new HttpError(404, "動画が見つかりません");
  return video;
}

export async function setVideoFeatured(db: D1Database, id: string, featured: boolean): Promise<VideoRow> {
  await db
    .prepare("UPDATE videos SET is_featured = ?, updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?")
    .bind(featured ? 1 : 0, id)
    .run();
  const video = await getVideo(db, id);
  if (!video) throw new HttpError(404, "動画が見つかりません");
  return video;
}
