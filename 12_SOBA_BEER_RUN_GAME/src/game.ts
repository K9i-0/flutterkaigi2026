import * as THREE from "three";
import { RunnerAudio } from "./audio.js";
import { playCutscene } from "./cutscene.js";
import {
  FINAL_RUSH_START,
  FINISH_DISTANCE,
  LANE_X,
  RUN_DURATION,
  buildCourse,
  rankFor,
  rankLabel,
  speedAt,
} from "./rules.js";
import type { CourseCell, Lane, Phase, RunResult } from "./types.js";
import {
  loadVoxelCharacter,
  runnerDefinition,
  type LoadedVoxelCharacter,
} from "./voxel-character-kit.js";

interface TrackEntity {
  kind: Exclude<CourseCell, null>;
  object: THREE.Object3D;
  distance: number;
  lane: Lane;
  baseY: number;
  consumed: boolean;
}

interface Burst {
  mesh: THREE.Mesh<THREE.TorusGeometry, THREE.MeshBasicMaterial>;
  age: number;
}

const BEST_SCORE_KEY = "sobaya-beer-run.best.v1";
const CAMERA_TARGET = new THREE.Vector3();
const TEMP_COLOR = new THREE.Color();

export class BeerRunnerGame {
  private readonly root: HTMLElement;
  private readonly canvas: HTMLCanvasElement;
  private readonly renderer: THREE.WebGLRenderer;
  private readonly scene = new THREE.Scene();
  private readonly camera = new THREE.PerspectiveCamera(56, 1, 0.1, 650);
  private readonly audio = new RunnerAudio();
  private readonly world = new THREE.Group();
  private readonly courseGroup = new THREE.Group();
  private readonly player = new THREE.Group();
  private readonly playerPlaceholder = new THREE.Group();
  private readonly carryMugs: THREE.Object3D[] = [];
  private readonly cameos: LoadedVoxelCharacter[] = [];
  private readonly bursts: Burst[] = [];
  private readonly beerTemplate = this.createBeerMug();
  private readonly crateTemplate = this.createCrate();
  private readonly barrelTemplate = this.createBarrel();

  private playerCharacter?: LoadedVoxelCharacter;
  private entities: TrackEntity[] = [];
  private phase: Phase = "title";
  private elapsed = 0;
  private distance = 0;
  private targetLaneIndex = 1;
  private carry = 0;
  private served = 0;
  private chain = 0;
  private bestChain = 0;
  private juggleCount = 0;
  private hits = 0;
  private feverTime = 0;
  private hitTime = 0;
  private finalRushAnnounced = false;
  private pointerStart?: { x: number; y: number };
  private lastFrameTime = performance.now();

  private readonly hud: HTMLElement;
  private readonly titleOverlay: HTMLElement;
  private readonly pauseOverlay: HTMLElement;
  private readonly resultOverlay: HTMLElement;
  private readonly timerText: HTMLElement;
  private readonly servedText: HTMLElement;
  private readonly mugText: HTMLElement;
  private readonly chainText: HTMLElement;
  private readonly feverBar: HTMLElement;
  private readonly progressBar: HTMLElement;
  private readonly announcer: HTMLElement;
  private readonly floatText: HTMLElement;
  private readonly resultRank: HTMLElement;
  private readonly resultLabel: HTMLElement;
  private readonly resultServed: HTMLElement;
  private readonly resultStats: HTMLElement;
  private readonly resultBest: HTMLElement;
  private readonly okayamanQuote: HTMLElement;
  private readonly loadingText: HTMLElement;

  constructor(root: HTMLElement) {
    this.root = root;
    this.root.innerHTML = this.createInterface();

    const canvas = this.root.querySelector<HTMLCanvasElement>("canvas");
    if (!canvas) throw new Error("ゲームCanvasが見つかりません");
    this.canvas = canvas;

    this.hud = this.required(".hud");
    this.titleOverlay = this.required(".title-screen");
    this.pauseOverlay = this.required(".pause-screen");
    this.resultOverlay = this.required(".result-screen");
    this.timerText = this.required("[data-timer]");
    this.servedText = this.required("[data-served]");
    this.mugText = this.required("[data-mugs]");
    this.chainText = this.required("[data-chain]");
    this.feverBar = this.required("[data-fever-bar]");
    this.progressBar = this.required("[data-progress-bar]");
    this.announcer = this.required(".announcer");
    this.floatText = this.required(".pickup-float");
    this.resultRank = this.required("[data-result-rank]");
    this.resultLabel = this.required("[data-result-label]");
    this.resultServed = this.required("[data-result-served]");
    this.resultStats = this.required("[data-result-stats]");
    this.resultBest = this.required("[data-result-best]");
    this.okayamanQuote = this.required("[data-okayaman-quote]");
    this.loadingText = this.required("[data-loading]");

    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: true,
      powerPreference: "high-performance",
      alpha: false,
    });
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFShadowMap;
    this.renderer.setClearColor(0x8ccde0);

    this.scene.background = new THREE.Color(0x8ccde0);
    this.scene.fog = new THREE.Fog(0x8ccde0, 32, 105);
    this.scene.add(this.world);
    this.world.add(this.courseGroup, this.player);

    this.createLighting();
    this.createCity();
    this.createPlayerPlaceholder();
    this.createCarryRack();
    this.loadCharacters();
    this.bindEvents();
    this.resize();
    this.updateHud();
    this.animate();
  }

  private required<T extends HTMLElement = HTMLElement>(selector: string): T {
    const element = this.root.querySelector<T>(selector);
    if (!element) throw new Error(`${selector} が見つかりません`);
    return element;
  }

  private createInterface(): string {
    return `
      <main class="game-shell">
        <section class="game-viewport" aria-label="そば屋のビールダッシュ">
          <canvas aria-label="3レーンのビール回収ゲーム"></canvas>

          <div class="hud" aria-live="polite">
            <div class="hud-card hud-timer">
              <span class="hud-kicker">のこり</span>
              <strong data-timer>45.0</strong><span>秒</span>
            </div>
            <div class="hud-card hud-served">
              <span class="hud-kicker">本日の提供</span>
              <strong data-served>0</strong><span>杯</span>
            </div>
            <div class="hud-card hud-mugs">
              <span class="hud-kicker">ジョッキ</span>
              <strong data-mugs>0/6</strong>
            </div>
            <button class="pause-button" type="button" aria-label="一時停止">Ⅱ</button>
            <div class="run-progress" aria-hidden="true"><i data-progress-bar></i></div>
            <div class="fever-meter" aria-label="ジョッキtoジョッキ残り時間">
              <span>JUG TO JUG</span><i data-fever-bar></i>
            </div>
            <div class="chain-pill" data-chain>CHAIN 0</div>
          </div>

          <div class="announcer" role="status"></div>
          <div class="pickup-float" aria-hidden="true">+1</div>

          <div class="lane-controls" aria-label="移動ボタン">
            <button type="button" data-move="-1" aria-label="左のレーンへ">‹</button>
            <button type="button" data-move="1" aria-label="右のレーンへ">›</button>
          </div>

          <section class="screen title-screen is-visible">
            <div class="title-vignette"></div>
            <div class="title-copy">
              <p class="eyebrow">MADOGIWA 3-LANE RUNNER</p>
              <h1><span>そば屋の</span>ビールダッシュ</h1>
              <p class="title-sub">ジョッキtoジョッキで、本日開店！</p>
              <div class="title-rule">
                <span>← → で移動</span>
                <span>6杯でフィーバー</span>
                <span>45秒一本勝負</span>
              </div>
              <button class="primary-button" type="button" data-start>
                <span>開店準備をはじめる</span>
                <b>RUN!</b>
              </button>
              <p class="loading-note" data-loading>正典ボクセルを搬入中…</p>
            </div>
            <div class="live-action-tease">
              <span>ゴール判定</span>
              <b>実写</b>
            </div>
          </section>

          <section class="screen pause-screen">
            <div class="compact-panel">
              <p class="eyebrow">BREAK TIME</p>
              <h2>ちょっと休憩です！</h2>
              <button class="primary-button" type="button" data-resume>走りつづける</button>
              <button class="text-button" type="button" data-quit>タイトルへ</button>
            </div>
          </section>

          <section class="screen result-screen">
            <div class="result-layout">
              <div class="okayaman-monitor" aria-label="窓際会議室の大型スクリーン">
                <div class="monitor-header">
                  <span class="live-dot"></span> MADOGIWA LIVE
                </div>
                <div class="live-photo">
                  <img src="images/okayaman.jpg" alt="実写のおかやまん" />
                  <div class="scanlines"></div>
                  <span class="photo-label">窓際王 おかやまん</span>
                </div>
                <p data-okayaman-quote>おかやまん。大変驚いております。</p>
              </div>

              <div class="result-panel">
                <p class="eyebrow">本日の営業結果</p>
                <div class="rank-lockup">
                  <strong data-result-rank>S</strong>
                  <div>
                    <span>RANK</span>
                    <b data-result-label>大変驚いております</b>
                  </div>
                </div>
                <div class="result-score"><strong data-result-served>0</strong><span>杯 提供！</span></div>
                <p class="result-stats" data-result-stats></p>
                <p class="new-best" data-result-best></p>
                <div class="result-actions">
                  <button class="primary-button" type="button" data-retry>もう一杯！</button>
                  <button class="text-button" type="button" data-result-home>タイトルへ</button>
                </div>
              </div>
            </div>
          </section>
        </section>
      </main>
    `;
  }

  private createLighting(): void {
    const hemisphere = new THREE.HemisphereLight(0xe9f8ff, 0x6c7b58, 2.2);
    this.scene.add(hemisphere);

    const sun = new THREE.DirectionalLight(0xfff0cf, 3.2);
    sun.position.set(-12, 24, 11);
    sun.castShadow = true;
    sun.shadow.mapSize.set(1024, 1024);
    sun.shadow.camera.left = -12;
    sun.shadow.camera.right = 12;
    sun.shadow.camera.top = 15;
    sun.shadow.camera.bottom = -8;
    this.scene.add(sun);
  }

  private createCity(): void {
    const roadMaterial = new THREE.MeshStandardMaterial({ color: 0x263542, roughness: 0.9 });
    const road = new THREE.Mesh(
      new THREE.PlaneGeometry(8.6, FINISH_DISTANCE + 80),
      roadMaterial,
    );
    road.rotation.x = -Math.PI / 2;
    road.position.set(0, -0.035, -(FINISH_DISTANCE + 40) / 2);
    road.receiveShadow = true;
    this.world.add(road);

    const sidewalkMaterial = new THREE.MeshStandardMaterial({ color: 0xc7c9c3, roughness: 1 });
    for (const side of [-1, 1]) {
      const sidewalk = new THREE.Mesh(
        new THREE.BoxGeometry(5.8, 0.22, FINISH_DISTANCE + 80),
        sidewalkMaterial,
      );
      sidewalk.position.set(side * 7.2, -0.02, -(FINISH_DISTANCE + 40) / 2);
      sidewalk.receiveShadow = true;
      this.world.add(sidewalk);
    }

    const tapeMaterial = new THREE.MeshBasicMaterial({ color: 0xf9f1cf });
    for (let z = 4; z > -FINISH_DISTANCE - 20; z -= 5.5) {
      for (const x of [-1.18, 1.18]) {
        const tape = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.018, 2.7), tapeMaterial);
        tape.position.set(x, 0.01, z);
        this.world.add(tape);
      }
    }

    const curbMaterial = new THREE.MeshStandardMaterial({ color: 0x596773, roughness: 0.85 });
    for (const side of [-1, 1]) {
      const curb = new THREE.Mesh(
        new THREE.BoxGeometry(0.32, 0.34, FINISH_DISTANCE + 80),
        curbMaterial,
      );
      curb.position.set(side * 4.45, 0.08, -(FINISH_DISTANCE + 40) / 2);
      this.world.add(curb);
    }

    for (let index = 0; index < 30; index += 1) {
      const side = index % 2 === 0 ? -1 : 1;
      const width = 5.5 + (index % 4) * 1.2;
      const height = 10 + (index * 7) % 18;
      const depth = 7 + (index % 3) * 2.3;
      const building = new THREE.Mesh(
        new THREE.BoxGeometry(width, height, depth),
        new THREE.MeshStandardMaterial({
          color: TEMP_COLOR.setHSL(0.56 + (index % 5) * 0.015, 0.16, 0.42 + (index % 3) * 0.07),
          roughness: 0.82,
        }),
      );
      building.position.set(
        side * (9 + (index % 3) * 2.1),
        height / 2,
        -12 - index * 16,
      );
      building.castShadow = true;
      building.receiveShadow = true;
      this.world.add(building);

      const windowMaterial = new THREE.MeshBasicMaterial({
        color: index % 4 === 0 ? 0xffd67d : 0x9ed7e8,
      });
      for (let floor = 0; floor < 3; floor += 1) {
        const strip = new THREE.Mesh(
          new THREE.PlaneGeometry(width * 0.72, 0.45),
          windowMaterial,
        );
        strip.position.set(
          building.position.x - side * (width / 2 + 0.012),
          3 + floor * 2.5,
          building.position.z,
        );
        strip.rotation.y = side > 0 ? -Math.PI / 2 : Math.PI / 2;
        this.world.add(strip);
      }
    }

    this.createTokyoTower();
    this.createFinishArea();
  }

  private createTokyoTower(): void {
    const tower = new THREE.Group();
    tower.position.set(-14, 0, -FINISH_DISTANCE - 18);
    const red = new THREE.MeshStandardMaterial({ color: 0xf05036, emissive: 0x3d0d07 });
    const white = new THREE.MeshStandardMaterial({ color: 0xf7eee0 });

    const lower = new THREE.Mesh(new THREE.CylinderGeometry(0.8, 3.5, 16, 4, 1, true), red);
    lower.position.y = 8;
    lower.rotation.y = Math.PI / 4;
    tower.add(lower);
    const middle = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 1.25, 10, 4, 1, true), white);
    middle.position.y = 20;
    middle.rotation.y = Math.PI / 4;
    tower.add(middle);
    const spire = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.42, 10, 8), red);
    spire.position.y = 30;
    tower.add(spire);
    this.world.add(tower);
  }

  private createFinishArea(): void {
    const wood = new THREE.MeshStandardMaterial({ color: 0x8b4d29, roughness: 0.92 });
    const navy = new THREE.MeshStandardMaterial({ color: 0x102a4a, roughness: 0.78 });
    const lantern = new THREE.MeshStandardMaterial({
      color: 0xee3c27,
      emissive: 0x8a1007,
      emissiveIntensity: 0.8,
    });

    const gate = new THREE.Group();
    gate.position.z = -FINISH_DISTANCE;
    for (const x of [-4.05, 4.05]) {
      const post = new THREE.Mesh(new THREE.BoxGeometry(0.35, 4.8, 0.35), wood);
      post.position.set(x, 2.4, 0);
      gate.add(post);
    }
    const banner = new THREE.Mesh(new THREE.BoxGeometry(8.4, 1.18, 0.24), navy);
    banner.position.y = 4.45;
    gate.add(banner);
    const sign = this.createTextSprite("本 日 開 店", "#fff4cf", "rgba(0,0,0,0)");
    sign.position.set(0, 4.45, 0.16);
    sign.scale.set(4.1, 1, 1);
    gate.add(sign);
    for (const x of [-3.25, 3.25]) {
      const light = new THREE.Mesh(new THREE.SphereGeometry(0.36, 16, 12), lantern);
      light.scale.y = 1.25;
      light.position.set(x, 3.4, 0);
      gate.add(light);
    }
    this.world.add(gate);

    const stall = new THREE.Group();
    stall.position.set(7.2, 0, -FINISH_DISTANCE - 2);
    const counter = new THREE.Mesh(new THREE.BoxGeometry(5.2, 1.7, 2.7), wood);
    counter.position.y = 0.85;
    stall.add(counter);
    const roof = new THREE.Mesh(new THREE.BoxGeometry(6.1, 0.34, 3.6), navy);
    roof.position.y = 4.3;
    stall.add(roof);
    for (const x of [-2.35, 2.35]) {
      const post = new THREE.Mesh(new THREE.BoxGeometry(0.25, 4.2, 0.25), wood);
      post.position.set(x, 2.1, 0);
      stall.add(post);
    }
    const noren = new THREE.Mesh(new THREE.PlaneGeometry(4.2, 1.15), navy);
    noren.position.set(0, 3.48, 1.4);
    stall.add(noren);
    this.world.add(stall);
  }

  private createPlayerPlaceholder(): void {
    // そば屋のNG変更要素: 白い仮面と大型ビールジョッキを必ず維持する。
    const red = new THREE.MeshStandardMaterial({ color: 0xd83d31 });
    const skin = new THREE.MeshStandardMaterial({ color: 0xb88164 });
    const white = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.45 });
    const dark = new THREE.MeshStandardMaterial({ color: 0x15191d });

    const body = new THREE.Mesh(new THREE.BoxGeometry(1.35, 1.45, 0.78), red);
    body.position.y = 1.55;
    const head = new THREE.Mesh(new THREE.BoxGeometry(0.94, 0.9, 0.78), skin);
    head.position.y = 2.58;
    const mask = new THREE.Mesh(new THREE.BoxGeometry(0.82, 0.66, 0.08), white);
    mask.position.set(0, 2.58, -0.43);
    const leftEye = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.08, 0.04), dark);
    leftEye.position.set(-0.2, 2.66, -0.49);
    const rightEye = leftEye.clone();
    rightEye.position.x = 0.2;
    this.playerPlaceholder.add(body, head, mask, leftEye, rightEye);
    this.player.add(this.playerPlaceholder);
  }

  private createCarryRack(): void {
    for (let index = 0; index < 6; index += 1) {
      const mug = this.beerTemplate.clone(true);
      mug.scale.setScalar(0.3);
      const column = index % 3;
      const row = Math.floor(index / 3);
      mug.position.set((column - 1) * 0.62, 1.15 + row * 0.55, 0.72);
      mug.rotation.y = Math.PI;
      mug.visible = false;
      this.player.add(mug);
      this.carryMugs.push(mug);
    }
  }

  private loadCharacters(): void {
    loadVoxelCharacter({
      definition: runnerDefinition("models/sobaya.glb", 1.18, Math.PI),
      parent: this.player,
      onReady: (character) => {
        this.playerCharacter = character;
        this.playerPlaceholder.visible = false;
        this.loadingText.textContent = "正典ボクセル搬入完了！";
        this.loadingText.classList.add("is-ready");
      },
      onError: () => {
        this.loadingText.textContent = "予備のそば屋で出走できます！";
      },
    });

    this.loadCameo("models/tokun.glb", 1.05, -5.5, -7, Math.PI / 2, "ALOHA!");
    this.loadCameo("models/fukuchan.glb", 1.05, 5.7, -210, -Math.PI / 2, "ギュンギュン！");
    this.loadCameo("models/takosan.glb", 0.96, 5.7, -FINISH_DISTANCE + 2, -Math.PI / 2, "……乾杯");
  }

  private loadCameo(
    url: string,
    scale: number,
    x: number,
    z: number,
    rotationY: number,
    label: string,
  ): void {
    const holder = new THREE.Group();
    holder.position.set(x, 0, z);
    this.world.add(holder);
    loadVoxelCharacter({
      definition: runnerDefinition(url, scale, rotationY),
      parent: holder,
      onReady: (character) => {
        this.cameos.push(character);
        const sprite = this.createTextSprite(label, "#fff7d0", "rgba(9,30,48,.82)");
        sprite.position.y = 4.1;
        sprite.scale.set(2.4, 0.72, 1);
        holder.add(sprite);
      },
    });
  }

  private bindEvents(): void {
    this.required<HTMLButtonElement>("[data-start]").addEventListener("click", () => {
      void this.startFromTitle();
    });
    this.required<HTMLButtonElement>("[data-retry]").addEventListener("click", () => this.startRun());
    this.required<HTMLButtonElement>("[data-resume]").addEventListener("click", () => this.resume());
    this.required<HTMLButtonElement>("[data-quit]").addEventListener("click", () => this.showTitle());
    this.required<HTMLButtonElement>("[data-result-home]").addEventListener("click", () => this.showTitle());
    this.required<HTMLButtonElement>(".pause-button").addEventListener("click", () => this.pause());

    this.root.querySelectorAll<HTMLButtonElement>("[data-move]").forEach((button) => {
      button.addEventListener("pointerdown", (event) => {
        event.preventDefault();
        event.stopPropagation();
        this.moveLane(Number(button.dataset.move) < 0 ? -1 : 1);
      });
    });

    window.addEventListener("keydown", (event) => {
      if (event.key === "ArrowLeft" || event.key.toLowerCase() === "a") {
        event.preventDefault();
        this.moveLane(-1);
      } else if (event.key === "ArrowRight" || event.key.toLowerCase() === "d") {
        event.preventDefault();
        this.moveLane(1);
      } else if (event.key.toLowerCase() === "p" || event.key === "Escape") {
        event.preventDefault();
        if (this.phase === "playing") this.pause();
        else if (this.phase === "paused") this.resume();
      }
    });

    this.canvas.addEventListener("pointerdown", (event) => {
      this.pointerStart = { x: event.clientX, y: event.clientY };
    });
    this.canvas.addEventListener("pointerup", (event) => {
      if (!this.pointerStart || this.phase !== "playing") return;
      const deltaX = event.clientX - this.pointerStart.x;
      const deltaY = event.clientY - this.pointerStart.y;
      const bounds = this.canvas.getBoundingClientRect();
      if (Math.abs(deltaX) > 28 && Math.abs(deltaX) > Math.abs(deltaY)) {
        this.moveLane(deltaX < 0 ? -1 : 1);
      } else {
        this.moveLane(event.clientX < bounds.left + bounds.width / 2 ? -1 : 1);
      }
      this.pointerStart = undefined;
    });

    window.addEventListener("resize", () => this.resize());
    document.addEventListener("visibilitychange", () => {
      if (document.hidden && this.phase === "playing") this.pause();
    });
  }

  private async startFromTitle(): Promise<void> {
    this.audio.unlock();
    const startButton = this.required<HTMLButtonElement>("[data-start]");
    startButton.disabled = true;
    await playCutscene(this.root, { src: "videos/opening.mp4" });
    startButton.disabled = false;
    this.startRun();
  }

  private startRun(): void {
    this.audio.unlock();
    this.phase = "playing";
    this.elapsed = 0;
    this.distance = 0;
    this.targetLaneIndex = 1;
    this.carry = 0;
    this.served = 0;
    this.chain = 0;
    this.bestChain = 0;
    this.juggleCount = 0;
    this.hits = 0;
    this.feverTime = 0;
    this.hitTime = 0;
    this.finalRushAnnounced = false;
    this.player.position.set(0, 0, 0);
    this.player.rotation.set(0, 0, 0);
    this.camera.position.set(0, 4.8, 8.8);
    this.createCourse(Date.now() & 0xfffffff);
    this.updateCarryRack();
    this.updateHud();
    this.titleOverlay.classList.remove("is-visible");
    this.pauseOverlay.classList.remove("is-visible");
    this.resultOverlay.classList.remove("is-visible");
    this.hud.classList.add("is-visible");
    this.audio.setPlaying(true);
    this.showAnnouncement("開店準備、スタート！", "gold");
  }

  private createCourse(seed: number): void {
    this.courseGroup.clear();
    this.entities = [];
    const rows = buildCourse(seed);
    for (const row of rows) {
      row.cells.forEach((cell, laneIndex) => {
        if (!cell) return;
        const lane = (laneIndex - 1) as Lane;
        const template = cell === "beer"
          ? this.beerTemplate
          : cell === "crate"
            ? this.crateTemplate
            : this.barrelTemplate;
        const object = template.clone(true);
        const baseY = cell === "beer" ? 1.05 : cell === "crate" ? 0.66 : 0.62;
        object.position.set(LANE_X[laneIndex], baseY, -row.distance);
        object.visible = true;
        this.courseGroup.add(object);
        this.entities.push({
          kind: cell,
          object,
          distance: row.distance,
          lane,
          baseY,
          consumed: false,
        });
      });
    }
  }

  private moveLane(direction: -1 | 1): void {
    if (this.phase !== "playing") return;
    this.targetLaneIndex = THREE.MathUtils.clamp(this.targetLaneIndex + direction, 0, 2);
  }

  private pause(): void {
    if (this.phase !== "playing") return;
    this.phase = "paused";
    this.audio.setPlaying(false);
    this.pauseOverlay.classList.add("is-visible");
  }

  private resume(): void {
    if (this.phase !== "paused") return;
    this.phase = "playing";
    this.audio.unlock();
    this.audio.setPlaying(true);
    this.pauseOverlay.classList.remove("is-visible");
    this.lastFrameTime = performance.now();
  }

  private showTitle(): void {
    this.phase = "title";
    this.audio.setPlaying(false);
    this.hud.classList.remove("is-visible");
    this.pauseOverlay.classList.remove("is-visible");
    this.resultOverlay.classList.remove("is-visible");
    this.titleOverlay.classList.add("is-visible");
    this.distance = 0;
    this.player.position.set(0, 0, 0);
    this.player.rotation.set(0, 0, 0);
  }

  private animate = (): void => {
    requestAnimationFrame(this.animate);
    const frameTime = performance.now();
    const dt = Math.min((frameTime - this.lastFrameTime) / 1000, 0.05);
    const visualTime = frameTime / 1000;
    this.lastFrameTime = frameTime;

    if (this.phase === "playing") this.updateRun(dt);
    else this.updateIdle(dt, visualTime);

    this.updateEffects(dt);
    this.updateCamera(dt);
    this.renderer.render(this.scene, this.camera);
  };

  private updateRun(dt: number): void {
    this.elapsed = Math.min(RUN_DURATION, this.elapsed + dt);
    this.audio.update(dt);
    this.feverTime = Math.max(0, this.feverTime - dt);
    this.hitTime = Math.max(0, this.hitTime - dt);

    const penalty = this.hitTime > 0 ? 0.42 : 1;
    this.distance += speedAt(this.elapsed) * penalty * dt;
    this.player.position.z = -this.distance;
    this.player.position.x = THREE.MathUtils.damp(
      this.player.position.x,
      LANE_X[this.targetLaneIndex],
      18,
      dt,
    );
    this.player.position.y = Math.abs(Math.sin(this.elapsed * 10.5)) * 0.055;
    this.player.rotation.z = this.hitTime > 0
      ? Math.sin(this.hitTime * 38) * this.hitTime * 0.46
      : THREE.MathUtils.damp(this.player.rotation.z, 0, 14, dt);

    this.playerCharacter?.mixer?.update(dt);
    this.playerCharacter?.actions?.update(dt, this.elapsed, true);
    this.cameos.forEach((cameo) => {
      cameo.mixer?.update(dt);
      cameo.actions?.update(dt, this.elapsed, false);
    });

    this.updateEntities(dt);

    if (!this.finalRushAnnounced && this.distance >= FINAL_RUSH_START) {
      this.finalRushAnnounced = true;
      this.showAnnouncement("乾杯ラッシュ！", "red");
      this.root.classList.add("is-final-rush");
    }

    this.updateHud();
    if (this.elapsed >= RUN_DURATION) this.finishRun();
  }

  private updateIdle(dt: number, visualTime: number): void {
    this.playerCharacter?.mixer?.update(dt);
    this.playerCharacter?.actions?.update(dt, visualTime, false);
    this.cameos.forEach((cameo) => {
      cameo.mixer?.update(dt);
      cameo.actions?.update(dt, visualTime, false);
    });
    this.player.position.y = Math.sin(visualTime * 2.1) * 0.025;
  }

  private updateEntities(dt: number): void {
    for (const entity of this.entities) {
      if (entity.consumed) continue;
      const delta = entity.distance - this.distance;
      if (delta < -3.5) continue;

      if (entity.kind === "beer") {
        entity.object.rotation.y += dt * 2.8;
        entity.object.position.y = entity.baseY + Math.sin(this.elapsed * 5 + entity.distance) * 0.13;
        if (this.feverTime > 0 && delta > -0.8 && delta < 9) {
          entity.object.position.x = THREE.MathUtils.damp(
            entity.object.position.x,
            this.player.position.x,
            10,
            dt,
          );
        }
      } else if (entity.kind === "barrel") {
        entity.object.rotation.x += dt * 1.4;
      }

      if (Math.abs(delta) > 0.82) continue;
      const laneDistance = Math.abs(entity.object.position.x - this.player.position.x);
      if (laneDistance > (entity.kind === "beer" ? 0.88 : 0.82)) continue;

      entity.consumed = true;
      entity.object.visible = false;
      if (entity.kind === "beer") this.collectBeer();
      else this.hitObstacle();
    }
  }

  private collectBeer(): void {
    const multiplier = this.feverTime > 0 ? 2 : 1;
    this.served += multiplier;
    this.chain += 1;
    this.bestChain = Math.max(this.bestChain, this.chain);
    this.audio.collect(this.chain);
    this.showPickup(multiplier);

    if (this.feverTime <= 0) {
      this.carry += 1;
      if (this.carry >= 6) {
        this.carry = 0;
        this.juggleCount += 1;
        this.feverTime = 3;
        this.audio.juggle();
        this.createJuggleBurst();
        this.showAnnouncement("ジョッキtoジョッキ！", "gold");
      }
    }
    this.updateCarryRack();
  }

  private hitObstacle(): void {
    if (this.hitTime > 0) return;
    this.hitTime = 0.78;
    this.hits += 1;
    this.chain = 0;
    this.carry = Math.max(0, this.carry - 1);
    this.audio.hit();
    this.updateCarryRack();
    this.showAnnouncement("セーフ！ まだ快適です！", "blue");
  }

  private finishRun(): void {
    if (this.phase !== "playing") return;
    this.phase = "result";
    this.audio.setPlaying(false);
    this.audio.finish();
    this.root.classList.remove("is-final-rush");
    this.hud.classList.remove("is-visible");

    const rank = rankFor(this.served);
    const previousBest = this.readBest();
    const newBest = this.served > previousBest;
    if (newBest) this.writeBest(this.served);
    const result: RunResult = {
      served: this.served,
      bestChain: this.bestChain,
      juggleCount: this.juggleCount,
      hits: this.hits,
      rank,
      newBest,
    };
    this.showResult(result);
  }

  private showResult(result: RunResult): void {
    this.resultRank.textContent = result.rank;
    this.resultLabel.textContent = rankLabel(result.rank);
    this.resultServed.textContent = String(result.served);
    this.resultStats.textContent =
      `最大チェイン ${result.bestChain} ／ ジョッキtoジョッキ ${result.juggleCount}回 ／ 接触 ${result.hits}回`;
    this.resultBest.textContent = result.newBest ? "NEW BEST! 本日の記録を更新しました！" : "";

    const detail = result.rank === "S"
      ? `提供${result.served}杯。これは弊社のレギュレーションを超える大繁盛です。`
      : result.rank === "A"
        ? `提供${result.served}杯。立ち飲み処が大繁盛で、大変驚いております。`
        : result.rank === "B"
          ? `提供${result.served}杯。常連のみなさんが笑顔で、大変驚いております。`
          : `提供${result.served}杯。もう一杯いけそうで、大変驚いております。`;
    this.okayamanQuote.textContent = `おかやまん。${detail}`;
    this.resultOverlay.classList.add("is-visible");
  }

  private updateHud(): void {
    const remaining = Math.max(0, RUN_DURATION - this.elapsed);
    this.timerText.textContent = remaining.toFixed(1);
    this.servedText.textContent = String(this.served);
    this.mugText.textContent = `${this.carry}/6`;
    this.chainText.textContent = `CHAIN ${this.chain}`;
    this.chainText.classList.toggle("is-hot", this.chain >= 8);
    this.feverBar.style.transform = `scaleX(${this.feverTime / 3})`;
    this.feverBar.parentElement?.classList.toggle("is-active", this.feverTime > 0);
    this.progressBar.style.transform = `scaleX(${this.elapsed / RUN_DURATION})`;
  }

  private updateCarryRack(): void {
    this.carryMugs.forEach((mug, index) => {
      mug.visible = index < this.carry;
    });
  }

  private showPickup(value: number): void {
    this.floatText.textContent = `+${value}`;
    this.floatText.classList.remove("is-showing");
    void this.floatText.offsetWidth;
    this.floatText.classList.add("is-showing");
  }

  private showAnnouncement(message: string, tone: "gold" | "blue" | "red"): void {
    this.announcer.textContent = message;
    this.announcer.dataset.tone = tone;
    this.announcer.classList.remove("is-showing");
    void this.announcer.offsetWidth;
    this.announcer.classList.add("is-showing");
  }

  private createJuggleBurst(): void {
    const material = new THREE.MeshBasicMaterial({
      color: 0xffd447,
      transparent: true,
      opacity: 1,
      depthWrite: false,
    });
    const ring = new THREE.Mesh(new THREE.TorusGeometry(1.05, 0.12, 10, 36), material);
    ring.rotation.x = Math.PI / 2;
    ring.position.set(this.player.position.x, 1.3, this.player.position.z - 0.5);
    this.world.add(ring);
    this.bursts.push({ mesh: ring, age: 0 });
  }

  private updateEffects(dt: number): void {
    for (let index = this.bursts.length - 1; index >= 0; index -= 1) {
      const burst = this.bursts[index];
      burst.age += dt;
      const scale = 1 + burst.age * 5;
      burst.mesh.scale.setScalar(scale);
      burst.mesh.material.opacity = Math.max(0, 1 - burst.age * 1.8);
      if (burst.age > 0.58) {
        this.world.remove(burst.mesh);
        burst.mesh.geometry.dispose();
        burst.mesh.material.dispose();
        this.bursts.splice(index, 1);
      }
    }
  }

  private updateCamera(dt: number): void {
    const playerZ = this.phase === "title" ? 0 : this.player.position.z;
    const desiredX = this.player.position.x * 0.23;
    this.camera.position.x = THREE.MathUtils.damp(this.camera.position.x, desiredX, 5, dt);
    this.camera.position.y = THREE.MathUtils.damp(
      this.camera.position.y,
      this.phase === "title" ? 4.45 : 4.8,
      5,
      dt,
    );
    this.camera.position.z = THREE.MathUtils.damp(
      this.camera.position.z,
      playerZ + (this.phase === "title" ? 9.8 : 8.8),
      10,
      dt,
    );
    CAMERA_TARGET.set(this.player.position.x * 0.38, 1.45, playerZ - 10.5);
    this.camera.lookAt(CAMERA_TARGET);
  }

  private resize(): void {
    const bounds = this.canvas.parentElement?.getBoundingClientRect();
    if (!bounds) return;
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.75));
    this.renderer.setSize(bounds.width, bounds.height, false);
    this.camera.aspect = bounds.width / bounds.height;
    this.camera.fov = bounds.width < 600 ? 66 : 56;
    this.camera.updateProjectionMatrix();
  }

  private createBeerMug(): THREE.Group {
    const group = new THREE.Group();
    const glass = new THREE.MeshStandardMaterial({
      color: 0xf7ae22,
      emissive: 0x8c4300,
      emissiveIntensity: 0.34,
      roughness: 0.28,
      metalness: 0.05,
    });
    const foam = new THREE.MeshStandardMaterial({
      color: 0xfff9de,
      emissive: 0x6a5932,
      emissiveIntensity: 0.08,
      roughness: 0.85,
    });
    const body = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.29, 0.82, 14), glass);
    body.castShadow = true;
    const top = new THREE.Mesh(new THREE.CylinderGeometry(0.36, 0.36, 0.16, 14), foam);
    top.position.y = 0.46;
    const handle = new THREE.Mesh(new THREE.TorusGeometry(0.28, 0.075, 8, 16), glass);
    handle.position.set(0.34, 0.02, 0);
    handle.rotation.y = Math.PI / 2;
    group.add(body, top, handle);
    return group;
  }

  private createCrate(): THREE.Group {
    const group = new THREE.Group();
    const material = new THREE.MeshStandardMaterial({ color: 0xc57a38, roughness: 0.92 });
    const tape = new THREE.MeshStandardMaterial({ color: 0xf4e4bd, roughness: 0.78 });
    const box = new THREE.Mesh(new THREE.BoxGeometry(1.5, 1.3, 1.15), material);
    box.castShadow = true;
    box.receiveShadow = true;
    const stripe = new THREE.Mesh(new THREE.BoxGeometry(0.22, 1.33, 1.18), tape);
    stripe.position.x = 0.2;
    group.add(box, stripe);
    return group;
  }

  private createBarrel(): THREE.Group {
    const group = new THREE.Group();
    const metal = new THREE.MeshStandardMaterial({
      color: 0x9ca9ae,
      metalness: 0.58,
      roughness: 0.38,
    });
    const band = new THREE.MeshStandardMaterial({ color: 0x344653, metalness: 0.4 });
    const barrel = new THREE.Mesh(new THREE.CylinderGeometry(0.58, 0.58, 1.25, 16), metal);
    barrel.rotation.z = Math.PI / 2;
    barrel.castShadow = true;
    const ringA = new THREE.Mesh(new THREE.TorusGeometry(0.6, 0.07, 8, 18), band);
    ringA.rotation.y = Math.PI / 2;
    ringA.position.x = -0.42;
    const ringB = ringA.clone();
    ringB.position.x = 0.42;
    group.add(barrel, ringA, ringB);
    return group;
  }

  private createTextSprite(
    text: string,
    color: string,
    background: string,
  ): THREE.Sprite {
    const canvas = document.createElement("canvas");
    canvas.width = 512;
    canvas.height = 128;
    const context = canvas.getContext("2d");
    if (!context) return new THREE.Sprite();
    context.clearRect(0, 0, canvas.width, canvas.height);
    context.fillStyle = background;
    this.roundRect(context, 4, 4, 504, 120, 28);
    context.fill();
    context.font = "900 58px system-ui, sans-serif";
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillStyle = color;
    context.fillText(text, 256, 67);
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    const material = new THREE.SpriteMaterial({ map: texture, transparent: true, depthTest: false });
    return new THREE.Sprite(material);
  }

  private roundRect(
    context: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
    radius: number,
  ): void {
    context.beginPath();
    context.roundRect(x, y, width, height, radius);
  }

  private readBest(): number {
    try {
      return Number(localStorage.getItem(BEST_SCORE_KEY) ?? 0);
    } catch {
      return 0;
    }
  }

  private writeBest(score: number): void {
    try {
      localStorage.setItem(BEST_SCORE_KEY, String(score));
    } catch {
      // Private browsing may reject storage; the current run still completes normally.
    }
  }
}
