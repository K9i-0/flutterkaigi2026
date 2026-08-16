export const characters = [
  { name: "そば屋", role: "窓際族 / 立ち飲み処 店主", image: "/site/characters/sobaya.webp", copy: "見た目は怖いが、穏やかでマイペース。今日も窓際でビールを注ぐ。" },
  { name: "福ちゃん", role: "窓際族", image: "/site/characters/fukuchan.webp", copy: "いつでも自然体。窓際の日常を明るくするムードメーカー。" },
  { name: "とーくん", role: "社長", image: "/site/characters/tokun.webp", copy: "アロハとウクレレがトレードマークの陽気な社長。" },
  { name: "よーたん", role: "CTO", image: "/site/characters/yotan.webp", copy: "金髪ロックな技術責任者。ギターと新技術を愛している。" },
  { name: "無職やめたろう", role: "逃走中", image: "/site/characters/yametaro.webp", copy: "紫のシャツと眼鏡が目印。窓際から始まる騒動の中心人物。" },
  { name: "窓際王おかやまん", role: "窓際王", image: "/site/characters/okayaman.webp", copy: "すべての窓際族を静かに見守る、伝説の王。" },
  { name: "タコさん", role: "謎の宇宙人", image: "/site/characters/takosan.webp", copy: "フードと触手を持つ謎の存在。タコ部屋からやってきた。" },
  { name: "ゆめみん", role: "夢の案内役", image: "/site/characters/yumemin.webp", copy: "空を飛ぶ青いバク。大きなハンマーを携え、夢を渡り歩く。" },
] as const;

export const comicEpisodes = [
  "入社", "僕の席", "ベランダ席", "立ち飲み処 開店", "ビールサーバ到着", "お店落下", "片付けと福ちゃん生存確認",
  "お店の再建", "正体バレ", "逃走", "タコ部屋に連行", "脱走", "窓際王おかやまん", "BONK",
].map((title, index) => ({
  number: index + 1,
  title,
  image: `/site/comic/episode-${String(index + 1).padStart(2, "0")}.webp`,
}));

export const galleryItems = [
  { title: "規制チーム、出動。", image: "/site/gallery/regulation-team.webp", kind: "KEY VISUAL" },
  { title: "Soba Shark", image: "/site/gallery/soba-shark.webp", kind: "SPECIAL ART" },
  { title: "タコさんの故郷", image: "/site/gallery/takosan-homeworld.webp", kind: "WORLD ART" },
  { title: "窓際族物語 一番くじ", image: "/site/gallery/ichiban-kuji.webp", kind: "COLLABORATION" },
] as const;

export const articles = [
  { label: "MAKING", title: "AI映像でつくる『窓際族物語』", copy: "Seedanceと制作アーカイブで、物語を育て続けるための舞台裏。" },
  { label: "VOICE", title: "キャラクターの声を保つ", copy: "Irodori-TTSと参照音声を使った、エピソードをまたぐ声づくり。" },
  { label: "TECHNOLOGY", title: "Cloudflareで育てる作品世界", copy: "動画・素材・プロンプトをひとつにつなぐMadogiwa Studioの設計。" },
] as const;
