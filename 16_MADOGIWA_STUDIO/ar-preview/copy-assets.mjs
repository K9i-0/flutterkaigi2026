import { copyFile, mkdir } from "node:fs/promises";
import path from "node:path";
const project = path.resolve(import.meta.dirname, "..");
for (const character of ["sobaya", "fukuchan", "takosan", "yametaro"]) {
  for (const asset of [`models/characters/${character}.glb`, `site/characters/${character}.webp`]) {
    const destination = path.join(project, "dist-ar-preview", asset);
    await mkdir(path.dirname(destination), { recursive: true });
    await copyFile(path.join(project, "public", asset), destination);
  }
}
console.log("Copied only four public character models and four thumbnails.");
