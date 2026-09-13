import { env } from "cloudflare:workers";
import { createExecutionContext } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { editorSchema, reorderEpisodes, saveEpisodeEditor } from "../worker/editor-repository";
import { createEpisode, createGeneration, createVideo, getEpisodeById, listEpisodes, setVideoFeatured, setVideoStatus, updateEpisode } from "../worker/repository";
import { listPublicEpisodes } from "../worker/public-repository";
import { loadPublicEpisode } from "../src/server/public-data.server";
import worker from "../worker";

async function fixture() {
  const episode = await createEpisode(env.DB, {slug: crypto.randomUUID(), title: "編集テスト", memberIds: ["sobaya"]}, "test");
  const detail = (await getEpisodeById(env.DB, episode.id))!;
  const first = await createVideo(env.DB, {generationId: detail.generations[0].id, filename: "a.mp4", label: "初版", contentType: "video/mp4", uploadedBy: "test"});
  const generation = await createGeneration(env.DB, episode.id, "改訂", null, "", "test");
  const second = await createVideo(env.DB, {generationId: generation.id, filename: "b.mp4", label: "改訂版", contentType: "video/mp4", uploadedBy: "test"});
  await setVideoStatus(env.DB, first.id, "ready"); await setVideoStatus(env.DB, second.id, "ready");
  return {episode, first, second};
}
async function draft(id: string) {
  const detail = (await getEpisodeById(env.DB, id))!;
  return editorSchema.parse({title: detail.episode.title, summary: "", status: "published", memberIds: ["sobaya"], representativeVideoId: null, expectedUpdatedAt: detail.episode.updated_at,
    videos: detail.generations.flatMap((generation) => generation.videos).map((video) => ({id: video.id, label: video.label, status: video.status, featured: !!video.is_featured, expectedUpdatedAt: video.updated_at}))});
}
describe("editing existing content", () => {
  it("saves titles, members, video order and representative independently of featured, invalidating warm public data", async () => {
    const {episode, first, second} = await fixture();
    await listPublicEpisodes(env.DB); await loadPublicEpisode(episode.slug);
    const input = await draft(episode.id);
    input.title = "変更後"; input.memberIds = ["fukuchan"];
    input.videos = [input.videos.find((video) => video.id === first.id)!, input.videos.find((video) => video.id === second.id)!];
    input.videos[0].featured = true; input.videos[1].label = "別バージョン"; input.representativeVideoId = second.id;
    await saveEpisodeEditor(env.DB, episode.id, input);
    const card = (await listPublicEpisodes(env.DB)).find((item) => item.id === episode.id)!;
    expect(card.title).toBe("変更後"); expect(card.members.map((item) => item.id)).toEqual(["fukuchan"]);
    expect(card.primary_video_id).toBe(second.id); expect(card.has_featured_video).toBe(1);
    const publicDetail = (await loadPublicEpisode(episode.slug))!;
    expect(publicDetail.videos.map((item) => item.id)).toEqual([first.id, second.id]);
    expect(publicDetail.videos[1].label).toBe("別バージョン");
    const adminCard = (await listEpisodes(env.DB)).find((item) => item.id === episode.id)!;
    expect(adminCard.primary_video_id).toBe(card.primary_video_id);
    expect(adminCard.primary_video_poster_url).toBe(card.primary_video_poster_url);
  });
  it("persists episode order through metadata edits and inserts new MCP registrations first", async () => {
    const {episode} = await fixture();
    const before = (await listEpisodes(env.DB)).map((item) => item.id);
    const ordered = [...before].reverse();
    await reorderEpisodes(env.DB, {itemIds: ordered, previousIds: before});
    await updateEpisode(env.DB, episode.id, {title: "改題"});
    expect((await listEpisodes(env.DB)).map((item) => item.id)).toEqual(ordered);
    const fresh = await createEpisode(env.DB, {slug: crypto.randomUUID(), title: "MCPから登録"}, "test");
    expect((await listPublicEpisodes(env.DB))[0].id).toBe(fresh.id);
    await expect(reorderEpisodes(env.DB, {itemIds: ordered, previousIds: ordered})).rejects.toMatchObject({status: 409});
  });
  it("rejects foreign videos, invalid members, duplicate ordering and stale MCP edits without partial saves", async () => {
    const {episode, first} = await fixture(); const foreign = await fixture();
    const input = await draft(episode.id);
    await expect(saveEpisodeEditor(env.DB, episode.id, {...input, title: "失敗", representativeVideoId: foreign.first.id})).rejects.toMatchObject({status: 400});
    await expect(saveEpisodeEditor(env.DB, episode.id, {...input, title: "失敗", memberIds: ["missing"]})).rejects.toMatchObject({status: 400});
    const ids = (await listEpisodes(env.DB)).map((item) => item.id);
    await expect(reorderEpisodes(env.DB, {previousIds: ids, itemIds: ids.map(() => ids[0])})).rejects.toMatchObject({status: 400});
    await setVideoFeatured(env.DB, first.id, true);
    // Force a distinct timestamp, independent of clock precision on fast runs.
    await env.DB.prepare("UPDATE videos SET updated_at = 'future' WHERE id = ?").bind(first.id).run();
    await expect(saveEpisodeEditor(env.DB, episode.id, {...input, title: "失敗"})).rejects.toMatchObject({status: 409});
    expect((await getEpisodeById(env.DB, episode.id))?.episode.title).toBe("編集テスト");
  });
  it("requires authentication on all new mutation and private preview endpoints", async () => {
    for (const [path, method] of [["episodes/reorder", "PUT"], ["episodes/id/editor", "PUT"], ["videos/id/preview", "GET"], ["videos/id/poster", "GET"]]) {
      const response = await worker.fetch(new Request(`http://localhost/admin-api/${path}`, {method}), env, createExecutionContext());
      expect(response.status).toBe(401);
    }
  });
});
