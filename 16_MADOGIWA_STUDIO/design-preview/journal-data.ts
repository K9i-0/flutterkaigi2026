import {
  characters as baseCharacters,
  comicEpisodes,
} from "../src/lib/site-content";
import snapshot from "./episodes.json";
export { comicEpisodes };
export const episodes = snapshot.filter(
  (e) => e.primary_video_id && !e.title.includes("検証"),
);
export type Episode = (typeof episodes)[number];
export const starterSlugs = [
  "madogiwa-super-try-commute",
  "professional-window-side-sobaya",
  "yametaro-unauthorized-office-livestream",
];
export const cachedSlugs = [
  ...starterSlugs,
  "tako-game-dormitory",
  "madogiwa-super-try-keisha",
  "sobaya-never-drops-beer",
  "madogiwa-super-try-sobaya-invasion-trailer",
];
const titles: Record<string, string> = {
  "madogiwa-super-try-commute": "出社インポッシブル",
  "professional-window-side-sobaya": "プロフェッショナル 窓際の流儀",
  "yametaro-unauthorized-office-livestream": "やめチャンネル — 無断生配信",
  "madogiwa-super-try-keisha": "土下座レース篇",
  "madogiwa-super-try-sobaya-invasion-trailer":
    "そば屋＆たこさん、初めての東京［予告編］",
  "madogiwa-super-try-sobaya-invasion": "そば屋＆たこさん、初めての東京",
  "madogiwa-super-try-underground": "地下労働篇",
  "madogiwa-super-try-space-casual": "宇宙カジュアル篇",
};
const copies: Record<string, string> = {
  "madogiwa-super-try-commute": "命懸けでよじ登った先は、いつもの窓際席。",
  "professional-window-side-sobaya":
    "出社して、ビールを注ぐ。一流の窓際社員の仕事に密着。",
  "yametaro-unauthorized-office-livestream":
    "配信を始めたら、映してはいけないものだらけ。",
  "tako-game-dormitory": "目覚めたら、そこは巨大なタコ部屋だった。",
  "madogiwa-super-try-keisha":
    "低姿勢で、ぶっちぎれ。窓際族たちの土下座レース。",
  "sobaya-never-drops-beer": "すべてが宙を舞っても、この一杯だけは。",
  "sobaya-beer-encouragement": "落ち込むやめさんに、そば屋から一杯。",
  "aronchia-makers-vlog": "段ボールから作る、俺たちのアーロンチュア。",
  "madogiwa-super-try-underground":
    "地下労働からの脱出。その決意を揺るがす、冷えた一杯。",
  "madogiwa-super-try-space-casual":
    "慎重に進む船外作業。その隣に、未確認窓際族。",
  "madogiwa-super-try-sobaya-invasion-trailer":
    "地球にやってきた、その目的は。",
  "madogiwa-super-try-sobaya-invasion":
    "赤坂に三脚マシン襲来。狙われたのは地球のビール。",
  "yumemi-group-sobaya-figure-shopping": "等身大そば屋を、まさかのお値段で。",
  "sobaya-hazard-trailer": "霧の向こうにも、白い仮面。",
  "balcony-bar-construction-timelapse":
    "ベランダを片付けたら、酒場になりました。",
};
export const episodeTitle = (e: Episode) => titles[e.slug] ?? e.title;
export const episodeCopy = (e: Episode) =>
  copies[e.slug] ?? e.members.map((m) => m.name).join("・");
export const poster = (e: Episode) =>
  e.slug === "madogiwa-super-try-sobaya-invasion-trailer"
    ? "/cache/editorial-trailer.jpg"
    : e.slug === "professional-window-side-sobaya"
      ? "/cache/editorial-professional.jpg"
      : e.primary_video_poster_url
        ? `/cache/${e.primary_video_id}.jpg`
        : "/site/hero-shibuya-wide.webp";
export const videoSource = (e: Episode) =>
  cachedSlugs.includes(e.slug)
    ? `/cache/${e.primary_video_id}.mp4`
    : `https://madogiwa.work/media/${e.primary_video_id}`;
export function runtime(e: Episode) {
  const seconds =
    e.slug === "professional-window-side-sobaya"
      ? "37"
      : e.summary.match(/(?:約)?(\d+(?:\.\d+)?)秒/)?.[1];
  return seconds ? `${seconds}秒` : "短編";
}
export const starters = starterSlugs.map((slug) =>
  episodes.find((e) => e.slug === slug)!,
);
export const categories = [
  "すべて",
  "会社の日常",
  "CM・番組",
  "アクション・不思議",
] as const;
export function category(e: Episode): string {
  return /CM|ニュース|通販|番組|プロフェッショナル/.test(e.summary)
    ? categories[2]
    : /バトル|巨大|宇宙|ホラー|召喚|サメ|ビーム|アクション/.test(e.summary)
      ? categories[3]
      : categories[1];
}
const bios: Record<
  string,
  {
    line: string;
    bio: string;
    detail: string;
    quote: string;
    facts: [string, string][];
    related: string[];
    relation: string[];
    color: string;
  }
> = {
  sobaya: {
    line: "ビール片手に、今日もマイペース。",
    bio: "白い仮面の、立ち飲み処の店主。見た目は怖いけれど、仲間には優しい。",
    detail:
      "席が窓際からベランダへ移っても、「ビールが冷えたまま」と前向き。追いやられた先で酒場を開き、今日も仲間たちを迎えます。壁をぶち破る怪力もあるけれど、片付けの手は黙々と動かす人。",
    quote: "乾杯！",
    facts: [
      ["いつもの場所", "窓際の立ち飲み処"],
      ["手放せないもの", "大型ビールジョッキ"],
      ["意外な一面", "仲間思いの力持ち"],
    ],
    related: ["fukuchan", "yametaro", "tokun"],
    relation: [
      "立ち飲み処の常連第一号",
      "「やめさん」と呼ぶ仲間",
      "酒場のBGM担当",
    ],
    color: "#9caa81",
  },
  yametaro: {
    line: "また、何かやらかしたらしい。",
    bio: "紫のシャツに丸眼鏡。窓際の騒動の中心には、だいたいこの男がいます。",
    detail:
      "正体がバレて、逃げて、確保されて、また脱走。社内指名手配中でも、どこか楽しそうな脱力系。そば屋には「やめさん」と呼ばれています。",
    quote: "どうせワイなんて……",
    facts: [
      ["目印", "紫のシャツと丸眼鏡"],
      ["ただいま", "社内指名手配中"],
      ["よく行く場所", "タコ部屋。できれば行きたくない。"],
    ],
    related: ["sobaya", "yotan", "takosan"],
    relation: [
      "「やめさん」と呼んでくれる",
      "正体を見破る、目ざとい人",
      "タコ部屋で待つ謎の存在",
    ],
    color: "#b3a4bf",
  },
  takosan: {
    line: "フードの下には、謎がいっぱい。",
    bio: "白い顔と黒い丸目。小さな手と、下半身から伸びる触手を持つ不思議な存在。",
    detail:
      "黒いフードの中は、いつも無表情。姿と色を変える擬態能力で、人物にも物にも化けられます。窓際の日常にいても、宇宙規模の騒動にいても、妙にしっくりくる宇宙人です。",
    quote: "……。",
    facts: [
      ["どこから", "謎の宇宙人"],
      ["特技", "人や物への擬態"],
      ["よく見ると", "手は白く、丸い。"],
    ],
    related: ["yametaro", "sobaya", "yumemin"],
    relation: [
      "タコ部屋にやってくる男",
      "地球のビールをめぐる仲間",
      "不思議な姿の仲間",
    ],
    color: "#a4b8ac",
  },
  fukuchan: {
    line: "今日も、ぎゅんぎゅん。",
    bio: "笑顔と両手を頬に当てたポーズが目印。立ち飲み処の常連第一号です。",
    detail:
      "お店が崩れても、瓦礫の前で自撮りしてしまうマイペースぶり。大騒動の中でも、自然体のひとことが場をさらいます。ときには、ずいぶん重いノートPCを持っていることも。",
    quote: "ぎゅぎゅんです！",
    facts: [
      ["おなじみ", "ギュンギュンポーズ"],
      ["立ち位置", "立ち飲み処の常連第一号"],
      ["持ちもの", "ときどき、とても重いPC"],
    ],
    related: ["sobaya", "yotan", "yametaro"],
    relation: [
      "なじみの酒場の店主",
      "一緒に工作も、釣りも",
      "配信に巻き込んでくる人",
    ],
    color: "#c9b28e",
  },
  tokun: {
    line: "騒動の隣に、ウクレレ。",
    bio: "ハワイ好きの陽気な社長。窓際の酒場では、音楽を担当しています。",
    detail:
      "アロハシャツに麦わら帽子、手にはウクレレ。仲間が逃走していても、演奏は続きます。お店が壊れると落ち込むけれど、立ち直りは早いのです。",
    quote: "酒場のBGM、担当。",
    facts: [
      ["役職", "社長"],
      ["好きなもの", "ハワイとウクレレ"],
      ["いつもの姿", "アロハシャツと麦わら帽子"],
    ],
    related: ["sobaya", "fukuchan", "yotan"],
    relation: [
      "演奏する場所をくれる店主",
      "一緒に通販番組にも出演",
      "窓際を彩る音楽仲間",
    ],
    color: "#c0c794",
  },
  yotan: {
    line: "窓際に、ロックを。",
    bio: "ギターと新技術を愛するCTO。窓際族の酒場を支える、頼もしい仲間。",
    detail:
      "やめ太郎の正体を一目で見破る目ざとさ。捕まった仲間には、こっそり差し入れを持っていく優しさも。お店が壊れたら、復旧作業にも加わります。",
    quote: "ロックが人生。",
    facts: [
      ["役職", "CTO"],
      ["相棒", "エレキギター"],
      ["もう一つの顔", "差し入れを持ってくる仲間"],
    ],
    related: ["yametaro", "sobaya", "fukuchan"],
    relation: [
      "見破ることも、助けることも",
      "酒場を一緒に建て直す",
      "釣りや工作のおとも",
    ],
    color: "#bba671",
  },
  okayaman: {
    line: "窓際を、見守っています。",
    bio: "穏やかな笑顔を浮かべる「窓際王」。窓際族の頂点に立つ存在です。",
    detail:
      "会議室の大型スクリーンにリモート出演。その実体がどこにいるのかは、謎のまま。会社のレギュレーションを司り、どんな事態にも丁寧な言葉で驚きます。",
    quote: "大変驚いております。",
    facts: [
      ["呼び名", "窓際王"],
      ["登場場所", "大型スクリーン"],
      ["司るもの", "謎のレギュレーション"],
    ],
    related: ["sobaya", "yametaro", "takosan"],
    relation: [
      "見守る窓際族のひとり",
      "何かと驚かせてくる男",
      "大騒動を起こすことも",
    ],
    color: "#9ca9a2",
  },
  yumemin: {
    line: "夢の向こうから、ふわり。",
    bio: "青い丸い体に、バクのような鼻。空を飛ぶ、夢の案内役です。",
    detail:
      "お尻側は白く、手には木槌。言葉は話さないけれど、その一振りは雄弁。窓際で居眠りする社員を見つけると、BONK！ と起こします。",
    quote: "BONK！",
    facts: [
      ["姿", "青と白の、丸いバク"],
      ["持ちもの", "木槌"],
      ["お仕事", "居眠りしている人を起こす"],
    ],
    related: ["sobaya", "takosan", "yametaro"],
    relation: [
      "居眠りしていたら、BONK！",
      "不思議な姿の仲間",
      "窓際の物語で出会う仲間",
    ],
    color: "#a6c4ce",
  },
};
export const cast = baseCharacters.map((c) => ({
  ...c,
  name: c.id === "takosan" ? "たこさん" : c.name,
  ...bios[c.id],
}));
export type Cast = (typeof cast)[number];
export const arts = [
  {
    src: "/site/gallery/regulation-team.webp",
    title: "規制チーム、出動。",
    kind: "キービジュアル",
  },
  {
    src: "/site/gallery/takosan-homeworld.webp",
    title: "たこさんの故郷",
    kind: "世界観アート",
  },
  {
    src: "/site/gallery/soba-shark.webp",
    title: "Soba Shark",
    kind: "特別作品",
  },
  {
    src: "/site/gallery/ichiban-kuji.webp",
    title: "窓際族物語 一番くじ",
    kind: "コンセプトアート",
  },
];
