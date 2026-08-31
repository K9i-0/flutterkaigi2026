# プロフェッショナル 窓際の流儀

## 企画

- 形式: 16:9、約30秒のWan生成素材を、Remotionの質問カード・タイトル・字幕で約36〜38秒へ編集する。
- 元ネタ: `NHK プロフェッショナル 仕事の流儀`の密着ドキュメンタリー文法を高密度にパロディする。
- 置換: `NHK` → `YHK`、`プロフェッショナル 仕事の流儀` → `プロフェッショナル 窓際の流儀`。
- 主演: そば屋。
- 肩書: `アクシデンチュア株式会社　ウィンドウサイドエンジニア`。
- postproduction: `remotion`
- visual_preset: `professional_window_side_v1`（本企画固有。ニュースプリセットは使用しない）
- Wan生成単位: `project_duration=30`、`generation_mode=single`。

## 演出方針

NHK系の人物密着番組らしい、抑制された公共放送ドキュメンタリーの撮影文法を使う。自然光、35〜50mm相当、浅い被写界深度、わずかな手持ち、長めの観察カット、静かな間、真面目な編集で、内容だけが異常という落差を作る。

質問はRemotionで完全な黒画面に白い明朝体として表示し、インタビュアー音声は付けない。質問カードの後に、同じ窓際デスクでそば屋が淡々と回答する映像へハードカットする。そば屋は白い仮面を全フレームで正しく装着するため、口元は見えない。正典声質素材をWanへ渡し、3回答と所作を一体生成する。Wan埋め込み音声を初版の同期源とし、誤読・欠落・言い換え・演技変更が必要な区間だけ、正典Irodori音声でRemotion修正する。

Wanには人物、所作、カメラ、オフィス、環境音、オリジナルのドキュメンタリーBGMだけを生成させる。画面内の正確な文字、質問、局名、番組名、肩書、字幕はすべてRemotionで後付けする。

## 台本と完成編集タイムライン（30fps、暫定）

| 完成区間 | 内容 | 音声・文字 |
|---|---|---|
| 0.0–4.0秒 | 出社、窓際席、ビール、Excelの観察モンタージュ | `YHK`、番組タイトル、主演導入 |
| 4.0–5.6秒 | 完全な黒画面 | `なぜ、出社してすぐビールを？` |
| 5.6–13.6秒 | ビールを一口飲み、手を落ち着かせ、マウスを握る | 「出社したら真っ先にビールを飲んでます。手の震えが止まって、エクセルの操作が安定するんですよね。」 |
| 13.6–15.0秒 | 完全な黒画面 | `エクセルでは、何を？` |
| 15.0–20.6秒 | 表計算画面を開き、閉じ、また開く | 「開いたり閉じたりしてます。こうすると働いてるって思われますから。」 |
| 20.6–22.0秒 | 完全な黒画面 | `最後に、一言。` |
| 22.0–29.0秒 | 窓際に立つ正面寄り。腕を組み、片手を仮面の顎へ添える思索ポーズから、後半で人差し指を静かに立てる | 「窓際に追い込まれてるうちは二流。一流の窓際族は、窓際を作り出す。」 |
| 29.0–36.5秒 | 余韻の静止気味カットとタイトル締め | `プロフェッショナル 窓際の流儀`、`YHK` |

完成タイミングはWan素材の実測カット位置へ合わせて整数フレームで確定する。

## Wan入力

| 番号 | ファイル | 役割 |
|---|---|---|
| Image 1 | `character_sobaya_basic_sheet.png` | そば屋の人物同一性、仮面、体格、衣装 |
| Image 2 | `office_window_desk_reference_production.png` | 採用B案。同じ窓際デスク、窓、東京タワー、ノートPC単体、ビール、照明、自然な横密着構図 |
| Image 3 | `prop_yametaro_wanted_poster.png` | 壁に固定する、やめ太郎本人の社内指名手配ポスター |

`character_sobaya_basic_sheet.png`は正本テンプレートから実ファイルでコピーし、SHA-256は正本と一致する。

## 音声方式

- adopted_audio_source: `irodori`
- adopted_audio_sync_strategy: `remotion_segment_replacement`
- adopted_final_output: `final_remotion_documentary_irodori_16x9.mp4`
- Wan埋め込み音声版は比較用として保持し、公開採用版には使用しない。
- `audio_source=wan3`
- `audio_sync_strategy=wan_generated_lip_sync`
- `reference_audio_usage=voice_timbre_only`
- Wan: `parameters.audio=true`。`sobaya_voice_timbre.wav`を声質参照として渡し、3回答、所作、環境音、権利クリアなオリジナルBGMを一体生成する。
- Audio 1: `sobaya_voice_timbre.wav`、8.000秒、SHA-256 `976916e670fea5fcf0f741d45e150eaf055c3b0e11d240e3be656dd724166b58`。元の語句・間・時間軸はコピーさせない。
- そば屋: `Aratako/Irodori-TTS-v4.1-Small`、正典参照`02_CHARACTERS/Sobaya_voice.wav`、seed `42`。
- caption: `低く落ち着いた成人男性。公共放送の密着取材に淡々と答える。真面目で自然、少し間を取り、言葉を明瞭に発音する。`
- 固有処理: 編集修復用の各Irodori出力へ`sobaya_monsterize.sh`を適用（pitch=-5 semitones、tremolo=70Hz）。正常なWan区間は全面差し替えしない。

| 採用音声 | 実測尺 | SHA-256 |
|---|---:|---|
| `sobaya_answer01_beer.wav` | 7.394813秒 | `edbaeb200de9e2bd162963c3bc1c9ddd14fc21c182745fb3044f782dc35db776` |
| `sobaya_answer02_excel.wav` | 4.977313秒 | `1e466a7c418f09bcf03847ead2b45c8c0c1c08291377e6a86698ab777ec2dce0` |
| `sobaya_answer03_final.wav` | 6.197604秒 | `72d9607e3b0fb402790b831da51cf2a4845d816c56c17ced2210a7c4bb4dd741` |

## 参照画像生成記録

- 生成方式: built-in image generation
- prompt: `reference_candidates/README.md`記載のB案
- 採用画像: `office_window_desk_reference_production.png`
- SHA-256: `40def343e782c1c404b1363371729fd9c0da7f84237dee5bee3c9c21045b6b60`
- 監査: そば屋1人、白い仮面、灰色肌、白Tシャツ、窓際デスク、ノートPC1台、外付けキーボードなし、マウスなし、ビールジョッキ1個、東京タワー、文字用余白を確認。生成画像の表計算文字はWanの雰囲気参照に限定し、完成版の正確な文字には使わない。

### やめ太郎指名手配ポスター

- prompt: `yametaro_wanted_poster_imagegen_prompt.txt`
- 採用素材: `prop_yametaro_wanted_poster.png`
- SHA-256: `25c1f898a20e621924ddffa8cc96786989dce3faa8b5fbf04c430521f4b01def`
- 正典identity: `02_CHARACTERS/Yametaro.jpg`と基本シート。
- exact text: `WANTED / YAMETARO / REWARD / ¥200,000,000`
- Wanでは独立した`Image 3`として渡し、同じ壁位置・同じ人物・同じ賞金額・1枚だけを全編で維持する。

### オフィス参照画像の再選定

そば屋の普段の雰囲気を正典写真へ戻し、上記の単体ポスターを共通参照にした3案を`reference_candidates/`へ作成した。詳細は同ディレクトリの`README.md`を参照する。

- A: `office_candidate_a_familiar.png` — 正面寄り、素朴で普段らしい。
- B: `office_candidate_b_candid.png` — 横からの自然な密着取材。
- C: `office_candidate_c_intelligent.png` — 静かで少し知的な構図。
- 採用案: B `office_candidate_b_candid.png`。本番名`office_window_desk_reference_production.png`へ実ファイルとしてコピーし、WanのImage 2へ設定済み。

## 生成・編集記録

- 2026-08-31公式確認: `wan3.0-video`は最大30秒、480P対応。現行480P単価は`$0.035/秒`のため、本設定30秒の見積は`$1.05`。
- Wan config: `wan3_config.json`
- Wan prompt: `prompt_wan3.txt`
- Wan output: `wan3_professional_window_side_seed590831_480p.mp4`
- Remotion project: `remotion/`
- Composition ID: `ProfessionalWindowSide`
- Final output: `final_remotion_documentary_16x9.mp4`
- 生成日: 2026-08-31
- Qwen Cloud task ID: `e7089a1b-b73d-4e8d-bead-bbd0196dab79`
- task status: `SUCCEEDED`（有料生成は1回のみ。再送なし）
- Wan output SHA-256: `9918785b1526255724220204b90751f58d808d7d770a626b4cac19f8eedfffba`
- Wan実測: 832×480、30fps、30.022993秒、H.264、AAC stereo 44.1kHz、15,045,718 bytes。
- 生成費用: `$1.05`（480P `$0.035/秒` × 30秒）。
- Wan映像監査: そば屋の白い仮面・体格・衣装、同じ窓際オフィス、ノートPC単体、ビール1杯、やめ太郎本人のポスター、最後に立って顎へ手を添える思索ポーズを確認。予定した人差し指の追加動作は出なかったが、ユーザー指定の「立って、ちょっと頭良さそうなポーズ」は満たす。
- Wan生成文字監査: 回答1の左下に意図しない英字メタデータ風テロップを確認。再生成せず、Remotionの不透明な肩書き帯と字幕帯で全区間を完全に覆った。
- 音声監査: 音声トラックと3回答区間を確認。Wanの同期音声を初版へ保持。環境に日本語ASRがないため自動語句照合は行わず、台本字幕を文字正本とした。誤読・欠落・演技変更時は、採用済みIrodori修復音声3本で該当回答だけ差し替える。

### Remotion完成記録

- Remotion: `4.0.518`（2026-08-31に`npm view remotion version`で確認し、全`@remotion/*`と同じ正確なバージョンへ固定）
- project: `remotion/`
- composition: `ProfessionalWindowSide`
- manifest: `remotion/src/edit-manifest.json`（1095フレームを唯一のタイミング正本とする）
- final output: `final_remotion_documentary_16x9.mp4`
- final SHA-256: `3183f86d54108bd60a342f2732d96e7e0646903fea53b48cf88981cc2fa0473e`
- final実測: 832×480、30fps、1095映像フレーム、36.544秒、H.264、AAC stereo 48kHz、7,206,761 bytes。
- 構成: 0–4秒導入、黒質問カード3枚、回答1・2・3、30.4–36.5秒の黒背景締めタイトル。
- 文字監査: `YHK`、`プロフェッショナル`、`窓際の流儀`、3質問、会社名、肩書、名前、全字幕を台本と照合。480p実レンダーで明朝・角ゴシックの可読性、2行以内、5%安全域、顔・仮面との非干渉を確認。
- 出力監査: `npm run validate`、`npm run typecheck`、全1095フレームの終端デコード、各質問・回答・字幕・締めの境界フレーム、偽テロップ遮蔽を確認。AAC末尾パディングによりコンテナ尺は映像正本36.500秒より0.044秒長い。

### Irodori音声置換版

- adoption_status: `adopted`
- composition: `ProfessionalWindowSideIrodori`
- final output: `final_remotion_documentary_irodori_16x9.mp4`
- final SHA-256: `60193cd8223073549f927404de9a364e297e7643870d5bfae48b8d54452419f2`
- final実測: 832×480、30fps、1095映像フレーム、36.544秒、H.264、AAC stereo 48kHz、7,293,246 bytes。
- 音声方式: 回答区間のWan音声を完全にミュートし、正典Irodori音声3本をRemotionで配置。字幕もIrodoriの実測尺へ合わせた`irodoriCaptions`へ切り替える。元のWan音声版は別composition・別MP4として維持する。
- Irodori配置（30fps整数フレーム）: 回答1=`177–399`、回答2=`466–615`、回答3=`699–885`。各素材へ3フレームの短い音量フェードを適用。
- 環境音: Wanの非発話Bロール18–22秒から`sobaya_ambient_bed.wav`を作成し、回答区間だけvolume `0.1`で敷く。48kHz stereo PCM、4.000秒、SHA-256 `108904fcf5805bead948318005523822463883a98cb0a8b96ed6f19819055d00`。
- 冒頭: 元のWan環境音を保持し、最初の質問カード直前8フレームでフェードアウト。
- 音声監査: 回答1/2/3の区間平均はすべて約`-23.3〜-23.6 dBFS`、最大は`-3.7〜-4.1 dBFS`でクリップなし。質問カード区間は最大`-37.7 dBFS`以下で実質無音。元回答音声との二重化なし。
- 出力監査: `npm run validate`、`npm run typecheck`、全1095フレームの終端デコード、Irodori音声・字幕の開始直前／開始／終了直前／終了フレームを確認。

### Madogiwa Studio登録

- 登録日: 2026-08-31
- Studio ID: `MS-CLFBD9B4`
- internal episode ID: `6eb67c29-675b-4848-adab-59df8aae646b`
- slug: `professional-window-side-sobaya`
- status: `archived`（Studio登録のみ。公開指示がないため非公開）
- generation: `v1`、ID `61469c88-3f07-4cf0-988f-05e8ea1b4e31`
- generation label: `Wan 3.0 480p + Irodori採用版`
- model: `Wan 3.0 + Irodori-TTS v4.1 Small + Remotion 4.0.518`
- current prompt: `Wan 3.0 30秒・Image 3 + Audio 1プロンプト`
- ready inputs: Image 1そば屋人物同一性、Image 2採用オフィスB、Image 3やめ太郎指名手配ポスター、Irodori採用版の`edit-manifest.json`。
- raw voice privacy: `sobaya_voice_timbre.wav`とIrodori単体WAVは、Studioへの個別音声アップロード許可がないため未送信。声質参照の発行済みチケット1件は`upload_pending`のまま未使用・失効待ち。
- adopted video ID: `991edfa4-92c6-4687-ab51-39213c6dc2f0`
- adopted video: `final_remotion_documentary_irodori_16x9.mp4`、status `ready`、7,293,246 bytes、poster登録済み、featured `false`。
