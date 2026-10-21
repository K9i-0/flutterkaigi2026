# ゆめみ採用試験

FlutterKaigi 2026向けの、Flutter Scene製3Dミニゲームのリポジトリです。ゆめみの採用試験で、受験者が赤坂の高層ビルの間に架かった鉄骨を渡らされる、というネタのゲームです。

- 端末を傾けて鉄骨の上を左右に移動し、落ちてくる「あたり」だけを20秒間キャッチします。
- 画面を左右にスワイプすると、カメラが30度ずつ回ります（一周できます）。
- キャラクター（福ギュン・CTOおだてつ・そば屋）と時間帯（昼・夜）を選べます。

ゲームの詳細・仕様・検証記録は [app/README.md](app/README.md) にあります。

## すぐに動かす

macOS、Xcode、iOS Simulator、[mise](https://mise.jdx.dev/) が必要です。

```sh
git clone https://github.com/K9i-0/flutterkaigi2026.git
cd flutterkaigi2026
mise trust .mise.toml && mise install
cd app
mise exec -- flutter pub get
open -a Simulator
mise exec -- flutter run -d <device-id>
```

- Flutterは `.mise.toml` の3.47.2を使います。
- 初回はビルドフックがGLBを変換するので時間がかかります。
- モデル・画像・効果音はリポジトリ内の相対シンボリックリンクで参照しています。`app/` だけを切り出さず、リポジトリごとcloneしてください。
- シミュレーターでは傾きセンサーが使えないので、矢印キーで移動します。
- VS Codeではルートを開き、「ゆめみ採用試験 (debug)」を選んでF5で起動できます。

検証は `app/` で `mise exec -- flutter analyze` と `mise exec -- flutter test` を実行します。ステージの描画予算は `python3 tool/audit_stage_asset.py` で確認します。

## 構成

| パス | 内容 |
|---|---|
| [app/](app/) | ゆめみ採用試験（Flutterアプリ本体） |
| [assets/](assets/) | ゲームが参照する3D・音声の共有素材（赤坂ステージ、キャラクターのGLB、ちくわ・缶など） |
| [characters/](characters/) | キャラクター設定（`*.md`）、正典写真、キャラクターシート（`sheets/`）、小道具の正典（`props/`）、ボイス参照 |
| [packages/](packages/) | 共有Dartパッケージ（`madogiwa_engine`、`flutter_scene_vrm`） |
| [labs/](labs/) | 以前に作ったFlutter Scene製のゲーム・検証アプリ |
| [tools/](tools/) | 素材生成・監査スクリプト（主に `labs/` 向け） |

### labs

| パス | 内容 |
|---|---|
| [labs/sobaya_hazard_lab/](labs/sobaya_hazard_lab/) | そば屋ハザード（本編と3D検証室） |
| [labs/sobaya_hazard/](labs/sobaya_hazard/) | そば屋ハザードの再設計版 |
| [labs/sobaya_tidewater/](labs/sobaya_tidewater/) | そば屋ハザードのTidewater移植プレビュー |
| [labs/sobaya_ippai/](labs/sobaya_ippai/) | そば屋の一杯 |
| [labs/flutter_scene_game/](labs/flutter_scene_game/) | 窓際族・無人島クラフト（ボクセル） |
| [labs/flutter_scene_vrm_lab/](labs/flutter_scene_vrm_lab/) | VRM・顔トラッキング検証室 |
| [labs/humanoid_motion_lab/](labs/humanoid_motion_lab/) | そば屋モーションラボ |

## 素材の原本について

このリポジトリには、ゲームが実際に読み込む完成版の素材だけを入れています。3Dモデルの作業ファイル（Blenderの原本、リグの元データ、ボクセルの原本など）、動画の台本・生成物、Webサイトは [Madogiwa Multimedia Universe](https://github.com/K9i-0/madogiwa-multimedia-universe) に残っています。原本から再生成するスクリプトの一部は、それらの素材があるMMU側で実行する前提です。

## 来歴

2026-10-19に、Madogiwa Multimedia Universeの `flutterkaigi2026` ブランチから独立しました。2026-10-21に、ゆめみ採用試験とFlutter Scene系のゲームだけを残すようgit履歴ごと整理しています。詳細は [MIGRATION.md](MIGRATION.md) を参照してください。

作品・IPの名前は「窓際族物語」です。元は同僚のそば屋さん（[sobaya-0141](https://github.com/sobaya-0141)）の [Seedance_Madogiwa](https://github.com/sobaya-0141/Seedance_Madogiwa) から始まったプロジェクトです。
