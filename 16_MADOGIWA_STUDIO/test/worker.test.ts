import { env } from "cloudflare:workers";
import { createExecutionContext, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import worker from "../worker";

function accessContext(): ExecutionContext {
  const ctx = createExecutionContext();
  Object.defineProperty(ctx, "access", {
    value: {
      aud: "madogiwa-studio-test",
      getIdentity: async () => ({ email: "test@madogiwa.studio", name: "Test admin" }),
    } satisfies CloudflareAccessContext,
  });
  return ctx;
}

function adminFetch(input: string, init?: RequestInit): Promise<Response> {
  return worker.fetch(new Request(input, init), env, accessContext());
}

describe("Madogiwa Studio Worker", () => {
  it("lists episodes with Studio IDs, generations, and members", async () => {
    const response = await SELF.fetch("http://localhost/api/episodes");
    expect(response.status).toBe(200);
    const body = await response.json<{ episodes: Array<{ slug: string; studio_id: string; generation_count: number; members: Array<{ id: string }> }> }>();
    expect(body.episodes).toContainEqual(expect.objectContaining({
      slug: "sobaya-beer-battery",
      studio_id: "MS-7K9Q2F",
      generation_count: 1,
      members: expect.arrayContaining([expect.objectContaining({ id: "sobaya" }), expect.objectContaining({ id: "fukuchan" })]),
    }));
  });

  it("creates an episode with v1 and adds a second generation", async () => {
    const slug = `test-${crypto.randomUUID()}`;
    const createResponse = await adminFetch("http://localhost/admin-api/episodes", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ slug, title: "テスト", summary: "versions", memberIds: ["sobaya", "yametaro"] }),
    });
    expect(createResponse.status).toBe(201);
    const episode = await createResponse.json<{ id: string; studio_id: string }>();
    expect(episode.studio_id).toMatch(/^MS-[2-9A-HJ-NP-Z]{8}$/);

    const generationResponse = await adminFetch(`http://localhost/admin-api/episodes/${episode.id}/generations`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ label: "再生成", modelName: "MiniMax H3", notes: "表情を改善" }),
    });
    expect(generationResponse.status).toBe(201);
    const generation = await generationResponse.json<{ id: string; version: number; model_name: string | null }>();
    expect(generation.version).toBe(2);
    expect(generation.model_name).toBe("MiniMax H3");

    const updateGenerationResponse = await adminFetch(`http://localhost/admin-api/generations/${generation.id}`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ modelName: "Seedance 2.5" }),
    });
    expect(updateGenerationResponse.status).toBe(200);

    const promptResponse = await adminFetch(`http://localhost/admin-api/generations/${generation.id}/prompts`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ label: "Seedance v2", body: "自然な会話の短編映像。" }),
    });
    expect(promptResponse.status).toBe(201);

    const detail = await (await SELF.fetch(`http://localhost/api/episodes/${slug}`)).json<{
      members: Array<{ id: string }>;
      generations: Array<{ version: number; model_name: string | null; prompt: { body: string } | null }>;
    }>();
    expect(detail.members.map((member) => member.id)).toEqual(["sobaya", "yametaro"]);
    expect(detail.generations.find((item) => item.version === 2)?.prompt?.body).toBe("自然な会話の短編映像。");
    expect(detail.generations.find((item) => item.version === 2)?.model_name).toBe("Seedance 2.5");
  });

  it("streams an uploaded featured video and supports featured filtering", async () => {
    const detail = await (await SELF.fetch("http://localhost/api/episodes/sobaya-beer-battery")).json<{ generations: Array<{ id: string }> }>();
    const ticketResponse = await adminFetch(`http://localhost/admin-api/generations/${detail.generations[0].id}/uploads`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ filename: "test.mp4", label: "Range test", contentType: "video/mp4", featured: true }),
    });
    const ticket = await ticketResponse.json<{ videoId: string; uploadUrl: string; posterUploadUrl: string }>();
    const posterBytes = new Uint8Array([255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 255, 217]);
    expect((await SELF.fetch(ticket.posterUploadUrl, {
      method: "PUT",
      headers: { "content-type": "image/jpeg", "content-length": String(posterBytes.byteLength) },
      body: posterBytes,
    })).status).toBe(201);
    const bytes = new Uint8Array(256).map((_, index) => index);
    expect((await SELF.fetch(ticket.uploadUrl, { method: "PUT", headers: { "content-type": "video/mp4", "content-length": "256" }, body: bytes })).status).toBe(201);
    const mediaResponse = await SELF.fetch(`http://localhost/media/${ticket.videoId}`, { headers: { range: "bytes=10-19" } });
    expect(mediaResponse.status).toBe(206);
    expect(mediaResponse.headers.get("content-range")).toBe("bytes 10-19/256");
    const posterResponse = await SELF.fetch(`http://localhost/posters/${ticket.videoId}`);
    expect(posterResponse.status).toBe(200);
    expect(posterResponse.headers.get("content-type")).toBe("image/jpeg");
    expect(posterResponse.headers.get("cache-control")).toContain("immutable");
    const featuredList = await (await SELF.fetch("http://localhost/api/episodes?featured=true")).json<{
      episodes: Array<{ slug: string; primary_video_id: string | null; primary_video_poster_url: string | null; has_featured_video: number }>;
    }>();
    expect(featuredList.episodes).toContainEqual(expect.objectContaining({
      slug: "sobaya-beer-battery",
      primary_video_id: ticket.videoId,
      primary_video_poster_url: `/posters/${ticket.videoId}`,
      has_featured_video: 1,
    }));
    const clearResponse = await adminFetch(`http://localhost/admin-api/videos/${ticket.videoId}`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ featured: false }),
    });
    expect(clearResponse.status).toBe(200);
    expect((await clearResponse.json<{ is_featured: number }>()).is_featured).toBe(0);
  });

  it("registers input assets inside a generation", async () => {
    const detail = await (await SELF.fetch("http://localhost/api/episodes/sobaya-beer-battery")).json<{ generations: Array<{ id: string }> }>();
    const ticketResponse = await adminFetch(`http://localhost/admin-api/generations/${detail.generations[0].id}/input-uploads`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ filename: "character.png", label: "Character", kind: "image", referenceLabel: "@Image 1", groupLabel: "Clip A", contentType: "image/png", displayOrder: 1 }),
    });
    const ticket = await ticketResponse.json<{ assetId: string; uploadUrl: string }>();
    const bytes = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]);
    expect((await SELF.fetch(ticket.uploadUrl, { method: "PUT", headers: { "content-type": "image/png", "content-length": "8" }, body: bytes })).status).toBe(201);
    const assetResponse = await SELF.fetch(`http://localhost/inputs/${ticket.assetId}`);
    expect(assetResponse.status).toBe(200);
    expect(assetResponse.headers.get("content-type")).toBe("image/png");
  });

  it("serves generation and member MCP tools", async () => {
    const request = new Request("http://localhost/mcp", {
      method: "POST",
      headers: { accept: "application/json, text/event-stream", "content-type": "application/json", host: "localhost", "mcp-protocol-version": "2025-06-18" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list", params: {} }),
    });
    const response = await worker.fetch(request, env, accessContext());
    const body = await response.text();
    expect(response.status).toBe(200);
    expect(body).toContain("create_generation");
    expect(body).toContain("update_generation");
    expect(body).toContain("set_episode_members");
    expect(body).toContain("create_input_upload");
    expect(body).toContain("set_video_featured");
  });

  it("does not trust spoofed Access headers or unverified JWTs", async () => {
    const emailHeaderRequest = new Request("https://madogiwa-studio.example/admin-api/session", {
      headers: { "Cf-Access-Authenticated-User-Email": "attacker@example.com" },
    });
    expect((await worker.fetch(emailHeaderRequest, env, createExecutionContext())).status).toBe(401);

    const invalidJwtRequest = new Request("https://madogiwa-studio.example/admin-api/session", {
      headers: { "Cf-Access-Jwt-Assertion": "not-a-signed-jwt" },
    });
    expect((await worker.fetch(invalidJwtRequest, env, createExecutionContext())).status).toBe(401);

    const invalidCookieRequest = new Request("https://madogiwa-studio.example/admin-api/session", {
      headers: { cookie: "CF_Authorization=not-a-signed-jwt" },
    });
    expect((await worker.fetch(invalidCookieRequest, env, createExecutionContext())).status).toBe(401);
  });
});
