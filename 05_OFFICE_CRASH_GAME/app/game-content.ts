export type GameStatus = "hub" | "playing" | "reward" | "gameover" | "victory";
export type FloorKind = "combat" | "elite" | "challenge" | "boss" | "final";
export type MasteryKey = "forge" | "vitality" | "hustle";
export type OvertimeRank = 0 | 1 | 2 | 3;
export type UpgradeId =
  | "heavy"
  | "wide"
  | "haste"
  | "foam"
  | "frost"
  | "yakitori"
  | "combo"
  | "guard"
  | "knockback"
  | "happy"
  | "perfect"
  | "runner";

export type GameProfile = {
  caps: number;
  bestFloor: number;
  bestScore: number;
  totalRuns: number;
  totalDestroyed: number;
  clears: number;
  mastery: Record<MasteryKey, number>;
};

export type RecentRun = {
  victory: number | boolean;
  floorReached: number;
  score: number;
  destroyed: number;
  maxCombo: number;
  capsEarned: number;
  overtimeRank: number;
  buildName: string;
  createdAt: string;
};

export type SiteGameData = {
  profile: GameProfile;
  recentRuns: RecentRun[];
  leaderboard: Array<{
    score: number;
    floorReached: number;
    victory: number | boolean;
    overtimeRank: number;
    buildName: string;
  }>;
  globalStats: { runs: number; destroyed: number; clears: number };
};

export type UpgradeDefinition = {
  id: UpgradeId;
  icon: string;
  slot: string;
  name: string;
  description: string;
  color: string;
  school: string;
};

export type RewardChoice = UpgradeDefinition & {
  tier: number;
  rarity: string;
  rarityClass: string;
  scale: number;
  effect: string;
  greater: boolean;
};

export type FloorDefinition = {
  floor: number;
  kind: FloorKind;
  name: string;
  kicker: string;
  objective: string;
  tint: number;
  accent: number;
  enemyCount: number;
};

export type OvertimeDefinition = {
  rank: OvertimeRank;
  label: string;
  kicker: string;
  description: string;
  scoreMultiplier: number;
  capsMultiplier: number;
  hpMultiplier: number;
  damageMultiplier: number;
  speedMultiplier: number;
  eliteBonus: number;
};

export type SynergyDefinition = {
  ids: [UpgradeId, UpgradeId];
  name: string;
  icon: string;
  effect: string;
};

export const EMPTY_PROFILE: GameProfile = {
  caps: 0,
  bestFloor: 0,
  bestScore: 0,
  totalRuns: 0,
  totalDestroyed: 0,
  clears: 0,
  mastery: { forge: 0, vitality: 0, hustle: 0 },
};

export const OVERTIME_RANKS: OvertimeDefinition[] = [
  {
    rank: 0,
    label: "定時",
    kicker: "NORMAL",
    description: "標準レギュレーション。まずはここから。",
    scoreMultiplier: 1,
    capsMultiplier: 1,
    hpMultiplier: 1,
    damageMultiplier: 1,
    speedMultiplier: 1,
    eliteBonus: 0,
  },
  {
    rank: 1,
    label: "残業",
    kicker: "OVERTIME I",
    description: "備品が少し強化。スコアと王冠が増える。",
    scoreMultiplier: 1.25,
    capsMultiplier: 1.2,
    hpMultiplier: 1.2,
    damageMultiplier: 1.12,
    speedMultiplier: 1.06,
    eliteBonus: 1,
  },
  {
    rank: 2,
    label: "深夜残業",
    kicker: "OVERTIME II",
    description: "強化備品が増加。当たり特性も出やすい。",
    scoreMultiplier: 1.55,
    capsMultiplier: 1.45,
    hpMultiplier: 1.48,
    damageMultiplier: 1.28,
    speedMultiplier: 1.12,
    eliteBonus: 2,
  },
  {
    rank: 3,
    label: "始発待ち",
    kicker: "OVERTIME III",
    description: "最高危険度。最高倍率で伝説を狙う。",
    scoreMultiplier: 1.95,
    capsMultiplier: 1.8,
    hpMultiplier: 1.82,
    damageMultiplier: 1.48,
    speedMultiplier: 1.2,
    eliteBonus: 3,
  },
];

export const FLOORS: FloorDefinition[] = [
  {
    floor: 1,
    kind: "combat",
    name: "中央執務フロア",
    kicker: "REGULATION 01",
    objective: "歩き出した備品をすべて資材へ戻せ",
    tint: 0xe8edf0,
    accent: 0x19b8ff,
    enemyCount: 7,
  },
  {
    floor: 2,
    kind: "combat",
    name: "会議室迷宮",
    kicker: "REGULATION 02",
    objective: "机の包囲を破り、出口を確保せよ",
    tint: 0xe7e2d8,
    accent: 0xffa51f,
    enemyCount: 10,
  },
  {
    floor: 3,
    kind: "challenge",
    name: "クラッシュタイム",
    kicker: "45 SECOND BONUS",
    objective: "画面内に集まる備品を45秒で好きなだけ片付けろ",
    tint: 0xd9f3ff,
    accent: 0xffcc22,
    enemyCount: 28,
  },
  {
    floor: 4,
    kind: "boss",
    name: "窓際フェス・第一幕",
    kicker: "MADOGIWA BOSS SESSION",
    objective: "本日の窓際族メンバーと平和な模擬戦を楽しめ",
    tint: 0x344752,
    accent: 0xff4fa6,
    enemyCount: 1,
  },
  {
    floor: 5,
    kind: "combat",
    name: "配線サーバーフロア",
    kicker: "REGULATION 05",
    objective: "暴走備品の増援を押し返せ",
    tint: 0xd9e9e7,
    accent: 0x54e0b4,
    enemyCount: 14,
  },
  {
    floor: 6,
    kind: "elite",
    name: "タコ部屋前室",
    kicker: "ELITE REGULATION",
    objective: "強化ロッカー部隊を突破せよ",
    tint: 0x4c4b57,
    accent: 0xff704c,
    enemyCount: 11,
  },
  {
    floor: 7,
    kind: "challenge",
    name: "窓際外周デッキ",
    kicker: "45 SECOND BONUS",
    objective: "東京タワーを背に連鎖破壊を決めろ",
    tint: 0xd9efff,
    accent: 0xff5d45,
    enemyCount: 36,
  },
  {
    floor: 8,
    kind: "final",
    name: "窓際リモート会議室",
    kicker: "FINAL MADOGIWA SESSION",
    objective: "画面越しのおかやまん最終チェックを突破せよ",
    tint: 0x232e3b,
    accent: 0xffd23f,
    enemyCount: 1,
  },
];

export const UPGRADES: UpgradeDefinition[] = [
  {
    id: "heavy",
    icon: "槌",
    slot: "ジョッキ底",
    name: "重量級ジョッキ底",
    description: "スマッシュの基礎威力を引き上げる。",
    color: "#ff7046",
    school: "衝撃",
  },
  {
    id: "wide",
    icon: "波",
    slot: "ジョッキ本体",
    name: "大口径ビアグラス",
    description: "攻撃範囲が広がり、MULTI BREAKを狙いやすくなる。",
    color: "#ffb11f",
    school: "爆泡",
  },
  {
    id: "haste",
    icon: "速",
    slot: "取っ手",
    name: "高速サーブハンドル",
    description: "スマッシュの待ち時間を短縮する。",
    color: "#43c8ff",
    school: "速配",
  },
  {
    id: "foam",
    icon: "泡",
    slot: "ビール",
    name: "はじける泡",
    description: "破壊した備品から泡が弾け、周囲にもダメージ。",
    color: "#ffe46a",
    school: "爆泡",
  },
  {
    id: "frost",
    icon: "冷",
    slot: "ビール",
    name: "キンキン冷却",
    description: "命中した暴走備品を冷やして動きを鈍らせる。",
    color: "#6edfff",
    school: "冷却",
  },
  {
    id: "yakitori",
    icon: "串",
    slot: "おつまみ",
    name: "店主の焼き鳥",
    description: "備品を片付けるたびに体力を少し回復する。",
    color: "#e9873c",
    school: "堅守",
  },
  {
    id: "combo",
    icon: "連",
    slot: "店主札",
    name: "乾杯コンボ",
    description: "コンボ受付時間を延長し、高倍率を維持する。",
    color: "#ff4f77",
    school: "速配",
  },
  {
    id: "guard",
    icon: "守",
    slot: "おつまみ",
    name: "冷奴シールド",
    description: "最大体力を増やし、獲得時に全回復する。",
    color: "#f4f4e7",
    school: "堅守",
  },
  {
    id: "knockback",
    icon: "飛",
    slot: "ジョッキ底",
    name: "壁ごと片付け",
    description: "衝撃が強くなり、敵を大きく吹き飛ばす。",
    color: "#ad8cff",
    school: "衝撃",
  },
  {
    id: "happy",
    icon: "生",
    slot: "店主札",
    name: "ハッピーアワー",
    description: "各フロア開始時に生ジョッキレールを補充する。",
    color: "#ffca22",
    school: "宴会",
  },
  {
    id: "perfect",
    icon: "芯",
    slot: "仮面裏",
    name: "一点集中",
    description: "中心命中以外でもPERFECT判定が発生しやすくなる。",
    color: "#ff5e54",
    school: "会心",
  },
  {
    id: "runner",
    icon: "走",
    slot: "足腰",
    name: "ついでに全力疾走",
    description: "移動速度とダッシュの回転率が上がる。",
    color: "#63df8e",
    school: "速配",
  },
];

export const SYNERGIES: SynergyDefinition[] = [
  {
    ids: ["wide", "foam"],
    name: "爆泡ジョッキ",
    icon: "泡",
    effect: "泡の連鎖範囲と威力が大幅アップ",
  },
  {
    ids: ["frost", "haste"],
    name: "キンキン速配",
    icon: "冷",
    effect: "冷えた備品へのダメージが1.5倍",
  },
  {
    ids: ["heavy", "perfect"],
    name: "店主の会心",
    icon: "芯",
    effect: "PERFECT SMASHの倍率が2.35倍",
  },
  {
    ids: ["guard", "yakitori"],
    name: "立ち飲み不沈艦",
    icon: "守",
    effect: "HP80%以上で受けるダメージを35%軽減",
  },
  {
    ids: ["combo", "runner"],
    name: "宴会ランナー",
    icon: "走",
    effect: "清掃熱の上昇量が1.5倍",
  },
];

export function resolveSynergies(values: Partial<Record<UpgradeId, number>>) {
  return SYNERGIES.filter(({ ids }) => ids.every((id) => (values[id] ?? 0) > 0));
}

const RARITIES = [
  { name: "生", className: "draft", scale: 1 },
  { name: "大生", className: "large", scale: 1.35 },
  { name: "特大生", className: "mega", scale: 1.75 },
  { name: "店主秘蔵", className: "secret", scale: 2.3 },
];

function effectText(id: UpgradeId, scale: number) {
  switch (id) {
    case "heavy": return `攻撃力 +${Math.round(28 * scale)}%`;
    case "wide": return `攻撃範囲 +${Math.round(16 * scale)}%`;
    case "haste": return `攻撃間隔 -${Math.round(9 * scale)}%`;
    case "foam": return `破壊時に周囲へ ${Math.round(45 * scale)}% ダメージ`;
    case "frost": return `移動速度 -${Math.round(24 * scale)}%`;
    case "yakitori": return `撃破時 HP ${Math.max(1, Math.round(2 * scale))} 回復`;
    case "combo": return `コンボ受付 +${(0.7 * scale).toFixed(1)}秒`;
    case "guard": return `最大HP +${Math.round(18 * scale)}`;
    case "knockback": return `吹き飛ばし +${Math.round(40 * scale)}%`;
    case "happy": return `各階 MEGA +${Math.max(1, Math.floor(scale))}`;
    case "perfect": return `追加PERFECT率 +${Math.round(10 * scale)}%`;
    case "runner": return `移動速度 +${Math.round(8 * scale)}%`;
  }
}

function rollTier(floor: number) {
  const roll = Math.random() + floor * 0.035;
  if (roll > 1.18) return 3;
  if (roll > 0.87) return 2;
  if (roll > 0.48) return 1;
  return 0;
}

export function makeRewardChoices(floor: number, overtimeRank: OvertimeRank = 0): RewardChoice[] {
  const pool = [...UPGRADES];
  const choices: RewardChoice[] = [];
  while (choices.length < 3) {
    const index = Math.floor(Math.random() * pool.length);
    const definition = pool.splice(index, 1)[0];
    const tier = rollTier(floor);
    const rarity = RARITIES[tier];
    const greater = Math.random() < 0.045 + floor * 0.012 + overtimeRank * 0.018;
    const scale = rarity.scale * (greater ? 1.45 : 1);
    choices.push({
      ...definition,
      tier,
      rarity: `${greater ? "金星 " : ""}${rarity.name}`,
      rarityClass: rarity.className,
      scale,
      effect: `${greater ? "★ " : ""}${effectText(definition.id, scale)}`,
      greater,
    });
  }
  return choices;
}

export function masteryCost(level: number) {
  return 20 + level * 20;
}
