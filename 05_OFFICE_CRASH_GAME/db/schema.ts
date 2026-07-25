import { index, integer, sqliteTable, text } from "drizzle-orm/sqlite-core";

export const players = sqliteTable("players", {
  id: text("id").primaryKey(),
  caps: integer("caps").notNull().default(0),
  bestFloor: integer("best_floor").notNull().default(0),
  bestScore: integer("best_score").notNull().default(0),
  totalRuns: integer("total_runs").notNull().default(0),
  totalDestroyed: integer("total_destroyed").notNull().default(0),
  clears: integer("clears").notNull().default(0),
  forge: integer("forge").notNull().default(0),
  vitality: integer("vitality").notNull().default(0),
  hustle: integer("hustle").notNull().default(0),
  createdAt: text("created_at").notNull(),
  updatedAt: text("updated_at").notNull(),
});

export const runs = sqliteTable("runs", {
  id: text("id").primaryKey(),
  playerId: text("player_id").notNull().references(() => players.id),
  victory: integer("victory", { mode: "boolean" }).notNull().default(false),
  floorReached: integer("floor_reached").notNull(),
  score: integer("score").notNull(),
  destroyed: integer("destroyed").notNull(),
  maxCombo: integer("max_combo").notNull(),
  capsEarned: integer("caps_earned").notNull(),
  buildJson: text("build_json").notNull(),
  createdAt: text("created_at").notNull(),
}, (table) => [
  index("runs_player_created_idx").on(table.playerId, table.createdAt),
  index("runs_score_idx").on(table.score),
]);
