import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const repository = readFileSync(`${root}/worker/repository.ts`, "utf8");
const legacy = repository.split("export async function listEpisodes")[1].split("export async function getEpisodeBySlug")[0];
const publicSource = readFileSync(`${root}/worker/public-repository.ts`, "utf8").split("export async function queryPublicEpisodes")[0];
const sqlStrings = (source) => [...source.matchAll(/`([^`]+)`/gs)].map((match) => match[1]);
const queries = [...sqlStrings(legacy).slice(0, 2), ...sqlStrings(publicSource)];
if (queries.length !== 5 || queries.some((sql) => !sql.trim().startsWith("SELECT"))) throw new Error("Review benchmark SQL extraction");
// Five read-only SELECTs, once each; no load test or data export.
const output = execFileSync(`${root}/node_modules/.bin/wrangler`, [
  "d1", "execute", "madogiwa-studio", process.argv.includes("--remote") ? "--remote" : "--local",
  "--command", queries.join(";\n"), "--json",
], { cwd: root, encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
const results = JSON.parse(output);
const before = results.slice(0, 2).reduce((sum, result) => sum + result.meta.rows_read, 0);
const after = results.slice(2).reduce((sum, result) => sum + result.meta.rows_read, 0);
console.log(JSON.stringify({
  measuredAt: new Date().toISOString(),
  queries: results.map((result, index) => ({ index, rowsRead: result.meta.rows_read, rowsReturned: result.results.length })),
  before, afterCold: after + 1, afterWarm: 1,
  coldReductionPercent: Number(((1 - (after + 1) / before) * 100).toFixed(2)),
  note: "Cold includes the one-row revision lookup; warm assumes a Cache API hit. Daily usage depends on traffic, updates and cache locality.",
}, null, 2));
