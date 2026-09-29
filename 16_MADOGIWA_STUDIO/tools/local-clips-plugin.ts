import { createReadStream, readFileSync } from "node:fs";
import { stat } from "node:fs/promises";
import path from "node:path";
import type { Plugin } from "vite";

// Dev server only. The allowlist prevents access to arbitrary workspace files.
export function localClips(): Plugin {
  const media = JSON.parse(
    readFileSync(new URL("./clip-media.json", import.meta.url), "utf8"),
  ) as Array<{ id: string; clip: string; episode: number }>;
  const allowed = new Set(
    media.flatMap((item) => [
      `${item.id}.mp4`,
      `${item.id}.jpg`,
      `source-${item.episode}.mp4`,
    ]),
  );
  const downloadNames = new Map(
    media.map((item) => [`${item.id}.mp4`, path.basename(item.clip)]),
  );
  return {
    name: "local-reply-clips",
    apply: "serve",
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        const url = new URL(req.url ?? "/", "http://localhost");
        if (!url.pathname.startsWith("/__local-clips/")) return next();
        const filename = url.pathname.slice("/__local-clips/".length);
        if (!allowed.has(filename)) {
          res.statusCode = 404;
          res.end();
          return;
        }
        if (req.method !== "GET" && req.method !== "HEAD") {
          res.statusCode = 405;
          res.end();
          return;
        }
        const file = path.resolve(
          import.meta.dirname,
          "../.local/clips",
          filename,
        );
        try {
          const { size } = await stat(file);
          res.setHeader(
            "Content-Type",
            filename.endsWith(".mp4") ? "video/mp4" : "image/jpeg",
          );
          res.setHeader("Accept-Ranges", "bytes");
          res.setHeader("Cache-Control", "no-cache");
          if (url.searchParams.has("download"))
            res.setHeader(
              "Content-Disposition",
              `attachment; filename="${filename}"; filename*=UTF-8''${encodeURIComponent(downloadNames.get(filename) ?? filename)}`,
            );
          let start = 0,
            end = size - 1;
          if (req.headers.range) {
            const range = /^bytes=(\d*)-(\d*)$/.exec(req.headers.range);
            if (range && (range[1] || range[2])) {
              start = range[1]
                ? Number(range[1])
                : Math.max(0, size - Number(range[2]));
              end =
                range[1] && range[2]
                  ? Math.min(Number(range[2]), size - 1)
                  : size - 1;
            } else start = size;
            if (start >= size || end < start) {
              res.statusCode = 416;
              res.setHeader("Content-Range", `bytes */${size}`);
              res.end();
              return;
            }
            res.statusCode = 206;
            res.setHeader("Content-Range", `bytes ${start}-${end}/${size}`);
          }
          res.setHeader("Content-Length", end - start + 1);
          if (req.method === "HEAD") {
            res.end();
            return;
          }
          const stream = createReadStream(file, { start, end });
          stream.on("error", () => res.destroy());
          res.on("close", () => stream.destroy());
          stream.pipe(res);
        } catch {
          res.statusCode = 404;
          res.end("Run npm run prepare:clips first.");
        }
      });
    },
  };
}
