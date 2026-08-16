import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import path from "node:path";

const [baseUrlArg, episodeSlug, fileArg, labelArg] = process.argv.slice(2);
if (!baseUrlArg || !episodeSlug || !fileArg) {
  console.error("Usage: node tools/upload-video.mjs <base-url> <episode-slug> <video-file> [label]");
  process.exitCode = 1;
} else {
  const baseUrl = new URL(baseUrlArg);
  const filePath = path.resolve(fileArg);
  const fileInfo = await stat(filePath);
  if (!fileInfo.isFile()) throw new Error(`Not a file: ${filePath}`);

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
  if (!ticketResponse.ok) throw new Error(`Upload ticket creation failed (${ticketResponse.status}): ${await ticketResponse.text()}`);
  const ticket = await ticketResponse.json();
  const uploadUrl = new URL(ticket.uploadUrl);
  if (uploadUrl.origin !== baseUrl.origin || !uploadUrl.pathname.startsWith("/api/uploads/")) {
    throw new Error("Server returned an unexpected upload URL");
  }

  const uploadResponse = await fetch(uploadUrl, {
    method: "PUT",
    headers: { "content-type": "video/mp4", "content-length": String(fileInfo.size) },
    body: createReadStream(filePath),
    duplex: "half",
  });
  if (!uploadResponse.ok) throw new Error(`Upload failed (${uploadResponse.status}): ${await uploadResponse.text()}`);
  console.log(JSON.stringify(await uploadResponse.json(), null, 2));
}
