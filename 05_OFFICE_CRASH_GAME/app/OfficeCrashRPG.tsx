"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import * as THREE from "three";
import { SOBAYA_CHARACTER } from "./characters/sobaya";
import {
  MID_BOSS_ROTATION,
  WINDOW_BOSSES,
  type CharacterBossId,
} from "./characters/window-bosses";
import {
  loadVoxelCharacter,
  type VoxelActionController,
} from "./characters/voxel-character-kit";
import {
  EMPTY_PROFILE,
  FLOORS,
  OVERTIME_RANKS,
  UPGRADES,
  makeRewardChoices,
  masteryCost,
  resolveSynergies,
  type GameProfile,
  type GameStatus,
  type MasteryKey,
  type OvertimeRank,
  type RewardChoice,
  type SiteGameData,
  type SynergyDefinition,
  type UpgradeId,
} from "./game-content";

type HudState = {
  floor: number;
  floorName: string;
  kicker: string;
  objective: string;
  hp: number;
  maxHp: number;
  score: number;
  combo: number;
  multiplier: number;
  enemies: number;
  totalEnemies: number;
  mega: number;
  caps: number;
  timer: number | null;
  dashReady: number;
  bossName: string;
  pressure: number;
  rushRemaining: number;
  overtimeLabel: string;
  scoreMultiplier: number;
  offscreenEnemies: number;
  incomingAttack: boolean;
};

type RunSummary = {
  victory: boolean;
  floorReached: number;
  score: number;
  destroyed: number;
  maxCombo: number;
  capsEarned: number;
  upgrades: string[];
  overtimeRank: OvertimeRank;
  buildName: string;
};

type GameApi = {
  start: (profile: GameProfile, overtimeRank: OvertimeRank) => void;
  smash: () => void;
  megaSmash: () => void;
  dash: () => void;
  pause: () => void;
  unlockAudio: () => void;
  testSound: () => void;
  toggleSound: () => boolean;
  pickUpgrade: (choice: RewardChoice) => void;
  rerollReward: () => void;
  returnHub: () => void;
};

type EquipmentEnemyKind = "chair" | "stapler" | "cabinet" | "desk" | "copier" | "gate" | "core";
type EnemyKind = EquipmentEnemyKind | "character";
type EliteAffix = "rapid" | "barrier" | "volatile" | "regenerator";
type EnemyAttackKind = "melee" | "pulse";

type Enemy = {
  group: THREE.Group;
  kind: EnemyKind;
  label: string;
  hp: number;
  maxHp: number;
  speed: number;
  damage: number;
  radius: number;
  points: number;
  color: number;
  alive: boolean;
  boss: boolean;
  characterBoss: CharacterBossId | null;
  elite: boolean;
  affix: EliteAffix | null;
  barrier: number;
  lastRegen: number;
  frozenUntil: number;
  nextAttack: number;
  pulseAt: number;
  attackKind: EnemyAttackKind | null;
  attackStartedAt: number;
  attackAt: number;
  attackOrigin: THREE.Vector3;
  attackRadius: number;
  attackWarning: THREE.Group | null;
  vulnerableFrom: number;
  vulnerableUntil: number;
  phase: 1 | 2;
  healthFill?: THREE.Mesh;
};

type PickupKind = "beer" | "clock" | "cap" | "yakitori";

type Pickup = {
  group: THREE.Group;
  kind: PickupKind;
  baseY: number;
  active: boolean;
};

type Debris = {
  mesh: THREE.Mesh;
  velocity: THREE.Vector3;
  spin: THREE.Vector3;
  life: number;
};

type Effect = {
  mesh: THREE.Mesh;
  life: number;
  maxLife: number;
};

type Hazard = {
  shape: "circle" | "beam";
  warning: THREE.Group;
  position: THREE.Vector3;
  radius: number;
  direction: THREE.Vector3;
  length: number;
  width: number;
  damage: number;
  startedAt: number;
  triggerAt: number;
  color: number;
};

type DizzyBoss = {
  group: THREE.Group;
  stars: THREE.Group;
  startedAt: number;
};

type MegaProjectile = {
  group: THREE.Group;
  lane: THREE.Group;
  origin: THREE.Vector3;
  direction: THREE.Vector3;
  distance: number;
  width: number;
  damage: number;
  startedAt: number;
  duration: number;
  previousDistance: number;
  lastTrailAt: number;
  hitEnemies: Set<Enemy>;
};

type TimedVisual = {
  object: THREE.Object3D;
  life: number;
  maxLife: number;
  spin: number;
};

const EMPTY_HUD: HudState = {
  floor: 1,
  floorName: FLOORS[0].name,
  kicker: FLOORS[0].kicker,
  objective: FLOORS[0].objective,
  hp: 100,
  maxHp: 100,
  score: 0,
  combo: 0,
  multiplier: 1,
  enemies: 0,
  totalEnemies: 0,
  mega: 0,
  caps: 0,
  timer: null,
  dashReady: 1,
  bossName: "",
  pressure: 0,
  rushRemaining: 0,
  overtimeLabel: OVERTIME_RANKS[0].label,
  scoreMultiplier: 1,
  offscreenEnemies: 0,
  incomingAttack: false,
};

const MAX_FLOOR = FLOORS.length;
const UP = new THREE.Vector3(0, 1, 0);

function getComboMultiplier(combo: number) {
  if (combo >= 30) return 4;
  if (combo >= 20) return 3;
  if (combo >= 12) return 2.25;
  if (combo >= 6) return 1.5;
  return 1;
}

function getRank(summary: RunSummary) {
  if (summary.victory && summary.score >= 70000) return "窓際伝説の店主";
  if (summary.victory) return "備品循環棟・完全制覇";
  if (summary.floorReached >= 7) return "レギュレーションブレイカー";
  if (summary.floorReached >= 4) return "窓際セッションの名手";
  return "片付けの途中です！";
}

function formatNumber(value: number) {
  return Math.max(0, Math.round(value)).toLocaleString("ja-JP");
}

function roundedBox(width: number, height: number, depth: number, color: number) {
  const mesh = new THREE.Mesh(
    new THREE.BoxGeometry(width, height, depth),
    new THREE.MeshStandardMaterial({ color, roughness: 0.74 }),
  );
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

function makeHealthBar(width: number, color = 0x56e07a) {
  const holder = new THREE.Group();
  const back = roundedBox(width, 0.13, 0.09, 0x182632);
  const fill = roundedBox(width * 0.92, 0.075, 0.12, color);
  fill.position.z = -0.07;
  holder.add(back, fill);
  holder.userData.fill = fill;
  return holder;
}

function makeSobayaFallback() {
  const root = new THREE.Group();
  const shirt = new THREE.MeshStandardMaterial({ color: 0xf5f6f2, roughness: 0.86 });
  const skin = new THREE.MeshStandardMaterial({ color: 0xa7b0b5, roughness: 0.78 });
  const white = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.58 });
  const amber = new THREE.MeshStandardMaterial({
    color: 0xf39b08,
    roughness: 0.25,
    emissive: 0x4b2200,
    emissiveIntensity: 0.2,
  });

  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.72, 0.82, 6, 14), shirt);
  torso.scale.set(1.28, 1, 0.9);
  torso.position.y = 1.45;
  torso.castShadow = true;
  root.add(torso);

  for (const x of [-0.42, 0.42]) {
    const leg = new THREE.Mesh(new THREE.CapsuleGeometry(0.21, 0.38, 5, 12), skin);
    leg.position.set(x, 0.38, 0);
    leg.castShadow = true;
    root.add(leg);
    const shoe = roundedBox(0.46, 0.2, 0.62, 0x11161b);
    shoe.position.set(x, 0.08, -0.16);
    root.add(shoe);
  }

  const head = new THREE.Mesh(new THREE.SphereGeometry(0.62, 22, 16), skin);
  head.position.y = 2.65;
  head.castShadow = true;
  root.add(head);
  const mask = new THREE.Mesh(new THREE.SphereGeometry(0.6, 24, 18), white);
  mask.scale.set(0.92, 1.03, 0.22);
  mask.position.set(0, 2.65, -0.57);
  root.add(mask);
  for (const x of [-0.22, 0.22]) {
    const eye = new THREE.Mesh(
      new THREE.CircleGeometry(0.095, 16),
      new THREE.MeshBasicMaterial({ color: 0x080a0b }),
    );
    eye.position.set(x, 2.75, -0.705);
    root.add(eye);
    const mark = new THREE.Mesh(
      new THREE.ConeGeometry(0.08, 0.3, 4),
      new THREE.MeshStandardMaterial({ color: 0xe12b2b }),
    );
    mark.position.set(x, 2.43, -0.69);
    root.add(mark);
  }

  const mug = new THREE.Group();
  const beer = new THREE.Mesh(new THREE.CylinderGeometry(0.26, 0.23, 0.72, 18), amber);
  mug.add(beer);
  const glass = new THREE.Mesh(
    new THREE.CylinderGeometry(0.29, 0.26, 0.78, 18, 1, true),
    new THREE.MeshPhysicalMaterial({
      color: 0xffffff,
      transparent: true,
      opacity: 0.38,
      roughness: 0.08,
      transmission: 0.3,
    }),
  );
  mug.add(glass);
  const handle = new THREE.Mesh(
    new THREE.TorusGeometry(0.2, 0.045, 8, 18, Math.PI * 1.6),
    white,
  );
  handle.position.x = 0.28;
  handle.rotation.z = -0.8;
  mug.add(handle);
  mug.position.set(0.95, 1.2, -0.48);
  root.add(mug);

  root.scale.setScalar(0.92);
  return root;
}

function makeSobaya() {
  const player = new THREE.Group();
  player.name = "sobaya";
  const fallback = makeSobayaFallback();
  player.add(fallback);

  const marker = new THREE.Mesh(
    new THREE.RingGeometry(0.88, 1.03, 42),
    new THREE.MeshBasicMaterial({
      color: 0xffc21d,
      transparent: true,
      opacity: 0.7,
      side: THREE.DoubleSide,
    }),
  );
  marker.rotation.x = -Math.PI / 2;
  marker.position.y = 0.025;
  player.add(marker);

  loadVoxelCharacter({
    definition: SOBAYA_CHARACTER,
    parent: player,
    onReady: ({ mixer, actions }) => {
      fallback.visible = false;
      if (mixer) player.userData.mixer = mixer;
      if (actions) player.userData.animator = actions;
    },
    onError: (error) => {
      console.warn("Sobaya GLB could not be loaded; using fallback.", error);
    },
  });
  return player;
}

function makeChairEnemy() {
  const group = new THREE.Group();
  const seat = roundedBox(0.78, 0.18, 0.74, 0x237bc1);
  seat.position.y = 0.72;
  const back = roundedBox(0.78, 0.8, 0.16, 0x2c92da);
  back.position.set(0, 1.18, 0.28);
  const stem = roundedBox(0.12, 0.55, 0.12, 0x33414a);
  stem.position.y = 0.38;
  group.add(seat, back, stem);
  for (let i = 0; i < 5; i += 1) {
    const angle = i / 5 * Math.PI * 2;
    const foot = roundedBox(0.52, 0.09, 0.1, 0x26333d);
    foot.position.set(Math.sin(angle) * 0.26, 0.12, Math.cos(angle) * 0.26);
    foot.rotation.y = angle;
    group.add(foot);
  }
  return group;
}

function makeStaplerEnemy() {
  const group = new THREE.Group();
  const base = roundedBox(0.95, 0.2, 0.48, 0x495b67);
  base.position.y = 0.28;
  const arm = roundedBox(0.9, 0.23, 0.43, 0xf06a31);
  arm.position.set(0, 0.55, -0.05);
  arm.rotation.x = -0.14;
  group.add(base, arm);
  for (const x of [-0.32, 0.32]) {
    const claw = new THREE.Mesh(
      new THREE.ConeGeometry(0.12, 0.42, 4),
      new THREE.MeshStandardMaterial({ color: 0xd9e2e7, metalness: 0.65, roughness: 0.35 }),
    );
    claw.position.set(x, 0.25, -0.42);
    claw.rotation.x = Math.PI / 2;
    group.add(claw);
  }
  return group;
}

function makeCabinetEnemy(armored = false) {
  const group = new THREE.Group();
  const body = roundedBox(1.05, 1.55, 0.76, armored ? 0x3f5260 : 0x7b8b95);
  body.position.y = 0.8;
  group.add(body);
  for (const y of [0.36, 0.77, 1.18]) {
    const drawer = roundedBox(0.78, 0.09, 0.06, armored ? 0xff793f : 0x33414a);
    drawer.position.set(0, y, -0.4);
    group.add(drawer);
  }
  for (const x of [-0.38, 0.38]) {
    const foot = roundedBox(0.22, 0.25, 0.34, 0x25323b);
    foot.position.set(x, 0.1, 0);
    group.add(foot);
  }
  return group;
}

function makeDeskEnemy() {
  const group = new THREE.Group();
  const top = roundedBox(1.8, 0.2, 0.85, 0xb97943);
  top.position.y = 0.83;
  group.add(top);
  for (const x of [-0.68, 0.68]) {
    const leg = roundedBox(0.18, 0.8, 0.18, 0x475761);
    leg.position.set(x, 0.4, 0);
    group.add(leg);
  }
  const screen = roundedBox(0.72, 0.54, 0.1, 0x172730);
  screen.position.set(0, 1.24, 0);
  group.add(screen);
  return group;
}

function makeCopierEnemy(gold = false) {
  const group = new THREE.Group();
  const body = roundedBox(1.35, 1.62, 1.0, gold ? 0xf6b80c : 0xd9e1e5);
  body.position.y = 0.82;
  const lid = roundedBox(1.25, 0.2, 0.88, gold ? 0xffdf4e : 0x687882);
  lid.position.set(0, 1.72, -0.04);
  lid.rotation.x = -0.12;
  const slot = roundedBox(0.82, 0.16, 0.12, gold ? 0xa86500 : 0x25343d);
  slot.position.set(0, 1.16, -0.54);
  group.add(body, lid, slot);
  for (const x of [-0.43, 0.43]) {
    const wheel = new THREE.Mesh(
      new THREE.CylinderGeometry(0.18, 0.18, 0.16, 14),
      new THREE.MeshStandardMaterial({ color: 0x222d34 }),
    );
    wheel.rotation.z = Math.PI / 2;
    wheel.position.set(x, 0.14, 0);
    group.add(wheel);
  }
  return group;
}

function makeGateEnemy() {
  const group = new THREE.Group();
  const body = roundedBox(2.1, 1.8, 0.45, 0x425864);
  body.position.y = 0.92;
  group.add(body);
  for (const y of [0.32, 0.74, 1.16, 1.58]) {
    const brace = roundedBox(2.3, 0.13, 0.55, y % 0.8 < 0.4 ? 0xff793f : 0x22333d);
    brace.position.set(0, y, -0.02);
    group.add(brace);
  }
  const core = roundedBox(0.5, 0.5, 0.18, 0xff9f19);
  core.position.set(0, 0.82, -0.35);
  group.add(core);
  return group;
}

function makeCoreEnemy() {
  const group = new THREE.Group();
  const dark = new THREE.MeshStandardMaterial({
    color: 0x18242e,
    metalness: 0.72,
    roughness: 0.34,
  });
  const red = new THREE.MeshStandardMaterial({
    color: 0xff4437,
    emissive: 0xff291d,
    emissiveIntensity: 1.5,
    roughness: 0.3,
  });
  const core = new THREE.Mesh(new THREE.OctahedronGeometry(0.9, 0), red);
  core.position.y = 1.25;
  core.castShadow = true;
  group.add(core);
  for (let i = 0; i < 3; i += 1) {
    const ring = new THREE.Mesh(new THREE.TorusGeometry(1.35 + i * 0.32, 0.09, 10, 42), dark);
    ring.position.y = 1.25;
    ring.rotation.set(i * 0.72, i * 0.56, i * 0.38);
    group.add(ring);
  }
  for (let i = 0; i < 6; i += 1) {
    const angle = i / 6 * Math.PI * 2;
    const pylon = roundedBox(0.28, 1.3, 0.28, i % 2 ? 0x445866 : 0xff704c);
    pylon.position.set(Math.sin(angle) * 1.7, 0.66, Math.cos(angle) * 1.7);
    group.add(pylon);
  }
  return group;
}

function makeEnemyModel(kind: EnemyKind, elite: boolean) {
  if (kind === "chair") return makeChairEnemy();
  if (kind === "stapler") return makeStaplerEnemy();
  if (kind === "cabinet") return makeCabinetEnemy(elite);
  if (kind === "desk") return makeDeskEnemy();
  if (kind === "copier") return makeCopierEnemy(elite);
  if (kind === "gate") return makeGateEnemy();
  return makeCoreEnemy();
}

function makePickup(kind: PickupKind) {
  const group = new THREE.Group();
  if (kind === "beer") {
    const glass = new THREE.Mesh(
      new THREE.CylinderGeometry(0.28, 0.24, 0.72, 16),
      new THREE.MeshStandardMaterial({
        color: 0xffaa10,
        emissive: 0x8b3a00,
        emissiveIntensity: 0.42,
      }),
    );
    group.add(glass);
    for (let i = 0; i < 5; i += 1) {
      const foam = new THREE.Mesh(
        new THREE.SphereGeometry(0.12, 10, 8),
        new THREE.MeshStandardMaterial({ color: 0xfff9dc }),
      );
      foam.position.set((i - 2) * 0.1, 0.38 + (i % 2) * 0.04, 0);
      group.add(foam);
    }
  } else if (kind === "clock") {
    const crystal = new THREE.Mesh(
      new THREE.OctahedronGeometry(0.38),
      new THREE.MeshStandardMaterial({
        color: 0x58dbff,
        emissive: 0x149dd1,
        emissiveIntensity: 0.7,
      }),
    );
    group.add(crystal);
  } else if (kind === "cap") {
    const cap = new THREE.Mesh(
      new THREE.CylinderGeometry(0.32, 0.32, 0.12, 18),
      new THREE.MeshStandardMaterial({
        color: 0xffca22,
        metalness: 0.52,
        roughness: 0.35,
        emissive: 0x7a4100,
        emissiveIntensity: 0.25,
      }),
    );
    cap.rotation.x = Math.PI / 2;
    group.add(cap);
  } else {
    const skewer = roundedBox(0.08, 0.82, 0.08, 0x8a4f29);
    skewer.rotation.z = -0.6;
    group.add(skewer);
    for (let i = 0; i < 3; i += 1) {
      const bite = roundedBox(0.26, 0.2, 0.22, 0xe77f38);
      bite.position.set((i - 1) * 0.18, (i - 1) * 0.26, 0);
      group.add(bite);
    }
  }
  const halo = new THREE.Mesh(
    new THREE.RingGeometry(0.5, 0.62, 28),
    new THREE.MeshBasicMaterial({
      color: kind === "clock" ? 0x65ddff : kind === "cap" ? 0xffcd2b : 0xffffff,
      transparent: true,
      opacity: 0.75,
      side: THREE.DoubleSide,
    }),
  );
  halo.rotation.x = -Math.PI / 2;
  halo.position.y = -0.4;
  group.add(halo);
  return group;
}

function makeFloorSign(title: string, kicker: string, accent: number) {
  const canvas = document.createElement("canvas");
  canvas.width = 1024;
  canvas.height = 256;
  const context = canvas.getContext("2d");
  if (!context) return new THREE.Group();
  context.fillStyle = "#172631";
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.fillStyle = `#${accent.toString(16).padStart(6, "0")}`;
  context.fillRect(0, 0, 28, canvas.height);
  context.fillStyle = "#91a4af";
  context.font = "700 40px sans-serif";
  context.fillText(kicker, 70, 72);
  context.fillStyle = "#ffffff";
  context.font = "900 82px sans-serif";
  context.fillText(title, 68, 174);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  const sign = new THREE.Mesh(
    new THREE.PlaneGeometry(8.8, 2.2),
    new THREE.MeshBasicMaterial({ map: texture }),
  );
  sign.position.set(0, 3.05, -14.78);
  return sign;
}

function healthColor(ratio: number) {
  if (ratio > 0.55) return 0x56e07a;
  if (ratio > 0.25) return 0xffc426;
  return 0xff4d3a;
}

export default function OfficeCrashRPG() {
  const hostRef = useRef<HTMLElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const apiRef = useRef<GameApi | null>(null);
  const joystickRef = useRef({ x: 0, z: 0 });
  const joystickPointer = useRef<number | null>(null);
  const profileRef = useRef<GameProfile>(EMPTY_PROFILE);
  const submitRunRef = useRef<(summary: RunSummary) => void>(() => {});
  const toastTimer = useRef<number | null>(null);
  const megaFlashTimer = useRef<number | null>(null);

  const [status, setStatus] = useState<GameStatus>("hub");
  const [hud, setHud] = useState<HudState>(EMPTY_HUD);
  const [paused, setPaused] = useState(false);
  const [soundOn, setSoundOn] = useState(true);
  const [audioReady, setAudioReady] = useState(false);
  const [audioError, setAudioError] = useState(false);
  const [toast, setToast] = useState("");
  const [megaFlash, setMegaFlash] = useState(false);
  const [joystick, setJoystick] = useState({ x: 0, y: 0 });
  const [rewardChoices, setRewardChoices] = useState<RewardChoice[]>([]);
  const [rerolls, setRerolls] = useState(1);
  const [build, setBuild] = useState<RewardChoice[]>([]);
  const [activeSynergies, setActiveSynergies] = useState<SynergyDefinition[]>([]);
  const [overtimeRank, setOvertimeRank] = useState<OvertimeRank>(0);
  const [summary, setSummary] = useState<RunSummary | null>(null);
  const [siteData, setSiteData] = useState<SiteGameData | null>(null);
  const [profileLoading, setProfileLoading] = useState(true);
  const [profileError, setProfileError] = useState(false);
  const [masteryBusy, setMasteryBusy] = useState<MasteryKey | null>(null);

  const notify = useCallback((message: string) => {
    setToast(message);
    if (toastTimer.current) window.clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToast(""), 1200);
  }, []);

  const applySiteData = useCallback((data: SiteGameData) => {
    setSiteData(data);
    profileRef.current = data.profile;
    setProfileError(false);
  }, []);

  const refreshProfile = useCallback(async () => {
    setProfileLoading(true);
    try {
      const response = await fetch("/api/game/profile", { cache: "no-store" });
      if (!response.ok) throw new Error("profile");
      applySiteData(await response.json() as SiteGameData);
    } catch {
      setProfileError(true);
      profileRef.current = EMPTY_PROFILE;
    } finally {
      setProfileLoading(false);
    }
  }, [applySiteData]);

  useEffect(() => {
    let active = true;
    fetch("/api/game/profile", { cache: "no-store" })
      .then((response) => {
        if (!response.ok) throw new Error("profile");
        return response.json() as Promise<SiteGameData>;
      })
      .then((data) => {
        if (active) applySiteData(data);
      })
      .catch(() => {
        if (active) {
          setProfileError(true);
          profileRef.current = EMPTY_PROFILE;
        }
      })
      .finally(() => {
        if (active) setProfileLoading(false);
      });
    return () => {
      active = false;
    };
  }, [applySiteData]);

  const submitRun = useCallback(async (run: RunSummary) => {
    try {
      const response = await fetch("/api/game/run", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(run),
      });
      if (!response.ok) throw new Error("run");
      applySiteData(await response.json() as SiteGameData);
      notify("ラン記録を立ち飲み処へ保存しました");
    } catch {
      setProfileError(true);
      notify("記録は通信復旧後にもう一度挑戦してください");
    }
  }, [applySiteData, notify]);

  useEffect(() => {
    submitRunRef.current = (run) => {
      void submitRun(run);
    };
  }, [submitRun]);

  const buyMastery = async (stat: MasteryKey) => {
    if (masteryBusy) return;
    setMasteryBusy(stat);
    try {
      const response = await fetch("/api/game/mastery", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ stat }),
      });
      const data = await response.json() as SiteGameData & { error?: string; cost?: number };
      if (!response.ok) {
        notify(data.error === "not_enough_caps" ? `王冠キャップが足りません（必要 ${data.cost}）` : "これ以上は強化できません");
        return;
      }
      applySiteData(data);
      notify("立ち飲み処で永続強化しました！");
    } catch {
      notify("強化を保存できませんでした");
    } finally {
      setMasteryBusy(null);
    }
  };

  useEffect(() => {
    const canvas = canvasRef.current;
    const host = hostRef.current;
    if (!canvas || !host) return;

    const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.7));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFShadowMap;
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.setClearColor(0xb9e7fb, 1);

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0xb9e7fb);
    scene.fog = new THREE.Fog(0xb9e7fb, 27, 48);

    const camera = new THREE.OrthographicCamera(-12, 12, 7, -7, 0.1, 100);
    const baseCameraPosition = new THREE.Vector3(17, 21, 21);
    camera.position.copy(baseCameraPosition);
    camera.lookAt(0, 0, -1.5);

    const hemi = new THREE.HemisphereLight(0xf3fbff, 0x705e52, 2.2);
    scene.add(hemi);
    const sun = new THREE.DirectionalLight(0xffffff, 3.5);
    sun.position.set(-8, 18, 11);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    sun.shadow.camera.left = -20;
    sun.shadow.camera.right = 20;
    sun.shadow.camera.top = 22;
    sun.shadow.camera.bottom = -22;
    sun.shadow.bias = -0.0004;
    scene.add(sun);
    const accentLight = new THREE.PointLight(0x19b8ff, 2.2, 26);
    accentLight.position.set(0, 8, -8);
    scene.add(accentLight);

    const floorMaterial = new THREE.MeshStandardMaterial({ color: 0xe8edf0, roughness: 0.92 });
    const floorMesh = new THREE.Mesh(new THREE.PlaneGeometry(22, 29), floorMaterial);
    floorMesh.rotation.x = -Math.PI / 2;
    floorMesh.position.z = -1.2;
    floorMesh.receiveShadow = true;
    scene.add(floorMesh);
    const grid = new THREE.GridHelper(29, 29, 0x899aa3, 0xc1ccd0);
    grid.position.set(0, 0.015, -1.2);
    scene.add(grid);

    const backWall = roundedBox(22, 4.8, 0.25, 0xf4f0e9);
    backWall.position.set(0, 2.4, -15);
    scene.add(backWall);
    const rightWall = roundedBox(0.25, 4.8, 29, 0xf5f1eb);
    rightWall.position.set(11, 2.4, -1.2);
    scene.add(rightWall);
    for (let i = 0; i < 7; i += 1) {
      const pane = new THREE.Mesh(
        new THREE.PlaneGeometry(2.7, 3.1),
        new THREE.MeshStandardMaterial({
          color: 0x91d9f8,
          emissive: 0x42b2df,
          emissiveIntensity: 0.24,
          roughness: 0.08,
        }),
      );
      pane.position.set(-10.88, 2.65, -12.8 + i * 4);
      pane.rotation.y = Math.PI / 2;
      scene.add(pane);
    }

    const player = makeSobaya();
    player.position.set(0, 0, 9.6);
    scene.add(player);

    const enemies: Enemy[] = [];
    const pickups: Pickup[] = [];
    const debris: Debris[] = [];
    const effects: Effect[] = [];
    const hazards: Hazard[] = [];
    const dizzyBosses: DizzyBoss[] = [];
    const megaProjectiles: MegaProjectile[] = [];
    const timedVisuals: TimedVisual[] = [];
    const stageObjects: THREE.Object3D[] = [];
    const upgradeValues = Object.fromEntries(
      UPGRADES.map((upgrade) => [upgrade.id, 0]),
    ) as Record<UpgradeId, number>;

    let audioContext: AudioContext | null = null;
    let audioResume: Promise<AudioContext> | null = null;
    let soundEnabled = true;
    const ensureAudioContext = () => {
      if (!audioContext) {
        const AudioContextConstructor = window.AudioContext
          ?? (window as Window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
        if (!AudioContextConstructor) throw new Error("Web Audio is unavailable");
        audioContext = new AudioContextConstructor();
      }
      return audioContext;
    };
    const resumeAudio = () => {
      let context: AudioContext;
      try {
        context = ensureAudioContext();
      } catch {
        setAudioReady(false);
        setAudioError(true);
        return Promise.reject(new Error("Web Audio is unavailable"));
      }
      if (context.state === "running") {
        setAudioReady(true);
        setAudioError(false);
        return Promise.resolve(context);
      }
      audioResume ??= context.resume()
        .then(() => {
          if (context.state !== "running") throw new Error("AudioContext did not start");
          setAudioReady(true);
          setAudioError(false);
          return context;
        })
        .catch((error) => {
          setAudioReady(false);
          setAudioError(true);
          throw error;
        })
        .finally(() => {
          audioResume = null;
        });
      return audioResume;
    };
    const withAudio = (callback: (context: AudioContext) => void) => {
      if (!soundEnabled) return;
      let context: AudioContext;
      try {
        context = ensureAudioContext();
      } catch {
        setAudioReady(false);
        setAudioError(true);
        return;
      }
      if (context.state === "running") {
        callback(context);
        return;
      }
      void resumeAudio().then(callback).catch(() => {
        // The visible sound-test button lets the player retry with a fresh gesture.
      });
    };
    const tone = (
      frequency: number,
      duration: number,
      type: OscillatorType = "sine",
      gainValue = 0.07,
      endFrequency = frequency,
      delay = 0,
    ) => {
      if (!soundEnabled) return;
      withAudio((context) => {
        const at = context.currentTime + delay;
        const oscillator = context.createOscillator();
        const gain = context.createGain();
        oscillator.type = type;
        oscillator.frequency.setValueAtTime(frequency, at);
        oscillator.frequency.exponentialRampToValueAtTime(Math.max(20, endFrequency), at + duration);
        gain.gain.setValueAtTime(0.0001, at);
        gain.gain.exponentialRampToValueAtTime(gainValue, at + 0.012);
        gain.gain.exponentialRampToValueAtTime(0.0001, at + duration);
        oscillator.connect(gain).connect(context.destination);
        oscillator.start(at);
        oscillator.stop(at + duration + 0.03);
      });
    };
    const noise = (duration: number, gainValue: number, highpass = 120) => {
      if (!soundEnabled) return;
      withAudio((context) => {
        const buffer = context.createBuffer(1, Math.ceil(context.sampleRate * duration), context.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < data.length; i += 1) data[i] = (Math.random() * 2 - 1) * (1 - i / data.length);
        const source = context.createBufferSource();
        const filter = context.createBiquadFilter();
        const gain = context.createGain();
        filter.type = "highpass";
        filter.frequency.value = highpass;
        gain.gain.setValueAtTime(gainValue, context.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + duration);
        source.buffer = buffer;
        source.connect(filter).connect(gain).connect(context.destination);
        source.start();
      });
    };
    const playSound = (kind: "smash" | "break" | "metal" | "beer" | "hurt" | "clear" | "start") => {
      if (kind === "smash") {
        noise(0.11, 0.11, 180);
        tone(115, 0.15, "sawtooth", 0.075, 48);
      } else if (kind === "break") {
        noise(0.22, 0.15, 110);
        tone(86, 0.18, "square", 0.065, 42);
      } else if (kind === "metal") {
        noise(0.15, 0.08, 900);
        tone(710, 0.2, "square", 0.045, 380);
      } else if (kind === "beer") {
        tone(440, 0.12, "sine", 0.06, 660);
        tone(660, 0.15, "triangle", 0.06, 990, 0.1);
        tone(990, 0.18, "sine", 0.045, 1320, 0.2);
      } else if (kind === "hurt") {
        noise(0.16, 0.08, 160);
        tone(190, 0.2, "sawtooth", 0.055, 70);
      } else if (kind === "clear") {
        tone(440, 0.13, "square", 0.05, 660);
        tone(660, 0.14, "square", 0.055, 880, 0.12);
        tone(880, 0.28, "triangle", 0.06, 1320, 0.24);
      } else {
        tone(330, 0.12, "square", 0.05, 440);
        tone(550, 0.18, "square", 0.055, 770, 0.12);
      }
    };

    const runtime = {
      playing: false,
      paused: false,
      submitted: false,
      elapsed: 0,
      floor: 1,
      score: 0,
      hp: 100,
      maxHp: 100,
      combo: 0,
      comboWindow: 0,
      maxCombo: 0,
      destroyed: 0,
      mega: 0,
      runCaps: 0,
      overtimeRank: 0 as OvertimeRank,
      pressure: 0,
      rushUntil: 0,
      rerolls: 1,
      floorKilled: 0,
      floorTotal: 0,
      timer: null as number | null,
      lastSmash: -10,
      lastMega: -10,
      lastBump: -10,
      lastDash: -10,
      megaLockUntil: 0,
      invulnerableUntil: 0,
      freezeUntil: 0,
      shake: 0,
      pendingSmash: null as { at: number; center: THREE.Vector3 } | null,
      pendingMega: null as {
        at: number;
        origin: THREE.Vector3;
        direction: THREE.Vector3;
      } | null,
      profile: EMPTY_PROFILE,
      guestBoss: "yotan" as CharacterBossId,
      lastBossDefeat: "",
      pendingFloorClear: false,
      selected: [] as RewardChoice[],
      synergies: [] as SynergyDefinition[],
    };

    const stageAdd = (object: THREE.Object3D) => {
      scene.add(object);
      stageObjects.push(object);
    };

    const removeDisposableObject = (object: THREE.Object3D) => {
      scene.remove(object);
      object.traverse((child) => {
        if (!(child instanceof THREE.Mesh)) return;
        child.geometry.dispose();
        const materials = Array.isArray(child.material) ? child.material : [child.material];
        for (const material of materials) material.dispose();
      });
    };

    const clearStage = () => {
      for (const enemy of enemies) {
        scene.remove(enemy.group);
        if (enemy.attackWarning) removeDisposableObject(enemy.attackWarning);
      }
      for (const pickup of pickups) scene.remove(pickup.group);
      for (const object of stageObjects) scene.remove(object);
      enemies.length = 0;
      pickups.length = 0;
      stageObjects.length = 0;
      for (const piece of debris) scene.remove(piece.mesh);
      debris.length = 0;
      for (const effect of effects) scene.remove(effect.mesh);
      effects.length = 0;
      for (const hazard of hazards) removeDisposableObject(hazard.warning);
      hazards.length = 0;
      for (const projectile of megaProjectiles) {
        removeDisposableObject(projectile.group);
        removeDisposableObject(projectile.lane);
      }
      megaProjectiles.length = 0;
      for (const visual of timedVisuals) removeDisposableObject(visual.object);
      timedVisuals.length = 0;
      dizzyBosses.length = 0;
    };

    const spawnDebris = (position: THREE.Vector3, color: number, amount: number) => {
      for (let i = 0; i < amount; i += 1) {
        const size = 0.1 + Math.random() * 0.26;
        const piece = new THREE.Mesh(
          new THREE.BoxGeometry(size, size * (0.6 + Math.random()), size),
          new THREE.MeshStandardMaterial({
            color: i % 5 === 0 ? 0xfff5dc : color,
            roughness: 0.84,
            transparent: true,
          }),
        );
        piece.position.copy(position).add(new THREE.Vector3(
          (Math.random() - 0.5) * 0.8,
          0.35 + Math.random() * 0.9,
          (Math.random() - 0.5) * 0.8,
        ));
        piece.castShadow = true;
        scene.add(piece);
        debris.push({
          mesh: piece,
          velocity: new THREE.Vector3(
            (Math.random() - 0.5) * 5.8,
            2.8 + Math.random() * 4.8,
            (Math.random() - 0.5) * 5.8,
          ),
          spin: new THREE.Vector3(Math.random() * 6, Math.random() * 6, Math.random() * 6),
          life: 1.1 + Math.random() * 0.9,
        });
      }
    };

    const spawnWave = (position: THREE.Vector3, color: number, size = 1) => {
      const wave = new THREE.Mesh(
        new THREE.RingGeometry(0.38, 0.57, 42),
        new THREE.MeshBasicMaterial({
          color,
          transparent: true,
          opacity: 0.85,
          side: THREE.DoubleSide,
        }),
      );
      wave.rotation.x = -Math.PI / 2;
      wave.position.copy(position);
      wave.position.y = 0.08;
      wave.scale.setScalar(size);
      scene.add(wave);
      effects.push({ mesh: wave, life: 0.46, maxLife: 0.46 });
    };

    const addTimedVisual = (object: THREE.Object3D, life: number, spin = 1.8) => {
      scene.add(object);
      timedVisuals.push({ object, life, maxLife: life, spin });
    };

    const makeMegaMugProjectile = () => {
      const group = new THREE.Group();
      const amber = new THREE.MeshStandardMaterial({
        color: 0xffa20d,
        emissive: 0xff5a00,
        emissiveIntensity: 1.25,
        metalness: 0.2,
        roughness: 0.18,
        transparent: true,
        opacity: 0.92,
      });
      const white = new THREE.MeshBasicMaterial({ color: 0xfffbd0 });
      const mug = new THREE.Mesh(new THREE.CylinderGeometry(0.36, 0.32, 0.76, 16), amber);
      mug.position.y = 0.42;
      const handle = new THREE.Mesh(new THREE.TorusGeometry(0.27, 0.075, 8, 18, Math.PI * 1.55), amber.clone());
      handle.position.set(0.38, 0.46, 0);
      handle.rotation.z = Math.PI / 2;
      for (let index = 0; index < 5; index += 1) {
        const foam = new THREE.Mesh(new THREE.SphereGeometry(0.16, 10, 8), white.clone());
        const angle = index / 5 * Math.PI * 2;
        foam.position.set(Math.cos(angle) * 0.2, 0.82, Math.sin(angle) * 0.2);
        group.add(foam);
      }
      const aura = new THREE.Mesh(
        new THREE.TorusGeometry(0.65, 0.08, 10, 28),
        new THREE.MeshBasicMaterial({
          color: 0xffee65,
          transparent: true,
          opacity: 0.78,
        }),
      );
      aura.rotation.x = Math.PI / 2;
      aura.position.y = 0.42;
      aura.name = "MegaMugAura";
      group.add(mug, handle, aura);
      const light = new THREE.PointLight(0xffa51f, 5.5, 9);
      light.position.y = 0.5;
      group.add(light);
      group.scale.setScalar(1.35);
      return group;
    };

    const makeMegaLane = (
      origin: THREE.Vector3,
      direction: THREE.Vector3,
      distance: number,
      width: number,
    ) => {
      const group = new THREE.Group();
      const glow = new THREE.Mesh(
        new THREE.BoxGeometry(width, 0.035, distance),
        new THREE.MeshBasicMaterial({
          color: 0xffa30d,
          transparent: true,
          opacity: 0.34,
          depthWrite: false,
        }),
      );
      glow.position.z = distance / 2;
      const core = new THREE.Mesh(
        new THREE.BoxGeometry(0.28, 0.055, distance),
        new THREE.MeshBasicMaterial({
          color: 0xffffff,
          transparent: true,
          opacity: 0.92,
          depthWrite: false,
        }),
      );
      core.position.set(0, 0.02, distance / 2);
      group.add(glow, core);
      group.position.copy(origin).setY(0.07);
      group.rotation.y = Math.atan2(direction.x, direction.z);
      scene.add(group);
      return group;
    };

    const spawnMegaTrail = (position: THREE.Vector3) => {
      const group = new THREE.Group();
      for (let index = 0; index < 5; index += 1) {
        const bubble = new THREE.Mesh(
          new THREE.SphereGeometry(0.08 + Math.random() * 0.13, 8, 6),
          new THREE.MeshBasicMaterial({
            color: index % 2 === 0 ? 0xffffff : 0xffc21d,
            transparent: true,
            opacity: 0.82,
          }),
        );
        bubble.position.copy(position).add(new THREE.Vector3(
          (Math.random() - 0.5) * 0.75,
          (Math.random() - 0.5) * 0.55,
          (Math.random() - 0.5) * 0.75,
        ));
        group.add(bubble);
      }
      addTimedVisual(group, 0.38);
    };

    const makeDangerZone = (position: THREE.Vector3, radius: number, color: number) => {
      const group = new THREE.Group();
      const fill = new THREE.Mesh(
        new THREE.CircleGeometry(radius, 48),
        new THREE.MeshBasicMaterial({
          color,
          transparent: true,
          opacity: 0.18,
          depthWrite: false,
          side: THREE.DoubleSide,
        }),
      );
      fill.rotation.x = -Math.PI / 2;
      const ring = new THREE.Mesh(
        new THREE.RingGeometry(radius * 0.86, radius, 48),
        new THREE.MeshBasicMaterial({
          color,
          transparent: true,
          opacity: 0.92,
          depthWrite: false,
          side: THREE.DoubleSide,
        }),
      );
      ring.rotation.x = -Math.PI / 2;
      ring.position.y = 0.015;
      group.add(fill, ring);
      group.position.copy(position);
      group.position.y = 0.055;
      group.userData.fill = fill;
      group.userData.ring = ring;
      scene.add(group);
      return group;
    };

    const makeBeamZone = (
      position: THREE.Vector3,
      direction: THREE.Vector3,
      length: number,
      width: number,
      color: number,
    ) => {
      const group = new THREE.Group();
      const fill = roundedBox(width, 0.035, length, color);
      const material = fill.material as THREE.MeshStandardMaterial;
      material.transparent = true;
      material.opacity = 0.2;
      material.depthWrite = false;
      fill.position.z = length / 2;
      const edgeMaterial = new THREE.MeshBasicMaterial({
        color,
        transparent: true,
        opacity: 0.95,
        depthWrite: false,
      });
      const leftEdge = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.045, length), edgeMaterial);
      const rightEdge = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.045, length), edgeMaterial.clone());
      leftEdge.position.set(-width / 2, 0.02, length / 2);
      rightEdge.position.set(width / 2, 0.02, length / 2);
      group.add(fill, leftEdge, rightEdge);
      group.position.copy(position).setY(0.055);
      group.rotation.y = Math.atan2(direction.x, direction.z);
      group.userData.fill = fill;
      group.userData.edges = [leftEdge, rightEdge];
      group.userData.beam = true;
      scene.add(group);
      return group;
    };

    const animateDangerZone = (
      warning: THREE.Group,
      startedAt: number,
      triggerAt: number,
      elapsed: number,
    ) => {
      const progress = THREE.MathUtils.clamp(
        (elapsed - startedAt) / Math.max(0.01, triggerAt - startedAt),
        0,
        1,
      );
      const pulse = 0.72 + Math.sin(elapsed * (12 + progress * 18)) * 0.18;
      if (!warning.userData.beam) warning.scale.setScalar(0.92 + progress * 0.08);
      const fill = warning.userData.fill as THREE.Mesh | undefined;
      const ring = warning.userData.ring as THREE.Mesh | undefined;
      const edges = warning.userData.edges as THREE.Mesh[] | undefined;
      if (fill) {
        const material = fill.material as THREE.MeshBasicMaterial | THREE.MeshStandardMaterial;
        material.opacity = 0.12 + progress * 0.24;
      }
      if (ring) (ring.material as THREE.MeshBasicMaterial).opacity = pulse;
      edges?.forEach((edge) => {
        (edge.material as THREE.MeshBasicMaterial).opacity = pulse;
      });
    };

    const addHazard = (
      position: THREE.Vector3,
      radius: number,
      damage: number,
      delay: number,
      color: number,
    ) => {
      const warning = makeDangerZone(position, radius, color);
      hazards.push({
        shape: "circle",
        warning,
        position: position.clone().setY(0),
        radius,
        direction: new THREE.Vector3(),
        length: 0,
        width: 0,
        damage,
        startedAt: runtime.elapsed,
        triggerAt: runtime.elapsed + delay,
        color,
      });
    };

    const addBeamHazard = (
      position: THREE.Vector3,
      direction: THREE.Vector3,
      length: number,
      width: number,
      damage: number,
      delay: number,
      color: number,
    ) => {
      const normalized = direction.clone().setY(0).normalize();
      const warning = makeBeamZone(position, normalized, length, width, color);
      hazards.push({
        shape: "beam",
        warning,
        position: position.clone().setY(0),
        radius: 0,
        direction: normalized,
        length,
        width,
        damage,
        startedAt: runtime.elapsed,
        triggerAt: runtime.elapsed + delay,
        color,
      });
    };

    const addPickup = (kind: PickupKind, position: THREE.Vector3) => {
      const group = makePickup(kind);
      group.position.copy(position);
      group.position.y = 0.75;
      scene.add(group);
      pickups.push({ group, kind, baseY: 0.75, active: true });
    };

    const spawnEnemy = (
      kind: EquipmentEnemyKind,
      x: number,
      z: number,
      options: {
        elite?: boolean;
        boss?: boolean;
        stationary?: boolean;
        scale?: number;
        hp?: number;
        label?: string;
      } = {},
    ) => {
      const floorDefinition = FLOORS[runtime.floor - 1];
      const overtime = OVERTIME_RANKS[runtime.overtimeRank];
      const elite = options.elite ?? false;
      const boss = options.boss ?? false;
      const affixes: EliteAffix[] = ["rapid", "barrier", "volatile", "regenerator"];
      const affix = elite && !boss
        ? affixes[Math.floor(Math.random() * affixes.length)]
        : null;
      const affixLabel = {
        rapid: "快速",
        barrier: "装甲",
        volatile: "余熱",
        regenerator: "再生",
      } as const;
      const affixColor = {
        rapid: 0xffa51f,
        barrier: 0x45d8ff,
        volatile: 0xff4d3a,
        regenerator: 0x56e07a,
      } as const;
      const group = makeEnemyModel(kind, elite || boss);
      const scale = options.scale ?? (elite ? 1.18 : 1);
      group.scale.setScalar(scale);
      group.position.set(x, 0, z);
      group.rotation.y = Math.random() * Math.PI * 2;
      const baseHp = options.hp ?? (2.1 + runtime.floor * 0.75) * (elite ? 1.85 : 1);
      const stats = {
        chair: { speed: 2.4, damage: 7, radius: 0.62, points: 190, color: 0x2c92da, label: "回転アーロンチュア" },
        stapler: { speed: 3.05, damage: 6, radius: 0.52, points: 170, color: 0xf06a31, label: "ホチキスガニ" },
        cabinet: { speed: 1.25, damage: 11, radius: 0.72, points: 260, color: 0x7b8b95, label: "キャビネットゴーレム" },
        desk: { speed: 1.65, damage: 9, radius: 0.95, points: 230, color: 0xb97943, label: "会議机ムカデ" },
        copier: { speed: boss ? 0.9 : 1.45, damage: boss ? 12 : 10, radius: boss ? 1.45 : 0.82, points: boss ? 6500 : 330, color: boss ? 0xf6b80c : 0xd9e1e5, label: boss ? "金の複合機・零式" : "複合機タンク" },
        gate: { speed: 1.1, damage: 14, radius: 1.15, points: 560, color: 0x425864, label: "強化ゲートΩ" },
        core: { speed: 0.92, damage: 22, radius: 1.65, points: 15000, color: 0xff4437, label: "REGULATION CORE" },
      }[kind];
      const baseFinalHp = (boss ? (kind === "core" ? 125 : 50) : baseHp) * overtime.hpMultiplier;
      const barrier = affix === "barrier" ? baseFinalHp * 0.5 : 0;
      const hp = baseFinalHp + barrier;
      const health = makeHealthBar(boss ? 3.2 : elite ? 1.65 : 1.1, boss ? floorDefinition.accent : 0x56e07a);
      health.position.y = kind === "core" ? 3.4 : boss ? 3.25 : kind === "cabinet" || kind === "gate" ? 2.25 : 1.85;
      health.rotation.x = -0.35;
      group.add(health);
      if (affix) {
        const aura = new THREE.Mesh(
          new THREE.TorusGeometry(stats.radius * 1.25, 0.075, 8, 28),
          new THREE.MeshBasicMaterial({
            color: affixColor[affix],
            transparent: true,
            opacity: 0.86,
          }),
        );
        aura.rotation.x = Math.PI / 2;
        aura.position.y = 0.12;
        group.add(aura);
      }
      scene.add(group);
      enemies.push({
        group,
        kind,
        label: `${affix ? `【${affixLabel[affix]}】` : ""}${options.label ?? stats.label}`,
        hp,
        maxHp: hp,
        speed: options.stationary
          ? 0
          : stats.speed * (1 + runtime.floor * 0.025) * overtime.speedMultiplier * (affix === "rapid" ? 1.38 : 1),
        damage: options.stationary
          ? 0
          : (stats.damage + runtime.floor * 0.9) * overtime.damageMultiplier,
        radius: stats.radius * scale,
        points: Math.round(stats.points * (elite ? 1.6 : 1)),
        color: stats.color,
        alive: true,
        boss,
        characterBoss: null,
        elite,
        affix,
        barrier,
        lastRegen: runtime.elapsed,
        frozenUntil: 0,
        nextAttack: runtime.elapsed + 0.9 + Math.random() * 0.65,
        pulseAt: runtime.elapsed + (kind === "core" ? 3.1 : 3.8),
        attackKind: null,
        attackStartedAt: 0,
        attackAt: 0,
        attackOrigin: new THREE.Vector3(),
        attackRadius: 0,
        attackWarning: null,
        vulnerableFrom: 0,
        vulnerableUntil: 0,
        phase: 1,
        healthFill: health.userData.fill as THREE.Mesh,
      });
    };

    const makeBossFallback = (color: number) => {
      const fallback = new THREE.Group();
      const body = roundedBox(1.35, 2.1, 0.9, color);
      body.position.y = 1.2;
      const head = roundedBox(1.2, 1.2, 1.05, 0xffc99e);
      head.position.y = 2.7;
      fallback.add(body, head);
      return fallback;
    };

    const spawnCharacterBoss = (id: CharacterBossId, x: number, z: number) => {
      const definition = WINDOW_BOSSES[id];
      const overtime = OVERTIME_RANKS[runtime.overtimeRank];
      const group = new THREE.Group();
      group.position.set(x, 0, z);
      group.rotation.y = Math.PI;

      const health = makeHealthBar(3.5, definition.color);
      health.position.y = definition.healthY;
      health.rotation.x = -0.35;
      group.add(health);

      loadVoxelCharacter({
        definition: definition.model,
        parent: group,
        onReady: ({ mixer, actions }) => {
          group.userData.mixer = mixer;
          group.userData.animator = actions;
        },
        onError: () => {
          group.add(makeBossFallback(definition.color));
        },
      });

      scene.add(group);
      const hp = definition.hp * overtime.hpMultiplier;
      enemies.push({
        group,
        kind: "character",
        label: `${definition.title}｜${definition.displayName}`,
        hp,
        maxHp: hp,
        speed: definition.speed * overtime.speedMultiplier,
        damage: definition.damage * overtime.damageMultiplier,
        radius: definition.radius,
        points: definition.points,
        color: definition.color,
        alive: true,
        boss: true,
        characterBoss: id,
        elite: true,
        affix: null,
        barrier: 0,
        lastRegen: runtime.elapsed,
        frozenUntil: 0,
        nextAttack: runtime.elapsed + 1.8,
        pulseAt: runtime.elapsed + (id === "okayaman" ? 2.6 : 3.1),
        attackKind: null,
        attackStartedAt: 0,
        attackAt: 0,
        attackOrigin: new THREE.Vector3(),
        attackRadius: 0,
        attackWarning: null,
        vulnerableFrom: 0,
        vulnerableUntil: 0,
        phase: 1,
        healthFill: health.userData.fill as THREE.Mesh,
      });
      group.userData.healthBar = health;
    };

    const randomSpawnPoints = (compact = false) => {
      const points: Array<[number, number]> = [];
      const zPositions = compact ? [-6.8, -4, -1.2, 1.6, 4.4] : [-11.7, -8.6, -5.3, -2.1, 1.2, 4.4];
      const xPositions = compact ? [-7, -4.2, -1.4, 1.4, 4.2, 7] : [-7.8, -4, 0, 4, 7.8];
      for (const z of zPositions) {
        for (const x of xPositions) {
          if (z > 2 && Math.abs(x) < 2) continue;
          const jitter = compact ? 0.3 : 0.9;
          points.push([x + (Math.random() - 0.5) * jitter, z + (Math.random() - 0.5) * jitter]);
        }
      }
      return points.sort(() => Math.random() - 0.5);
    };

    const addDecorations = (accent: number, darkFloor: boolean) => {
      const railMaterial = new THREE.MeshStandardMaterial({
        color: accent,
        emissive: accent,
        emissiveIntensity: darkFloor ? 0.65 : 0.18,
        roughness: 0.45,
      });
      for (const x of [-9.9, 9.9]) {
        const rail = new THREE.Mesh(new THREE.BoxGeometry(0.15, 0.12, 26), railMaterial);
        rail.position.set(x, 0.08, -1.2);
        stageAdd(rail);
      }
      for (const z of [-12.8, -6.4, 0, 6.4]) {
        const marker = roundedBox(1.5, 0.035, 0.2, accent);
        marker.position.set(0, 0.04, z);
        stageAdd(marker);
      }
      for (let i = 0; i < 8; i += 1) {
        const box = roundedBox(
          0.75 + Math.random() * 0.6,
          0.55 + Math.random() * 0.7,
          0.75,
          i % 3 === 0 ? accent : 0x87949b,
        );
        box.position.set(i % 2 ? -9.6 : 9.5, box.geometry.parameters.height / 2, -11.5 + i * 3.1);
        stageAdd(box);
      }
    };

    const syncHud = () => {
      const floorDefinition = FLOORS[runtime.floor - 1];
      const alive = enemies.filter((enemy) => enemy.alive).length;
      const boss = enemies.find((enemy) => enemy.alive && enemy.boss);
      const dashCooldown = Math.max(0.85, 2.15 / (1 + upgradeValues.runner * 0.16));
      const dashProgress = THREE.MathUtils.clamp((runtime.elapsed - runtime.lastDash) / dashCooldown, 0, 1);
      const overtime = OVERTIME_RANKS[runtime.overtimeRank];
      const rushRemaining = Math.max(0, runtime.rushUntil - runtime.elapsed);
      const offscreenEnemies = enemies.filter((enemy) => {
        if (!enemy.alive || enemy.boss) return false;
        const projected = enemy.group.position.clone().add(new THREE.Vector3(0, 0.8, 0)).project(camera);
        return projected.x < -0.92 || projected.x > 0.92 || projected.y < -0.88 || projected.y > 0.88;
      }).length;
      setHud({
        floor: runtime.floor,
        floorName: floorDefinition.name,
        kicker: floorDefinition.kicker,
        objective: floorDefinition.objective,
        hp: Math.ceil(runtime.hp),
        maxHp: Math.ceil(runtime.maxHp),
        score: Math.round(runtime.score),
        combo: runtime.combo,
        multiplier: getComboMultiplier(runtime.combo),
        enemies: alive,
        totalEnemies: runtime.floorTotal,
        mega: runtime.mega,
        caps: runtime.runCaps,
        timer: runtime.timer === null ? null : Math.max(0, Math.ceil(runtime.timer)),
        dashReady: dashProgress,
        bossName: boss
          ? `${boss.label}${boss.phase === 2 ? "｜ENCORE PHASE" : ""}${
            runtime.elapsed >= boss.vulnerableFrom && runtime.elapsed < boss.vulnerableUntil
              ? "｜反動中：ジョッキレール好機"
              : ""
          }`
          : "",
        pressure: rushRemaining > 0 ? 100 : runtime.pressure,
        rushRemaining,
        overtimeLabel: overtime.label,
        scoreMultiplier: overtime.scoreMultiplier * (rushRemaining > 0 ? 1.5 : 1),
        offscreenEnemies,
        incomingAttack: hazards.length > 0 || enemies.some((enemy) => enemy.alive && enemy.attackKind !== null),
      });
    };

    const setupFloor = () => {
      clearStage();
      setMegaFlash(false);
      const floorDefinition = FLOORS[runtime.floor - 1];
      const overtime = OVERTIME_RANKS[runtime.overtimeRank];
      floorMaterial.color.setHex(floorDefinition.tint);
      accentLight.color.setHex(floorDefinition.accent);
      const darkFloor = runtime.floor === 4 || runtime.floor === 6 || runtime.floor === 8;
      scene.background = new THREE.Color(darkFloor ? 0x7790a0 : 0xb9e7fb);
      scene.fog = new THREE.Fog(darkFloor ? 0x7790a0 : 0xb9e7fb, 27, 48);
      renderer.setClearColor(darkFloor ? 0x7790a0 : 0xb9e7fb, 1);
      const sign = makeFloorSign(floorDefinition.name, floorDefinition.kicker, floorDefinition.accent);
      stageAdd(sign);
      addDecorations(floorDefinition.accent, darkFloor);

      player.position.set(0, 0, 9.7);
      player.rotation.y = 0;
      runtime.floorKilled = 0;
      runtime.timer = floorDefinition.kind === "challenge" ? 45 : null;
      runtime.combo = 0;
      runtime.comboWindow = 0;
      runtime.pendingSmash = null;
      runtime.pendingMega = null;
      runtime.megaLockUntil = 0;
      runtime.lastBossDefeat = "";
      runtime.pendingFloorClear = false;
      runtime.mega = Math.min(3, runtime.mega + Math.max(0, Math.floor(upgradeValues.happy)));
      runtime.playing = true;
      runtime.paused = false;
      runtime.lastBump = -10;

      const points = randomSpawnPoints(floorDefinition.kind === "challenge");
      if (floorDefinition.kind === "boss") {
        spawnCharacterBoss(runtime.guestBoss, 0, -7.2);
      } else if (floorDefinition.kind === "final") {
        spawnCharacterBoss("okayaman", 0, -7.4);
      } else {
        const kinds: EquipmentEnemyKind[] = floorDefinition.kind === "challenge"
          ? ["chair", "desk", "cabinet", "copier"]
          : runtime.floor === 6
            ? ["cabinet", "gate", "cabinet", "stapler"]
            : runtime.floor >= 5
              ? ["stapler", "cabinet", "desk", "copier", "chair"]
              : ["chair", "stapler", "desk", "cabinet"];
        for (let i = 0; i < floorDefinition.enemyCount; i += 1) {
          const [x, z] = points[i % points.length];
          spawnEnemy(kinds[i % kinds.length], x, z, {
            elite: floorDefinition.kind === "elite"
              || (runtime.floor >= 5 && i % 6 === 0)
              || (runtime.overtimeRank > 0 && i < overtime.eliteBonus),
            stationary: floorDefinition.kind === "challenge",
            hp: floorDefinition.kind === "challenge" ? 1 : undefined,
            scale: floorDefinition.kind === "challenge" ? 0.92 : undefined,
          });
        }
      }
      runtime.floorTotal = enemies.length;
      setPaused(false);
      setStatus("playing");
      syncHud();
      playSound("start");
      if (floorDefinition.kind === "boss") {
        notify(WINDOW_BOSSES[runtime.guestBoss].introLine);
      } else if (floorDefinition.kind === "final") {
        notify(WINDOW_BOSSES.okayaman.introLine);
      } else {
        notify(`${floorDefinition.floor}F「${floorDefinition.name}」— ${overtime.label}`);
      }
    };

    const makeSummary = (victory: boolean): RunSummary => ({
      victory,
      floorReached: runtime.floor,
      score: Math.round(runtime.score),
      destroyed: runtime.destroyed,
      maxCombo: runtime.maxCombo,
      capsEarned: runtime.runCaps,
      upgrades: runtime.selected.map((item) => `${item.rarity}｜${item.name}`),
      overtimeRank: runtime.overtimeRank,
      buildName: runtime.synergies.map((synergy) => synergy.name).join(" × ") || "単品ジョッキ",
    });

    const endRun = (victory: boolean) => {
      if (runtime.submitted) return;
      runtime.playing = false;
      runtime.submitted = true;
      if (victory) {
        runtime.runCaps += Math.round(30 * OVERTIME_RANKS[runtime.overtimeRank].capsMultiplier);
      }
      const result = makeSummary(victory);
      setSummary(result);
      setStatus(victory ? "victory" : "gameover");
      setPaused(false);
      playSound(victory ? "clear" : "hurt");
      submitRunRef.current(result);
    };

    const finishFloor = () => {
      if (!runtime.playing) return;
      runtime.playing = false;
      const overtime = OVERTIME_RANKS[runtime.overtimeRank];
      const floorBonus = Math.round((800 + runtime.floor * 320) * overtime.scoreMultiplier);
      runtime.score += floorBonus;
      runtime.runCaps += Math.round((3 + Math.floor(runtime.floor / 2)) * overtime.capsMultiplier);
      if (runtime.floor >= MAX_FLOOR) {
        if (runtime.lastBossDefeat) notify(runtime.lastBossDefeat);
        endRun(true);
        return;
      }
      const choices = makeRewardChoices(runtime.floor, runtime.overtimeRank);
      setRewardChoices(choices);
      setRerolls(runtime.rerolls);
      syncHud();
      setStatus("reward");
      playSound("clear");
      if (choices.some((choice) => choice.greater)) {
        playSound("beer");
        notify("★ 金星特性を発見！ 違いの分かる一杯です");
      } else {
        notify(runtime.lastBossDefeat || `FLOOR CLEAR +${formatNumber(floorBonus)}`);
      }
    };

    const updateEnemyHealth = (enemy: Enemy) => {
      if (!enemy.healthFill) return;
      const ratio = THREE.MathUtils.clamp(enemy.hp / enemy.maxHp, 0, 1);
      enemy.healthFill.scale.x = ratio;
      (enemy.healthFill.material as THREE.MeshStandardMaterial).color.setHex(
        enemy.barrier > 0 ? 0x45d8ff : healthColor(ratio),
      );
    };

    const makeDizzyBoss = (enemy: Enemy) => {
      const definition = enemy.characterBoss ? WINDOW_BOSSES[enemy.characterBoss] : null;
      const stars = new THREE.Group();
      stars.position.y = Math.max(2.25, (definition?.healthY ?? 3.5) - 0.65);
      for (let index = 0; index < 5; index += 1) {
        const star = new THREE.Mesh(
          new THREE.OctahedronGeometry(0.16, 0),
          new THREE.MeshStandardMaterial({
            color: index % 2 === 0 ? 0xffdf3d : 0xffffff,
            emissive: 0x6b4200,
            emissiveIntensity: 0.45,
            roughness: 0.38,
          }),
        );
        const angle = index / 5 * Math.PI * 2;
        star.position.set(Math.cos(angle) * 0.95, Math.sin(angle * 2) * 0.12, Math.sin(angle) * 0.95);
        stars.add(star);
      }
      enemy.group.add(stars);
      (enemy.group.userData.healthBar as THREE.Group | undefined)?.removeFromParent();
      enemy.group.rotation.z = 0.16;
      dizzyBosses.push({ group: enemy.group, stars, startedAt: runtime.elapsed });
    };

    const completeEnemyWave = () => {
      runtime.pendingFloorClear = false;
      const floorDefinition = FLOORS[runtime.floor - 1];
      if (floorDefinition.kind === "challenge" && (runtime.timer ?? 0) > 0) {
        const points = randomSpawnPoints();
        const kinds: EquipmentEnemyKind[] = ["chair", "desk", "cabinet", "copier"];
        const waveSize = runtime.floor === 7 ? 18 : 14;
        for (let index = 0; index < waveSize; index += 1) {
          const [x, z] = points[index];
          spawnEnemy(kinds[index % kinds.length], x, z, {
            stationary: true,
            hp: 1,
            scale: 0.92,
          });
        }
        runtime.floorTotal += waveSize;
        notify("BONUS WAVE! まだまだ快適です！");
      } else {
        finishFloor();
      }
    };

    const destroyEnemy = (enemy: Enemy, critical: boolean, chainDepth = 0) => {
      if (!enemy.alive) return;
      enemy.alive = false;
      if (enemy.attackWarning) {
        removeDisposableObject(enemy.attackWarning);
        enemy.attackWarning = null;
      }
      const peacefulBoss = enemy.characterBoss !== null;
      if (peacefulBoss) {
        for (const hazard of hazards) removeDisposableObject(hazard.warning);
        hazards.length = 0;
        makeDizzyBoss(enemy);
        runtime.lastBossDefeat = WINDOW_BOSSES[enemy.characterBoss!].defeatLine;
      } else {
        scene.remove(enemy.group);
      }
      runtime.destroyed += 1;
      runtime.floorKilled += 1;
      runtime.combo += 1;
      runtime.maxCombo = Math.max(runtime.maxCombo, runtime.combo);
      runtime.comboWindow = 2.1 + upgradeValues.combo * 0.7;
      const multiplier = getComboMultiplier(runtime.combo);
      const overtime = OVERTIME_RANKS[runtime.overtimeRank];
      const rushActive = runtime.elapsed < runtime.rushUntil;
      runtime.score += Math.round(
        enemy.points
        * multiplier
        * (critical ? 1.25 : 1)
        * overtime.scoreMultiplier
        * (rushActive ? 1.5 : 1),
      );
      const pressureScale = runtime.synergies.some((synergy) => synergy.name === "宴会ランナー") ? 1.5 : 1;
      runtime.pressure = Math.min(
        100,
        runtime.pressure + (enemy.boss ? 35 : enemy.elite ? 18 : 8 + Math.min(8, runtime.combo * 0.18)) * pressureScale,
      );
      if (runtime.pressure >= 100 && !rushActive) {
        runtime.rushUntil = runtime.elapsed + 8;
        runtime.pressure = 100;
        runtime.mega = Math.min(3, runtime.mega + 1);
        playSound("beer");
        notify("清掃熱 MAX！ 8秒間 RUSH TIME ×1.5");
      }
      runtime.shake = Math.max(runtime.shake, enemy.boss ? 0.55 : 0.22);
      if (peacefulBoss) {
        spawnWave(enemy.group.position, enemy.color, 1.8);
        tone(520, 0.16, "triangle", 0.05, 760);
        tone(760, 0.22, "sine", 0.045, 980, 0.16);
      } else {
        spawnDebris(enemy.group.position, enemy.color, enemy.boss ? 42 : 13);
        playSound(enemy.boss ? "metal" : "break");
        if (runtime.floor >= 5) {
          spawnWave(enemy.group.position, enemy.elite ? 0xffd23f : enemy.color, enemy.elite ? 1.25 : 0.72);
          if (enemy.elite) {
            spawnWave(enemy.group.position, 0xffffff, 0.82);
            tone(310, 0.11, "square", 0.028, 620);
          }
        }
      }
      navigator.vibrate?.(enemy.boss ? 45 : 15);

      if (enemy.affix === "volatile") {
        addHazard(enemy.group.position, 3.2, enemy.damage * 0.62, 0.9, 0xff4d3a);
        notify("余熱注意！ 赤い範囲から離れてください");
      }

      if (upgradeValues.yakitori > 0) {
        runtime.hp = Math.min(runtime.maxHp, runtime.hp + Math.max(1, Math.round(upgradeValues.yakitori * 2)));
      }
      if (!enemy.boss) {
        const roll = Math.random();
        if (roll < 0.12) addPickup("beer", enemy.group.position);
        else if (roll < 0.2) addPickup("clock", enemy.group.position);
        else if (roll < 0.36) addPickup("cap", enemy.group.position);
        else if (roll < 0.43) addPickup("yakitori", enemy.group.position);
      } else {
        addPickup("beer", enemy.group.position.clone().add(new THREE.Vector3(-1.2, 0, 0)));
        addPickup("cap", enemy.group.position.clone().add(new THREE.Vector3(1.2, 0, 0)));
      }

      if (upgradeValues.foam > 0 && chainDepth === 0) {
        const explosiveFoam = runtime.synergies.some((synergy) => synergy.name === "爆泡ジョッキ");
        const splashDamage = (2 * (1 + runtime.profile.mastery.forge * 0.08 + upgradeValues.heavy * 0.28))
          * upgradeValues.foam * 0.45 * (explosiveFoam ? 1.35 : 1);
        spawnWave(enemy.group.position, 0xfff0a1, explosiveFoam ? 1.15 : 0.8);
        for (const other of enemies) {
          if (!other.alive || other === enemy) continue;
          if (other.group.position.distanceTo(enemy.group.position) < (explosiveFoam ? 4.1 : 2.6)) {
            other.hp -= splashDamage;
            updateEnemyHealth(other);
            if (other.hp <= 0) destroyEnemy(other, false, chainDepth + 1);
          }
        }
      }

      syncHud();
      if (enemies.every((candidate) => !candidate.alive)) {
        if (megaProjectiles.length > 0) {
          runtime.pendingFloorClear = true;
        } else {
          completeEnemyWave();
        }
      }
    };

    const damageEnemy = (enemy: Enemy, amount: number, critical: boolean, center: THREE.Vector3) => {
      if (!enemy.alive) return;
      const chilledVulnerable = runtime.elapsed < enemy.frozenUntil
        && runtime.synergies.some((synergy) => synergy.name === "キンキン速配");
      const bossOpening = enemy.boss
        && runtime.elapsed >= enemy.vulnerableFrom
        && runtime.elapsed < enemy.vulnerableUntil;
      const finalAmount = amount * (chilledVulnerable ? 1.5 : 1) * (bossOpening ? 1.65 : 1);
      enemy.hp -= finalAmount;
      enemy.barrier = Math.max(0, enemy.barrier - finalAmount);
      enemy.frozenUntil = Math.max(enemy.frozenUntil, runtime.elapsed + upgradeValues.frost * 0.45);
      if (
        enemy.characterBoss
        && enemy.phase === 1
        && enemy.hp > 0
        && enemy.hp / enemy.maxHp <= 0.5
      ) {
        enemy.phase = 2;
        for (const hazard of hazards) removeDisposableObject(hazard.warning);
        hazards.length = 0;
        enemy.pulseAt = Math.min(enemy.pulseAt, runtime.elapsed + 1.05);
        const aura = new THREE.Mesh(
          new THREE.TorusGeometry(enemy.radius * 1.65, 0.12, 10, 38),
          new THREE.MeshBasicMaterial({
            color: WINDOW_BOSSES[enemy.characterBoss].color,
            transparent: true,
            opacity: 0.88,
          }),
        );
        aura.rotation.x = Math.PI / 2;
        aura.position.y = 0.18;
        aura.userData.phaseAura = true;
        enemy.group.add(aura);
        enemy.group.userData.phaseAura = aura;
        spawnWave(enemy.group.position, 0xffffff, 2.25);
        spawnWave(enemy.group.position, WINDOW_BOSSES[enemy.characterBoss].color, 1.45);
        runtime.shake = Math.max(runtime.shake, 0.48);
        tone(220, 0.22, "square", 0.05, 440);
        tone(440, 0.3, "sawtooth", 0.045, 880, 0.16);
        notify(`ENCORE PHASE！ ${WINDOW_BOSSES[enemy.characterBoss].displayName}の攻撃が強化！`);
      }
      const away = enemy.group.position.clone().sub(center).setY(0);
      if (away.lengthSq() > 0.01 && !enemy.boss) {
        away.normalize().multiplyScalar(0.38 + upgradeValues.knockback * 0.4);
        enemy.group.position.add(away);
      }
      updateEnemyHealth(enemy);
      if (enemy.hp <= 0) {
        destroyEnemy(enemy, critical);
      } else if (enemy.characterBoss) {
        spawnWave(enemy.group.position, enemy.color, 0.62);
        tone(240, 0.07, "square", 0.025, 360);
      } else {
        spawnDebris(enemy.group.position.clone().add(new THREE.Vector3(0, 0.8, 0)), enemy.color, 4);
        playSound("metal");
      }
    };

    const getMegaTravelDistance = (origin: THREE.Vector3, direction: THREE.Vector3) => {
      const distances: number[] = [];
      if (direction.x > 0.001) distances.push((9.75 - origin.x) / direction.x);
      if (direction.x < -0.001) distances.push((-9.75 - origin.x) / direction.x);
      if (direction.z > 0.001) distances.push((11.55 - origin.z) / direction.z);
      if (direction.z < -0.001) distances.push((-13.35 - origin.z) / direction.z);
      const positive = distances.filter((distance) => distance > 0.2);
      return THREE.MathUtils.clamp(Math.min(...positive, 22), 0.8, 22);
    };

    const launchMegaMug = (
      origin: THREE.Vector3,
      direction: THREE.Vector3,
    ) => {
      const distance = getMegaTravelDistance(origin, direction);
      const rushActive = runtime.elapsed < runtime.rushUntil;
      const width = 2.3 * (1 + upgradeValues.wide * 0.13) * (rushActive ? 1.16 : 1);
      const baseDamage = 2 * (
        1
        + runtime.profile.mastery.forge * 0.08
        + upgradeValues.heavy * 0.28
      );
      const group = makeMegaMugProjectile();
      group.position.copy(origin).setY(0.82);
      scene.add(group);
      const lane = makeMegaLane(origin, direction, distance, width);
      megaProjectiles.push({
        group,
        lane,
        origin: origin.clone().setY(0),
        direction: direction.clone().setY(0).normalize(),
        distance,
        width,
        damage: baseDamage * 3.15 * (rushActive ? 1.18 : 1),
        startedAt: runtime.elapsed,
        duration: 0.4 + distance / 38,
        previousDistance: 0,
        lastTrailAt: runtime.elapsed,
        hitEnemies: new Set(),
      });
      noise(0.32, 0.12, 320);
      tone(190, 0.36, "sawtooth", 0.065, 980);
      tone(760, 0.18, "square", 0.04, 1320, 0.12);
      notify("必殺・生ジョッキレール！ 直線上をまとめて貫通！");
    };

    const spawnMegaImpact = (projectile: MegaProjectile) => {
      const impact = projectile.origin.clone().addScaledVector(projectile.direction, projectile.distance);
      const blastRadius = 3.5 * (1 + upgradeValues.wide * 0.12);
      const burst = new THREE.Group();
      burst.position.copy(impact);
      const pillar = new THREE.Mesh(
        new THREE.CylinderGeometry(0.48, 2.4, 7.2, 28, 1, true),
        new THREE.MeshBasicMaterial({
          color: 0xffe552,
          transparent: true,
          opacity: 0.8,
          side: THREE.DoubleSide,
          depthWrite: false,
        }),
      );
      pillar.position.y = 3.6;
      burst.add(pillar);
      for (let index = 0; index < 12; index += 1) {
        const ray = new THREE.Mesh(
          new THREE.BoxGeometry(0.16, 0.09, 5.2),
          new THREE.MeshBasicMaterial({
            color: index % 2 === 0 ? 0xffffff : 0xff9d0b,
            transparent: true,
            opacity: 0.86,
          }),
        );
        ray.position.y = 0.18;
        ray.rotation.y = index / 12 * Math.PI;
        burst.add(ray);
      }
      const flashLight = new THREE.PointLight(0xffd23f, 14, 20);
      flashLight.position.y = 2.2;
      burst.add(flashLight);
      addTimedVisual(burst, 0.58);
      spawnWave(impact, 0xffffff, 3.4);
      spawnWave(impact, 0xffc21d, 2.35);
      spawnWave(impact, 0xff6b16, 1.35);
      spawnDebris(impact.clone().setY(0.55), 0xffad17, 32);
      runtime.shake = Math.max(runtime.shake, 1.2);
      noise(0.5, 0.19, 75);
      tone(74, 0.46, "sawtooth", 0.095, 34);
      tone(392, 0.28, "square", 0.06, 784, 0.08);
      tone(784, 0.36, "triangle", 0.055, 1568, 0.2);
      navigator.vibrate?.([35, 35, 90]);
      setMegaFlash(true);
      if (megaFlashTimer.current) window.clearTimeout(megaFlashTimer.current);
      megaFlashTimer.current = window.setTimeout(() => setMegaFlash(false), 180);

      for (const enemy of [...enemies]) {
        if (!enemy.alive) continue;
        const distance = Math.max(0, enemy.group.position.distanceTo(impact) - enemy.radius);
        if (distance <= blastRadius) {
          projectile.hitEnemies.add(enemy);
          damageEnemy(enemy, projectile.damage * 0.82, distance <= 0.75, impact);
        }
      }

      const hits = projectile.hitEnemies.size;
      const bonus = Math.round(
        Math.max(1, hits)
        * 680
        * getComboMultiplier(runtime.combo)
        * OVERTIME_RANKS[runtime.overtimeRank].scoreMultiplier,
      );
      runtime.score += bonus;
      notify(`生ジョッキレール ×${hits}｜着弾大爆発 +${formatNumber(bonus)}`);
      playSound("beer");
      syncHud();
    };

    const updateMegaProjectiles = (dt: number) => {
      for (let index = megaProjectiles.length - 1; index >= 0; index -= 1) {
        const projectile = megaProjectiles[index];
        const progress = THREE.MathUtils.clamp(
          (runtime.elapsed - projectile.startedAt) / projectile.duration,
          0,
          1,
        );
        const eased = 1 - Math.pow(1 - progress, 2);
        const traveled = projectile.distance * eased;
        projectile.group.position
          .copy(projectile.origin)
          .addScaledVector(projectile.direction, traveled);
        projectile.group.position.y = 0.92 + Math.sin(progress * Math.PI) * 0.7;
        projectile.group.rotation.x += dt * 12;
        projectile.group.rotation.y += dt * 18;
        const aura = projectile.group.getObjectByName("MegaMugAura");
        if (aura) aura.rotation.z += dt * 9;

        if (runtime.elapsed - projectile.lastTrailAt >= 0.035) {
          projectile.lastTrailAt = runtime.elapsed;
          spawnMegaTrail(projectile.group.position);
        }

        if (runtime.playing) {
          for (const enemy of [...enemies]) {
            if (!enemy.alive || projectile.hitEnemies.has(enemy)) continue;
            const delta = enemy.group.position.clone().sub(projectile.origin).setY(0);
            const along = delta.dot(projectile.direction);
            const sideDistance = Math.abs(delta.dot(
              new THREE.Vector3(-projectile.direction.z, 0, projectile.direction.x),
            ));
            if (
              along >= projectile.previousDistance - enemy.radius
              && along <= traveled + enemy.radius
              && sideDistance <= projectile.width / 2 + enemy.radius
            ) {
              projectile.hitEnemies.add(enemy);
              const perfectLine = sideDistance <= 0.38;
              enemy.frozenUntil = Math.max(enemy.frozenUntil, runtime.elapsed + 0.16);
              spawnWave(enemy.group.position, perfectLine ? 0xffffff : 0xffc21d, perfectLine ? 1.25 : 0.9);
              runtime.shake = Math.max(runtime.shake, perfectLine ? 0.52 : 0.34);
              damageEnemy(
                enemy,
                projectile.damage * (perfectLine ? 1.48 : 1),
                perfectLine,
                projectile.origin,
              );
            }
          }
        }
        projectile.previousDistance = traveled;

        if (progress >= 1) {
          megaProjectiles.splice(index, 1);
          removeDisposableObject(projectile.group);
          timedVisuals.push({
            object: projectile.lane,
            life: 0.34,
            maxLife: 0.34,
            spin: 0,
          });
          spawnMegaImpact(projectile);
          if (runtime.pendingFloorClear && megaProjectiles.length === 0) completeEnemyWave();
        }
      }
    };

    const hurtPlayer = (amount: number, source: THREE.Vector3) => {
      if (!runtime.playing || runtime.elapsed < runtime.invulnerableUntil) return;
      runtime.invulnerableUntil = runtime.elapsed + 0.78;
      const fortified = runtime.hp / runtime.maxHp >= 0.8
        && runtime.synergies.some((synergy) => synergy.name === "立ち飲み不沈艦");
      const finalAmount = amount * (fortified ? 0.65 : 1);
      runtime.hp = Math.max(0, runtime.hp - finalAmount);
      runtime.combo = 0;
      runtime.comboWindow = 0;
      runtime.shake = Math.max(runtime.shake, 0.36);
      const away = player.position.clone().sub(source).setY(0);
      if (away.lengthSq() > 0.01) {
        away.normalize().multiplyScalar(0.75);
        player.position.add(away);
      }
      playSound("hurt");
      navigator.vibrate?.(35);
      notify(`HP -${Math.ceil(finalAmount)}${fortified ? "　不沈艦ガード！" : "　まだ快適です！"}`);
      syncHud();
      if (runtime.hp <= 0) endRun(false);
    };

    const launchCharacterSpecial = (enemy: Enemy) => {
      if (!enemy.characterBoss) return;
      const id = enemy.characterBoss;
      const definition = WINDOW_BOSSES[id];
      const origin = enemy.group.position.clone().setY(0);
      const target = player.position.clone().setY(0);
      const direction = target.clone().sub(origin).setY(0);
      if (direction.lengthSq() < 0.01) direction.set(0, 0, 1);
      direction.normalize();
      const side = new THREE.Vector3(-direction.z, 0, direction.x);
      const bossDamage = enemy.damage;
      const encore = enemy.phase === 2;
      let lastTriggerDelay = 1.45;

      (enemy.group.userData.animator as VoxelActionController | undefined)?.triggerSmash(true);

      if (id === "yotan") {
        [-2.9, 0, 2.9].forEach((offset, index) => {
          addHazard(
            target.clone().addScaledVector(side, offset),
            1.55,
            bossDamage * 0.58,
            1.2 + index * 0.16,
            definition.color,
          );
        });
        spawnWave(origin, definition.color, 1.4);
        tone(164, 0.42, "sawtooth", 0.05, 440);
        tone(246, 0.38, "square", 0.035, 659, 0.1);
        if (encore) {
          addHazard(target.clone().addScaledVector(direction, 3.4), 2.05, bossDamage * 0.64, 1.68, 0xffffff);
          addHazard(target.clone().addScaledVector(direction, -3.4), 2.05, bossDamage * 0.64, 1.68, 0xffd23f);
          lastTriggerDelay = 1.68;
        }
        if (!encore) lastTriggerDelay = 1.52;
      } else if (id === "tokun") {
        [-2.7, 0, 2.7].forEach((offset, index) => {
          addHazard(
            target.clone().addScaledVector(side, offset).addScaledVector(direction, (index - 1) * 1.3),
            1.45,
            bossDamage * 0.56,
            1.3 + index * 0.14,
            definition.color,
          );
        });
        spawnWave(origin, definition.color, 1.65);
        tone(392, 0.3, "triangle", 0.045, 523);
        tone(587, 0.34, "sine", 0.04, 784, 0.12);
        if (encore) {
          addHazard(target.clone().addScaledVector(direction, 3.5), 1.55, bossDamage * 0.58, 1.7, 0xffef83);
          addHazard(target.clone().addScaledVector(direction, -3.5), 1.55, bossDamage * 0.58, 1.7, 0xffef83);
          lastTriggerDelay = 1.7;
        } else {
          lastTriggerDelay = 1.58;
        }
      } else if (id === "fukuchan") {
        addHazard(target, 2.8, bossDamage * 0.62, 1.42, definition.color);
        addHazard(target.clone().addScaledVector(side, 4.2), 1.65, bossDamage * 0.46, 1.62, 0xffffff);
        addHazard(target.clone().addScaledVector(side, -4.2), 1.65, bossDamage * 0.46, 1.62, 0xffffff);
        tone(820, 0.12, "sine", 0.045, 1480);
        if (encore) {
          addHazard(target.clone().addScaledVector(direction, 4.1), 2, bossDamage * 0.58, 1.78, 0xffffff);
          addHazard(target.clone().addScaledVector(direction, -4.1), 2, bossDamage * 0.58, 1.78, definition.color);
          lastTriggerDelay = 1.78;
        } else {
          lastTriggerDelay = 1.62;
        }
      } else if (id === "yumemin") {
        addHazard(target, 2.45, bossDamage * 0.74, 1.5, definition.color);
        addHazard(
          target.clone().addScaledVector(direction, 3.6),
          1.65,
          bossDamage * 0.52,
          1.72,
          0xdff8ff,
        );
        tone(110, 0.18, "square", 0.04, 82);
        if (encore) {
          addHazard(target.clone().addScaledVector(side, 3.1), 1.75, bossDamage * 0.58, 1.88, 0xffffff);
          lastTriggerDelay = 1.88;
        } else {
          lastTriggerDelay = 1.72;
        }
      } else if (id === "takosan") {
        for (let index = 0; index < 6; index += 1) {
          if (index === 1) continue;
          const angle = index / 6 * Math.PI * 2;
          const position = target.clone().add(new THREE.Vector3(
            Math.cos(angle) * 3.25,
            0,
            Math.sin(angle) * 3.25,
          ));
          addHazard(position, 1.5, bossDamage * 0.54, 1.28 + index * 0.06, definition.color);
        }
        tone(145, 0.5, "triangle", 0.04, 92);
        if (encore) {
          addHazard(target, 1.65, bossDamage * 0.62, 1.74, 0xffffff);
          lastTriggerDelay = 1.74;
        } else {
          lastTriggerDelay = 1.58;
        }
      } else if (id === "yametaro") {
        addBeamHazard(origin, direction, 20, 2.3, bossDamage * 0.7, 1.35, definition.color);
        if (encore) {
          addBeamHazard(
            origin,
            direction.clone().applyAxisAngle(UP, -Math.PI * 0.24),
            20,
            1.7,
            bossDamage * 0.55,
            1.58,
            0xffd23f,
          );
        }
        tone(280, 0.3, "sawtooth", 0.045, 720);
        lastTriggerDelay = encore ? 1.58 : 1.35;
      } else {
        if (encore) {
          [-0.3, 0, 0.3].forEach((angle, index) => {
            addBeamHazard(
              origin,
              direction.clone().applyAxisAngle(UP, Math.PI * angle),
              22,
              index === 1 ? 2.35 : 1.45,
              bossDamage * (index === 1 ? 0.7 : 0.5),
              1.42 + index * 0.14,
              index === 1 ? definition.color : 0xff6b3d,
            );
          });
          lastTriggerDelay = 1.7;
        } else {
          addBeamHazard(origin, direction, 22, 2.15, bossDamage * 0.68, 1.45, definition.color);
          const crossingDirection = direction.clone().applyAxisAngle(UP, Math.PI * 0.34);
          addBeamHazard(origin, crossingDirection, 22, 1.55, bossDamage * 0.48, 1.72, 0xff6b3d);
          lastTriggerDelay = 1.72;
        }
        tone(96, 0.62, "sawtooth", 0.055, 420);
        tone(720, 0.2, "square", 0.035, 1180, 0.32);
      }

      enemy.vulnerableFrom = runtime.elapsed + lastTriggerDelay;
      enemy.vulnerableUntil = enemy.vulnerableFrom + 1.9;
      enemy.pulseAt = enemy.vulnerableUntil
        + (id === "okayaman" ? (encore ? 0.95 : 1.55) : encore ? 1.45 : 2.1);
      enemy.nextAttack = enemy.pulseAt + 0.35;
      notify(
        id === "yumemin" || id === "takosan"
          ? `${encore ? "ENCORE｜" : ""}${definition.displayName}｜${definition.specialName} — 床予告から退避！`
          : `${encore ? "ENCORE｜" : ""}${definition.displayName}「${definition.specialName}」— 床予告から退避！`,
      );
    };

    const beginEnemyAttack = (enemy: Enemy, kind: EnemyAttackKind) => {
      if (enemy.attackKind || !enemy.alive) return;
      const pulse = kind === "pulse";
      const windup = pulse ? (enemy.kind === "core" ? 1.35 : 1.2) : enemy.boss ? 0.9 : 0.62;
      const radius = pulse
        ? (enemy.kind === "core" ? 6 : 4.7)
        : enemy.radius + (enemy.boss ? 1.35 : 1.05);
      enemy.attackKind = kind;
      enemy.attackStartedAt = runtime.elapsed;
      enemy.attackAt = runtime.elapsed + windup;
      enemy.attackOrigin.copy(enemy.group.position).setY(0);
      enemy.attackRadius = radius;
      enemy.attackWarning = makeDangerZone(
        enemy.attackOrigin,
        radius,
        pulse ? (enemy.kind === "core" ? 0xff4437 : 0xffb51f) : 0xff4a32,
      );
      if (pulse) {
        tone(128, windup * 0.72, "sawtooth", 0.035, 228);
      }
    };

    const resolveEnemyAttack = (enemy: Enemy) => {
      if (!enemy.attackKind) return;
      const kind = enemy.attackKind;
      const hit = player.position.distanceTo(enemy.attackOrigin) <= enemy.attackRadius;
      const dodged = !hit || runtime.elapsed < runtime.invulnerableUntil;
      const color = kind === "pulse"
        ? (enemy.kind === "core" ? 0xff4437 : 0xffc21d)
        : 0xff5b38;
      spawnWave(enemy.attackOrigin, color, Math.max(0.8, enemy.attackRadius * 0.34));
      if (hit) {
        hurtPlayer(enemy.damage * (kind === "pulse" ? 0.62 : 1), enemy.attackOrigin);
      }
      if (enemy.attackWarning) {
        removeDisposableObject(enemy.attackWarning);
        enemy.attackWarning = null;
      }
      enemy.attackKind = null;
      enemy.nextAttack = runtime.elapsed + (enemy.boss ? 1.65 : 1.2);
      if (kind === "pulse") {
        enemy.pulseAt = runtime.elapsed + (enemy.kind === "core" ? 3.7 : 4.5);
      }
      if (enemy.boss) {
        enemy.vulnerableFrom = runtime.elapsed;
        enemy.vulnerableUntil = runtime.elapsed + 1.8;
        if (dodged) {
          notify("回避成功！ 反動中に生ジョッキレールを叩き込め！");
          tone(660, 0.12, "square", 0.045, 880);
        } else {
          notify("ボスが反動中！ 今ならダメージ ×1.65");
        }
      }
    };

    const performSmash = (center: THREE.Vector3) => {
      playSound("smash");
      const baseDamage = 2 * (1 + runtime.profile.mastery.forge * 0.08 + upgradeValues.heavy * 0.28);
      const damage = baseDamage;
      const radius = 1.65 * (1 + upgradeValues.wide * 0.16);
      const criticalMultiplier = runtime.synergies.some((synergy) => synergy.name === "店主の会心") ? 2.35 : 1.75;
      spawnWave(center, 0xffffff, 1);
      runtime.shake = Math.max(runtime.shake, 0.24);
      let hits = 0;
      let criticals = 0;
      for (const enemy of enemies) {
        if (!enemy.alive) continue;
        const distance = Math.max(0, enemy.group.position.distanceTo(center) - enemy.radius);
        if (distance <= radius) {
          hits += 1;
          const critical = distance <= 0.58 || Math.random() < upgradeValues.perfect * 0.1;
          if (critical) criticals += 1;
          damageEnemy(enemy, damage * (critical ? criticalMultiplier : 1), critical, center);
        }
      }
      if (hits > 1) {
        const bonus = Math.round(hits * hits * 45 * getComboMultiplier(runtime.combo));
        runtime.score += bonus;
        notify(`MULTI BREAK ×${hits} +${formatNumber(bonus)}`);
      } else if (criticals > 0) {
        notify(`PERFECT SMASH! ×${criticalMultiplier.toFixed(2)}`);
      } else if (hits === 0) {
        notify("SMASH!");
      }
      syncHud();
    };

    const smash = () => {
      if (!runtime.playing || runtime.paused) return;
      if (runtime.elapsed < runtime.megaLockUntil || runtime.pendingSmash || runtime.pendingMega) return;
      const rushActive = runtime.elapsed < runtime.rushUntil;
      const cooldown = Math.max(0.16, 0.46 * (1 - upgradeValues.haste * 0.09) * (rushActive ? 0.7 : 1));
      if (runtime.elapsed - runtime.lastSmash < cooldown) return;
      runtime.lastSmash = runtime.elapsed;
      const forward = new THREE.Vector3(0, 0, -1).applyAxisAngle(UP, player.rotation.y);
      const center = player.position.clone().addScaledVector(forward, 1.2);
      center.y = 0;
      (player.userData.animator as VoxelActionController | undefined)?.triggerSmash(false);
      tone(280, 0.1, "sawtooth", 0.045, 720);
      runtime.pendingSmash = { at: runtime.elapsed + 0.17, center };
      syncHud();
    };

    const megaSmash = () => {
      if (!runtime.playing || runtime.paused || runtime.mega <= 0) return;
      if (
        runtime.pendingSmash
        || runtime.pendingMega
        || megaProjectiles.length > 0
        || runtime.elapsed - runtime.lastMega < 0.9
      ) return;
      runtime.lastMega = runtime.elapsed;
      runtime.mega -= 1;
      runtime.megaLockUntil = runtime.elapsed + 0.72;
      runtime.invulnerableUntil = runtime.elapsed + 0.82;
      const forward = new THREE.Vector3(0, 0, -1).applyAxisAngle(UP, player.rotation.y);
      const origin = player.position.clone().addScaledVector(forward, 0.72).setY(0);
      (player.userData.animator as VoxelActionController | undefined)?.triggerSmash(true);
      spawnWave(player.position, 0xffffff, 1.55);
      spawnWave(player.position, 0xffc21d, 0.9);
      const charge = new THREE.Group();
      charge.position.copy(player.position);
      for (let index = 0; index < 3; index += 1) {
        const ring = new THREE.Mesh(
          new THREE.TorusGeometry(0.75 + index * 0.36, 0.055, 8, 30),
          new THREE.MeshBasicMaterial({
            color: index === 1 ? 0xffffff : 0xffc21d,
            transparent: true,
            opacity: 0.82,
          }),
        );
        ring.rotation.x = Math.PI / 2;
        ring.position.y = 0.4 + index * 0.38;
        charge.add(ring);
      }
      const chargeLight = new THREE.PointLight(0xffc21d, 8, 12);
      chargeLight.position.y = 1.5;
      charge.add(chargeLight);
      addTimedVisual(charge, 0.52);
      tone(110, 0.48, "sawtooth", 0.055, 880);
      tone(440, 0.28, "square", 0.04, 1320, 0.18);
      runtime.pendingMega = {
        at: runtime.elapsed + 0.48,
        origin,
        direction: forward,
      };
      notify("必殺技装填！ 向いている方向へジョッキを投げる！");
      syncHud();
    };

    const dash = () => {
      if (!runtime.playing || runtime.paused) return;
      if (runtime.elapsed < runtime.megaLockUntil) return;
      const cooldown = Math.max(0.85, 2.15 / (1 + upgradeValues.runner * 0.16));
      if (runtime.elapsed - runtime.lastDash < cooldown) return;
      runtime.lastDash = runtime.elapsed;
      runtime.invulnerableUntil = runtime.elapsed + 0.46;
      const forward = new THREE.Vector3(0, 0, -1).applyAxisAngle(UP, player.rotation.y);
      player.position.addScaledVector(forward, 3.15);
      player.position.x = THREE.MathUtils.clamp(player.position.x, -9.4, 9.4);
      player.position.z = THREE.MathUtils.clamp(player.position.z, -13.1, 11.3);
      spawnWave(player.position, 0x5de3ff, 0.7);
      tone(480, 0.11, "sine", 0.045, 960);
      syncHud();
    };

    const start = (profile: GameProfile, selectedOvertimeRank: OvertimeRank) => {
      void resumeAudio().catch(() => {
        notify("音声を開始できません。立ち飲み処の試聴ボタンを押してください");
      });
      runtime.profile = profile;
      runtime.guestBoss = MID_BOSS_ROTATION[profile.totalRuns % MID_BOSS_ROTATION.length];
      runtime.overtimeRank = selectedOvertimeRank;
      runtime.floor = 1;
      runtime.score = 0;
      runtime.combo = 0;
      runtime.maxCombo = 0;
      runtime.destroyed = 0;
      runtime.runCaps = 0;
      runtime.pressure = 0;
      runtime.rushUntil = 0;
      runtime.rerolls = 1;
      runtime.mega = 1;
      runtime.submitted = false;
      runtime.selected = [];
      runtime.synergies = [];
      runtime.maxHp = 100 + profile.mastery.vitality * 10;
      runtime.hp = runtime.maxHp;
      runtime.lastSmash = -10;
      runtime.lastMega = -10;
      runtime.lastDash = -10;
      runtime.megaLockUntil = 0;
      runtime.invulnerableUntil = 0;
      for (const key of Object.keys(upgradeValues) as UpgradeId[]) upgradeValues[key] = 0;
      setBuild([]);
      setActiveSynergies([]);
      setRerolls(1);
      setSummary(null);
      setupFloor();
    };

    const pickUpgrade = (choice: RewardChoice) => {
      if (runtime.playing || runtime.floor >= MAX_FLOOR) return;
      upgradeValues[choice.id] += choice.scale;
      runtime.selected.push(choice);
      if (choice.id === "guard") {
        runtime.maxHp += 18 * choice.scale;
        runtime.hp = runtime.maxHp;
      }
      if (choice.id === "happy") runtime.mega = Math.min(3, runtime.mega + Math.max(1, Math.floor(choice.scale)));
      const previousSynergyCount = runtime.synergies.length;
      runtime.synergies = resolveSynergies(upgradeValues);
      setBuild([...runtime.selected]);
      setActiveSynergies([...runtime.synergies]);
      if (runtime.synergies.length > previousSynergyCount) playSound("beer");
      runtime.floor += 1;
      setupFloor();
    };

    const rerollReward = () => {
      if (runtime.playing || runtime.floor >= MAX_FLOOR || runtime.rerolls <= 0) return;
      runtime.rerolls -= 1;
      const choices = makeRewardChoices(runtime.floor, runtime.overtimeRank);
      setRewardChoices(choices);
      setRerolls(runtime.rerolls);
      tone(280, 0.1, "square", 0.05, 520);
      tone(520, 0.15, "triangle", 0.055, 820, 0.08);
      notify(choices.some((choice) => choice.greater) ? "引き直し成功！ ★ 金星特性です" : "戦利品を入れ替えました");
    };

    const pause = () => {
      if (!runtime.playing) return;
      runtime.paused = !runtime.paused;
      setPaused(runtime.paused);
    };

    const toggleSound = () => {
      soundEnabled = !soundEnabled;
      setSoundOn(soundEnabled);
      if (soundEnabled) {
        void resumeAudio()
          .then(() => {
            tone(520, 0.1, "sine", 0.06, 760);
            tone(760, 0.14, "triangle", 0.055, 1040, 0.09);
          })
          .catch(() => notify("音声を開始できませんでした"));
      }
      return soundEnabled;
    };

    const unlockAudio = () => {
      if (!soundEnabled) return;
      void resumeAudio().catch(() => {
        // Keep the retry UI visible without interrupting gameplay.
      });
    };

    const testSound = () => {
      soundEnabled = true;
      setSoundOn(true);
      void resumeAudio()
        .then(() => {
          tone(392, 0.12, "triangle", 0.085, 523);
          tone(523, 0.14, "triangle", 0.085, 659, 0.1);
          tone(659, 0.22, "sine", 0.075, 988, 0.2);
          notify("♪ 乾杯！この音が聞こえれば準備OKです");
        })
        .catch(() => notify("音声を開始できません。端末の消音設定も確認してください"));
    };

    const returnHub = () => {
      runtime.playing = false;
      runtime.paused = false;
      clearStage();
      setMegaFlash(false);
      player.position.set(0, 0, 9.7);
      setPaused(false);
      setStatus("hub");
      setRewardChoices([]);
      setBuild([]);
      setActiveSynergies([]);
    };

    apiRef.current = {
      start,
      smash,
      megaSmash,
      dash,
      pause,
      unlockAudio,
      testSound,
      toggleSound,
      pickUpgrade,
      rerollReward,
      returnHub,
    };

    const keys = new Set<string>();
    const onKeyDown = (event: KeyboardEvent) => {
      unlockAudio();
      if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", " ", "Shift"].includes(event.key)) {
        event.preventDefault();
      }
      keys.add(event.key.toLowerCase());
      if (event.key === " ") smash();
      if (event.key.toLowerCase() === "e") megaSmash();
      if (event.key === "Shift") dash();
      if (event.key.toLowerCase() === "p" || event.key === "Escape") pause();
    };
    const onKeyUp = (event: KeyboardEvent) => keys.delete(event.key.toLowerCase());
    const onVisibilityChange = () => {
      if (document.visibilityState === "visible" && soundEnabled && audioContext) unlockAudio();
    };
    window.addEventListener("keydown", onKeyDown, { passive: false });
    window.addEventListener("keyup", onKeyUp);
    document.addEventListener("visibilitychange", onVisibilityChange);

    const resize = () => {
      const width = host.clientWidth;
      const height = host.clientHeight;
      renderer.setSize(width, height, false);
      const aspect = width / Math.max(1, height);
      const viewHeight = aspect < 1 ? 18 : 14.5;
      camera.left = -viewHeight * aspect / 2;
      camera.right = viewHeight * aspect / 2;
      camera.top = viewHeight / 2;
      camera.bottom = -viewHeight / 2;
      camera.updateProjectionMatrix();
    };
    const observer = new ResizeObserver(resize);
    observer.observe(host);
    resize();

    let requestId = 0;
    let previous = performance.now();
    let frame = 0;
    const tick = (now: number) => {
      const dt = Math.min((now - previous) / 1000, 0.04);
      previous = now;
      if (!runtime.paused) {
        runtime.elapsed += dt;
        (player.userData.mixer as THREE.AnimationMixer | undefined)?.update(dt);
      }
      let walking = false;

      if (runtime.playing && !runtime.paused) {
        if (runtime.pendingSmash && runtime.elapsed >= runtime.pendingSmash.at) {
          const pending = runtime.pendingSmash;
          runtime.pendingSmash = null;
          performSmash(pending.center);
        }
        if (runtime.pendingMega && runtime.elapsed >= runtime.pendingMega.at) {
          const pending = runtime.pendingMega;
          runtime.pendingMega = null;
          launchMegaMug(pending.origin, pending.direction);
        }

        const rushActive = runtime.elapsed < runtime.rushUntil;
        if (!rushActive && runtime.rushUntil > 0) {
          runtime.rushUntil = 0;
          runtime.pressure = 0;
          notify("RUSH TIME 終了。次の大整理へ！");
        } else if (!rushActive) {
          runtime.pressure = Math.max(0, runtime.pressure - dt * 3.6);
        }

        const move = new THREE.Vector2(
          (keys.has("d") || keys.has("arrowright") ? 1 : 0)
            - (keys.has("a") || keys.has("arrowleft") ? 1 : 0)
            + joystickRef.current.x,
          (keys.has("s") || keys.has("arrowdown") ? 1 : 0)
            - (keys.has("w") || keys.has("arrowup") ? 1 : 0)
            + joystickRef.current.z,
        );
        if (move.lengthSq() > 0.02 && runtime.elapsed >= runtime.megaLockUntil) {
          walking = true;
          move.normalize();
          const speed = 5.35
            * (1 + runtime.profile.mastery.hustle * 0.04 + upgradeValues.runner * 0.08)
            * (rushActive ? 1.16 : 1);
          player.position.x += move.x * speed * dt;
          player.position.z += move.y * speed * dt;
          player.position.x = THREE.MathUtils.clamp(player.position.x, -9.45, 9.45);
          player.position.z = THREE.MathUtils.clamp(player.position.z, -13.15, 11.35);
          const rotation = Math.atan2(-move.x, -move.y);
          player.rotation.y = THREE.MathUtils.lerp(player.rotation.y, rotation, 0.24);
          player.position.y = Math.sin(runtime.elapsed * 14) * 0.035;
        } else {
          player.position.y = THREE.MathUtils.lerp(player.position.y, 0, 0.24);
        }

        const aliveMovers = enemies.filter((enemy) => enemy.alive && !enemy.boss && enemy.speed > 0).length;
        for (let i = 0; i < enemies.length; i += 1) {
          const enemy = enemies[i];
          if (!enemy.alive) continue;
          (enemy.group.userData.mixer as THREE.AnimationMixer | undefined)?.update(dt);
          if (enemy.affix === "regenerator"
            && enemy.hp < enemy.maxHp
            && runtime.elapsed - enemy.lastRegen >= 0.65) {
            enemy.lastRegen = runtime.elapsed;
            enemy.hp = Math.min(enemy.maxHp, enemy.hp + enemy.maxHp * 0.025);
            updateEnemyHealth(enemy);
          }
          const toPlayer = player.position.clone().sub(enemy.group.position).setY(0);
          const distance = toPlayer.length();
          const frozen = runtime.elapsed < enemy.frozenUntil;
          const chilled = frozen ? Math.max(0.25, 1 - upgradeValues.frost * 0.24) : 1;
          (enemy.group.userData.animator as VoxelActionController | undefined)?.update(
            dt,
            runtime.elapsed,
            enemy.speed > 0 && distance > enemy.radius + 0.72,
          );
          const phaseAura = enemy.group.userData.phaseAura as THREE.Mesh | undefined;
          if (phaseAura) {
            phaseAura.rotation.z += dt * 2.8;
            phaseAura.scale.setScalar(1 + Math.sin(runtime.elapsed * 7) * 0.08);
          }

          if (enemy.attackKind) {
            if (frozen) {
              enemy.attackStartedAt += dt;
              enemy.attackAt += dt;
            }
            if (enemy.attackWarning) {
              animateDangerZone(enemy.attackWarning, enemy.attackStartedAt, enemy.attackAt, runtime.elapsed);
            }
            if (!frozen && runtime.elapsed >= enemy.attackAt) resolveEnemyAttack(enemy);
            continue;
          }

          if (enemy.characterBoss && runtime.elapsed >= enemy.pulseAt) {
            if (frozen) {
              enemy.pulseAt += dt;
            } else {
              launchCharacterSpecial(enemy);
            }
            continue;
          }

          if (enemy.boss && !enemy.characterBoss && runtime.elapsed >= enemy.pulseAt) {
            beginEnemyAttack(enemy, "pulse");
            continue;
          }

          if (enemy.speed <= 0) continue;

          if (distance > enemy.radius + 0.72) {
            toPlayer.normalize();
            const lastCallBoost = aliveMovers <= 3 && distance > 5.8 ? 1.85 : 1;
            enemy.group.position.addScaledVector(toPlayer, enemy.speed * chilled * lastCallBoost * dt);
            enemy.group.rotation.y = THREE.MathUtils.lerp(
              enemy.group.rotation.y,
              Math.atan2(-toPlayer.x, -toPlayer.z),
              0.12,
            );
          } else if (runtime.elapsed >= enemy.nextAttack) {
            beginEnemyAttack(enemy, "melee");
          }

          for (let j = i + 1; j < enemies.length; j += 1) {
            const other = enemies[j];
            if (!other.alive) continue;
            const separation = enemy.group.position.clone().sub(other.group.position).setY(0);
            const minimum = (enemy.radius + other.radius) * 0.72;
            if (separation.lengthSq() > 0.001 && separation.length() < minimum) {
              separation.normalize().multiplyScalar(dt * 0.65);
              enemy.group.position.add(separation);
              other.group.position.sub(separation);
            }
          }

        }

        for (let i = hazards.length - 1; i >= 0; i -= 1) {
          const hazard = hazards[i];
          animateDangerZone(hazard.warning, hazard.startedAt, hazard.triggerAt, runtime.elapsed);
          if (runtime.elapsed < hazard.triggerAt) continue;
          let hit = false;
          if (hazard.shape === "beam") {
            const delta = player.position.clone().sub(hazard.position).setY(0);
            const forwardDistance = delta.dot(hazard.direction);
            const sideDistance = Math.abs(delta.dot(
              new THREE.Vector3(-hazard.direction.z, 0, hazard.direction.x),
            ));
            hit = forwardDistance >= 0
              && forwardDistance <= hazard.length
              && sideDistance <= hazard.width / 2;
            spawnWave(hazard.position, hazard.color, 1.1);
            tone(118, 0.16, "sawtooth", 0.04, 680);
          } else {
            hit = player.position.distanceTo(hazard.position) <= hazard.radius;
            spawnWave(hazard.position, hazard.color, Math.max(0.9, hazard.radius * 0.38));
          }
          if (hit) {
            hurtPlayer(hazard.damage, hazard.position);
          }
          removeDisposableObject(hazard.warning);
          hazards.splice(i, 1);
        }

        for (const pickup of pickups) {
          if (!pickup.active) continue;
          pickup.group.rotation.y += dt * 1.8;
          pickup.group.position.y = pickup.baseY + Math.sin(runtime.elapsed * 3 + pickup.baseY) * 0.13;
          if (pickup.group.position.distanceTo(player.position) < 1.1) {
            pickup.active = false;
            pickup.group.visible = false;
            if (pickup.kind === "beer") {
              runtime.mega = Math.min(3, runtime.mega + 1);
              playSound("beer");
              notify("MUG RAIL STOCK +1｜Eキー / 黄ボタンで直線必殺技");
            } else if (pickup.kind === "clock") {
              runtime.freezeUntil = runtime.elapsed + 3.5;
              for (const enemy of enemies) enemy.frozenUntil = runtime.freezeUntil;
              tone(760, 0.2, "sine", 0.06, 1280);
              notify("COMBO FREEZE + 全備品停止 3.5秒");
            } else if (pickup.kind === "cap") {
              runtime.runCaps += 2;
              tone(930, 0.16, "triangle", 0.055, 1320);
              notify("王冠キャップ +2");
            } else {
              runtime.hp = Math.min(runtime.maxHp, runtime.hp + 18);
              tone(520, 0.18, "sine", 0.05, 880);
              notify("焼き鳥で HP +18");
            }
            syncHud();
          }
        }

        runtime.comboWindow -= dt;
        if (runtime.comboWindow <= 0 && runtime.combo > 0) {
          runtime.combo = 0;
          syncHud();
        }

        const floorDefinition = FLOORS[runtime.floor - 1];
        if (floorDefinition.kind === "challenge" && runtime.timer !== null) {
          runtime.timer -= dt;
          if (runtime.timer <= 0) {
            runtime.timer = 0;
            finishFloor();
          }
        }
      }

      if (!runtime.paused) {
        updateMegaProjectiles(dt);
        (player.userData.animator as VoxelActionController | undefined)?.update(
          dt,
          runtime.elapsed,
          walking && runtime.playing,
        );
        for (const dizzy of dizzyBosses) {
          const time = runtime.elapsed - dizzy.startedAt;
          dizzy.stars.rotation.y += dt * 2.8;
          dizzy.stars.position.y += Math.sin(time * 4.2) * dt * 0.12;
          dizzy.group.rotation.z = 0.16 + Math.sin(time * 2.6) * 0.035;
          dizzy.stars.children.forEach((star, index) => {
            star.rotation.x += dt * (1.4 + index * 0.15);
            star.rotation.z += dt * 1.8;
          });
        }
      }

      for (let i = debris.length - 1; i >= 0; i -= 1) {
        const piece = debris[i];
        piece.life -= dt;
        piece.velocity.y -= 9.8 * dt;
        piece.mesh.position.addScaledVector(piece.velocity, dt);
        piece.mesh.rotation.x += piece.spin.x * dt;
        piece.mesh.rotation.y += piece.spin.y * dt;
        piece.mesh.rotation.z += piece.spin.z * dt;
        if (piece.mesh.position.y < 0.08) {
          piece.mesh.position.y = 0.08;
          piece.velocity.y *= -0.22;
          piece.velocity.x *= 0.82;
          piece.velocity.z *= 0.82;
        }
        (piece.mesh.material as THREE.MeshStandardMaterial).opacity = Math.min(1, piece.life * 1.5);
        if (piece.life <= 0) {
          scene.remove(piece.mesh);
          debris.splice(i, 1);
        }
      }

      for (let i = effects.length - 1; i >= 0; i -= 1) {
        const effect = effects[i];
        effect.life -= dt;
        const progress = 1 - effect.life / effect.maxLife;
        effect.mesh.scale.multiplyScalar(1 + dt * (6 + progress * 4));
        (effect.mesh.material as THREE.MeshBasicMaterial).opacity = Math.max(0, effect.life / effect.maxLife);
        if (effect.life <= 0) {
          scene.remove(effect.mesh);
          effects.splice(i, 1);
        }
      }

      for (let index = timedVisuals.length - 1; index >= 0; index -= 1) {
        const visual = timedVisuals[index];
        visual.life -= dt;
        const opacity = THREE.MathUtils.clamp(visual.life / visual.maxLife, 0, 1);
        visual.object.traverse((child) => {
          if (!(child instanceof THREE.Mesh)) return;
          const materials = Array.isArray(child.material) ? child.material : [child.material];
          materials.forEach((material) => {
            if ("opacity" in material) {
              material.transparent = true;
              material.opacity = Math.min(material.opacity, opacity);
            }
          });
        });
        visual.object.rotation.y += dt * visual.spin;
        if (visual.life <= 0) {
          removeDisposableObject(visual.object);
          timedVisuals.splice(index, 1);
        }
      }

      if (runtime.shake > 0.002) {
        camera.position.copy(baseCameraPosition).add(new THREE.Vector3(
          (Math.random() - 0.5) * runtime.shake,
          (Math.random() - 0.5) * runtime.shake * 0.5,
          (Math.random() - 0.5) * runtime.shake,
        ));
        runtime.shake *= Math.pow(0.03, dt);
      } else {
        camera.position.copy(baseCameraPosition);
        runtime.shake = 0;
      }
      camera.lookAt(0, 0, -1.5);

      if (frame % 6 === 0 && runtime.playing) syncHud();
      frame += 1;
      renderer.render(scene, camera);
      requestId = requestAnimationFrame(tick);
    };
    requestId = requestAnimationFrame(tick);

    return () => {
      cancelAnimationFrame(requestId);
      observer.disconnect();
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("keyup", onKeyUp);
      document.removeEventListener("visibilitychange", onVisibilityChange);
      if (toastTimer.current) window.clearTimeout(toastTimer.current);
      if (megaFlashTimer.current) window.clearTimeout(megaFlashTimer.current);
      if (audioContext && audioContext.state !== "closed") void audioContext.close();
      renderer.dispose();
      apiRef.current = null;
      scene.traverse((object) => {
        if (object instanceof THREE.Mesh) {
          object.geometry.dispose();
          const materials = Array.isArray(object.material) ? object.material : [object.material];
          for (const material of materials) material.dispose();
        }
      });
    };
  }, [notify]);

  const updateJoystick = (clientX: number, clientY: number, target: HTMLElement) => {
    const rect = target.getBoundingClientRect();
    const x = THREE.MathUtils.clamp((clientX - rect.left - rect.width / 2) / (rect.width * 0.34), -1, 1);
    const y = THREE.MathUtils.clamp((clientY - rect.top - rect.height / 2) / (rect.height * 0.34), -1, 1);
    const length = Math.hypot(x, y);
    const nx = length > 1 ? x / length : x;
    const ny = length > 1 ? y / length : y;
    joystickRef.current = { x: nx, z: ny };
    setJoystick({ x: nx * 32, y: ny * 32 });
  };

  const releaseJoystick = () => {
    joystickPointer.current = null;
    joystickRef.current = { x: 0, z: 0 };
    setJoystick({ x: 0, y: 0 });
  };

  const profile = siteData?.profile ?? EMPTY_PROFILE;
  const hpRatio = Math.max(0, Math.min(100, hud.hp / Math.max(1, hud.maxHp) * 100));
  const dashRatio = Math.max(0, Math.min(100, hud.dashReady * 100));
  const enemyRatio = hud.totalEnemies > 0
    ? Math.max(0, Math.min(100, (hud.totalEnemies - hud.enemies) / hud.totalEnemies * 100))
    : 0;
  const pressureRatio = Math.max(0, Math.min(100, hud.pressure));

  return (
    <main
      className="rpg-shell"
      ref={hostRef}
      onPointerDownCapture={() => apiRef.current?.unlockAudio()}
    >
      <canvas
        ref={canvasRef}
        className="rpg-canvas"
        aria-label="そば屋のオフィスクラッシュ 無限フロア大整理 ゲーム画面"
      />
      <div className="rpg-sun" aria-hidden="true" />
      <div className={`rpg-mega-flash ${megaFlash ? "show" : ""}`} aria-hidden="true" />
      {status === "playing" && (
        <div
          className={`rpg-danger-vignette ${hpRatio <= 35 ? "low-hp" : ""} ${hud.incomingAttack ? "incoming" : ""}`}
          aria-hidden="true"
        />
      )}

      {status === "playing" && (
        <>
          <header className="rpg-hud">
            <div className="rpg-brand">
              <span>そば屋の</span>
              <strong>オフィスクラッシュ</strong>
              <small>無限フロア大整理</small>
            </div>
            <div className="rpg-floor">
              <span>{hud.kicker}</span>
              <strong>{hud.floor}F</strong>
              <b>{hud.floorName}</b>
            </div>
            <div className="rpg-hud-actions">
              <span className={`rpg-overtime rank-${overtimeRank}`}>{hud.overtimeLabel} ×{hud.scoreMultiplier.toFixed(2)}</span>
              <span className="rpg-cap">王冠 {hud.caps}</span>
              <button onClick={() => apiRef.current?.toggleSound()} aria-label={soundOn ? "効果音をオフ" : "効果音をオン"}>
                {soundOn ? "音 ON" : "音 OFF"}
              </button>
              <button onClick={() => apiRef.current?.pause()} aria-label="一時停止">Ⅱ</button>
            </div>
          </header>

          <section className="rpg-vitals" aria-label="プレイヤー情報">
            <div className="rpg-vital-row">
              <span>店主HP</span>
              <div className="rpg-bar"><i style={{ width: `${hpRatio}%` }} /></div>
              <strong>{hud.hp}/{hud.maxHp}</strong>
            </div>
            <div className="rpg-score-row">
              <span>SCORE</span>
              <strong>{formatNumber(hud.score)}</strong>
            </div>
            <div className={`rpg-combo ${hud.combo > 0 ? "active" : ""}`}>
              COMBO {hud.combo} <b>×{hud.multiplier.toFixed(2)}</b>
            </div>
            <div className={`rpg-pressure ${hud.rushRemaining > 0 ? "rush" : ""}`}>
              <span>{hud.rushRemaining > 0 ? `RUSH TIME ${hud.rushRemaining.toFixed(1)}s` : "清掃熱"}</span>
              <div><i style={{ width: `${pressureRatio}%` }} /></div>
            </div>
          </section>

          <section className="rpg-objective" aria-live="polite">
            <span>{hud.timer !== null ? `残り ${hud.timer}秒` : hud.bossName || `残り備品 ${hud.enemies}`}</span>
            <strong>{hud.objective}</strong>
            {hud.offscreenEnemies > 0 && <em>⚠ 画面外 {hud.offscreenEnemies}体・中央へ接近中</em>}
            {hud.incomingAttack && <em className="attack-alert">赤い予告範囲から離れろ！</em>}
            <div className="rpg-progress"><i style={{ width: `${enemyRatio}%` }} /></div>
          </section>

          <aside className="rpg-build-rail" aria-label="現在のビルド">
            <span>RUN BUILD</span>
            {build.length === 0 && <small>戦利品は階層クリア後に獲得</small>}
            {activeSynergies.map((synergy) => (
              <div className="rpg-synergy-chip" key={synergy.name} title={synergy.effect}>
                <b>{synergy.icon}</b>
                <span>{synergy.name}</span>
              </div>
            ))}
            {build.slice(-6).map((item, index) => (
              <div className={`rpg-build-chip ${item.rarityClass} ${item.greater ? "greater" : ""}`} key={`${item.id}-${index}`} title={item.effect}>
                <b>{item.icon}</b>
                <span>{item.name}</span>
              </div>
            ))}
          </aside>

          <div className={`rpg-mega ${hud.mega > 0 ? "ready" : ""}`}>
            <span>MUG RAIL STOCK</span>
            <div>{[0, 1, 2].map((slot) => <i className={slot < hud.mega ? "full" : ""} key={slot}>生</i>)}</div>
            <small>向きを決めて E / 黄ボタン</small>
          </div>

          <div
            className="rpg-joystick"
            role="button"
            aria-label="移動ジョイスティック"
            tabIndex={0}
            onPointerDown={(event) => {
              joystickPointer.current = event.pointerId;
              event.currentTarget.setPointerCapture(event.pointerId);
              updateJoystick(event.clientX, event.clientY, event.currentTarget);
            }}
            onPointerMove={(event) => {
              if (joystickPointer.current === event.pointerId) {
                updateJoystick(event.clientX, event.clientY, event.currentTarget);
              }
            }}
            onPointerUp={releaseJoystick}
            onPointerCancel={releaseJoystick}
          >
            <span aria-hidden="true">▲<b>◀　▶</b>▼</span>
            <i style={{ transform: `translate(${joystick.x}px, ${joystick.y}px)` }} />
          </div>

          <div className="rpg-action-stack">
            <div className="rpg-sub-actions">
              <button
                className="rpg-dash-button"
                onPointerDown={(event) => {
                  event.preventDefault();
                  apiRef.current?.dash();
                }}
                aria-label="ダッシュ"
              >
                <i style={{ width: `${dashRatio}%` }} />
                <strong>DASH</strong>
              </button>
              <button
                className={`rpg-mega-button ${hud.mega > 0 ? "ready" : ""}`}
                disabled={hud.mega <= 0}
                onPointerDown={(event) => {
                  event.preventDefault();
                  apiRef.current?.megaSmash();
                }}
                aria-label={`必殺生ジョッキレール 残り${hud.mega}`}
              >
                <span>必殺</span>
                <strong>RAIL</strong>
                <small>×{hud.mega}</small>
              </button>
            </div>
            <button
              className="rpg-smash-button"
              onPointerDown={(event) => {
                event.preventDefault();
                apiRef.current?.smash();
              }}
              aria-label="ジョッキスマッシュ"
            >
              <span aria-hidden="true">槌</span>
              <strong>SMASH!</strong>
            </button>
          </div>
        </>
      )}

      <div className={`rpg-toast ${toast ? "show" : ""}`} aria-live="assertive">{toast}</div>

      {status === "hub" && (
        <section className="rpg-overlay hub-overlay" aria-labelledby="hub-title">
          <div className="hub-card">
            <div className="hub-copy">
              <p className="rpg-eyebrow">MADOGIWA HACK, SMASH & DRAFT</p>
              <h1 id="hub-title">
                <span>そば屋の</span>
                オフィスクラッシュ
                <small>無限フロア大整理</small>
              </h1>
              <blockquote>
                「おかやまん。弊社の備品が自律歩行を始めており、<br />
                大変驚いております」
              </blockquote>
              <p className="hub-lead">
                タコ部屋の人型の大穴、その先は図面にない備品循環棟だった。
                ジョッキを強化し、8つのレギュレーションを片付けろ！
              </p>
              <div className="hub-features" aria-label="ゲームの特徴">
                <span>8 FLOORS</span>
                <span>生ジョッキレール</span>
                <span>LOOT DRAFT</span>
                <span>金星特性</span>
                <span>ビルド共鳴</span>
                <span>残業難度</span>
                <span>永続記録</span>
              </div>
              <section className="overtime-select" aria-label="残業難度">
                <div>
                  <span>RISK × REWARD</span>
                  <strong>残業指令を選ぶ</strong>
                </div>
                <div className="overtime-options">
                  {OVERTIME_RANKS.map((rank) => (
                    <button
                      type="button"
                      className={overtimeRank === rank.rank ? "active" : ""}
                      key={rank.rank}
                      onClick={() => setOvertimeRank(rank.rank)}
                      title={rank.description}
                    >
                      <small>{rank.kicker}</small>
                      <b>{rank.label}</b>
                      <em>得点 ×{rank.scoreMultiplier.toFixed(2)}</em>
                    </button>
                  ))}
                </div>
                <p>{OVERTIME_RANKS[overtimeRank].description}</p>
              </section>
              <div className={`audio-check ${audioReady ? "ready" : ""} ${audioError ? "error" : ""}`}>
                <button type="button" onClick={() => apiRef.current?.testSound()}>
                  <span aria-hidden="true">{audioReady ? "🔊" : "🔈"}</span>
                  {audioReady ? "効果音をもう一度試す" : "まず効果音を試す"}
                </button>
                <small>
                  {audioError
                    ? "音が出ない場合は端末の消音設定を解除して、もう一度押してください"
                    : audioReady
                      ? "音声準備OK。突入後にスマッシュ音が鳴ります"
                      : "ブラウザの音声ロックをタップで解除します"}
                </small>
              </div>
              <button
                className="hub-start"
                onClick={() => apiRef.current?.start(profile, overtimeRank)}
                disabled={profileLoading}
              >
                <span>{profileLoading ? "立ち飲み処を準備中…" : "備品循環棟へ突入！"}</span>
                <small>移動 WASD / 矢印・通常攻撃 SPACE・ジョッキ投擲 E・回避 SHIFT　向きを合わせて一網打尽！</small>
              </button>
              {profileError && (
                <button className="profile-retry" onClick={() => void refreshProfile()}>
                  記録サーバーへ再接続
                </button>
              )}
            </div>

            <div className="hub-data">
              <div className="hub-stats">
                <div><span>王冠キャップ</span><strong>{formatNumber(profile.caps)}</strong></div>
                <div><span>自己ベスト</span><strong>{formatNumber(profile.bestScore)}</strong></div>
                <div><span>最高到達</span><strong>{profile.bestFloor || "—"}F</strong></div>
                <div><span>完全制覇</span><strong>{profile.clears}</strong></div>
              </div>

              <section className="mastery-panel">
                <div className="panel-heading">
                  <span>立ち飲み処</span>
                  <strong>永続仕込み</strong>
                </div>
                {([
                  ["forge", "ジョッキ鍛造", "攻撃力 +8% / Lv", "槌"],
                  ["vitality", "店主の大盛り", "最大HP +10 / Lv", "盛"],
                  ["hustle", "ついでに足腰", "移動速度 +4% / Lv", "走"],
                ] as Array<[MasteryKey, string, string, string]>).map(([key, name, effect, icon]) => {
                  const level = profile.mastery[key];
                  const cost = masteryCost(level);
                  return (
                    <div className="mastery-row" key={key}>
                      <b>{icon}</b>
                      <span><strong>{name}</strong><small>{effect}</small></span>
                      <em>Lv.{level}/5</em>
                      <button
                        onClick={() => void buyMastery(key)}
                        disabled={profileLoading || masteryBusy !== null || level >= 5}
                      >
                        {level >= 5 ? "MAX" : `${cost} 王冠`}
                      </button>
                    </div>
                  );
                })}
              </section>

              <div className="hub-live-grid">
                <section>
                  <div className="panel-heading"><span>GLOBAL</span><strong>全店主の記録</strong></div>
                  <p><b>{formatNumber(Number(siteData?.globalStats.runs ?? 0))}</b> ラン</p>
                  <p><b>{formatNumber(Number(siteData?.globalStats.destroyed ?? 0))}</b> 備品を整理</p>
                </section>
                <section>
                  <div className="panel-heading"><span>TOP 5</span><strong>スコアボード</strong></div>
                  {(siteData?.leaderboard ?? []).slice(0, 3).map((run, index) => (
                    <p key={`${run.score}-${index}`}>
                      <b>#{index + 1}</b> {formatNumber(run.score)}
                      <small>{run.floorReached}F・{OVERTIME_RANKS[Math.max(0, Math.min(3, run.overtimeRank))].label}</small>
                    </p>
                  ))}
                  {!siteData?.leaderboard.length && <p className="muted">最初の伝説を作ろう</p>}
                </section>
              </div>
            </div>
          </div>
        </section>
      )}

      {status === "reward" && (
        <section className="rpg-overlay reward-overlay" aria-labelledby="reward-title">
          <div className="reward-card">
            <p className="rpg-eyebrow">FLOOR {hud.floor} CLEAR — LOOT DRAFT</p>
            <h2 id="reward-title">戦利品をひとつ選ぶ</h2>
            <p>同系統のパーツを組み合わせると「ビルド共鳴」が発動。金星特性は通常より45%強力です。</p>
            <div className="reward-grid">
              {rewardChoices.map((choice) => (
                <button
                  className={`loot-card ${choice.rarityClass} ${choice.greater ? "greater" : ""}`}
                  key={choice.id}
                  onClick={() => apiRef.current?.pickUpgrade(choice)}
                >
                  <span className="loot-rarity">{choice.rarity}</span>
                  <span className="loot-school">{choice.school}系統</span>
                  <b className="loot-icon" style={{ color: choice.color }}>{choice.icon}</b>
                  <small>{choice.slot}</small>
                  <strong>{choice.name}</strong>
                  <p>{choice.description}</p>
                  <em>{choice.effect}</em>
                  <i>装備して次の階へ</i>
                </button>
              ))}
            </div>
            <button
              type="button"
              className="loot-reroll"
              onClick={() => apiRef.current?.rerollReward()}
              disabled={rerolls <= 0}
            >
              品書きを全部引き直す <b>{rerolls}/1</b>
            </button>
            {activeSynergies.length > 0 && (
              <div className="reward-synergies">
                <span>発動中</span>
                {activeSynergies.map((synergy) => <b key={synergy.name}>{synergy.icon} {synergy.name}</b>)}
              </div>
            )}
          </div>
        </section>
      )}

      {(status === "gameover" || status === "victory") && summary && (
        <section className={`rpg-overlay result-overlay ${status}`} aria-labelledby="result-title">
          <div className="result-card">
            <span className="result-stamp">{summary.victory ? "REGULATION CLEAR!" : "BONK! 搬送完了"}</span>
            <p className="rpg-eyebrow">{summary.victory ? "ALL 8 FLOORS COMPLETE" : `REACHED FLOOR ${summary.floorReached}`}</p>
            <h2 id="result-title">{getRank(summary)}</h2>
            <p>{summary.victory ? "備品はすべて資材へ戻りました。最後は立ち飲み処で乾杯です！" : "ゆめみんに起こされました。仕込みを整えて、また行けます！"}</p>
            <div className="result-score">
              <span>FINAL SCORE</span>
              <strong>{formatNumber(summary.score)}</strong>
              <small>{OVERTIME_RANKS[summary.overtimeRank].label} ×{OVERTIME_RANKS[summary.overtimeRank].scoreMultiplier.toFixed(2)} ／ {summary.buildName}</small>
            </div>
            <div className="result-grid">
              <div><span>到達</span><strong>{summary.floorReached}F</strong></div>
              <div><span>備品整理</span><strong>{summary.destroyed}</strong></div>
              <div><span>MAX COMBO</span><strong>{summary.maxCombo}</strong></div>
              <div><span>獲得王冠</span><strong>+{summary.capsEarned}</strong></div>
            </div>
            <div className="result-build">
              {build.map((item, index) => (
                <span className={item.rarityClass} key={`${item.id}-${index}`}>{item.icon} {item.name}</span>
              ))}
            </div>
            <div className="result-actions">
              <button onClick={() => apiRef.current?.start(profileRef.current, overtimeRank)}>もう一度突入</button>
              <button onClick={() => apiRef.current?.returnHub()}>立ち飲み処へ戻る</button>
            </div>
          </div>
        </section>
      )}

      {paused && status === "playing" && (
        <section className="rpg-overlay pause-overlay">
          <div className="pause-card">
            <p className="rpg-eyebrow">PAUSED REGULATION</p>
            <strong>一時休憩です！</strong>
            <button onClick={() => apiRef.current?.pause()}>片付けを続ける</button>
          </div>
        </section>
      )}
    </main>
  );
}
