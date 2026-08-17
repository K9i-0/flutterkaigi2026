export const characters = [
  { id: "sobaya", name: "そば屋", role: "窓際族 / 立ち飲み処 店主", image: "/site/characters/sobaya.webp", copy: "見た目は怖いが、穏やかでマイペース。今日も窓際でビールを注ぐ。" },
  { id: "yametaro", name: "無職やめ太郎", role: "逃走中", image: "/site/characters/yametaro.webp", copy: "紫のシャツと眼鏡が目印。窓際から始まる騒動の中心人物。" },
  { id: "takosan", name: "タコさん", role: "謎の宇宙人", image: "/site/characters/takosan.webp", copy: "フードと触手を持つ謎の存在。タコ部屋からやってきた。" },
  { id: "fukuchan", name: "福ちゃん", role: "窓際族", image: "/site/characters/fukuchan.webp", copy: "いつでも自然体。窓際の日常を明るくするムードメーカー。" },
  { id: "tokun", name: "とーくん", role: "社長", image: "/site/characters/tokun.webp", copy: "アロハとウクレレがトレードマークの陽気な社長。" },
  { id: "yotan", name: "よーたん", role: "CTO", image: "/site/characters/yotan.webp", copy: "金髪ロックな技術責任者。ギターと新技術を愛している。" },
  { id: "okayaman", name: "窓際王おかやまん", role: "窓際王", image: "/site/characters/okayaman.webp", copy: "すべての窓際族を静かに見守る、伝説の王。" },
  { id: "yumemin", name: "ゆめみん", role: "夢の案内役", image: "/site/characters/yumemin.webp", copy: "空を飛ぶ青いバク。大きなハンマーを携え、夢を渡り歩く。" },
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
