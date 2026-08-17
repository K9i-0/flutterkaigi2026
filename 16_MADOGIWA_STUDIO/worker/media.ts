import { HttpError } from "./http";
import { getVideo } from "./repository";
import { serveR2Object } from "./r2-response";
import { requireAdmin } from "./auth";

async function requireVideoAccess(request: Request, env: Env, ctx: ExecutionContext, videoId: string): Promise<void> {
  const episode = await env.DB.prepare(
    "SELECT episodes.status FROM videos JOIN episodes ON episodes.id = videos.episode_id WHERE videos.id = ?",
  ).bind(videoId).first<{ status: string }>();
  if (!episode) throw new HttpError(404, "動画が見つかりません");
  if (episode.status !== "published") await requireAdmin(request, env, ctx);
}

export async function serveVideo(request: Request, env: Env, ctx: ExecutionContext, videoId: string): Promise<Response> {
  await requireVideoAccess(request, env, ctx, videoId);
  const video = await getVideo(env.DB, videoId);
  if (!video || video.status === "archived" || video.status === "upload_pending") {
    throw new HttpError(404, "動画が見つかりません");
  }

  return serveR2Object(request, env.MEDIA, video.r2_key);
}

export async function serveVideoPoster(request: Request, env: Env, ctx: ExecutionContext, videoId: string): Promise<Response> {
  await requireVideoAccess(request, env, ctx, videoId);
  const video = await getVideo(env.DB, videoId);
  if (!video || !video.poster_r2_key || video.status === "archived" || video.status === "upload_pending") {
    throw new HttpError(404, "動画サムネイルが見つかりません");
  }

  return serveR2Object(request, env.MEDIA, video.poster_r2_key, undefined, "public, max-age=604800, immutable");
}
