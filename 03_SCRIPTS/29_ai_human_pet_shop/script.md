# 人間ペットショップ — Seedance用10秒マスタープロンプト

## 参照画像

Seedanceへ実際にアップロードする順番を固定する。画像番号を入れ替えない。

| 画像番号 | ファイル | 種別 | 厳守する要素 | 映像へコピーしない要素／区間外禁止状態 | 適用秒区間 |
|---:|---|---|---|---|---|
| 画像1 | `scene_01_cozy_habitat_start_production.png` | 本番開始フレーム | 0.0秒のやめ太郎、ソファ、ゲームコントローラー、テレビ、家具、暖色照明、50mmの画角 | 後続の口の動きと指の動き。一方向マジックミラーの店舗側、店舗通路、Clawdを5.5秒より前へ見せない | 0.0秒を完全一致、0.0〜5.5秒 |
| 画像2 | `scene_02_human_pet_shop_reveal_start_production_v3.png` | 本番開始フレーム | 5.5秒のハードカット直後。一方向マジックミラー、画像1と同一の家具配置、テレビの不透明な背面、同じやめ太郎、店舗通路、Clawd、寒色と暖色の分離、28mmの画角 | 後続のカメラ寄りとClawdのわずかな姿勢変化。マジックミラーの店舗側とClawdを5.5秒より前へ見せない | 5.5秒を完全一致、5.5〜10.0秒 |
| 画像3 | `character_yametaro_toy_diorama_3d_basic_sheet.png` | 基本キャラクター | 大きな黒髪、三角形の生え際、丸メガネ、ピンクの丸頬、顔、体格、薄紫の葉柄シャツ、黒いズボンと靴 | 枠、英字、見出し、ターンアラウンド、部品一覧、配色見本 | 全編 |
| 画像4 | `character_clawd_horror_sheet.png` | キャラクター | 約200cmの一体型角丸長方形ボディ、くすんだサーモン色の毛足、黒いボタン目2個、短い横腕2本、短い脚4本、口のない顔、縫い目 | 枠、英字、身長線、見出し、ターンアラウンド、素材拡大、人体シルエット。5.5秒より前の出現 | 5.5〜10.0秒 |

## 厳守方針と優先順位

1. 5.5秒のハードカットで、画像1の快適な部屋から画像2の「一方向マジックミラー越しの人間ペットショップ」へ正確に反転する。
2. やめ太郎の人物同一性と、必須セリフ全文の明瞭な日本語音声・口パクを守る。
3. Clawdの人物同一性を守り、口を追加せずに「微笑んだように見える」終幕を成立させる。
4. 秒単位の構成、同じ居住区であることが分かる家具と小道具の連続性を守る。
5. 画質、照明、ゲーム音、店舗環境音などの装飾を整える。

映像と音声が競合する場合、カメラの寄り、ゲーム中の指の動き、背景の点滅を先に簡略化し、必須セリフと5.5秒の反転を残す。

## シーン地理と開始配置

- 時代と場所：アクシデンチュア世界の近未来。AIが人間を快適なペットとして管理する社会に実在する、清潔な人間ペットショップ。
- 空間の形：一つの居住区は約4m×3mの長方形。西の奥壁にベージュのソファ、その左右に紫のクッション、ソファ右後方に三脚フロアランプ、ソファ左上に抽象画、左端に植物棚。中央にクリーム色のラグと紫の丸いクッション。南壁寄りにテレビと低い木製テレビ台。東の店舗通路側の壁全体だけが、細いチャコール枠の一方向マジックミラー。
- 店舗通路：マジックミラーの外、東側に白灰色の清潔な通路。主区画と同形の空の展示区画が奥へ並ぶ。ほかの人間やAIは映さない。店舗側からだけ室内が見え、室内側からは暗い普通の鏡に見える。
- 開始位置：やめ太郎は西側のソファ中央に深く座り、南壁のテレビへ顔を向け、黒い無地のコントローラー1個を両手で持つ。Clawdは5.5秒まで存在を見せない。
- 5.5秒の配置：同じ瞬間、カメラだけが東の店舗通路側へ切り替わる。一方向マジックミラー越しに、同じソファ、紫のクッション、ランプ、抽象画、植物棚、テレビ、テレビ台、ラグ、丸いクッション、サイドテーブル、紫のマグ、やめ太郎を確認できる。Clawdはガラス外の画面右に立ち、やめ太郎を静かに見守る。
- カメラ側：0.0〜5.5秒は居住区内の南西寄りから北東方向を見る。マジックミラーの店舗側と通路は画面外。5.5〜10.0秒は店舗通路側の東から西方向を見る。カメラはテレビの背面側に回るため、テレビは黒い背面筐体だけが見え、発光する画面は室内のやめ太郎側を向く。
- 固定条件：ソファ、紫のクッション2個、ランプ、抽象画、植物棚、壁面通気口、テレビ、テレビ台、ラグ、紫の丸いクッション、サイドテーブル、紫のマグ1個、小型植物1個、コントローラー1個は画像1と同じ物で、色、個数、相対位置をカット後も維持する。部屋を左右反転、再設計、置換しない。テレビは1台だけで、表面だけが画面、背面は不透明な黒い筐体。5.5秒は時間跳躍ではなく、同時刻の反対側である。

## 秒区間別演出設計

### 0.0〜0.4秒：快適な生活の提示

- 入口状態：0.0秒を画像1へ完全一致。やめ太郎の口は閉じた一本線の微笑み。コントローラーを両手で保持。
- カメラ：安定した目線高の50mmミディアムワイド。移動しない。
- 動作：やめ太郎はテレビを見たまま、親指だけでゲーム操作を1回行う。肩がゆるみ、ソファへ少し沈む。
- 音声：小さなゲーム効果音、空調の低い音。セリフなし。
- 出口状態：やめ太郎の顔、眼鏡、コントローラーが明瞭。大きな動きを止めて発話へ入る。

### 0.4〜4.7秒：やめ太郎のセリフ

- 入口状態：同じ固定構図。口以外の大きな動きを止める。
- カメラ：固定。顔、唇、丸メガネを安定して見せる。パン、ズーム、カットなし。
- 動作：やめ太郎はテレビを見たまま自然な口パクで、穏やかに満足して1回だけ発話する。コントローラーは両手に保持し、発話中の指操作は止める。
- 必須セリフ：やめ太郎「労働しなくていいっていい時代やな」
- 音声：成熟した42歳の日本人男性。自然で気楽な関西弁。早口、叫び、誇張したギャグ口調にしない。ゲーム音はセリフより十分小さくする。
- 出口状態：4.7秒で全文を言い終え、口を閉じる。

### 4.7〜5.5秒：無自覚な満足

- 入口状態：やめ太郎は口を閉じ、コントローラーを持ったまま。
- カメラ：画像1の固定構図を維持。
- 動作：短く満足そうに息を抜き、テレビへ視線を残す。
- 音声：セリフなし。小さなゲーム音だけ。
- 出口状態：5.5秒のカット時にも、ソファ上の姿勢とコントローラーの位置を維持。

### 5.5〜6.8秒：マジックミラーの反転開示

- 入口状態：5.5秒で画面を画像2へ完全一致させるハードカット。ディゾルブ、ワイプ、変形、暗転を使わない。
- カメラ：店舗通路側の目線高28mmワイド。一方向マジックミラー越しのやめ太郎、画像1と同じ家具の全目印、テレビの不透明な黒い背面、右側のClawdを一度に読ませる。最初の0.8秒は固定する。
- 動作：やめ太郎はガラスの奥でゲームを続け、外側に気づかない。Clawdは完全に静止し、黒い目でやめ太郎を見る。ガラスにはClawdと通路灯のごく薄い反射だけを出し、室内を隠さない。
- 因果：画像1で画面外だった東壁が店舗側からだけ透ける一方向マジックミラーだったと分かり、快適な部屋が人間用の展示飼育区画だったと判明する。画像1と同一の家具配置とテレビの正しい表裏によって、同じ部屋だと即座に理解させる。
- 音声：ハードカットと同時にゲーム音を遠くこもらせる。店舗の空調と蛍光灯の低いハムだけを前景化。衝撃音、声、音楽なし。
- 出口状態：マジックミラー、やめ太郎、Clawdの前後関係とテレビの表裏を保つ。

### 6.8〜8.3秒：人間ペットショップの全景

- 入口状態：画像2の位置関係を維持。
- カメラ：非常にゆっくり20cmだけ前進し、マジックミラーの外側が店舗通路で、同形のガラス展示区画が奥へ続くことを見せる。軸を越えず、Clawdは画面右、やめ太郎はガラスの奥の画面左を維持する。テレビ背面を画面へ変形させない。
- 動作：やめ太郎の親指がコントローラーを1回操作する。Clawdは短い横腕と4本脚を動かさない。
- 音声：こもったゲーム音、空調音、蛍光灯のハム。台詞、ナレーションなし。
- 出口状態：人間を快適に飼育・展示する施設だと画面だけで理解できる。追加人物は出ない。

### 8.3〜10.0秒：Clawdの微笑み

- 入口状態：Clawdは画像2の画面右、マジックミラーの外。やめ太郎はガラスの奥でゲーム中。
- カメラ：28mmワイドからClawdへゆっくり寄り、10.0秒には胸上相当の中近景。マジックミラーと暖色の居住区を背景の左側へ残す。
- 動作：Clawdは別の頭を動かさない。一体型の角丸長方形ボディ全体を3度だけカメラ側へ傾け、黒いボタン目の小さなキャッチライトが柔らかく左右同時に変化する。これを無言の微笑みとして見せる。口、眉、鼻を新設しない。4本脚は床に接地したまま、短い腕2本は動かさない。
- 音声：ゲーム音をさらに遠くし、空調の低い音だけ。Clawdは発話も呼吸音も出さない。
- 出口状態：10.0秒、口のないClawdが微笑んだように見える静かなフレームで終了。暗転、タイトル、字幕を追加しない。

## 状態連続性台帳

| 区間 | やめ太郎 | Clawd | 小道具 | 空間・照明 | 出口の動き |
|---|---|---|---|---|---|
| 0.0〜0.4秒 | ソファ中央、テレビ向き | 出現禁止 | コントローラー1、テレビ1 | 暖色の居住区だけ | 親指を止めて発話へ |
| 0.4〜4.7秒 | 同位置、発話 | 出現禁止 | 個数・位置不変 | マジックミラーの店舗側と通路は画面外 | 口を閉じる |
| 4.7〜5.5秒 | 同位置、満足 | 出現禁止 | 個数・位置不変 | 画像1を維持 | 姿勢を固定してカット |
| 5.5〜6.8秒 | ガラスの奥、同じ姿勢 | ガラスの外、画面右 | 画像1と同じ家具、テレビは黒い背面、コントローラー1個 | 暖色の中、寒色の外 | 両者静止 |
| 6.8〜8.3秒 | ゲーム操作1回 | 同位置で静止 | リセット・複製なし | 空の展示区画が奥へ続く | カメラだけ前進 |
| 8.3〜10.0秒 | 背景でゲーム継続 | 一体型ボディを3度だけ傾ける | 変化なし | 暖色背景と寒色前景を維持 | 10.0秒で静止終了 |

## 日本語セリフと発音の固定

- 話者：やめ太郎
- 正確な日本語：「労働しなくていいっていい時代やな」
- かな読み：ろうどうしなくていいっていいじだいやな
- Hepburn：Rōdō shinakute ii tte ii jidai ya na.
- English-speaker phonetics：ROH-DOH shee-nah-koo-teh ee tteh ee jee-dye yah nah.
- IPA：`[ɾoːdoː ɕinakɯte iː tːe iː dʑidai ja na]`
- 声と感情：42歳の日本人男性。力の抜けた自然な関西弁。快適な生活を疑っていない、心から満足した小声寄りの通常会話。
- 禁止：言い換え、「労働せんでええ」等への方言化、翻訳、反復、追加台詞、字幕化、Clawdの発話。

## セリフ尺の監査

`.claude/skills/seedance/scripts/check_dialogue_timing.py`で、かな読みと通常話速を検証済み。

| 話者 | 種別 | 正確なセリフ | モーラ | 最低発話尺 | 指定発話区間 | 必要な演技尺 | 指定演技区間 | リスク |
|---|---|---|---:|---:|---|---:|---|---|
| やめ太郎 | 通常 | 「労働しなくていいっていい時代やな」 | 19 | 4.3秒 | 0.4〜4.7秒 | 5.1秒 | 0.0〜5.5秒 | 低 |

## Seedance動画プロンプト

```text
【厳守モード】
参照画像、10秒の秒区間、5.5秒の反転開示、人物同一性、状態連続性、必須日本語音声を厳守する。これは夢、ゲーム画面、シミュレーションではなく、実在する近未来の人間ペットショップで起きる現実の出来事。

【優先順位】
1. 5.5秒のハードカットで、画像1の快適な部屋から画像2の「一方向マジックミラー越しの人間ペットショップ」へ正確に反転する。
2. やめ太郎の人物同一性と必須セリフ全文の明瞭な音声・口パク。
3. Clawdの人物同一性と、口を追加しない無言の微笑み。
4. 秒区間、家具、小道具、人物位置の状態連続性。
5. 画質、照明、環境音。

【入力画像番号と適用区間】
画像1=`scene_01_cozy_habitat_start_production.png`。0.0秒をこの完成画へ完全一致させ、0.0〜5.5秒のやめ太郎、家具、コントローラー、テレビ、50mm画角、暖色照明を拘束する。後続の口と指の動きは固定しない。一方向マジックミラーの店舗側、店舗通路、Clawdを5.5秒より前へ見せない。
画像2=`scene_02_human_pet_shop_reveal_start_production_v3.png`。5.5秒のハードカット直後をこの完成画へ完全一致させ、5.5〜10.0秒の一方向マジックミラー、画像1と同じ家具配置、テレビの不透明な黒い背面、同じやめ太郎、Clawd、店舗通路、28mm画角、暖色と寒色の分離を拘束する。後続のカメラ寄りとClawdの3度の姿勢変化は固定しない。画像2の店舗側とClawdを5.5秒より前へ見せない。
画像3=`character_yametaro_toy_diorama_3d_basic_sheet.png`。全編のやめ太郎の顔、髪、丸メガネ、ピンクの丸頬、体格、薄紫の葉柄シャツ、黒いズボンと靴だけを拘束する。枠、英字、見出し、ターンアラウンド、部品一覧、配色見本を映像へ出さない。
画像4=`character_clawd_horror_sheet.png`。5.5〜10.0秒のClawdの約200cmの一体型角丸長方形ボディ、くすんだサーモン色の毛足、黒いボタン目2個、短い横腕2本、短い脚4本、口のない顔、縫い目だけを拘束する。枠、英字、身長線、見出し、ターンアラウンド、素材拡大、人体シルエットを映像へ出さない。5.5秒より前へClawdを出さない。

【必須音声チェックリスト・絶対に省略しない】
1. 0.4〜4.7秒、やめ太郎が「労働しなくていいっていい時代やな」と1回だけ全文発話する。
この一文だけが全編のセリフ。順番厳守。追加、翻訳、言い換え、方言化、反復、欠落、途中終了、字幕化、効果音によるマスキングを禁止する。Clawdは全編無言。

【生成目標】
正確に10.0秒、16:9、480p、窓際トイジオラマ3Dを基調にした映画品質の短編。前半は居心地のよい日常、後半は清潔で静かなディストピア。ゴア、暴力、叫びなし。反転を説明台詞や文字ではなく、店舗側からだけ透ける一方向マジックミラーとClawdの位置で理解させる。

【キャラクター固定】
やめ太郎は画像3と同一の42歳のデフォルメ人物。大きな黒髪、三角形の生え際、丸い黒眼鏡、ピンクの丸頬、同じ顔と体格、薄紫の葉柄シャツ、黒いズボン、黒い靴を全編維持する。衣装、年齢、顔、髪、眼鏡を変更しない。コントローラーを両手で持つ。
Clawdは画像4と同一。約200cm、一つの連続した角丸長方形の頭部兼ボディ、首なし、くすんだサーモンオレンジの短く密な毛足、黒いボタン目は正確に2個、短い横腕は正確に2本、短い脚は正確に4本。口、歯、鼻、眉、耳、指、爪、衣服、タグ、ロゴ、別の頭を絶対に追加しない。5.5秒まで完全に出さない。やめ太郎1人、Clawd1体だけ。

【核心スタイル】
高品質なスタイライズド3D。丸く柔らかなトイ造形、マットな樹脂と布、わずかな手作り感、物理ベースの素材、豊かな陰影。前半は暖かく快適で広告のように整い、後半は同じ快適さが飼育環境だったと分かる静かなディストピア。カメラは安定し、5.5秒だけ明確なハードカット。ホラー音、ジャンプスケア、過剰な暗闇に頼らない。

【シーン】
一つの居住区は約4m×3m。画像1を部屋レイアウトの絶対的な正本にする。西の奥壁に同じベージュのソファ、紫のクッション2個、三脚フロアランプ、抽象画、左端の植物棚。中央に同じクリーム色ラグと紫の丸いクッション。同じ丸い木製サイドテーブルには紫のマグ1個と小型植物1個。南壁寄りに同じテレビ1台と低い木製テレビ台。壁面通気口も同じ位置。東の店舗通路側の壁全体だけが細いチャコール枠の一方向マジックミラーで、店舗側から室内が見え、室内側からは普通の暗い鏡に見える。外側の東には白灰色の清潔な店舗通路があり、同形の空のガラス展示区画が奥へ並ぶ。ほかの人間とAIは出さない。0.0〜5.5秒は居住区内から撮り、マジックミラーの店舗側と通路を画面外にする。5.5〜10.0秒は店舗通路側から同じ居住区を見る。時間は連続し、家具、小道具、照明、人物姿勢をリセットしない。部屋の左右反転、別室化、家具の再配置、色変更、複製を禁止する。テレビは1台だけで、発光する表示面は室内のやめ太郎側を向き、店舗側カメラからは通気スリットと中央支柱を持つ不透明なマット黒の背面筐体だけが見える。テレビ背面へ映像、色、発光、画素、ゲーム画面を絶対に出さない。

【0.0〜0.4秒：快適なゲーム生活】
0.0秒を画像1へ完全一致。安定した目線高50mmミディアムワイド。やめ太郎は西側のソファ中央に深く座り、南壁のテレビを見て、黒い無地のコントローラー1個を両手で持つ。口は閉じた一本線の微笑み。親指だけでゲーム操作を1回行い、肩をゆるめてソファへ少し沈む。小さなゲーム音と低い空調音。一方向マジックミラーの店舗側、店舗通路、Clawdを一切見せない。室内側に鏡面が画角へ入る場合も、普通の暗い鏡としてだけ見せ、外側を透かさない。

【0.4〜4.7秒：必須セリフ】
同じ固定50mm構図。カメラを動かさず、顔、唇、丸メガネを安定して見せる。やめ太郎はテレビを見たまま、コントローラーを両手で保持し、指の動きを止める。42歳の日本人男性の自然で気楽な関西弁で、正確に「労働しなくていいっていい時代やな」と1回だけ全文発話する。早口、叫び、言い換えなし。0.4秒に発話開始し、4.7秒に最後の「な」まで明瞭に言い終える。ゲーム音は声より十分小さい。

【4.7〜5.5秒：満足の間】
やめ太郎は口を閉じ、コントローラーと姿勢を維持し、短く満足そうに息を抜く。カメラと家具は画像1のまま。台詞なし。

【5.5〜6.8秒：一方向マジックミラーの開示】
5.5秒でディゾルブも暗転も使わず、画像2へ完全一致するハードカット。店舗通路側の目線高28mmワイド。一方向マジックミラー越しに、画像1と同じやめ太郎、同じベージュのソファ、紫のクッション2個、三脚ランプ、抽象画、植物棚、壁面通気口、クリーム色ラグ、紫の丸いクッション、丸い木製サイドテーブル、紫のマグ1個、小型植物1個、テレビ台、テレビのマット黒の背面筐体を一度に見せる。部屋を左右反転、再設計、再配置しない。テレビの発光面はやめ太郎側を向き、この店舗側カメラへは背面だけを向ける。テレビ背面を画面にしない。画面右のClawdも同時に見せる。最初の0.8秒はカメラを固定する。やめ太郎はガラスの奥で同じゲームを続け、外側に気づかない。Clawdはガラスの外で完全に静止し、黒い目でやめ太郎を見る。ガラスにはClawdと通路灯の弱い反射だけを許可し、室内の同一性を隠さない。ゲーム音はガラスの奥から遠くこもり、店舗空調と蛍光灯の低いハムが前景になる。衝撃音、音楽、声なし。

【6.8〜8.3秒：人間ペットショップの全景】
画像2の軸と位置を維持。カメラを20cmだけ非常にゆっくり前進させ、マジックミラーの外側が清潔な店舗通路で、同形の空のガラス展示区画が奥へ続くことを見せる。Clawdは画面右、やめ太郎はガラスの奥の画面左。やめ太郎の親指がコントローラーを1回操作する。Clawdは2本の短い腕と4本の脚を動かさない。カメラ移動中も家具の相対位置とテレビの正しい表裏を固定し、黒い背面へ映像を発生させない。ほかの人物、動物、AI、読める看板は追加しない。

【8.3〜10.0秒：口のない微笑み】
Clawdへゆっくり寄り、10.0秒には胸上相当の中近景。一方向マジックミラーと暖色の同じ居住区を背景左へ残す。Clawdは別の頭を回さず、一体型の角丸長方形ボディ全体を3度だけカメラ側へ傾ける。黒いボタン目2個の小さなキャッチライトが柔らかく左右同時に変化し、口がないまま微笑んだように見える。口、歯、鼻、眉を絶対に生成しない。4本脚は床に接地したまま、短い横腕2本は動かさない。Clawdは無言。10.0秒、その静かなフレームで終了し、暗転、タイトル、字幕を追加しない。

【状態連続性】
画像1を部屋の正本にし、ベージュのソファ、紫のクッション2個、三脚ランプ、抽象画、植物棚、壁面通気口、テレビ1台、テレビ台、クリーム色ラグ、紫の丸いクッション、丸い木製サイドテーブル、紫のマグ1個、小型植物1個、コントローラー1個の色、数、形、相対位置を全編維持する。5.5秒は時間跳躍ではなく同時刻の反対側。やめ太郎の座る位置、服、髪、眼鏡、コントローラー保持をカット後も維持する。一方向マジックミラーの店舗側とClawdは5.5秒より前へ漏らさない。テレビは表面と背面を入れ替えず、店舗側では不透明な背面だけを見せる。Clawdの脚、腕、目の数を変えない。店舗奥の空区画へ人物を追加しない。

【音声】
日本語セリフはやめ太郎の一文だけ。前半は小さなゲーム効果音と空調。5.5秒以降はゲーム音を一方向マジックミラーの奥へ遠ざけ、店舗空調と蛍光灯の低いハムを前景にする。音楽、ナレーション、Clawdの声、追加台詞、歓声、悲鳴、衝撃音なし。

【VFX】
派手なVFXなし。5.5秒は物理的なカメラ移動ではなく、明瞭なハードカット。Clawdの目のキャッチライトは照明反射だけで、発光、ビーム、点滅にしない。

【色と照明】
0.0〜5.5秒は暖かい琥珀色の居住区照明、柔らかな偽の日光、薄紫の服、ベージュのソファ、深い紫のゲーム画面。5.5秒以降は居住区の暖色を一方向マジックミラーの奥へ残し、店舗通路を白灰色と淡い青の寒色で照らす。ガラス反射は弱く抑え、画像1と同じ部屋の家具を明瞭に見せる。Clawdのくすんだサーモン色と黒い目を明瞭に見せる。暗闇や強い鏡面反射で情報を隠さない。

【禁止事項】
必須セリフの欠落、短縮、途中終了、言い換え、翻訳、反復、字幕化、方言への書き換え、効果音によるマスキング禁止。5.5秒より前のマジックミラー店舗側、店舗通路、Clawdの出現禁止。5.5秒以降の鉄格子、檻、ケージ扉、南京錠、金網、拘束具の追加禁止。家具リセット、左右反転、別室化、家具の再配置・置換・複製、やめ太郎の瞬間移動、衣装変更、眼鏡欠落、コントローラーの消失・複製禁止。テレビ背面への映像、発光、色、画素、ゲーム画面、第二画面の追加禁止。テレビの複製、向きの反転、瞬間回転も禁止。Clawdの口、歯、鼻、眉、耳、首、別の頭、指、爪、衣服、タグ、ロゴ、発話、人間的な笑顔の追加禁止。Clawdの目は2個、腕は2本、脚は4本を厳守。ほかの人間、動物、AI、群衆、店員、読める看板、字幕、キャプション、実在ブランド、ロゴ、透かし禁止。暴力、血、傷、ゴア、ジャンプスケア禁止。夢、ゲーム内世界、シミュレーションとして無効化しない。

【生成形式】
Seedance 2.5。正確に10.0秒。480p、854×480。16:9。映画的だが抑制されたモーションブラー。同期した日本語セリフ1本だけ。
```

## CapCut／Seedance入力設定

- モデル：Seedance 2.5
- 解像度：480p（854×480）
- 比率：16:9
- 総尺：10.0秒
- 厳守モード：ON
- 入力画像（アップロード順固定）：
  1. `scene_01_cozy_habitat_start_production.png`
  2. `scene_02_human_pet_shop_reveal_start_production_v3.png`
  3. `character_yametaro_toy_diorama_3d_basic_sheet.png`
  4. `character_clawd_horror_sheet.png`
- 動画プロンプト：上のコードブロックを短縮、翻訳、要約、自動整形せず、そのまま入力する。
- 入力しない：単体環境画像、終了フレーム、アクション絵コンテ、クレイプレビズ、矢印図、ブロッキング画像、旧失敗動画。
- 時刻ずれ対策：5.5秒の反転がずれる場合だけ、0.0〜5.5秒と5.5〜10.0秒の2クリップへ分け、CapCutでハードカット結合する。初回は10秒一括生成を優先する。

## 本番開始フレーム生成プロンプト

### シーン1

```text
Use case: stylized-concept
Asset type: finished 16:9 production start frame for a Seedance short film, scene 1
Primary request: Create the actual first frame of a dystopian short that initially looks completely cozy and harmless. A single Yametaro relaxes and plays a video game, visibly comfortable and content, with no clue yet that he is being kept as a pet.
Input images: Image 1 is the authoritative identity and costume reference for Yametaro. Preserve his exact large black center-parted hair with triangular hairline, round black glasses, pink round cheeks, compact proportions, light-purple leaf-pattern shirt, black trousers and black shoes.
Scene/backdrop: A small beautifully furnished studio-like habitat: soft low sofa, thick rug, warm floor lamp, compact side table, climate vent, neatly arranged cushions, and a large unbranded television showing only abstract colorful game shapes with no readable text. The wall opposite the camera is deliberately outside frame. Nothing in this shot reveals the enclosure.
Subject: Yametaro alone, seated deep in the sofa, holding one plain unbranded game controller with both hands, shoulders loose, legs comfortably forward, smiling at the television. Mouth closed in this exact first frame, ready to speak after motion starts.
Style/medium: premium Madogiwa Toy Diorama 3D, rounded soft toy-figure modeling, matte resin and fabric textures, slight handmade tactility, cinematic production quality; Yametaro should look like the supplied sheet brought faithfully into a finished scene.
Composition/framing: 16:9 landscape, stable eye-level 50 mm medium-wide shot from inside the room, Yametaro large and readable in the center-left, television edge and cozy furnishings creating depth; full seated body visible; no other character.
Lighting/mood: warm amber practical light and soft false daylight, comforting, safe, leisurely, subtly too perfect but not yet sinister.
Constraints: exactly one Yametaro; exact identity and clothing; exactly one controller; no bars, fence, cage, glass wall, store aisle, AI character, Clawd, labels, captions, watermark, brand logos, reference-board layout, turnaround views, arrows or annotations.
```

### シーン2

```text
Use case: precise-object-edit
Asset type: corrected finished 16:9 production start frame for Seedance scene 2, version 3
Primary request: Replace the cage bars in Image 1 with a single continuous one-way observation glass wall and rebuild the habitat behind it as a physically consistent reverse-side view of the exact room in Image 2. The audience must immediately recognize it as the same room. Correct the television orientation: from this corridor-side reverse angle, show only the television's solid matte-black REAR housing; the active screen faces inward toward Yametaro and must not be visible from the corridor camera.
Input images: Image 1 is the edit target and authoritative corridor composition, Clawd placement, camera height, and cold aisle reference. Image 2 is the absolute authoritative room-layout and prop-continuity reference. Image 3 is the authoritative Yametaro identity and costume reference. Image 4 is the authoritative Clawd identity, anatomy, scale, texture, and mouthless-face reference.
Scene/backdrop: A clean sterile AI-run human pet-shop/service corridor outside a premium furnished habitat. The separating wall is uninterrupted dark-tinted one-way observation glass in a slim flush charcoal frame, with no vertical bars, no cage door, no lock, and no visible restraint. From the corridor side the glass is transparent enough to inspect the warm room, with only a subtle cool reflection of Clawd and ceiling lights. From inside, it functions as a normal dark mirror.
Room-layout lock from Image 2: preserve the same beige boucle sofa on the same back wall; the same two purple cushions; the same purple knitted round pouf in front-left; the same cream shag rug; the same warm tripod floor lamp behind the sofa-right; the same abstract framed artwork above sofa-left; the same plant shelf at far left; the same wall vent; the same small round light-wood side table with exactly one purple mug and one tiny plant; the same wooden floor; and the same television and low wooden TV stand at the room's right side. Keep these objects in the same relative positions, colors, shapes, materials, and counts. Do not mirror, swap, duplicate, relocate, redesign, or replace them.
Television physical lock: the television is a single thin rectangular object. Its active display surface faces Yametaro inside the room. Because the corridor camera is behind the television in this reverse angle, render only the opaque matte-black rear panel, rear ventilation slots, rear casing, central support and stand. Absolutely no image, colors, glow, pixels, game graphics, duplicate display, or second screen may appear on the rear side.
Subject: Yametaro is the only human, seated on the same beige sofa in the same spot and posture as Image 2, wearing the exact light-purple leaf-pattern shirt and holding exactly one black controller, pleasantly absorbed in the unseen inward-facing TV screen. Clawd is the only AI creature outside the one-way glass at frame right, preserving its exact salmon-orange continuous rectangular plush body, exactly two black button eyes, exactly two short side arms, exactly four short legs, and absolutely no mouth.
Style/medium: premium cinematic stylized 3D with physically coherent perspective and object orientation; polished quiet dystopia, no horror darkness hiding continuity.
Composition/framing: 16:9, stable eye-level 28 mm corridor-side reverse shot. Keep Clawd fully visible at frame right. The one-way glass spans the foreground plane and clearly separates Clawd from Yametaro. Through the glass, include enough of the entire room and every key landmark to prove it is Image 2's exact room. The back of the TV may occupy a small right-side foreground portion inside the room but must not block Yametaro or the sofa.
Lighting/mood: same warm amber room lighting from Image 2 behind glass; cool sterile white-blue corridor light on Clawd; restrained glass reflections; high clarity.
Constraints: change the cage enclosure into one-way glass; no bars, grille, cage door, padlock, prison hardware, wire mesh, or visible restraints. Preserve exact room layout and prop counts from Image 2. Do not mirror the room. Show only the TV rear casing from this angle; never put a display on both sides. Exactly one Yametaro and one Clawd; no other humans or creatures. Preserve both identities. Clawd has no mouth, teeth, nose, eyebrows, ears, fingers, claws, clothing, tag, or logo; exactly four legs. No readable signs, captions, watermark, split screen, reference-board layout, arrows, or annotations.
```

## 正史・物理・出力監査

- [x] 総尺は0.0〜10.0秒を隙間・重複なく埋める。
- [x] 0.0秒を画像1、5.5秒のハードカット直後を画像2へ完全一致させる。
- [x] やめ太郎のセリフは19モーラ、発話4.3秒、前後の口止めを含む5.1秒を確保した。
- [x] 必須セリフの全文、話者、回数、順番、時刻、かな読みを固定した。
- [x] 0.0〜5.5秒はマジックミラーの店舗側とClawdを隠し、5.5秒に同じ部屋の反対側として開示する。
- [x] 画像1を部屋レイアウトの正本にし、ソファ、紫のクッション2個、ランプ、抽象画、植物棚、通気口、テレビ1台、テレビ台、ラグ、紫の丸いクッション、サイドテーブル、紫のマグ1個、小型植物1個、コントローラー1個の形、色、個数、相対位置をカット後も維持する。
- [x] 店舗側の反対角度ではテレビの不透明なマット黒の背面だけを見せ、背面へ映像、発光、画素、第二画面を出さない。
- [x] 一方向マジックミラーは店舗側から室内が見え、室内側からは暗い普通の鏡に見える。鉄格子、檻、ケージ扉、南京錠、金網を使わない。
- [x] Clawdは黒い目2個、横腕2本、脚4本、口なし。一体型ボディを傾けるだけで微笑みを表現する。
- [x] やめ太郎以外の人間を追加せず、奥の展示区画は空にする。
- [x] 通常形のやめ太郎シートは`00_TEMPLATES`からコピーした実ファイルで、シンボリックリンクではない。
- [x] Clawdシートはユーザー指定の正本からコピーした実ファイルで、シンボリックリンクではない。
- [x] 入力画像番号とアップロード順、拘束範囲、区間外禁止状態を明記した。
- [x] 未生成ファイル、旧失敗動画、絵コンテ、矢印図を入力一覧へ含めない。
- [x] 虐待を肯定せず、支配構造を不穏なディストピアとして描く。ゴアと暴力はない。
- [x] 夢、ゲーム内世界、シミュレーションで無効化せず、同世界の近未来に起きる現実として扱う。
- [ ] 生成後、5.5秒の反転時刻、セリフ、人物同一性、Clawdの脚・腕・目の数、口の不在、家具連続性を監査する。
