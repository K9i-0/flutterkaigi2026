# WAI (Window-Side AI) — 30秒紹介動画・認識合わせ案

## 現在の段階

Wan 3.0本番生成前のビジュアル認識合わせ。ロゴと主要6場面はコンセプト画像であり、採用後に本番参照画像、`prompt_wan3.txt`、`wan3_config.json`へ固定する。

## 企画の芯

- 架空サービス名: `WAI (Window-Side AI)`
- 読み: `ワ・イ`。英語音声でも英単語`why` /waɪ/やアルファベット読みにはせず、日本語を少しぎこちなく発音する二拍の`wah-ee` [wa.i]。短く区切り、第二拍の`イ`をわずかに立てる
- 名前の由来: 無職やめたろうの一人称「ワイ」
- セリフ上の唯一の違和感: 正式名称が`Window-Side AI`であることだけ。それ以外のナレーションと字幕は、すべて真面目で説得力のある製品発表文にする
- 表現: 世界的AI企業の新製品発表のように、終始きわめて真面目で高級。コード画面はVisual Studio Code、ターミナル画面はiTerm2の実在UIを使用する
- 笑い: ナレーションは革新的な能力として説明するが、背景のソースコードとターミナルではエラーが増え続け、最後はコードとプロジェクトを完全削除して「技術的負債ゼロ」にする
- 学習元のオチ: 「日本のプロフェッショナルから学習」と荘厳に説明しながら、巨大な`窓際族`の文字とそば屋・福ちゃんを見せる
- 色: 黒、白、グレー。赤はエラーだけに限定
- 音声: 英語のプロフェッショナルな成人男性ナレーター。落ち着いた中低音、抑制された自信、皮肉を演じない
- 発音の連続性: 台本中のすべての`WAI`は必ず同じカタコト日本語風の`ワ・イ`。`Window-Side AI`を含むほかの英語は流暢でプロフェッショナルに読む
- 字幕: 日本語。生成映像へ焼き込まず、編集時に正確な文字で後載せする
- 人物: 本編に無職やめたろう本人は出さない。人物同一性はロゴの髪、生え際、丸メガネ、輪郭へ集約する

## 30秒ナレーション／字幕たたき台

| 時間 | 英語ナレーション | 日本語字幕 | 画面 |
|---|---|---|---|
| 0.0–3.7 | Today, we're introducing WAI. Window-Side AI. | 本日、WAIをご紹介します。Window-Side AIです。 | 暗闇から白いWAIロゴが現れる |
| 3.7–8.4 | Software development, at a speed never seen before. | ソフトウェア開発を、これまでにない速度へ。 | VS Codeの2行だけの無意味なコード、`12,489 errors` |
| 8.4–12.5 | WAI instantly resolves errors, complex code, | WAIは、エラーや複雑なコードなど、 | iTerm2の両ペインでエラーが猛烈に増殖する |
| 12.5–16.7 | and every form of technical debt. | あらゆる技術的負債を瞬時に解決します。 | VS Codeから全ファイルと全コードが消え、`0 ERRORS / 0 FILES / 0 DEBT` |
| 16.7–22.8 | Our model was trained by professionals across Japan. | 私たちのモデルは、日本のプロフェッショナルから学習しました。 | 巨大な`窓際族`。そば屋と福ちゃんを荘厳に見せる |
| 22.8–30.0 | WAI. Empowering every developer to build what comes next. | WAI。すべての開発者に、次の可能性を。 | WAIエンドカード。赤いエラー光が消える |

## 認識合わせ画像

| 役割 | ファイル | 参照する要素 |
|---|---|---|
| 人物同一性 | `character_yametaro_basic_sheet.png` | 大きな黒髪、中央の三角形の生え際、完全な丸メガネ、丸い顔 |
| 人物同一性 | `character_sobaya_basic_sheet.png` | 白い仮面、赤い縦模様、グレーの露出肌、筋肉質な巨体、白Tシャツ、大型ビールジョッキ |
| 人物同一性 | `character_fukuchan_basic_sheet.png` | 福ちゃん本人の顔、黒髪、細身体型、黒いセットアップ、SPONSORストラップ、名札 |
| ロゴ案 | `logo_wai_concept_v1.png` | モノクロの顔マーク、`WAI`、`Window-Side AI` |
| Shot 1 | `scene_01_launch_reveal_concept.png` | 黒い発表空間、白いロゴ、荘厳な導入 |
| Shot 2・字幕レイアウト案v3 | `scene_02_vscode_errors_serious_copy_concept_v3.png` | Visual Studio Code Dark Modern、Explorer、`wai.ts`、Problems、赤い波線、`12,489 errors`、真面目な速度訴求 |
| Shot 3・字幕レイアウト案v3 | `scene_03_iterm2_debt_resolution_concept_v3.png` | iTerm2、macOSウインドウ、zsh、分割ペイン、大量エラー、`rm -rf ./wai-project`、真面目な負債解消訴求 |
| Shot 4・採用候補v3 | `scene_03_vscode_all_debt_deleted_concept_v3.png` | VS Codeの全ファイルと全コードが消失、`0 ERRORS / 0 FILES / 0 DEBT` |
| Shot 5・採用候補v1 | `scene_04_japanese_professionals_madogiwa_concept_v1.png` | 巨大な`窓際族`、そば屋1人、福ちゃん1人、ビールジョッキ1個 |
| Shot 6・字幕レイアウト案v2 | `scene_06_end_card_serious_concept_v2.png` | 余白の大きい静かなエンドカード、真面目なブランドメッセージ |

## 本番化の方針（方向性承認後）

- 30秒一発生成ではなく、ロゴ／VS Codeエラー／iTerm2エラー／VS Code全削除／窓際族専門家／エンドカードをショット単位でWan生成し編集する。
- Visual Studio CodeはDark ModernのActivity Bar、Explorer、タブ、breadcrumb、TypeScript syntax highlighting、minimap、Problemsパネル、青いStatus Barを維持する。WAIは拡張機能バッジとして表示する。
- iTerm2はmacOS交通信号、iTerm2タイトル／タブ、zshプロンプト、分割ペイン、monospaceフォント、status barを維持する。WAIは選択中プロファイルとして表示する。
- 全削除ショットはShot 2と同じVS Codeウインドウ、カメラ、照明を維持し、Explorer、タブ、コード、Problemsが連続的にゼロになる。削除後は`NO FOLDER OPENED`と`0 ERRORS / 0 FILES / 0 DEBT`だけを残す。
- 学習元ショットはそば屋1人、福ちゃん1人だけ。人物同一性はエピソード内の各シートを優先し、巨大な正確な日本語`窓際族`を1回だけ表示する。
- 正確な製品UI、WAIロゴ、コマンド、エラー数、英語音声、日本語字幕は編集工程で合成し、動画モデルには画面内スクロール、照明、粒子、カメラを担当させる。
- Wanへ渡す本番画像と本番プロンプトは字幕なしにする。現在の字幕入りコンセプトは文言、位置、サイズのレイアウトガイドとしてだけ使う。
- 生成後にショットを30秒へ編集し、`narration_en.txt`の英語台本と`subtitles_ja.ass`の日本語字幕を同期する。字幕は1920×1080基準、画面下中央、白文字、黒縁、セーフマージン内に固定する。
- 英語音声生成では`narration_en_tts.txt`を実入力にし、`narration_direction.md`の発音指定を適用する。全3回の`WAI`を同じ`ワ・イ`へ統一し、英単語`why`、`way`、`double-u ay eye`へ変えない。
- 英語ナレーターは窓際メンバー外のため、`VOICE_CAST.md`の固定参照音声は使用しない。作品専用の許諾済み男性音声またはWanの音声生成を使う。
- 本番API送信は、方向性承認と従量課金実行の明示承認後に行う。
