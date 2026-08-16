import { requireAdmin } from "./auth";
import { HttpError, json, readJson } from "./http";
import { consumeInputUpload, createInputUpload } from "./input-assets";
import {
  createEpisode,
  createGeneration,
  getEpisodeBySlug,
  listEpisodes,
  listMembers,
  setVideoStatus,
  setVideoFeatured,
  updateEpisode,
  updateEpisodeMembers,
  updateGeneration,
  upsertPrompt,
} from "./repository";
import {
  createEpisodeSchema,
  generationSchema,
  inputUploadSchema,
  memberIdsSchema,
  promptSchema,
  updateEpisodeSchema,
  updateGenerationSchema,
  uploadSchema,
  videoStatusSchema,
  videoFeaturedSchema,
} from "./schemas";
import { consumePosterUpload, consumeUpload, createUpload } from "./uploads";

function pathSegments(pathname: string): string[] {
  return pathname.split("/").filter(Boolean);
}

export async function handleApi(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  const url = new URL(request.url);
  const isAdminApi = url.pathname === "/admin-api" || url.pathname.startsWith("/admin-api/");
  const routePath = isAdminApi ? url.pathname.replace(/^\/admin-api/, "/api") : url.pathname;
  const segments = pathSegments(routePath);
  const admin = isAdminApi ? await requireAdmin(request, env, ctx) : null;

  if (isAdminApi && request.method === "GET" && routePath === "/api/session") {
    return json({ admin });
  }
  if (request.method === "GET" && routePath === "/api/members") {
    return json({ members: await listMembers(env.DB) }, { headers: { "cache-control": "no-store" } });
  }
  if (request.method === "GET" && routePath === "/api/episodes") {
    return json(
      { episodes: await listEpisodes(env.DB, { featuredOnly: url.searchParams.get("featured") === "true" }) },
      { headers: { "cache-control": "no-store" } },
    );
  }
  if (request.method === "GET" && segments.length === 3 && segments[1] === "episodes") {
    const detail = await getEpisodeBySlug(env.DB, decodeURIComponent(segments[2]));
    if (!detail) throw new HttpError(404, "エピソードが見つかりません");
    return json(detail, { headers: { "cache-control": "no-store" } });
  }

  if (isAdminApi && request.method === "POST" && routePath === "/api/episodes") {
    const input = createEpisodeSchema.parse(await readJson(request));
    return json(await createEpisode(env.DB, input, admin!.email), { status: 201 });
  }
  if (isAdminApi && request.method === "PATCH" && segments.length === 3 && segments[1] === "episodes") {
    const detail = await getEpisodeBySlug(env.DB, decodeURIComponent(segments[2]));
    if (!detail) throw new HttpError(404, "エピソードが見つかりません");
    return json(await updateEpisode(env.DB, detail.episode.id, updateEpisodeSchema.parse(await readJson(request))));
  }
  if (
    isAdminApi &&
    request.method === "PUT" &&
    segments.length === 4 &&
    segments[1] === "episodes" &&
    segments[3] === "members"
  ) {
    const body = await readJson(request);
    const memberIds = memberIdsSchema.parse((body as { memberIds?: unknown }).memberIds);
    return json({ members: await updateEpisodeMembers(env.DB, segments[2], memberIds) });
  }
  if (
    isAdminApi &&
    request.method === "POST" &&
    segments.length === 4 &&
    segments[1] === "episodes" &&
    segments[3] === "generations"
  ) {
    const input = generationSchema.parse(await readJson(request));
    return json(await createGeneration(env.DB, segments[2], input.label, input.modelName, input.notes, admin!.email), { status: 201 });
  }
  if (isAdminApi && request.method === "PATCH" && segments.length === 3 && segments[1] === "generations") {
    const input = updateGenerationSchema.parse(await readJson(request));
    return json(await updateGeneration(env.DB, segments[2], input));
  }
  if (
    isAdminApi &&
    request.method === "POST" &&
    segments.length === 4 &&
    segments[1] === "generations" &&
    segments[3] === "prompts"
  ) {
    const input = promptSchema.parse(await readJson(request));
    return json(await upsertPrompt(env.DB, segments[2], input.label, input.body, admin!.email), { status: 201 });
  }
  if (
    isAdminApi &&
    request.method === "POST" &&
    segments.length === 4 &&
    segments[1] === "generations" &&
    segments[3] === "uploads"
  ) {
    const input = uploadSchema.parse(await readJson(request));
    return json(
      await createUpload(env, url.origin, {
        generationId: segments[2],
        filename: input.filename,
        label: input.label,
        contentType: input.contentType,
        featured: input.featured,
        uploadedBy: admin!.email,
      }),
      { status: 201 },
    );
  }
  if (
    isAdminApi &&
    request.method === "POST" &&
    segments.length === 4 &&
    segments[1] === "generations" &&
    segments[3] === "input-uploads"
  ) {
    const input = inputUploadSchema.parse(await readJson(request));
    return json(
      await createInputUpload(env, url.origin, {
        generationId: segments[2],
        filename: input.filename,
        label: input.label,
        kind: input.kind,
        referenceLabel: input.referenceLabel,
        groupLabel: input.groupLabel,
        notes: input.notes,
        contentType: input.contentType,
        displayOrder: input.displayOrder,
        uploadedBy: admin!.email,
      }),
      { status: 201 },
    );
  }

  if (request.method === "PUT" && segments.length === 3 && segments[1] === "uploads") {
    return consumeUpload(request, env, segments[2]);
  }
  if (request.method === "PUT" && segments.length === 3 && segments[1] === "poster-uploads") {
    return consumePosterUpload(request, env, segments[2]);
  }
  if (request.method === "PUT" && segments.length === 3 && segments[1] === "input-uploads") {
    return consumeInputUpload(request, env, segments[2]);
  }
  if (isAdminApi && request.method === "PATCH" && segments.length === 3 && segments[1] === "videos") {
    const body = await readJson(request);
    if ("featured" in (body as Record<string, unknown>)) {
      const input = videoFeaturedSchema.parse(body);
      return json(await setVideoFeatured(env.DB, segments[2], input.featured));
    }
    const input = videoStatusSchema.parse(body);
    return json(await setVideoStatus(env.DB, segments[2], input.status));
  }

  throw new HttpError(404, "API endpoint not found");
}
