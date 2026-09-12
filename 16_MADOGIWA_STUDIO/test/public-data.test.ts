import { env } from "cloudflare:workers";
import { SELF } from "cloudflare:test";
import { describe, expect, it, vi } from "vitest";
import { cachedPublicData } from "../worker/public-cache";
import { listPublicEpisodes, listPublicSitemapEntries, queryPublicEpisodes } from "../worker/public-repository";
import { createEpisode, createGeneration, createVideo, listEpisodes, setVideoFeatured, setVideoStatus, updateEpisode } from "../worker/repository";
import { loadPublicEpisode } from "../src/server/public-data.server";

describe("public data cost and freshness", () => {
  it("serves video metadata for SEO without loading primary, alternate or related video bytes", async () => {
    const episode = await createEpisode(env.DB, { slug: crypto.randomUUID(), title: "Click to play" }, "test");
    const generation = await createGeneration(env.DB, episode.id, "v2", "model", "", "test");
    for (const filename of ["primary.mp4", "alternate.mp4"]) {
      const video = await createVideo(env.DB, { generationId: generation.id, filename, label: filename, contentType: "video/mp4", uploadedBy: "test" });
      await setVideoStatus(env.DB, video.id, "ready");
    }
    const response = await SELF.fetch(`http://localhost/episodes/${episode.slug}`);
    expect(response.status).toBe(200);
    const html = await response.text();
    expect(html).toContain('"@type":"VideoObject"');
    expect(html).toContain('"contentUrl":"https://madogiwa.work/media/');
    expect(html.match(/class="deferred-video"/g)).toHaveLength(2);
    expect(html).not.toMatch(/<video\b/);
    expect(html).not.toMatch(/<source\b/);
  });
  it("keeps public cards equivalent with multiple generations, pending and archived videos", async () => {
    const episode = await createEpisode(env.DB, { slug: crypto.randomUUID(), title: "Public card", memberIds: ["sobaya", "fukuchan"] }, "test");
    const generation = await createGeneration(env.DB, episode.id, "v2", "model", "", "test");
    const featured = await createVideo(env.DB, { generationId: generation.id, filename: "a.mp4", label: "featured", contentType: "video/mp4", uploadedBy: "test", featured: true });
    await setVideoStatus(env.DB, featured.id, "ready");
    await createVideo(env.DB, { generationId: generation.id, filename: "b.mp4", label: "pending", contentType: "video/mp4", uploadedBy: "test", featured: true });
    const archived = await createVideo(env.DB, { generationId: generation.id, filename: "c.mp4", label: "archived", contentType: "video/mp4", uploadedBy: "test" });
    await setVideoStatus(env.DB, archived.id, "archived");
    const legacy = (await listEpisodes(env.DB)).filter((row) => row.status === "published").map((row) => ({
      ...row, input_count: 0, prompt_label: null,
      members: row.members.map(({ id, slug, name, sort_order }) => ({ id, slug, name, sort_order })),
    }));
    expect(await queryPublicEpisodes(env.DB)).toEqual(legacy);
    const first = (await listPublicEpisodes(env.DB)).find((row) => row.id === episode.id)!;
    expect(first.primary_video_id).toBe(featured.id);
    await setVideoFeatured(env.DB, featured.id, false);
    expect((await listPublicEpisodes(env.DB)).find((row) => row.id === episode.id)?.has_featured_video).toBe(0);
  });

  it("reuses JSON and invalidates even direct D1 writes without purging a local cache", async () => {
    const key = `test:${crypto.randomUUID()}`;
    const loader = vi.fn(async () => ({ value: crypto.randomUUID() }));
    const first = await cachedPublicData(env.DB, key, loader);
    expect(await cachedPublicData(env.DB, key, loader)).toEqual(first);
    expect(loader).toHaveBeenCalledTimes(1);
    await env.DB.prepare("UPDATE members SET name = name WHERE id = 'sobaya'").run();
    expect(await cachedPublicData(env.DB, key, loader)).not.toEqual(first);
    expect(loader).toHaveBeenCalledTimes(2);
    const revision = await env.DB.prepare("SELECT revision FROM public_content_revision WHERE id = 1").all();
    expect(revision.meta.rows_read).toBe(1);
  });

  it("removes archived episodes from warm lists, details, related cards and sitemap immediately", async () => {
    const episode = await createEpisode(env.DB, { slug: crypto.randomUUID(), title: "Fresh", memberIds: ["sobaya"] }, "test");
    expect((await listPublicEpisodes(env.DB)).some((row) => row.id === episode.id)).toBe(true);
    expect((await loadPublicEpisode(episode.slug))?.episode.title).toBe("Fresh");
    expect((await listPublicSitemapEntries(env.DB)).some((row) => row.path.endsWith(episode.slug))).toBe(true);
    await updateEpisode(env.DB, episode.id, { status: "archived" });
    expect((await listPublicEpisodes(env.DB)).some((row) => row.id === episode.id)).toBe(false);
    expect(await loadPublicEpisode(episode.slug)).toBeNull();
    expect((await listPublicSitemapEntries(env.DB)).some((row) => row.path.endsWith(episode.slug))).toBe(false);
    const another = (await listPublicEpisodes(env.DB))[0];
    if (another) expect((await loadPublicEpisode(another.slug))?.related.some((row) => row.id === episode.id)).toBe(false);
  });
});
