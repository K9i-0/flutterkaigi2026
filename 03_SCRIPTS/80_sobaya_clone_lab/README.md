## 現行：Aの声採用＋測定中の人物を静止化

`final_remotion_clone_lab_takosan_a.mp4`（33秒）。ユーザー採用Aの高い声をたこさんの全台詞へ適用。「五千」の測定シーンは閉口した福ちゃん・やめ太郎の静止画に変更し、UIのみ動かす。詳細は `POST_AUDIO.md` の追記。[比較ページ](review.html)。

## 現行の改善候補（2026-09-26）

`final_remotion_clone_lab_horror.mp4`：33秒。たこさんの「興味深い」をIrodoriで1秒だけ修復し、ガラスの異音・破砕前の静けさ・衝撃音を追加。末尾3秒に既存ロゴとそば屋の声のタイトルコール。前回30秒版は保持。

[比較ページ](review.html) / [修復・音響の詳細](POST_AUDIO.md)。`remotion/`で `npm run render:horror` により再現。ASR・PCM検証と試聴の合格は区別し、現時点は比較試聴用。

# そば屋クローン研究所 — 採用ステージと窓際力UI

本編初回生成済み。UI合成版は `final_remotion_clone_lab.mp4`、480Pの生成原版は `wan3_clone_lab_seed26092580_480p.mp4`。既知の映像差異がある確認用テイク。詳細は `generation_record.json`。

ステージ参照画像と単体UIも保持。現行v2は1920×1080 / 30fps / 150フレーム（5秒）、音声なし。

窓際力は標準的な窓際社員を **10 MW** と定義した相対尺度。福ちゃん **213 MW**、やめ太郎 **5,082 MW**、そば屋 **10,247 MW**。福ちゃんは高値、やめ太郎とそば屋は規格外。


## 採用ステージ

ユーザーが **A4（投影装置の主張を抑えたA案）** を採用。
正本画像：[`reference_lab_hologram_adopted.png`](reference_lab_hologram_adopted.png)。動画制作時の本番環境・構図参照としてGit管理する。

- 広い研究室の左右に円筒状のビール培養ポッドを配置し、一槽にそば屋一体。
- 最奥に大きなたこさんの立体ホログラム。黒いフードとローブ、白衣なし。
- 培養ポッドとホログラム本体を主役にし、投影設備は控えめな床面発光として扱う。
- 巨大な天井リング、投影支柱、大型投影機械は設置しない。
- 福ちゃんとやめ太郎は手前からたこさんに対面する。

採用元：`stage_candidates/A4_discreet_projector.png`。実送信画像生成プロンプト：`stage_candidates/prompt_A4.txt`。A2の研究卓案・A3のホログラム縮小案は採用しない。今回確定したのはステージの見た目で、台詞・本編動画生成は別工程。

## v2の表示方針

短時間で読める要素を「人物名・大きな測定値・判定」に絞る。二人の監視映像の下へ152pxの数値を配置し、カウントアップは維持。比較表、対数バー、倍率、原体比、繰り返しラベルを撤去。標準窓際社員＝10 MWは上部へ残す。機器番号、そば屋の原体値、生体回収指示は一時停止で読める13pxの小さな下端ログ。

- 6〜35f：福ちゃんを測定、213 MWに確定。
- 38〜80f：やめ太郎を測定、5,082 MWに確定し赤色へ。
- 80〜114f：「規格外の窓際力を検出」。
- 115〜149f：「両名を捕獲せよ」。福ちゃんの数値は琥珀色のままで、規格外との区別を維持。

実際の尺と数値の正本は `remotion/src/edit-manifest.json`。人物枠は仮置きで、自動追跡は実装しない。本番映像の位置・動きに合わせて調整する。

## 成果物

- `final_remotion_scanner_preview_v2.mp4`: 暗い仮背景付きの5秒UI確認動画。本編完成版ではない。
- `scanner_overlay_alpha_v2.mov`: 背景透過のProRes 4444。
- `remotion/out/v2-scan-84.png`: 規格外警告画面。
- `remotion/out/v2-scan-135.png`: 捕獲指示画面。
- `remotion/out/v2-overlay.png`: 捕獲指示画面の透過PNG。
- `ScannerPreview`: 確認用の薄いグリッド背景付き。
- `ScannerOverlay`: 背景なし。可読性のため数値パネルと警告帯は残す。

初版の10秒MP4/MOVは比較用にローカル保持。現行コードはv2を再現する。初版のコードはGitコミット `219eda0`。

```sh
cd 03_SCRIPTS/80_sobaya_clone_lab/remotion
npm ci
npm run typecheck
npm run studio
npm run stills
npm run render
npm run alpha
```

Remotion関連パッケージは4.0.528へ統一固定。日本語フォントはmacOSのHiragino Sansを使用。他OSでは同フォントの用意、または日本語フォントの明示的な差し替えが必要。

単体UIは字幕・ニュースプリセット・音声なし。本編はpostproduction=remotionでWan埋め込み音声を維持。

v2検証：TypeScriptチェック成功。測定確定と警告・捕獲の切替前後をPNG出力し、主要警告画面の文字・数値配置を目視確認。MP4と透過MOVは双方1920×1080・30fps・150フレーム・5秒、全編デコード成功。透過PNGの人物映像領域はalpha=0。ProResはアルファ付き画素形式を確認。

## 生成準備パッケージ

最終準備は[`PRE_FLIGHT.md`](PRE_FLIGHT.md)参照。送信本文`prompt_wan3.txt`、設定`wan3_config.json`、本番素材台帳`input_manifest.json`を配置。480P・30秒単一タスクの乾式検証済み。本編APIは2026-09-25に送信し成功。生成記録は `generation_record.json`。

`CloneLabFilm`は30秒本編にUIを重ねる構成。`remotion/public/input.mp4`へ採用動画を配置し、監視カットの実測時刻に`remotion/src/production-edit.json`を合わせた後、`npm run render:film`で完成版を出力する。タイミングが一致するまでは完成版扱いにしない。

## 初回生成・UI合成（2026-09-25）

Wan原版は854×480・30fps・30秒。生成タスクは一回のみ、見積$1.05（実請求未確認）。UI合成版は1920×1080・30fps・30秒。元映像の細部は480Pのまま。

実カット348〜485f（11.6〜16.2秒）のみ、生成された不正確なUIを除き、同時刻の二人の顔を切り出して測定UIへ配置。カウントアップは単体UIの既存タイミングを維持し、捕獲表示はカット末尾まで。配置・区間の正本は `remotion/src/production-edit.json`。全体の音声・再生速度を維持。

序盤のやめ太郎の顔変形とガラス内の重複像、ホログラム上部の大型設備は未修正。ASRで台詞の大筋を照合したが、通し試聴・発音・リップシンク合格は未判定。採用確定ではなく確認用テイクとして扱う。

再現: `remotion/`で `npm run typecheck`、`node render.mjs film-stills`、`npm run render:film`。生成原版を`public/input.mp4`にhardlink済み。

最終検証: 合成版900フレーム・30秒、全編デコード成功。Remotion再エンコード音声に約42.6ms遅延があったため原版AACをコピーして再mux。最終30秒のデコードPCMは原版と完全一致。`render.mjs`も同じ手順を再現する。
