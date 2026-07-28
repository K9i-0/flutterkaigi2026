import { playCutscene } from "./cutscene";
import type { Direction, EndingKind, Item, ItemId, MapDefinition, MapId, Phase, Position } from "./types";

const ITEMS: Item[] = [
  { id: "happoshu", name: "発泡酒", price: 80, note: "軽やか。あの日の記憶がよみがえる味。" },
  { id: "third", name: "第三のビール", price: 100, note: "財布にはやさしい。魔王には未知数。" },
  { id: "nonAlcohol", name: "ノンアルビール", price: 120, note: "冒険中にも安心。泡はとても立派。" },
  { id: "superDry", name: "スーパードライ", price: 300, note: "キレ味するどい王道の一杯。" },
  { id: "yebisu", name: "エビス", price: 450, note: "黄金色に輝く、ちょっとぜいたくな一杯。" },
  { id: "premiumMalts", name: "プレモル", price: 400, note: "華やかな香りのプレミアムな一杯。" },
];

const MAPS: Record<MapId, MapDefinition> = {
  castle: {
    id: "castle",
    name: "ギュンギュン城",
    hint: "福ちゃん王に話しかけよう",
    start: { x: 5, y: 6 },
    tiles: [
      "###########",
      "#....K....#",
      "#.........#",
      "#..##.##..#",
      "#.........#",
      "#.........#",
      "#####D#####",
      "#####.#####",
    ],
  },
  town: {
    id: "town",
    name: "ギュンギュン王国",
    hint: "道具屋でビールを選ぼう",
    start: { x: 5, y: 6 },
    tiles: [
      "###########",
      "#...S.....#",
      "#.hhhhh...#",
      "#.........#",
      "#...f.....#",
      "#.........#",
      "#####C#####",
      "#####.#####",
    ],
  },
  field: {
    id: "field",
    name: "ギュンギュン平原",
    hint: "北東の洞窟を目指そう",
    start: { x: 1, y: 6 },
    tiles: [
      "###########",
      "#.......V.#",
      "#.~~~..##.#",
      "#...~.....#",
      "#...~.~~..#",
      "#.........#",
      "#.........#",
      "###########",
    ],
  },
  cave: {
    id: "cave",
    name: "泡なき洞窟",
    hint: "一本道の奥へ進もう",
    start: { x: 1, y: 6 },
    tiles: [
      "###########",
      "########.B#",
      "########.##",
      "####......#",
      "####.######",
      "#....######",
      "#.#########",
      "###########",
    ],
  },
  throne: {
    id: "throne",
    name: "魔王の間",
    hint: "そば屋に話しかけよう",
    start: { x: 5, y: 6 },
    tiles: [
      "###########",
      "#....M....#",
      "#.........#",
      "#.t.....t.#",
      "#.........#",
      "#.........#",
      "#####.#####",
      "###########",
    ],
  },
};

const WALKABLE = new Set([".", "D", "C", "V", "B", "S", "K", "M", "f"]);
const ENEMY_IDLE = [
  "ぼーっと窓の外をながめている。",
  "遠くの雲を数えている。",
  "なにもしない。じつに窓際らしい。",
  "定時まであと何分か考えている。",
  "どこか一点を静かに見つめている。",
];

export class GyunGyunQuest {
  private phase: Phase = "title";
  private mapId: MapId = "castle";
  private player: Position = { ...MAPS.castle.start };
  private direction: Direction = "up";
  private money = 0;
  private inventory: ItemId[] = [];
  private hasFunds = false;
  private steps = 0;
  private encounters = 0;
  private battleTurns = 0;
  private battleEnemy = "";
  private message = "";

  constructor(private readonly root: HTMLElement) {
    this.onKeyDown = this.onKeyDown.bind(this);
    window.addEventListener("keydown", this.onKeyDown);
    this.render();
  }

  private async start(): Promise<void> {
    if (this.phase !== "title") return;
    await playCutscene(this.root, { src: "videos/opening.mp4" });
    this.phase = "dialog";
    this.message = "発泡酒を出されて怒ったそば屋は、ついに魔王となった。人類の希望は、たこさんに託された！";
    this.renderDialog("ものがたり", this.message, () => {
      this.phase = "map";
      this.render();
    });
  }

  private reset(): void {
    this.phase = "title";
    this.mapId = "castle";
    this.player = { ...MAPS.castle.start };
    this.direction = "up";
    this.money = 0;
    this.inventory = [];
    this.hasFunds = false;
    this.steps = 0;
    this.encounters = 0;
    this.battleTurns = 0;
    this.render();
  }

  private onKeyDown(event: KeyboardEvent): void {
    if (this.phase !== "map") return;
    const keyDirections: Record<string, Direction | undefined> = {
      ArrowUp: "up",
      w: "up",
      W: "up",
      ArrowDown: "down",
      s: "down",
      S: "down",
      ArrowLeft: "left",
      a: "left",
      A: "left",
      ArrowRight: "right",
      d: "right",
      D: "right",
    };
    const direction = keyDirections[event.key];
    if (direction) {
      event.preventDefault();
      this.move(direction);
      return;
    }
    if (event.key === "Enter" || event.key === " " || event.key.toLowerCase() === "z") {
      event.preventDefault();
      this.interact();
    }
  }

  private move(direction: Direction): void {
    if (this.phase !== "map") return;
    this.direction = direction;
    const delta: Record<Direction, Position> = {
      up: { x: 0, y: -1 },
      down: { x: 0, y: 1 },
      left: { x: -1, y: 0 },
      right: { x: 1, y: 0 },
    };
    const next = { x: this.player.x + delta[direction].x, y: this.player.y + delta[direction].y };
    const tile = MAPS[this.mapId].tiles[next.y]?.[next.x] ?? "#";
    if (!WALKABLE.has(tile)) {
      this.flash("そちらには進めない。");
      return;
    }
    this.player = next;
    this.steps += 1;
    this.onStep(tile);
    if (this.phase === "map") this.render();
  }

  private onStep(tile: string): void {
    if (this.mapId === "castle" && tile === "D") {
      if (!this.hasFunds) {
        this.flash("王さまに旅の相談をしてから出発しよう。");
        this.player = { x: 5, y: 5 };
      } else {
        this.enterMap("town", { x: 5, y: 6 });
      }
      return;
    }
    if (this.mapId === "town" && tile === "C") {
      this.enterMap("field", { x: 1, y: 6 });
      return;
    }
    if (this.mapId === "field" && tile === "V") {
      this.enterMap("cave", MAPS.cave.start);
      return;
    }
    if (this.mapId === "cave" && tile === "B") {
      this.enterMap("throne", MAPS.throne.start);
      return;
    }
    if ((this.mapId === "field" || this.mapId === "cave") && this.steps > 0 && this.steps % 7 === 0) {
      this.startBattle();
    }
  }

  private enterMap(mapId: MapId, position: Position): void {
    this.mapId = mapId;
    this.player = { ...position };
    this.flash(`${MAPS[mapId].name}に入った。`);
  }

  private interact(): void {
    if (this.phase !== "map") return;
    const delta: Record<Direction, Position> = {
      up: { x: 0, y: -1 },
      down: { x: 0, y: 1 },
      left: { x: -1, y: 0 },
      right: { x: 1, y: 0 },
    };
    const target = { x: this.player.x + delta[this.direction].x, y: this.player.y + delta[this.direction].y };
    const tile = MAPS[this.mapId].tiles[target.y]?.[target.x] ?? "#";
    if (tile === "K") {
      this.talkToKing();
    } else if (tile === "S") {
      this.openShop();
    } else if (tile === "M") {
      this.startBoss();
    } else {
      this.flash("そこには誰もいない。");
      this.render();
    }
  }

  private talkToKing(): void {
    this.phase = "dialog";
    if (!this.hasFunds) {
      this.hasFunds = true;
      this.money = 500;
      this.renderDialog(
        "ギュンギュン王・福ちゃん",
        "たこさん！ 魔王そば屋の怒りを鎮めて、世界をギュンジョイにしておくれ！ 旅の資金500円を授けよう。ギュンギュン！",
        () => {
          this.phase = "map";
          this.render();
        },
        "characters/fukuchan.jpg",
      );
    } else {
      this.renderDialog("福ちゃん", "最高の一杯が世界を救うはず。道具屋でよーく選ぶんだよ。ギュンギュン！", () => {
        this.phase = "map";
        this.render();
      }, "characters/fukuchan.jpg");
    }
  }

  private openShop(): void {
    this.phase = "shop";
    this.render();
  }

  private buy(item: Item): void {
    if (this.money < item.price) {
      this.flash("お金が足りない！");
      this.render();
      return;
    }
    this.money -= item.price;
    this.inventory.push(item.id);
    this.flash(`${item.name}を買った！`);
    this.render();
  }

  private startBattle(): void {
    this.phase = "battle";
    this.battleTurns = 0;
    this.battleEnemy = this.encounters++ % 2 === 0 ? "窓際見習い" : "ベテラン窓際";
    this.message = `${this.battleEnemy}が あらわれた！`;
    this.render();
  }

  private battleAction(action: string): void {
    this.battleTurns += 1;
    if (this.battleTurns >= 2) {
      this.message = `${this.battleEnemy}は定時になったので帰っていった。たこさんは経験値0を得た！`;
      this.render();
      window.setTimeout(() => {
        this.phase = "map";
        this.render();
      }, 1200);
      return;
    }
    const idle = ENEMY_IDLE[(this.steps + this.encounters + this.battleTurns) % ENEMY_IDLE.length];
    this.message = `たこさんは${action}。しかし ${this.battleEnemy}は ${idle}`;
    this.render();
  }

  private startBoss(): void {
    this.phase = "boss";
    this.message = "「発泡酒をビールと言うなあああ！」魔王そば屋の仮面が真っ赤に燃えた！";
    this.render();
  }

  private useBossItem(itemId: ItemId): void {
    const item = ITEMS.find((candidate) => candidate.id === itemId);
    if (!item) return;
    this.inventory.splice(this.inventory.indexOf(itemId), 1);
    if (itemId === "superDry") {
      this.showEnding("good");
    } else if (itemId === "yebisu") {
      this.showEnding("close");
    } else {
      this.showEnding("gameover");
    }
  }

  private showEnding(kind: EndingKind): void {
    this.phase = "ending";
    const data: Record<EndingKind, { title: string; text: string; image: string; badge: string }> = {
      good: {
        title: "GOOD END　キレ味で世界を救え！",
        text: "スーパードライの一口で、そば屋の仮面は真っ白に。魔王は立ち飲み処の店主へ戻り、たこさんと人類は笑顔で乾杯した。",
        image: "endings/good-end.png",
        badge: "世界はギュンジョイに包まれた",
      },
      close: {
        title: "ギリギリ CLEAR　黄金の休戦",
        text: "エビスの上品な味に、そば屋はひとまず納得。ただし「次はもっとキレのあるやつな！」――人類はギリギリ救われた。",
        image: "endings/close-end.png",
        badge: "人類、かろうじて生存",
      },
      gameover: {
        title: "GAME OVER　それじゃない！",
        text: "そば屋の仮面は真っ赤に発光！ たこさんは無傷で城へ逃げ帰り、世界はもう一度ビール選びからやり直すことになった。",
        image: "endings/game-over.png",
        badge: "正解の一杯を探そう",
      },
    };
    const ending = data[kind];
    this.root.innerHTML = `
      <section class="ending ending-${kind}">
        <img src="${ending.image}" alt="${ending.title}のピクセルアート" />
        <div class="ending-copy">
          <span>${ending.badge}</span>
          <h1>${ending.title.replace("　", "<br />")}</h1>
          <p>${ending.text}</p>
          <button class="rpg-button primary" data-action="restart">もう一度 冒険する</button>
        </div>
      </section>`;
    this.root.querySelector<HTMLButtonElement>("[data-action='restart']")?.addEventListener("click", () => this.reset());
  }

  private flash(message: string): void {
    this.message = message;
  }

  private render(): void {
    if (this.phase === "title") {
      this.renderTitle();
    } else if (this.phase === "map") {
      this.renderMap();
    } else if (this.phase === "shop") {
      this.renderShop();
    } else if (this.phase === "battle") {
      this.renderBattle();
    } else if (this.phase === "boss") {
      this.renderBoss();
    }
  }

  private renderTitle(): void {
    this.root.innerHTML = `
      <section class="title-screen">
        <div class="stars" aria-hidden="true"></div>
        <div class="title-emblem">
          <span class="title-kicker">MADOGIWA LEGEND</span>
          <h1>ギュンギュン<br /><strong>クエスト</strong></h1>
          <p>魔王そば屋と 最高の一杯</p>
        </div>
        <div class="title-party" aria-hidden="true">
          <span class="hero-sprite large"><i></i></span>
          <span class="mug-icon">🍺</span>
        </div>
        <button class="start-button" data-action="start"><span>▶</span> 冒険をはじめる</button>
        <small>音が出ます　／　オープニングはタップでスキップ</small>
      </section>`;
    this.root.querySelector<HTMLButtonElement>("[data-action='start']")?.addEventListener("click", () => void this.start());
  }

  private renderMap(): void {
    const map = MAPS[this.mapId];
    const tiles = map.tiles
      .flatMap((row, y) =>
        [...row].map((tile, x) => {
          const playerHere = this.player.x === x && this.player.y === y;
          const content = playerHere ? this.heroMarkup() : this.tileContent(tile);
          return `<div class="tile tile-${this.tileClass(tile)}" aria-hidden="true">${content}</div>`;
        }),
      )
      .join("");
    const inventoryNames = this.inventory.map((id) => ITEMS.find((item) => item.id === id)?.name).filter(Boolean);
    this.root.innerHTML = `
      <section class="game-shell">
        <header class="hud">
          <div><span>LV</span><strong>1</strong></div>
          <div class="hud-location"><span>現在地</span><strong>${map.name}</strong></div>
          <div><span>G</span><strong>${this.money}円</strong></div>
        </header>
        <div class="quest-strip"><span>目的</span>${map.hint}</div>
        <div class="map-wrap">
          <div class="map-grid" style="--cols:${map.tiles[0]?.length ?? 11}">${tiles}</div>
          <div class="map-vignette"></div>
        </div>
        <div class="message-bar">${this.message || "十字キーで移動　Aで話す・調べる"}</div>
        <div class="inventory-strip"><b>どうぐ</b>${inventoryNames.length ? inventoryNames.join("　") : "（からっぽ）"}</div>
        ${this.controlsMarkup()}
      </section>`;
    this.bindControls();
    this.message = "";
  }

  private renderDialog(speaker: string, text: string, onContinue: () => void, portrait?: string): void {
    this.root.innerHTML = `
      <section class="dialog-scene">
        ${portrait ? `<img class="dialog-portrait" src="${portrait}" alt="${speaker}" />` : `<div class="story-icon">◆</div>`}
        <div class="dialog-box">
          <h2>${speaker}</h2>
          <p>${text}</p>
          <button class="rpg-button primary" data-action="continue">つづける ▼</button>
        </div>
      </section>`;
    this.root.querySelector<HTMLButtonElement>("[data-action='continue']")?.addEventListener("click", onContinue);
  }

  private renderShop(): void {
    this.root.innerHTML = `
      <section class="panel-screen shop-screen">
        <header>
          <div><span class="sign-icon">酒</span><h1>ギュンギュン道具屋</h1></div>
          <strong>${this.money}円</strong>
        </header>
        <p class="shop-greeting">「魔王にも好みってものがあるからね。よーく選びな！」</p>
        <div class="shop-grid">
          ${ITEMS.map(
            (item) => `
              <button class="shop-item" data-buy="${item.id}" ${this.money < item.price ? "disabled" : ""}>
                <span class="can can-${item.id}"></span>
                <span><b>${item.name}</b><small>${item.note}</small></span>
                <em>${item.price}円</em>
              </button>`,
          ).join("")}
        </div>
        <div class="shop-footer"><span>${this.message}</span><button class="rpg-button" data-action="close-shop">店を出る</button></div>
      </section>`;
    this.root.querySelectorAll<HTMLButtonElement>("[data-buy]").forEach((button) => {
      button.addEventListener("click", () => {
        const item = ITEMS.find((candidate) => candidate.id === button.dataset.buy);
        if (item) this.buy(item);
      });
    });
    this.root.querySelector<HTMLButtonElement>("[data-action='close-shop']")?.addEventListener("click", () => {
      this.phase = "map";
      this.render();
    });
    this.message = "";
  }

  private renderBattle(): void {
    const veteran = this.battleEnemy === "ベテラン窓際";
    this.root.innerHTML = `
      <section class="battle-screen">
        <div class="battle-sky"><span class="cloud one"></span><span class="cloud two"></span></div>
        <div class="enemy ${veteran ? "veteran" : "trainee"}">
          <span class="window-frame"></span>
          <span class="office-person"><i></i></span>
          <b>${this.battleEnemy}</b>
        </div>
        <div class="battle-party">${this.heroMarkup()}</div>
        <div class="battle-box">
          <p>${this.message}</p>
          <div>
            <button data-battle="ようすを見た">ようすをみる</button>
            <button data-battle="そっと声をかけた">はなしかける</button>
          </div>
        </div>
      </section>`;
    this.root.querySelectorAll<HTMLButtonElement>("[data-battle]").forEach((button) => {
      button.addEventListener("click", () => this.battleAction(button.dataset.battle ?? "待った"));
    });
  }

  private renderBoss(): void {
    const inventoryItems = this.inventory
      .map((id, index) => {
        const item = ITEMS.find((candidate) => candidate.id === id);
        return item ? `<button class="boss-item" data-item="${id}" data-index="${index}"><span class="can can-${id}"></span>${item.name}</button>` : "";
      })
      .join("");
    this.root.innerHTML = `
      <section class="boss-screen">
        <div class="boss-aura"></div>
        <img src="characters/sobaya.jpg" alt="白い仮面と巨大ビールジョッキを持つ魔王そば屋" />
        <div class="boss-title"><span>FINAL BATTLE</span><h1>魔王 そば屋</h1></div>
        <div class="boss-command">
          <p>${this.message}</p>
          <h2>どの道具を使う？</h2>
          <div class="boss-items">${inventoryItems || "<em>使える道具がない！</em>"}</div>
          <button class="rpg-button retreat" data-action="retreat">城下町へ戻る</button>
        </div>
      </section>`;
    this.root.querySelectorAll<HTMLButtonElement>("[data-item]").forEach((button) => {
      button.addEventListener("click", () => this.useBossItem(button.dataset.item as ItemId));
    });
    this.root.querySelector<HTMLButtonElement>("[data-action='retreat']")?.addEventListener("click", () => {
      this.phase = "map";
      this.enterMap("town", { x: 5, y: 6 });
      this.render();
    });
  }

  private tileContent(tile: string): string {
    if (tile === "K") return `<span class="npc king"><i>福</i></span>`;
    if (tile === "S") return `<span class="building shop"><i>酒</i></span>`;
    if (tile === "V") return `<span class="cave-mouth"></span>`;
    if (tile === "M") return `<span class="boss-sprite"><i></i></span>`;
    if (tile === "f") return `<span class="fountain">♨</span>`;
    if (tile === "h") return `<span class="house"></span>`;
    if (tile === "t") return `<span class="torch">♨</span>`;
    return "";
  }

  private tileClass(tile: string): string {
    if (tile === "#") return "wall";
    if (tile === "~") return "water";
    if (tile === "D" || tile === "C" || tile === "B") return "path";
    return "ground";
  }

  private heroMarkup(): string {
    // NG変更: たこさんの黒いフード付きローブ・白い顔・タコの触手を維持する。
    return `<span class="hero-sprite facing-${this.direction}"><i></i></span>`;
  }

  private controlsMarkup(): string {
    return `
      <div class="mobile-controls" aria-label="ゲーム操作">
        <div class="dpad">
          <button data-dir="up" aria-label="上">▲</button>
          <button data-dir="left" aria-label="左">◀</button>
          <button data-dir="right" aria-label="右">▶</button>
          <button data-dir="down" aria-label="下">▼</button>
        </div>
        <button class="action-button" data-action="interact" aria-label="話す・調べる"><b>A</b><span>はなす</span></button>
      </div>`;
  }

  private bindControls(): void {
    this.root.querySelectorAll<HTMLButtonElement>("[data-dir]").forEach((button) => {
      button.addEventListener("click", () => this.move(button.dataset.dir as Direction));
    });
    this.root.querySelector<HTMLButtonElement>("[data-action='interact']")?.addEventListener("click", () => this.interact());
  }
}
