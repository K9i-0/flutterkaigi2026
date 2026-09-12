import { readFile, mkdir, access, rename, rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { execFile } from "node:child_process";
const run = promisify(execFile);
const root = new URL("../design-preview/", import.meta.url);
const rows = JSON.parse(await readFile(new URL("episodes.json", root), "utf8"));
const localSlugs = [
  "madogiwa-super-try-commute",
  "professional-window-side-sobaya",
  "yametaro-unauthorized-office-livestream",
  "tako-game-dormitory",
  "madogiwa-super-try-keisha",
  "sobaya-never-drops-beer",
  "madogiwa-super-try-sobaya-invasion-trailer",
];
await mkdir(new URL("public/cache/", root), { recursive: true });
const jobs = rows
  .filter((e) => e.primary_video_poster_url)
  .map((e) => ({
    url: `https://madogiwa.work${e.primary_video_poster_url}`,
    name: `${e.primary_video_id}.jpg`,
  }));
for (const e of rows.filter((e) => localSlugs.includes(e.slug)))
  jobs.push({
    url: `https://madogiwa.work/media/${e.primary_video_id}`,
    name: `${e.primary_video_id}.mp4`,
  });
let completed = 0;
async function worker() {
  for (let job; (job = jobs.shift());) {
    const destination = fileURLToPath(
      new URL(`public/cache/${job.name}`, root),
    );
    try {
      await access(destination);
    } catch {
      try {
        await run("curl", [
          "-fsSL",
          "--retry",
          "2",
          job.url,
          "-o",
          `${destination}.part`,
        ]);
        await rename(`${destination}.part`, destination);
      } catch (error) {
        await rm(`${destination}.part`, { force: true });
        throw error;
      }
    }
    completed++;
  }
}
await Promise.all(Array.from({ length: 4 }, worker));
console.log(`Design preview: ${completed} public assets ready.`);

// Use a recognizable character frame instead of the opening transition.
const editorialPoster = fileURLToPath(
  new URL("public/cache/editorial-professional.jpg", root),
);
try {
  await access(editorialPoster);
} catch {
  await run("ffmpeg", [
    "-hide_banner",
    "-loglevel",
    "error",
    "-ss",
    "24",
    "-i",
    fileURLToPath(
      new URL("public/cache/991edfa4-92c6-4687-ab51-39213c6dc2f0.mp4", root),
    ),
    "-frames:v",
    "1",
    "-q:v",
    "2",
    "-update",
    "1",
    editorialPoster,
  ]);
}

const trailerPoster = fileURLToPath(
  new URL("public/cache/editorial-trailer.jpg", root),
);
try {
  await access(trailerPoster);
} catch {
  await run("ffmpeg", [
    "-hide_banner",
    "-loglevel",
    "error",
    "-ss",
    "36",
    "-i",
    fileURLToPath(
      new URL("public/cache/912872aa-41a1-4902-80cd-e6dc8ba0205d.mp4", root),
    ),
    "-frames:v",
    "1",
    "-q:v",
    "2",
    "-update",
    "1",
    trailerPoster,
  ]);
}
