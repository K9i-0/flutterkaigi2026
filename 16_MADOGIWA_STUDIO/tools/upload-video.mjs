import { execFile } from "node:child_process";
import { createReadStream } from "node:fs";
import { mkdtemp, rm, stat } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const [baseUrlArg, episodeSlug, fileArg, labelArg] = process.argv.slice(2);

if (!baseUrlArg || !episodeSlug || !fileArg) {
  console.error("Usage: node tools/upload-video.mjs <base-url> <episode-slug> <video-file> [label]");
  process.exitCode = 1;
} else {
  const baseUrl = new URL(baseUrlArg);
  const filePath = path.resolve(fileArg);
  const fileInfo = await stat(filePath);
  if (!fileInfo.isFile()) throw new Error(`Not a file: ${filePath}`);

  const temporaryDirectory = await mkdtemp(path.join(os.tmpdir(), "madogiwa-poster-"));
  const expectedPrefix = path.join(os.tmpdir(), "madogiwa-poster-");
  if (!temporaryDirectory.startsWith(expectedPrefix)) throw new Error("Unexpected temporary directory");
  const posterPath = path.join(temporaryDirectory, "poster.jpg");

  try {
    await execFileAsync("ffmpeg", [
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      "-ss",
      "0.5",
      "-i",
      filePath,
      "-frames:v",
      "1",
      "-vf",
      "scale=1280:1280:force_original_aspect_ratio=decrease",
      "-q:v",
      "3",
      posterPath,
    ]);
    const posterInfo = await stat(posterPath);

    const episodeResponse = await fetch(new URL(`/api/episodes/${encodeURIComponent(episodeSlug)}`, baseUrl));
    if (!episodeResponse.ok) throw new Error(`Episode lookup failed (${episodeResponse.status})`);
    const detail = await episodeResponse.json();
    const generation = detail.generations?.[0];
    if (!generation) throw new Error("Episode has no generation");

    const ticketResponse = await fetch(new URL(`/admin-api/generations/${generation.id}/uploads`, baseUrl), {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        filename: path.basename(filePath),
        label: labelArg ?? "Generated video",
        contentType: "video/mp4",
      }),
    });
    if (!ticketResponse.ok) {
      throw new Error(`Upload ticket creation failed (${ticketResponse.status}): ${await ticketResponse.text()}`);
    }
    const ticket = await ticketResponse.json();
    const uploadUrl = new URL(ticket.uploadUrl);
    const posterUploadUrl = new URL(ticket.posterUploadUrl);
    if (uploadUrl.origin !== baseUrl.origin || !uploadUrl.pathname.startsWith("/api/uploads/")) {
      throw new Error("Server returned an unexpected video upload URL");
    }
    if (posterUploadUrl.origin !== baseUrl.origin || !posterUploadUrl.pathname.startsWith("/api/poster-uploads/")) {
      throw new Error("Server returned an unexpected poster upload URL");
    }

    const posterResponse = await fetch(posterUploadUrl, {
      method: "PUT",
      headers: { "content-type": "image/jpeg", "content-length": String(posterInfo.size) },
      body: createReadStream(posterPath),
      duplex: "half",
    });
    if (!posterResponse.ok) {
      throw new Error(`Poster upload failed (${posterResponse.status}): ${await posterResponse.text()}`);
    }

    const uploadResponse = await fetch(uploadUrl, {
      method: "PUT",
      headers: { "content-type": "video/mp4", "content-length": String(fileInfo.size) },
      body: createReadStream(filePath),
      duplex: "half",
    });
    if (!uploadResponse.ok) throw new Error(`Upload failed (${uploadResponse.status}): ${await uploadResponse.text()}`);
    console.log(JSON.stringify({ ...(await uploadResponse.json()), poster: await posterResponse.json() }, null, 2));
  } finally {
    await rm(temporaryDirectory, { recursive: true });
  }
}
