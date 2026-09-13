import { z } from "zod";
import { HttpError } from "./http";
import { getEpisodeById } from "./repository";
import { memberIdsSchema } from "./schemas";

export const orderSchema = z.object({
  itemIds: z.array(z.string().uuid()).max(1000),
  previousIds: z.array(z.string().uuid()).max(1000),
});
export const editorSchema = z.object({
  title: z.string().trim().min(1).max(120),
  summary: z.string().trim().max(1000),
  status: z.enum(["published", "archived"]),
  memberIds: memberIdsSchema,
  representativeVideoId: z.string().uuid().nullable(),
  expectedUpdatedAt: z.string(),
  videos: z.array(z.object({
    id: z.string().uuid(), label: z.string().trim().min(1).max(120), featured: z.boolean(),
    status: z.enum(["upload_pending", "ready", "published", "archived"]), expectedUpdatedAt: z.string(),
  })).max(1000),
});

async function revision(db: D1Database) {
  return db.prepare("SELECT revision FROM public_content_revision WHERE id = 1").first<string>("revision");
}
async function guardedBatch(db: D1Database, expected: string | null, statements: D1PreparedStatement[]) {
  const id = crypto.randomUUID();
  try {
    await db.batch([
      db.prepare("INSERT INTO admin_write_guards(id, valid) SELECT ?, CASE WHEN revision = ? THEN 1 ELSE 0 END FROM public_content_revision WHERE id = 1").bind(id, expected),
      ...statements,
      db.prepare("DELETE FROM admin_write_guards WHERE id = ?").bind(id),
    ]);
  } catch (error) {
    if (error instanceof Error && error.message.includes("CHECK constraint failed")) throw new HttpError(409, "別の更新がありました。再読み込みしてから保存してください。");
    throw error;
  }
}

export async function reorderEpisodes(db: D1Database, input: z.infer<typeof orderSchema>) {
  const expected = await revision(db);
  const rows = await db.prepare("SELECT id FROM episodes ORDER BY display_order, created_at DESC, id").all<{id: string}>();
  validateOrder(rows.results.map((row) => row.id), input);
  await guardedBatch(db, expected, input.itemIds.map((id, index) => db.prepare("UPDATE episodes SET display_order = ? WHERE id = ?").bind(index, id)));
}
function validateOrder(current: string[], input: z.infer<typeof orderSchema>) {
  if (JSON.stringify(current) !== JSON.stringify(input.previousIds)) throw new HttpError(409, "一覧が更新されています。再読み込みしてから並べ替えてください。");
  if (new Set(input.itemIds).size !== current.length || input.itemIds.length !== current.length || input.itemIds.some((id) => !current.includes(id))) throw new HttpError(400, "並び順には対象の全IDを重複なく指定してください。");
}
export async function saveEpisodeEditor(db: D1Database, episodeId: string, input: z.infer<typeof editorSchema>) {
  const expected = await revision(db);
  const detail = await getEpisodeById(db, episodeId);
  if (!detail) throw new HttpError(404, "作品が見つかりません");
  const currentVideos = detail.generations.flatMap((generation) => generation.videos);
  if (detail.episode.updated_at !== input.expectedUpdatedAt || input.videos.length !== currentVideos.length || currentVideos.some((video) => !input.videos.some((item) => item.id === video.id && item.expectedUpdatedAt === video.updated_at))) throw new HttpError(409, "作品が更新されています。再読み込みしてから編集してください。");
  if (new Set(input.videos.map((video) => video.id)).size !== input.videos.length) throw new HttpError(400, "動画IDが重複しています");
  const members = await db.prepare("SELECT id FROM members").all<{id: string}>();
  if (input.memberIds.some((id) => !members.results.some((member) => member.id === id))) throw new HttpError(400, "登場人物が見つかりません");
  if (input.representativeVideoId && !input.videos.some((video) => video.id === input.representativeVideoId && (video.status === "ready" || video.status === "published"))) throw new HttpError(400, "代表には再生できる動画を選択してください");
  // Upload completion remains exclusively owned by the upload workflow.
  if (input.videos.some((video) => (video.status === "upload_pending") !== (currentVideos.find((item) => item.id === video.id)?.status === "upload_pending"))) throw new HttpError(400, "アップロード中の動画の状態は変更できません");
  const statements = [
    db.prepare("UPDATE episodes SET title = ?, summary = ?, status = ?, representative_video_id = ?, published_at = CASE WHEN ? = 'published' THEN COALESCE(published_at, strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) ELSE published_at END, updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?").bind(input.title, input.summary, input.status, input.representativeVideoId, input.status, episodeId),
    db.prepare("DELETE FROM episode_members WHERE episode_id = ?").bind(episodeId),
    ...[...new Set(input.memberIds)].map((id) => db.prepare("INSERT INTO episode_members(episode_id, member_id) VALUES (?, ?)").bind(episodeId, id)),
    ...input.videos.map((video, index) => db.prepare("UPDATE videos SET label = ?, is_featured = ?, status = ?, display_order = ?, updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ? AND episode_id = ?").bind(video.label, Number(video.featured), video.status, index, video.id, episodeId)),
  ];
  await guardedBatch(db, expected, statements);
  return getEpisodeById(db, episodeId);
}
