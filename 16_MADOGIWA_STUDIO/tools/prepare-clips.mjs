import { mkdir, readFile, symlink, rm } from "node:fs/promises";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const studio = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const root = resolve(studio, "..");
const destination = resolve(studio, ".local/clips");
const media = JSON.parse(
  await readFile(new URL("./clip-media.json", import.meta.url), "utf8"),
);
await mkdir(destination, { recursive: true });
async function link(source, filename) {
  const target = resolve(destination, filename);
  await rm(target, { force: true });
  await symlink(resolve(root, source), target);
}
for (const item of media) {
  await link(item.clip, `${item.id}.mp4`);
  await link(item.source, `source-${item.episode}.mp4`);
  execFileSync("ffmpeg", [
    "-hide_banner",
    "-loglevel",
    "error",
    "-y",
    "-ss",
    "0.5",
    "-i",
    resolve(root, item.clip),
    "-frames:v",
    "1",
    "-vf",
    "scale=640:-1",
    "-q:v",
    "3",
    resolve(destination, `${item.id}.jpg`),
  ]);
}
console.log(
  `Prepared ${media.length} local clips and source links (no video copies).`,
);
