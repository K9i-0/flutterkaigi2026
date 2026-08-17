import { requireAdmin } from "./auth";
import { handleApi } from "./api";
import { errorResponse, HttpError } from "./http";
import { serveVideo, serveVideoPoster } from "./media";
import { handleMcp } from "./mcp";
import { serveInputAsset } from "./input-assets";
import { serveGalleryImage } from "./gallery-images";

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    try {
      if (url.pathname === "/mcp" || url.pathname.startsWith("/mcp/")) {
        const admin = await requireAdmin(request, env, ctx);
        return await handleMcp(request, env, ctx, admin.email);
      }

      if (url.pathname.startsWith("/api/") || url.pathname.startsWith("/admin-api/")) {
        return await handleApi(request, env, ctx);
      }

      if (url.pathname.startsWith("/media/")) {
        const videoId = url.pathname.slice("/media/".length);
        if (!videoId) throw new HttpError(404, "動画が見つかりません");
        return await serveVideo(request, env, videoId);
      }

      if (url.pathname.startsWith("/posters/")) {
        const videoId = url.pathname.slice("/posters/".length);
        if (!videoId) throw new HttpError(404, "動画サムネイルが見つかりません");
        return await serveVideoPoster(request, env, videoId);
      }

      if (url.pathname.startsWith("/inputs/")) {
        const assetId = url.pathname.slice("/inputs/".length);
        if (!assetId) throw new HttpError(404, "入力アセットが見つかりません");
        return await serveInputAsset(request, env, assetId);
      }

      if (url.pathname.startsWith("/gallery-images/")) {
        const galleryItemId = url.pathname.slice("/gallery-images/".length);
        if (!galleryItemId) throw new HttpError(404, "ギャラリー画像が見つかりません");
        return await serveGalleryImage(request, env, galleryItemId);
      }

      return await env.ASSETS.fetch(request);
    } catch (error) {
      return errorResponse(error, url.pathname);
    }
  },
} satisfies ExportedHandler<Env>;
