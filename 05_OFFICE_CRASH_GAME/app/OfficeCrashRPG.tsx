"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import * as THREE from "three";
import { SOBAYA_CHARACTER } from "./characters/sobaya";
import {
  loadVoxelCharacter,
  type VoxelActionController,
} from "./characters/voxel-character-kit";
import {
  EMPTY_PROFILE,
  FLOORS,
  UPGRADES,
  makeRewardChoices,
  masteryCost,
  type GameProfile,
  type GameStatus,
  type MasteryKey,
  type RewardChoice,
  type SiteGameData,
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
};

type RunSummary = {
  victory: boolean;
  floorReached: number;
  score: number;
  destroyed: number;
  maxCombo: number;
  capsEarned: number;
  upgrades: string[];
};

type GameApi = {
  start: (profile: GameProfile) => void;
  smash: () => void;
  dash: () => void;
  pause: () => void;
  unlockAudio: () => void;
  testSound: () => void;
  toggleSound: () => boolean;
  pickUpgrade: (choice: RewardChoice) => void;
  returnHub: () => void;
};

type EnemyKind = "chair" | "stapler" | "cabinet" | "desk" | "copier" | "gate" | "core";

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
  frozenUntil: number;
  nextAttack: number;
  pulseAt: number;
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
  if (summary.floorReached >= 4) return "金の複合機クラッシャー";
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

  const [status, setStatus] = useState<GameStatus>("hub");
  const [hud, setHud] = useState<HudState>(EMPTY_HUD);
  const [paused, setPaused] = useState(false);
  const [soundOn, setSoundOn] = useState(true);
  const [audioReady, setAudioReady] = useState(false);
  const [audioError, setAudioError] = useState(false);
  const [toast, setToast] = useState("");
  const [joystick, setJoystick] = useState({ x: 0, y: 0 });
  const [rewardChoices, setRewardChoices] = useState<RewardChoice[]>([]);
  const [build, setBuild] = useState<RewardChoice[]>([]);
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
      floorKilled: 0,
      floorTotal: 0,
      timer: null as number | null,
      lastSmash: -10,
      lastBump: -10,
      lastDash: -10,
      invulnerableUntil: 0,
      freezeUntil: 0,
      shake: 0,
      pendingSmash: null as { at: number; center: THREE.Vector3; mega: boolean } | null,
      profile: EMPTY_PROFILE,
      selected: [] as RewardChoice[],
    };

    const stageAdd = (object: THREE.Object3D) => {
      scene.add(object);
      stageObjects.push(object);
    };

    const clearStage = () => {
      for (const enemy of enemies) scene.remove(enemy.group);
      for (const pickup of pickups) scene.remove(pickup.group);
      for (const object of stageObjects) scene.remove(object);
      enemies.length = 0;
      pickups.length = 0;
      stageObjects.length = 0;
      for (const piece of debris) scene.remove(piece.mesh);
      debris.length = 0;
      for (const effect of effects) scene.remove(effect.mesh);
      effects.length = 0;
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

    const addPickup = (kind: PickupKind, position: THREE.Vector3) => {
      const group = makePickup(kind);
      group.position.copy(position);
      group.position.y = 0.75;
      scene.add(group);
      pickups.push({ group, kind, baseY: 0.75, active: true });
    };

    const spawnEnemy = (
      kind: EnemyKind,
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
      const elite = options.elite ?? false;
      const boss = options.boss ?? false;
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
        copier: { speed: boss ? 1.05 : 1.45, damage: boss ? 18 : 10, radius: boss ? 1.45 : 0.82, points: boss ? 6500 : 330, color: boss ? 0xf6b80c : 0xd9e1e5, label: boss ? "金の複合機・零式" : "複合機タンク" },
        gate: { speed: 1.1, damage: 14, radius: 1.15, points: 560, color: 0x425864, label: "強化ゲートΩ" },
        core: { speed: 0.92, damage: 22, radius: 1.65, points: 15000, color: 0xff4437, label: "REGULATION CORE" },
      }[kind];
      const hp = boss ? (kind === "core" ? 125 : 72) : baseHp;
      const health = makeHealthBar(boss ? 3.2 : elite ? 1.65 : 1.1, boss ? floorDefinition.accent : 0x56e07a);
      health.position.y = kind === "core" ? 3.4 : boss ? 3.25 : kind === "cabinet" || kind === "gate" ? 2.25 : 1.85;
      health.rotation.x = -0.35;
      group.add(health);
      scene.add(group);
      enemies.push({
        group,
        kind,
        label: options.label ?? stats.label,
        hp,
        maxHp: hp,
        speed: options.stationary ? 0 : stats.speed * (1 + runtime.floor * 0.025),
        damage: options.stationary ? 0 : stats.damage + runtime.floor * 0.9,
        radius: stats.radius * scale,
        points: stats.points,
        color: stats.color,
        alive: true,
        boss,
        frozenUntil: 0,
        nextAttack: runtime.elapsed + 1,
        pulseAt: runtime.elapsed + 2.8,
        healthFill: health.userData.fill as THREE.Mesh,
      });
    };

    const randomSpawnPoints = () => {
      const points: Array<[number, number]> = [];
      for (const z of [-11.7, -8.6, -5.3, -2.1, 1.2, 4.4]) {
        for (const x of [-7.8, -4, 0, 4, 7.8]) {
          if (z > 2 && Math.abs(x) < 2) continue;
          points.push([x + (Math.random() - 0.5) * 0.9, z + (Math.random() - 0.5) * 0.9]);
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
        bossName: boss?.label ?? "",
      });
    };

    const setupFloor = () => {
      clearStage();
      const floorDefinition = FLOORS[runtime.floor - 1];
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
      runtime.mega = Math.min(3, runtime.mega + Math.max(0, Math.floor(upgradeValues.happy)));
      runtime.playing = true;
      runtime.paused = false;
      runtime.lastBump = -10;

      const points = randomSpawnPoints();
      if (floorDefinition.kind === "boss") {
        spawnEnemy("copier", 0, -7.2, { boss: true, elite: true, scale: 1.75 });
      } else if (floorDefinition.kind === "final") {
        spawnEnemy("core", 0, -7.4, { boss: true, elite: true, scale: 1.32 });
      } else {
        const kinds: EnemyKind[] = floorDefinition.kind === "challenge"
          ? ["chair", "desk", "cabinet", "copier"]
          : runtime.floor === 6
            ? ["cabinet", "gate", "cabinet", "stapler"]
            : runtime.floor >= 5
              ? ["stapler", "cabinet", "desk", "copier", "chair"]
              : ["chair", "stapler", "desk", "cabinet"];
        for (let i = 0; i < floorDefinition.enemyCount; i += 1) {
          const [x, z] = points[i % points.length];
          spawnEnemy(kinds[i % kinds.length], x, z, {
            elite: floorDefinition.kind === "elite" || (runtime.floor >= 5 && i % 6 === 0),
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
      notify(`${floorDefinition.floor}F「${floorDefinition.name}」`);
    };

    const makeSummary = (victory: boolean): RunSummary => ({
      victory,
      floorReached: runtime.floor,
      score: Math.round(runtime.score),
      destroyed: runtime.destroyed,
      maxCombo: runtime.maxCombo,
      capsEarned: runtime.runCaps,
      upgrades: runtime.selected.map((item) => `${item.rarity}｜${item.name}`),
    });

    const endRun = (victory: boolean) => {
      if (runtime.submitted) return;
      runtime.playing = false;
      runtime.submitted = true;
      if (victory) runtime.runCaps += 30;
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
      const floorBonus = 800 + runtime.floor * 320;
      runtime.score += floorBonus;
      runtime.runCaps += 3 + Math.floor(runtime.floor / 2);
      if (runtime.floor >= MAX_FLOOR) {
        endRun(true);
        return;
      }
      const choices = makeRewardChoices(runtime.floor);
      setRewardChoices(choices);
      syncHud();
      setStatus("reward");
      playSound("clear");
      notify(`FLOOR CLEAR +${formatNumber(floorBonus)}`);
    };

    const updateEnemyHealth = (enemy: Enemy) => {
      if (!enemy.healthFill) return;
      const ratio = THREE.MathUtils.clamp(enemy.hp / enemy.maxHp, 0, 1);
      enemy.healthFill.scale.x = ratio;
      (enemy.healthFill.material as THREE.MeshStandardMaterial).color.setHex(healthColor(ratio));
    };

    const destroyEnemy = (enemy: Enemy, critical: boolean, chainDepth = 0) => {
      if (!enemy.alive) return;
      enemy.alive = false;
      scene.remove(enemy.group);
      runtime.destroyed += 1;
      runtime.floorKilled += 1;
      runtime.combo += 1;
      runtime.maxCombo = Math.max(runtime.maxCombo, runtime.combo);
      runtime.comboWindow = 2.1 + upgradeValues.combo * 0.7;
      const multiplier = getComboMultiplier(runtime.combo);
      runtime.score += Math.round(enemy.points * multiplier * (critical ? 1.25 : 1));
      runtime.shake = Math.max(runtime.shake, enemy.boss ? 0.55 : 0.22);
      spawnDebris(enemy.group.position, enemy.color, enemy.boss ? 42 : 13);
      playSound(enemy.boss ? "metal" : "break");
      navigator.vibrate?.(enemy.boss ? 45 : 15);

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
        const splashDamage = (2 * (1 + runtime.profile.mastery.forge * 0.08 + upgradeValues.heavy * 0.28))
          * upgradeValues.foam * 0.45;
        spawnWave(enemy.group.position, 0xfff0a1, 0.8);
        for (const other of enemies) {
          if (!other.alive || other === enemy) continue;
          if (other.group.position.distanceTo(enemy.group.position) < 2.6) {
            other.hp -= splashDamage;
            updateEnemyHealth(other);
            if (other.hp <= 0) destroyEnemy(other, false, chainDepth + 1);
          }
        }
      }

      syncHud();
      if (enemies.every((candidate) => !candidate.alive)) {
        const floorDefinition = FLOORS[runtime.floor - 1];
        if (floorDefinition.kind === "challenge" && (runtime.timer ?? 0) > 0) {
          const points = randomSpawnPoints();
          const kinds: EnemyKind[] = ["chair", "desk", "cabinet", "copier"];
          const waveSize = runtime.floor === 7 ? 18 : 14;
          for (let i = 0; i < waveSize; i += 1) {
            const [x, z] = points[i];
            spawnEnemy(kinds[i % kinds.length], x, z, {
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
      }
    };

    const damageEnemy = (enemy: Enemy, amount: number, critical: boolean, center: THREE.Vector3) => {
      if (!enemy.alive) return;
      enemy.hp -= amount;
      enemy.frozenUntil = Math.max(enemy.frozenUntil, runtime.elapsed + upgradeValues.frost * 0.45);
      const away = enemy.group.position.clone().sub(center).setY(0);
      if (away.lengthSq() > 0.01 && !enemy.boss) {
        away.normalize().multiplyScalar(0.38 + upgradeValues.knockback * 0.4);
        enemy.group.position.add(away);
      }
      updateEnemyHealth(enemy);
      if (enemy.hp <= 0) {
        destroyEnemy(enemy, critical);
      } else {
        spawnDebris(enemy.group.position.clone().add(new THREE.Vector3(0, 0.8, 0)), enemy.color, 4);
        playSound("metal");
      }
    };

    const hurtPlayer = (amount: number, source: THREE.Vector3) => {
      if (!runtime.playing || runtime.elapsed < runtime.invulnerableUntil) return;
      runtime.invulnerableUntil = runtime.elapsed + 0.68;
      runtime.hp = Math.max(0, runtime.hp - amount);
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
      notify(`HP -${Math.ceil(amount)}　まだ快適です！`);
      syncHud();
      if (runtime.hp <= 0) endRun(false);
    };

    const performSmash = (center: THREE.Vector3, mega: boolean) => {
      playSound("smash");
      const baseDamage = 2 * (1 + runtime.profile.mastery.forge * 0.08 + upgradeValues.heavy * 0.28);
      const damage = baseDamage * (mega ? 2.15 : 1);
      const radius = 1.65 * (1 + upgradeValues.wide * 0.16) * (mega ? 1.5 : 1);
      spawnWave(center, mega ? 0xffc21d : 0xffffff, mega ? 1.35 : 1);
      runtime.shake = Math.max(runtime.shake, mega ? 0.42 : 0.24);
      let hits = 0;
      let criticals = 0;
      for (const enemy of enemies) {
        if (!enemy.alive) continue;
        const distance = Math.max(0, enemy.group.position.distanceTo(center) - enemy.radius);
        if (distance <= radius) {
          hits += 1;
          const critical = distance <= 0.58 || Math.random() < upgradeValues.perfect * 0.1;
          if (critical) criticals += 1;
          damageEnemy(enemy, damage * (critical ? 1.75 : 1), critical, center);
        }
      }
      if (hits > 1) {
        const bonus = Math.round(hits * hits * 45 * getComboMultiplier(runtime.combo));
        runtime.score += bonus;
        notify(`MULTI BREAK ×${hits} +${formatNumber(bonus)}`);
      } else if (criticals > 0) {
        notify("PERFECT SMASH! ×1.75");
      } else if (hits === 0) {
        notify(mega ? "MEGA SMASH!" : "SMASH!");
      }
      syncHud();
    };

    const smash = () => {
      if (!runtime.playing || runtime.paused) return;
      const cooldown = Math.max(0.2, 0.46 * (1 - upgradeValues.haste * 0.09));
      if (runtime.elapsed - runtime.lastSmash < cooldown) return;
      runtime.lastSmash = runtime.elapsed;
      const mega = runtime.mega > 0;
      if (mega) runtime.mega -= 1;
      const forward = new THREE.Vector3(0, 0, -1).applyAxisAngle(UP, player.rotation.y);
      const center = player.position.clone().addScaledVector(forward, 1.2);
      center.y = 0;
      (player.userData.animator as VoxelActionController | undefined)?.triggerSmash(mega);
      tone(280, 0.1, "sawtooth", 0.045, 720);
      runtime.pendingSmash = { at: runtime.elapsed + 0.17, center, mega };
      syncHud();
    };

    const dash = () => {
      if (!runtime.playing || runtime.paused) return;
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

    const start = (profile: GameProfile) => {
      void resumeAudio().catch(() => {
        notify("音声を開始できません。立ち飲み処の試聴ボタンを押してください");
      });
      runtime.profile = profile;
      runtime.floor = 1;
      runtime.score = 0;
      runtime.combo = 0;
      runtime.maxCombo = 0;
      runtime.destroyed = 0;
      runtime.runCaps = 0;
      runtime.mega = 1;
      runtime.submitted = false;
      runtime.selected = [];
      runtime.maxHp = 100 + profile.mastery.vitality * 10;
      runtime.hp = runtime.maxHp;
      runtime.lastSmash = -10;
      runtime.lastDash = -10;
      runtime.invulnerableUntil = 0;
      for (const key of Object.keys(upgradeValues) as UpgradeId[]) upgradeValues[key] = 0;
      setBuild([]);
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
      setBuild([...runtime.selected]);
      runtime.floor += 1;
      setupFloor();
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
      player.position.set(0, 0, 9.7);
      setPaused(false);
      setStatus("hub");
      setRewardChoices([]);
      setBuild([]);
    };

    apiRef.current = {
      start,
      smash,
      dash,
      pause,
      unlockAudio,
      testSound,
      toggleSound,
      pickUpgrade,
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
          performSmash(pending.center, pending.mega);
        }

        const move = new THREE.Vector2(
          (keys.has("d") || keys.has("arrowright") ? 1 : 0)
            - (keys.has("a") || keys.has("arrowleft") ? 1 : 0)
            + joystickRef.current.x,
          (keys.has("s") || keys.has("arrowdown") ? 1 : 0)
            - (keys.has("w") || keys.has("arrowup") ? 1 : 0)
            + joystickRef.current.z,
        );
        if (move.lengthSq() > 0.02) {
          walking = true;
          move.normalize();
          const speed = 5.35
            * (1 + runtime.profile.mastery.hustle * 0.04 + upgradeValues.runner * 0.08);
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

        for (let i = 0; i < enemies.length; i += 1) {
          const enemy = enemies[i];
          if (!enemy.alive || enemy.speed <= 0) continue;
          const toPlayer = player.position.clone().sub(enemy.group.position).setY(0);
          const distance = toPlayer.length();
          const chilled = runtime.elapsed < enemy.frozenUntil ? Math.max(0.25, 1 - upgradeValues.frost * 0.24) : 1;
          if (distance > enemy.radius + 0.72) {
            toPlayer.normalize();
            enemy.group.position.addScaledVector(toPlayer, enemy.speed * chilled * dt);
            enemy.group.rotation.y = THREE.MathUtils.lerp(
              enemy.group.rotation.y,
              Math.atan2(-toPlayer.x, -toPlayer.z),
              0.12,
            );
          } else if (runtime.elapsed >= enemy.nextAttack) {
            enemy.nextAttack = runtime.elapsed + (enemy.boss ? 1.35 : 1.05);
            hurtPlayer(enemy.damage, enemy.group.position);
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

          if (enemy.boss) {
            enemy.group.rotation.y += dt * 0.35;
            if (runtime.elapsed >= enemy.pulseAt) {
              enemy.pulseAt = runtime.elapsed + (enemy.kind === "core" ? 2.65 : 3.2);
              spawnWave(enemy.group.position, enemy.kind === "core" ? 0xff4437 : 0xffc21d, 1.4);
              if (distance < (enemy.kind === "core" ? 6.3 : 5.2)) {
                hurtPlayer(enemy.damage * 0.72, enemy.group.position);
              }
            }
          }
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
              notify("BEER GET! 次の一撃がMEGA");
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
        (player.userData.animator as VoxelActionController | undefined)?.update(
          dt,
          runtime.elapsed,
          walking && runtime.playing,
        );
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
          </section>

          <section className="rpg-objective" aria-live="polite">
            <span>{hud.timer !== null ? `残り ${hud.timer}秒` : hud.bossName || `残り備品 ${hud.enemies}`}</span>
            <strong>{hud.objective}</strong>
            <div className="rpg-progress"><i style={{ width: `${enemyRatio}%` }} /></div>
          </section>

          <aside className="rpg-build-rail" aria-label="現在のビルド">
            <span>RUN BUILD</span>
            {build.length === 0 && <small>戦利品は階層クリア後に獲得</small>}
            {build.slice(-6).map((item, index) => (
              <div className={`rpg-build-chip ${item.rarityClass}`} key={`${item.id}-${index}`} title={item.effect}>
                <b>{item.icon}</b>
                <span>{item.name}</span>
              </div>
            ))}
          </aside>

          <div className={`rpg-mega ${hud.mega > 0 ? "ready" : ""}`}>
            <span>MEGA</span>
            <div>{[0, 1, 2].map((slot) => <i className={slot < hud.mega ? "full" : ""} key={slot}>生</i>)}</div>
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
              className={`rpg-smash-button ${hud.mega > 0 ? "mega-ready" : ""}`}
              onPointerDown={(event) => {
                event.preventDefault();
                apiRef.current?.smash();
              }}
              aria-label="ジョッキスマッシュ"
            >
              <span aria-hidden="true">槌</span>
              <strong>{hud.mega > 0 ? "MEGA!" : "SMASH!"}</strong>
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
                <span>MEGA SMASH</span>
                <span>LOOT DRAFT</span>
                <span>永続記録</span>
              </div>
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
                onClick={() => apiRef.current?.start(profile)}
                disabled={profileLoading}
              >
                <span>{profileLoading ? "立ち飲み処を準備中…" : "備品循環棟へ突入！"}</span>
                <small>WASD / 矢印・SPACE・SHIFT　スマホ操作対応</small>
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
                    <p key={`${run.score}-${index}`}><b>#{index + 1}</b> {formatNumber(run.score)} <small>{run.floorReached}F</small></p>
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
            <p>大型ジョッキと白い仮面はそのまま。中身とパーツでビルドを変えよう。</p>
            <div className="reward-grid">
              {rewardChoices.map((choice) => (
                <button
                  className={`loot-card ${choice.rarityClass}`}
                  key={choice.id}
                  onClick={() => apiRef.current?.pickUpgrade(choice)}
                >
                  <span className="loot-rarity">{choice.rarity}</span>
                  <b className="loot-icon" style={{ color: choice.color }}>{choice.icon}</b>
                  <small>{choice.slot}</small>
                  <strong>{choice.name}</strong>
                  <p>{choice.description}</p>
                  <em>{choice.effect}</em>
                  <i>装備して次の階へ</i>
                </button>
              ))}
            </div>
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
              <button onClick={() => apiRef.current?.start(profileRef.current)}>もう一度突入</button>
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
