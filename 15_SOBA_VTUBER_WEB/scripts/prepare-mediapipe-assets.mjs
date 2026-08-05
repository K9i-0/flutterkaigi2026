import { cp, mkdir, stat } from "node:fs/promises";
import { resolve } from "node:path";

const projectRoot = resolve(import.meta.dirname, "..");
const sourceWasm = resolve(projectRoot, "node_modules/@mediapipe/tasks-vision/wasm");
const targetWasm = resolve(projectRoot, "public/mediapipe/wasm");
const modelPath = resolve(projectRoot, "public/models/face_landmarker.task");

await mkdir(targetWasm, { recursive: true });
await cp(sourceWasm, targetWasm, { recursive: true, force: true });

try {
  await stat(modelPath);
} catch {
  throw new Error(
    "Missing public/models/face_landmarker.task. Run the model download command documented in README.md.",
  );
}
