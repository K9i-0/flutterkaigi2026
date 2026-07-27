import assert from "node:assert/strict";
import { access, readFile, stat } from "node:fs/promises";
import test from "node:test";

test("production build contains the worker and required game assets", async () => {
  const required = [
    "dist/client/index.html",
    "dist/server/index.js",
    "dist/client/assets/models/sobaya.glb",
    "dist/client/assets/models/okayaman.glb",
    "dist/client/assets/og.png",
  ];
  await Promise.all(required.map((path) => access(path)));
  const sobaya = await stat("dist/client/assets/models/sobaya.glb");
  const worker = await readFile("dist/server/index.js", "utf8");
  assert.ok(sobaya.size > 100_000);
  assert.match(worker, /env\?\.ASSETS/);
});
