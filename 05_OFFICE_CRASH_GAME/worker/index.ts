import { handleImageOptimization, DEFAULT_DEVICE_SIZES, DEFAULT_IMAGE_SIZES } from "vinext/server/image-optimization";
import handler from "vinext/server/app-router-entry";

interface Env {
  ASSETS: Fetcher;
  DB?: D1Database;
  IMAGES: {
    input(stream: ReadableStream): {
      transform(options: Record<string, unknown>): {
        output(options: { format: string; quality: number }): Promise<{ response(): Response }>;
      };
    };
  };
}

interface ExecutionContext {
  waitUntil(promise: Promise<unknown>): void;
  passThroughOnException(): void;
}

type PlayerRow = {
  id: string;
  caps: number;
  best_floor: number;
  best_score: number;
  total_runs: number;
  total_destroyed: number;
  clears: number;
  forge: number;
  vitality: number;
  hustle: number;
};

type RunPayload = {
  victory?: unknown;
  floorReached?: unknown;
  score?: unknown;
  destroyed?: unknown;
  maxCombo?: unknown;
  capsEarned?: unknown;
  upgrades?: unknown;
};

const PLAYER_COOKIE = "sobaya_player";
const MAX_BODY_BYTES = 12_000;
let schemaReady: Promise<void> | null = null;

function json(data: unknown, init: ResponseInit = {}) {
  const headers = new Headers(init.headers);
  headers.set("content-type", "application/json; charset=utf-8");
  headers.set("cache-control", "no-store");
  return new Response(JSON.stringify(data), { ...init, headers });
}

function safeInt(value: unknown, min: number, max: number) {
  const number = typeof value === "number" ? value : Number.NaN;
  return Number.isFinite(number) ? Math.max(min, Math.min(max, Math.round(number))) : min;
}

function getCookie(request: Request, key: string) {
  const cookie = request.headers.get("cookie") ?? "";
  for (const part of cookie.split(";")) {
    const [name, ...value] = part.trim().split("=");
    if (name === key) return decodeURIComponent(value.join("="));
  }
  return null;
}

function validPlayerId(value: string | null) {
  return value && /^[0-9a-f-]{36}$/i.test(value) ? value : null;
}

function playerCookie(playerId: string, secure: boolean) {
  return `${PLAYER_COOKIE}=${encodeURIComponent(playerId)}; Path=/; Max-Age=31536000; HttpOnly; SameSite=Lax${secure ? "; Secure" : ""}`;
}

async function ensureSchema(db: D1Database) {
  schemaReady ??= (async () => {
    await db.batch([
      db.prepare(`CREATE TABLE IF NOT EXISTS players (
        id TEXT PRIMARY KEY NOT NULL,
        caps INTEGER DEFAULT 0 NOT NULL,
        best_floor INTEGER DEFAULT 0 NOT NULL,
        best_score INTEGER DEFAULT 0 NOT NULL,
        total_runs INTEGER DEFAULT 0 NOT NULL,
        total_destroyed INTEGER DEFAULT 0 NOT NULL,
        clears INTEGER DEFAULT 0 NOT NULL,
        forge INTEGER DEFAULT 0 NOT NULL,
        vitality INTEGER DEFAULT 0 NOT NULL,
        hustle INTEGER DEFAULT 0 NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )`),
      db.prepare(`CREATE TABLE IF NOT EXISTS runs (
        id TEXT PRIMARY KEY NOT NULL,
        player_id TEXT NOT NULL,
        victory INTEGER DEFAULT 0 NOT NULL,
        floor_reached INTEGER NOT NULL,
        score INTEGER NOT NULL,
        destroyed INTEGER NOT NULL,
        max_combo INTEGER NOT NULL,
        caps_earned INTEGER NOT NULL,
        build_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players(id)
      )`),
      db.prepare("CREATE INDEX IF NOT EXISTS runs_player_created_idx ON runs (player_id, created_at)"),
      db.prepare("CREATE INDEX IF NOT EXISTS runs_score_idx ON runs (score)"),
    ]);
  })();
  await schemaReady;
}

async function readJsonBody(request: Request) {
  const size = Number(request.headers.get("content-length") ?? 0);
  if (size > MAX_BODY_BYTES) throw new Error("payload_too_large");
  return request.json();
}

async function getPlayer(db: D1Database, playerId: string) {
  const now = new Date().toISOString();
  await db.prepare(`INSERT INTO players (id, created_at, updated_at)
    VALUES (?, ?, ?) ON CONFLICT(id) DO NOTHING`).bind(playerId, now, now).run();
  return db.prepare("SELECT * FROM players WHERE id = ?").bind(playerId).first<PlayerRow>();
}

function publicProfile(row: PlayerRow) {
  return {
    caps: row.caps,
    bestFloor: row.best_floor,
    bestScore: row.best_score,
    totalRuns: row.total_runs,
    totalDestroyed: row.total_destroyed,
    clears: row.clears,
    mastery: {
      forge: row.forge,
      vitality: row.vitality,
      hustle: row.hustle,
    },
  };
}

async function profilePayload(db: D1Database, playerId: string) {
  const player = await getPlayer(db, playerId);
  if (!player) throw new Error("profile_unavailable");
  const [recent, leaders, global] = await Promise.all([
    db.prepare(`SELECT victory, floor_reached AS floorReached, score, destroyed,
      max_combo AS maxCombo, caps_earned AS capsEarned, created_at AS createdAt
      FROM runs WHERE player_id = ? ORDER BY created_at DESC LIMIT 5`)
      .bind(playerId).all(),
    db.prepare(`SELECT score, floor_reached AS floorReached, victory
      FROM runs ORDER BY score DESC, floor_reached DESC LIMIT 5`).all(),
    db.prepare(`SELECT COUNT(*) AS runs, COALESCE(SUM(destroyed), 0) AS destroyed,
      COALESCE(SUM(victory), 0) AS clears FROM runs`).first(),
  ]);
  return {
    profile: publicProfile(player),
    recentRuns: recent.results,
    leaderboard: leaders.results,
    globalStats: global ?? { runs: 0, destroyed: 0, clears: 0 },
  };
}

async function handleGameApi(request: Request, env: Env) {
  if (!env.DB) return json({ error: "database_unavailable" }, { status: 503 });
  const db = env.DB;
  await ensureSchema(db);
  const requestUrl = new URL(request.url);
  const cookieId = validPlayerId(getCookie(request, PLAYER_COOKIE));
  const playerId = cookieId ?? crypto.randomUUID();
  const cookieHeader = cookieId ? undefined : playerCookie(playerId, requestUrl.protocol === "https:");

  if (request.method === "GET" && requestUrl.pathname === "/api/game/profile") {
    const response = json(await profilePayload(db, playerId));
    if (cookieHeader) response.headers.set("set-cookie", cookieHeader);
    return response;
  }

  if (request.method === "POST" && requestUrl.pathname === "/api/game/run") {
    const payload = await readJsonBody(request) as RunPayload;
    await getPlayer(db, playerId);
    const floorReached = safeInt(payload.floorReached, 1, 8);
    const score = safeInt(payload.score, 0, 10_000_000);
    const destroyed = safeInt(payload.destroyed, 0, 10_000);
    const maxCombo = safeInt(payload.maxCombo, 0, 10_000);
    const capsEarned = safeInt(payload.capsEarned, 0, 5_000);
    const victory = payload.victory === true;
    const upgrades = Array.isArray(payload.upgrades)
      ? payload.upgrades.slice(0, 30).map((value) => String(value).slice(0, 80))
      : [];
    const now = new Date().toISOString();
    await db.batch([
      db.prepare(`INSERT INTO runs (
        id, player_id, victory, floor_reached, score, destroyed,
        max_combo, caps_earned, build_json, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).bind(
        crypto.randomUUID(), playerId, victory ? 1 : 0, floorReached, score,
        destroyed, maxCombo, capsEarned, JSON.stringify(upgrades), now,
      ),
      db.prepare(`UPDATE players SET
        caps = caps + ?,
        best_floor = MAX(best_floor, ?),
        best_score = MAX(best_score, ?),
        total_runs = total_runs + 1,
        total_destroyed = total_destroyed + ?,
        clears = clears + ?,
        updated_at = ?
        WHERE id = ?`).bind(
        capsEarned, floorReached, score, destroyed, victory ? 1 : 0, now, playerId,
      ),
    ]);
    const response = json(await profilePayload(db, playerId), { status: 201 });
    if (cookieHeader) response.headers.set("set-cookie", cookieHeader);
    return response;
  }

  if (request.method === "POST" && requestUrl.pathname === "/api/game/mastery") {
    const body = await readJsonBody(request) as { stat?: unknown };
    const stat = body.stat;
    const columns = { forge: "forge", vitality: "vitality", hustle: "hustle" } as const;
    if (typeof stat !== "string" || !(stat in columns)) {
      return json({ error: "invalid_mastery" }, { status: 400 });
    }
    const player = await getPlayer(db, playerId);
    if (!player) return json({ error: "profile_unavailable" }, { status: 503 });
    const key = stat as keyof typeof columns;
    const level = player[key];
    const cost = 20 + level * 20;
    if (level >= 5) return json({ error: "mastery_maxed" }, { status: 409 });
    if (player.caps < cost) return json({ error: "not_enough_caps", cost }, { status: 409 });
    const column = columns[key];
    await db.prepare(`UPDATE players SET ${column} = ${column} + 1,
      caps = caps - ?, updated_at = ? WHERE id = ? AND caps >= ?`)
      .bind(cost, new Date().toISOString(), playerId, cost).run();
    const response = json(await profilePayload(db, playerId));
    if (cookieHeader) response.headers.set("set-cookie", cookieHeader);
    return response;
  }

  return json({ error: "not_found" }, { status: 404 });
}

const worker = {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname.startsWith("/api/game/")) {
      try {
        return await handleGameApi(request, env);
      } catch (error) {
        console.error("Game API error", error);
        return json({ error: "server_error" }, { status: 500 });
      }
    }

    if (url.pathname === "/_vinext/image") {
      const allowedWidths = [...DEFAULT_DEVICE_SIZES, ...DEFAULT_IMAGE_SIZES];
      return handleImageOptimization(request, {
        fetchAsset: (path) => env.ASSETS.fetch(new Request(new URL(path, request.url))),
        transformImage: async (body, { width, format, quality }) => {
          const result = await env.IMAGES.input(body).transform(width > 0 ? { width } : {}).output({ format, quality });
          return result.response();
        },
      }, allowedWidths);
    }

    return handler.fetch(request, env, ctx);
  },
};

export default worker;
