import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", { headers: { accept: "text/html" } }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("renders the Office Crash game shell", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>そば屋のオフィスクラッシュ ～無限フロア大整理～<\/title>/);
  assert.match(html, /aria-label="そば屋のオフィスクラッシュ 無限フロア大整理 ゲーム画面"/);
  assert.match(html, /立ち飲み処を準備中/);
  assert.match(html, /MADOGIWA HACK, SMASH &amp; DRAFT/);
  assert.match(html, /生ジョッキレール/);
  assert.match(html, /OFFICE RUSH/);
  assert.match(html, /永続仕込み/);
  assert.match(html, /スコアボード名/);
  assert.match(html, /匿名窓際社員/);
  assert.match(html, /名前を保存/);
  assert.match(html, /王冠キャップ/);
  assert.match(html, /LOOT DRAFT/);
  assert.match(html, /永続記録/);
  assert.match(html, /退社作戦を選ぶ/);
  assert.match(html, /残業/);
  assert.match(html, /定時退社/);
  assert.match(html, /フライング退社/);
  assert.match(html, /破壊数 ×/);
  assert.match(html, /金星特性/);
  assert.match(html, /ビルド共鳴/);
  assert.match(html, /まず効果音を試す/);
  assert.match(html, /ブラウザの音声ロックをタップで解除します/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape/);
});

test("uses Three.js with a fixed camera, combat floors, and keyboard plus touch controls", async () => {
  const source = await readFile(new URL("../app/OfficeCrashRPG.tsx", import.meta.url), "utf8");
  assert.match(source, /new THREE\.WebGLRenderer/);
  assert.match(source, /new THREE\.OrthographicCamera/);
  assert.match(source, /baseCameraPosition = new THREE\.Vector3\(17, 21, 21\)/);
  assert.match(source, /keydown/);
  assert.match(source, /onPointerDown/);
  assert.match(source, /makeRewardChoices/);
  assert.match(source, /resolveSynergies/);
  assert.match(source, /type EliteAffix/);
  assert.match(source, /runtime\.pressure/);
  assert.match(source, /rerollReward/);
  assert.match(source, /OVERTIME_RANKS/);
  assert.match(source, /runtime\.timer = floorDefinition\.kind === "challenge" \? 15 : null/);
  assert.match(source, /makeCoreEnemy/);
  assert.match(source, /pickUpgrade/);
  assert.match(source, /runtime\.profile\.mastery\.forge/);
  assert.match(source, /webkitAudioContext/);
  assert.match(source, /context\.resume\(\)/);
  assert.match(source, /onPointerDownCapture/);
  assert.match(source, /testSound/);
  assert.match(source, /megaSmash/);
  assert.match(source, /launchMegaMug/);
  assert.match(source, /spawnMegaImpact/);
  assert.match(source, /生ジョッキレール/);
  assert.match(source, /ENCORE PHASE/);
  assert.match(source, /type EnemyAttackKind = "melee" \| "pulse"/);
  assert.match(source, /makeDangerZone/);
  assert.match(source, /赤い予告範囲から離れろ/);
  assert.match(source, /lastCallBoost/);
  assert.match(source, /formationSpawnPoints/);
  assert.match(source, /MAX_CONCURRENT_MOB_ATTACKS = 4/);
  assert.match(source, /runtime\.floorKilled >= runtime\.floorQuota/);
  assert.match(source, /gainMegaGauge/);
  assert.match(source, /startOfficeRush/);
  assert.match(source, /spawnQuotaReinforcements/);
  assert.match(source, /overtime\.destructionMultiplier/);
  assert.match(source, /destroyOfficeProp/);
  assert.match(source, /showDamageNumber/);
  assert.match(source, /DAMAGE_DISPLAY_MULTIPLIER = 10/);
  assert.match(source, /amount \* DAMAGE_DISPLAY_MULTIPLIER/);
  assert.match(source, /MEGA HIT/);
  assert.match(source, /WEAK ×/);
  assert.match(source, /rpg-damage-layer/);
  assert.match(source, /射線予測/);
  assert.match(source, /撃破・回避・生ジョッキで補充/);
  assert.match(source, /kind === "core" \? 125 : 50/);
  assert.match(source, /fetch\("\/api\/game\/run"/);
  assert.match(source, /fetch\("\/api\/game\/mastery"/);
});

test("stores profiles, run history, mastery, and leaderboard data in D1", async () => {
  const source = await readFile(new URL("../worker/index.ts", import.meta.url), "utf8");
  const hosting = await readFile(new URL("../.openai/hosting.json", import.meta.url), "utf8");
  assert.match(hosting, /"d1": "DB"/);
  assert.match(source, /CREATE TABLE IF NOT EXISTS players/);
  assert.match(source, /CREATE TABLE IF NOT EXISTS runs/);
  assert.match(source, /overtime_rank/);
  assert.match(source, /build_name/);
  assert.match(source, /\/api\/game\/profile/);
  assert.match(source, /\/api\/game\/run/);
  assert.match(source, /\/api\/game\/mastery/);
  assert.match(source, /\/api\/game\/username/);
  assert.match(source, /匿名窓際社員/);
  assert.match(source, /INNER JOIN players/);
  assert.match(source, /best\.player_id = runs\.player_id/);
  assert.match(source, /ORDER BY runs\.score DESC/);
});
