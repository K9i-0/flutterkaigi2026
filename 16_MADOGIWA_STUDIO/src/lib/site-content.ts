export const characters = [
  { name: "そば屋", role: "窓際族 / 立ち飲み処 店主", image: "/site/characters/sobaya.webp", copy: "見た目は怖いが、穏やかでマイペース。今日も窓際でビールを注ぐ。" },
  { name: "無職やめ太郎", role: "逃走中", image: "/site/characters/yametaro.webp", copy: "紫のシャツと眼鏡が目印。窓際から始まる騒動の中心人物。" },
  { name: "タコさん", role: "謎の宇宙人", image: "/site/characters/takosan.webp", copy: "フードと触手を持つ謎の存在。タコ部屋からやってきた。" },
  { name: "福ちゃん", role: "窓際族", image: "/site/characters/fukuchan.webp", copy: "いつでも自然体。窓際の日常を明るくするムードメーカー。" },
  { name: "とーくん", role: "社長", image: "/site/characters/tokun.webp", copy: "アロハとウクレレがトレードマークの陽気な社長。" },
  { name: "よーたん", role: "CTO", image: "/site/characters/yotan.webp", copy: "金髪ロックな技術責任者。ギターと新技術を愛している。" },
  { name: "窓際王おかやまん", role: "窓際王", image: "/site/characters/okayaman.webp", copy: "すべての窓際族を静かに見守る、伝説の王。" },
  { name: "ゆめみん", role: "夢の案内役", image: "/site/characters/yumemin.webp", copy: "空を飛ぶ青いバク。大きなハンマーを携え、夢を渡り歩く。" },
] as const;

export const comicEpisodes = [
  { title: "入社", description: "そば屋がワクワク気分で入社。用意された椅子は「AERON CHUA」と手書きされた段ボール箱だったが、本人はもちろん快適です！" },
  { title: "僕の席", description: "本来の席はオフィスの窓際。机には「窓際族」の貼り紙があり、段ボール椅子の表記だけは「アーロンチェア」に訂正されていた。" },
  { title: "ベランダ席", description: "翌朝、席はビル外壁のベランダへ。冬の寒ささえ「ビールが冷えたまま」というメリットに変えてしまう。" },
  { title: "立ち飲み処 開店", description: "会社が自由ならこちらも自由に。ベランダへ暖簾と赤提灯を掲げ、とーくんのウクレレをBGMに立ち飲み処が開店する。" },
  { title: "ビールサーバ到着", description: "待望のビールサーバが到着し、ジョッキtoジョッキを卒業。「やめさん確保でビール永久無料キャンペーン」が始まる。" },
  { title: "お店落下", description: "作りの悪さか酒の在庫過多か、店がベランダごと地上へ落下。人的被害はなく、酒瓶の棚だけは奇跡的に無事だった。" },
  { title: "片付けと福ちゃん生存確認", description: "夕方まで片付ける一同の横で、福ちゃんは瓦礫を背景に自撮り。「窓際で生き残れてたのね！良かった！！」" },
  { title: "お店の再建", description: "地上の歩道沿いに木造屋台を再建。よーたんに加え、紫シャツと丸眼鏡の怪しい男も釘打ちを手伝っていた。" },
  { title: "正体バレ", description: "よーたんが怪しい男を指名手配中の無職やめ太郎だと見破る。そば屋は我関せず、ビールを飲みながら木材を運ぶ。" },
  { title: "逃走", description: "無職やめ太郎が赤坂の街を全力逃走。そば屋もジョッキを6個抱えたまま「ついでに」逃げ、とーくんは演奏を続ける。" },
  { title: "タコ部屋に連行", description: "2人はついに確保され、タコ部屋へ。そば屋はタイピング、無職やめ太郎は電話対応という強制労働が始まる。" },
  { title: "脱走", description: "よーたんが差し入れを持って訪ねると、壁には巨大な人型の穴。そば屋と無職やめ太郎は壁を破って脱走していた。" },
  { title: "窓際王おかやまん", description: "窓際王おかやまんがリモート出演。窓際十人衆（Windows 10）の野望のため、2人を地下懲罰房へ送るよう命じる。" },
  { title: "BONK", description: "窓際で居眠りするそば屋を、ゆめみんが木槌でBONK! 夢だったように思えた一連の出来事は、すべて現実である。" },
].map((episode, index) => ({
  ...episode,
  number: index + 1,
  image: `/site/comic/episode-${String(index + 1).padStart(2, "0")}.webp`,
}));

export const galleryItems = [
  { title: "規制チーム、出動。", image: "/site/gallery/regulation-team.webp", kind: "KEY VISUAL" },
  { title: "Soba Shark", image: "/site/gallery/soba-shark.webp", kind: "SPECIAL ART" },
  { title: "タコさんの故郷", image: "/site/gallery/takosan-homeworld.webp", kind: "WORLD ART" },
  { title: "窓際族物語 一番くじ", image: "/site/gallery/ichiban-kuji.webp", kind: "COLLABORATION" },
] as const;

export const articles = [
  {
    label: "ORIGINAL",
    source: "NOTE",
    title: "窓際族物語",
    copy: "そば屋の入社と、窓際から始まった物語。全14話の原作漫画をnoteで読む。",
    url: "https://note.com/sobaya/n/nb138c222aea0",
    action: "原作を読む",
  },
  {
    label: "CHARACTER",
    source: "NOTE",
    title: "窓際族物語〜登場人物紹介〜",
    copy: "そば屋、無職やめ太郎、とーくん、福ちゃん、よーたん。物語を彩る窓際社員たちの人物紹介。",
    url: "https://note.com/sobaya/n/n9b1ba408a198",
    action: "記事を読む",
  },
  {
    label: "MAKING",
    source: "ZENN",
    title: "高性能なPCが無くても格安で窓際動画を作る",
    copy: "クラウドサービスを活用し、高性能なPCに頼らず窓際動画を低コストで制作する実践的な方法。",
    url: "https://zenn.dev/yumemi_inc/articles/8dfa5814286ad6",
    action: "記事を読む",
  },
  {
    label: "SLIDES",
    source: "GOOGLE SLIDES",
    title: "窓際族物語の作り方",
    copy: "「大企業の中でスタートアップするって実際どうなの会」で紹介した、窓際族物語の制作スライド。",
    url: "https://docs.google.com/presentation/d/1Uo4ZKENR104i6vHdstXbLlBIpv3jFyLY_fyOdujchec/edit?usp=sharing",
    action: "スライドを見る",
  },
] as const;
