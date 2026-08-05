import { Application, Assets, Container, Sprite, Texture } from "pixi.js";
import { layerAssetUrls } from "./assets";
import { clamp, radians } from "./math";
import type { BackgroundMode, CheersMotion, LayerId, RigConfig, TrackingPose } from "./types";

interface RigNodes {
  body: Container;
  head: Container;
  mouth: Container;
  mug: Container;
  eyeLidL: Sprite;
  eyeLidR: Sprite;
  mouthSprite: Sprite;
}

const backgrounds: Record<BackgroundMode, string> = {
  studio: "studio",
  transparent: "transparent",
  green: "green",
  magenta: "magenta",
};

export class SobayaPuppet {
  readonly app = new Application();
  private readonly modelRoot = new Container();
  private readonly textures = new Map<LayerId, Texture>();
  private nodes: RigNodes | null = null;
  private elapsedSeconds = 0;
  private resizeObserver: ResizeObserver | null = null;
  private destroyed = false;

  constructor(
    private readonly mount: HTMLElement,
    private readonly config: RigConfig,
  ) {}

  async initialize(): Promise<void> {
    this.destroyed = false;
    await this.app.init({
      resizeTo: this.mount,
      antialias: true,
      autoDensity: true,
      backgroundAlpha: 0,
      resolution: Math.min(2, window.devicePixelRatio || 1),
      preference: "webgl",
    });
    this.app.canvas.className = "puppet-canvas";
    this.mount.append(this.app.canvas);

    const urls = Object.values(layerAssetUrls);
    await Assets.load(urls);
    for (const layer of this.config.layers) {
      this.textures.set(layer.id, Texture.from(layerAssetUrls[layer.id]));
    }

    this.buildRig();
    this.app.stage.addChild(this.modelRoot);
    this.app.stage.sortableChildren = true;
    this.fitToViewport();
    this.resizeObserver = new ResizeObserver(() => this.fitToViewport());
    this.resizeObserver.observe(this.mount);
  }

  private spriteFor(id: LayerId): Sprite {
    const texture = this.textures.get(id);
    if (!texture) throw new Error(`Missing texture for ${id}`);
    const sprite = new Sprite(texture);
    sprite.position.set(0, 0);
    return sprite;
  }

  private buildRig(): void {
    this.modelRoot.sortableChildren = true;
    this.modelRoot.pivot.set(this.config.canvas.width / 2, this.config.canvas.height / 2);

    const body = new Container();
    const head = new Container();
    const mouth = new Container();
    const mug = new Container();
    body.sortableChildren = true;
    head.sortableChildren = true;
    mouth.sortableChildren = true;
    mug.sortableChildren = true;

    const layerById = new Map(this.config.layers.map((layer) => [layer.id, layer]));
    const configurePivot = (container: Container, id: LayerId): void => {
      const [x, y] = layerById.get(id)?.pivot ?? [0, 0];
      container.pivot.set(x, y);
      container.position.set(x, y);
    };

    configurePivot(body, "body");
    configurePivot(head, "head");
    configurePivot(mouth, "mouth");
    configurePivot(mug, "mug");

    const bodySprite = this.spriteFor("body");
    const headSprite = this.spriteFor("head");
    const eyeLidL = this.spriteFor("eyeLidL");
    const eyeLidR = this.spriteFor("eyeLidR");
    const mouthSprite = this.spriteFor("mouth");
    const mugSprite = this.spriteFor("mug");

    bodySprite.zIndex = layerById.get("body")?.zIndex ?? 100;
    headSprite.zIndex = layerById.get("head")?.zIndex ?? 200;
    eyeLidL.zIndex = layerById.get("eyeLidL")?.zIndex ?? 240;
    eyeLidR.zIndex = layerById.get("eyeLidR")?.zIndex ?? 241;
    mouth.zIndex = layerById.get("mouth")?.zIndex ?? 250;
    mouthSprite.zIndex = 0;
    mugSprite.zIndex = layerById.get("mug")?.zIndex ?? 300;

    eyeLidL.alpha = 0;
    eyeLidR.alpha = 0;

    body.addChild(bodySprite);
    mouth.addChild(mouthSprite);
    head.addChild(headSprite, eyeLidL, eyeLidR, mouth);
    mug.addChild(mugSprite);
    this.modelRoot.addChild(body, head, mug);
    body.zIndex = 100;
    head.zIndex = 200;
    mug.zIndex = 300;

    this.nodes = { body, head, mouth, mug, eyeLidL, eyeLidR, mouthSprite };
  }

  private fitToViewport(): void {
    const { width, height } = this.mount.getBoundingClientRect();
    const fit = Math.min(width / this.config.canvas.width, height / this.config.canvas.height);
    const scale = fit * this.config.viewport.fit;
    this.modelRoot.scale.set(scale);
    this.modelRoot.position.set(
      width / 2,
      height * (0.5 + this.config.viewport.verticalOffset),
    );
  }

  applyPose(pose: TrackingPose, deltaMs: number, cheers: CheersMotion): void {
    if (this.destroyed || !this.nodes) return;
    this.elapsedSeconds += deltaMs / 1000;
    const { motion } = this.config;
    const breathing = (Math.sin(this.elapsedSeconds * 2.1) * 0.5 + 0.5) * pose.presence;

    this.nodes.head.position.set(
      this.config.layers.find((layer) => layer.id === "head")!.pivot[0] +
        pose.yaw * motion.headYawPixels,
      this.config.layers.find((layer) => layer.id === "head")!.pivot[1] +
        pose.pitch * motion.headPitchPixels - cheers.lift * 5,
    );
    this.nodes.head.rotation = radians(pose.roll * motion.headRollDegrees);
    this.nodes.head.scale.set(1 - Math.abs(pose.yaw) * 0.018, 1);

    const bodyPivot = this.config.layers.find((layer) => layer.id === "body")!.pivot;
    this.nodes.body.position.set(
      bodyPivot[0] + pose.faceX * motion.bodySwayPixels,
      bodyPivot[1] + pose.faceY * 5 - cheers.lift * 7,
    );
    this.nodes.body.rotation = radians(pose.roll * motion.bodyRollDegrees);
    this.nodes.body.scale.set(1 + breathing * motion.breathingScale * 0.35, 1 + breathing * motion.breathingScale);

    this.nodes.eyeLidL.alpha = clamp(1 - pose.eyeOpenL, 0, 1);
    this.nodes.eyeLidR.alpha = clamp(1 - pose.eyeOpenR, 0, 1);
    this.nodes.mouth.scale.set(1, 1 + pose.mouthOpen * motion.mouthOpenScale);
    this.nodes.mouthSprite.alpha = 0.86 + pose.mouthOpen * 0.14;

    const mugPivot = this.config.layers.find((layer) => layer.id === "mug")!.pivot;
    const mugIdle = Math.sin(this.elapsedSeconds * 2.1 + 0.4) * 2 * pose.presence;
    this.nodes.mug.position.set(
      mugPivot[0] + pose.faceX * 3 + cheers.lift * motion.cheersCenterPixels + cheers.clink * 8,
      mugPivot[1] + mugIdle + pose.pitch * motion.mugBouncePixels - cheers.lift * motion.cheersLiftPixels,
    );
    this.nodes.mug.rotation = radians(
      -pose.roll * 1.5 + cheers.lift * motion.cheersTiltDegrees + cheers.clink * 2.5,
    );
    this.nodes.mug.scale.set(1 + cheers.lift * motion.cheersScale);
  }

  setBackground(mode: BackgroundMode): void {
    this.mount.dataset.background = backgrounds[mode];
  }

  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    this.resizeObserver?.disconnect();
    this.resizeObserver = null;
    this.nodes = null;
    this.app.destroy(true, { children: true, texture: false });
  }
}
