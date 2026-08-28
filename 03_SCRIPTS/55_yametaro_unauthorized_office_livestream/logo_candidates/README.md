# YumeTubeロゴ候補

YouTubeを下敷きにした架空の配信サービス`YumeTube Live`用ロゴ。OpenAI組み込みImageGenで、候補ごとに独立生成した透過PNG。

## 共通仕様

- 正確な表記: `YumeTube`
- 再生アイコンの基調色: ゆめみん正典画像`02_CHARACTERS/Yumemin.jpg`の代表色`#5EB6E8`
- 白い右向き再生三角、濃紺〜黒のワードマーク
- 横長、配信画面左上で縮小しても読める構成
- 余分な文字、透かし、実在の`YouTube`表記は禁止

## A — CLASSIC（採用）

- ファイル: `yumetube_logo_candidate_a_classic.png`
- プロンプト要旨: 青い角丸長方形の再生アイコンと、太い幾何学サンセリフの正確な`YumeTube`。王道の動画プラットフォームらしさを優先し、追加バッジやマスコット要素を入れない。
- 採用後の正本: `../yumetube_logo_black.png`と`../yumetube_logo_white.png`
- 色差分は再生成せず、元のアイコン・文字形状・アルファを固定したままワードマーク領域だけを純黒`#000000`／純白`#FFFFFF`へ決定的に置換した。

## B — YUMEMIN SOFT

- ファイル: `yumetube_logo_candidate_b_yumemin_soft.png`
- プロンプト要旨: `#5EB6E8`の柔らかな有機形状の再生アイコン。右下にゆめみんの丸い輪郭を思わせる小さな上向きカーブを加え、丸みの強い`YumeTube`書体と組み合わせる。目、耳、顔、全身マスコットは描かない。

## C — LIVE

- ファイル: `yumetube_logo_candidate_c_live.png`
- プロンプト要旨: 王道の再生アイコンと`YumeTube`ワードマークに、同じゆめみんブルーの小型`LIVE`カプセルを追加。配信UIへそのまま置ける一段の横組み。

## 比較用

- `yumetube_logo_candidates_preview.png`: A・B・Cを白背景上で縦に並べた比較シート

B・Cは比較履歴として保持する。Remotionは採用したA案の黒文字版・白文字版を`remotion/public/`から読み込む。
