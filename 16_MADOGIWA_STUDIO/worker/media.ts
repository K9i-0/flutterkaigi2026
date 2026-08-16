import { HttpError } from "./http";
import { getVideo } from "./repository";
import { serveR2Object } from "./r2-response";

export async function serveVideo(request: Request, env: Env, videoId: string): Promise<Response> {
  const video = await getVideo(env.DB, videoId);
  if (!video || video.status === "archived" || video.status === "upload_pending") {
    throw new HttpError(404, "動画が見つかりません");
  }

  return serveR2Object(request, env.MEDIA, video.r2_key);
}
