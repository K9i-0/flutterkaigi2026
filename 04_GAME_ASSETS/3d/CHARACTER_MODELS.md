# 窓際族物語・共有3Dモデル一覧

更新日: 2026-09-16。**モデルを使いたい場合は、まず下表の「採用GLB」を使用してください。** 公式サイトの3D表示・ARで使用している非ボクセルモデル4体です。旧版・生成直後のモデルと取り違えないための共有入口です。

共有URL: https://github.com/K9i-0/Seedance_Madogiwa-voxel-game/blob/main/04_GAME_ASSETS/3d/CHARACTER_MODELS.md

## 採用モデルと完成度

完成度は2026-09-16時点のユーザー評価です。形式検査の合否とは別に扱います。

| キャラ | 完成度・現状 | 採用GLB（Git管理済み） | サイズ | 収録動作 |
| --- | --- | --- | --- | --- |
| たこさん | **かなり完成度が高い**。放射状の6本脚、中央残骸の除去、丸い手＋突起1本を反映 | [takosan.glb](characters/takosan/rig_radial_v4_hands/takosan.glb) | 約1.45 MiB | 3本: Idle / Talk / Wave |
| やめ太郎 | **かなり完成度が高い**。鼻は黒点ではなく肌色の膨らみ。ARの側面の三角形状のムラも修正済み | [yametaro.glb](characters/yametaro/rig_nose_v3/yametaro.glb) | 約3.25 MiB | 4本: Idle / Talk / Walk / Wave |
| そば屋 | **改善の余地あり**。v2の仮面修正版 | [sobaya.glb](hazard_adopted/v2_20260915_mask/sobaya.glb) | 約22.48 MiB | 103本。Idle / Walk / Run / Greetingなど |
| 福ちゃん | **課題が多い**。Tripo由来の実写系v2。完成版の品質基準として扱わず、用途ごとに見た目・動作を確認 | [fukuchan.glb](hazard_adopted/v2_20260913/fukuchan.glb) | 約18.51 MiB | 99本。Idle / Walk / Run / Greetingなど |

そば屋・福ちゃんの詳細な改善項目はこの一覧では未確定です。制作記録は、それぞれ[そば屋v2仮面修正](characters/sobaya/v2_20260915_mask/README.md)、[福ちゃんv2](characters/fukuchan/v2_20260913/README.md)を参照してください。

### コピーして使えるリポジトリ内パス

すべてリポジトリルートからの相対パスです。特定の開発者のMacの絶対パスではありません。

```text
04_GAME_ASSETS/3d/characters/takosan/rig_radial_v4_hands/takosan.glb
04_GAME_ASSETS/3d/characters/yametaro/rig_nose_v3/yametaro.glb
04_GAME_ASSETS/3d/hazard_adopted/v2_20260915_mask/sobaya.glb
04_GAME_ASSETS/3d/hazard_adopted/v2_20260913/fukuchan.glb
```

## まず見てみる・ダウンロードする

リポジトリを取得しなくても公式サイトで確認できます。「紹介」の「3Dで見る」は回転・拡大・動作確認用、「AR」はiPhoneのSafari向けです。GLBリンクは公式サイトで現在配信しているモデルで、今後の採用変更時には内容が更新されます。再現性が必要ならGitのコミットと上記パスを固定してください。

| キャラ | 3D表示の入口 | AR撮影 | 配信GLB |
| --- | --- | --- | --- |
| たこさん | [紹介](https://madogiwa.work/characters/takosan) | [AR](https://madogiwa.work/camera/takosan) | [GLB](https://madogiwa.work/models/characters/takosan.glb) |
| やめ太郎 | [紹介](https://madogiwa.work/characters/yametaro) | [AR](https://madogiwa.work/camera/yametaro) | [GLB](https://madogiwa.work/models/characters/yametaro.glb) |
| そば屋 | [紹介](https://madogiwa.work/characters/sobaya) | [AR](https://madogiwa.work/camera/sobaya) | [GLB](https://madogiwa.work/models/characters/sobaya.glb) |
| 福ちゃん | [紹介](https://madogiwa.work/characters/fukuchan) | [AR](https://madogiwa.work/camera/fukuchan) | [GLB](https://madogiwa.work/models/characters/fukuchan.glb) |

公式サイトのそば屋は2026-09-17に **v3（未リグ・静止モデル）** へ更新。正本は [仕上げ版GLB](characters/sobaya/wan_multiview_20260916/imagegen_mask_v1/sobaya_refined_final.glb)、制作記録は [FINAL.md](characters/sobaya/wan_multiview_20260916/FINAL.md)。3DビューとARは静止姿勢で利用できます。ゲーム採用版は上表のv2を維持しています。

## 別の制作物で使う

- **Blender:** GLBをglTF 2.0としてインポートすれば形状・材質・リグ・収録動作を利用できます。元の編集履歴やBlender固有の設定まで復元するものではありません。
- **Three.js:** `GLTFLoader`で読み込み、`gltf.scene`を配置。動作は`gltf.animations`を`AnimationMixer`で再生します。手振りは、たこさん・やめ太郎が`Wave`、動作入りそば屋v2・福ちゃんが`Greeting`です。公式サイトのそば屋v3には動作を収録していません。
- **Flutter Scene:** 同じGLBをビルド時に変換し、`loadScene()`で読み込んで`Scene`へ追加。`SceneView`で表示します。導入手順と短いコード例は下記を参照。
- **このモノレポの別プロジェクト:** モデルの重複コピーを避け、`public/models/`などから上記GLBへ相対symlinkを張ります。既存の[公式サイトの参照先](../../16_MADOGIWA_STUDIO/public/models/characters/)もこの方式です。
- **ゲーム用動作:** そば屋・福ちゃんは動作入りの`hazard_adopted`版を使用。制作元のGLBには同じ動作が揃っていない場合があります。[採用モデルの説明](hazard_adopted/README.md)を参照。
- **モデルの区別:** 本一覧は非ボクセル版です。ボクセル版は別の[VOXEL_CHARACTER_KIT](../voxel/VOXEL_CHARACTER_KIT.md)を使用します。

キャラクターの人物同一性は[キャラクター設定](../../02_CHARACTERS/)を参照。たこさん・やめ太郎の最新版は公式サイトに採用済みですが、各ゲームの参照先が自動でこの版になるわけではありません。

### Flutter Sceneでの最小の使い方

このリポジトリの[そば屋ハザード](../../21_SOBAYA_HAZARD_LAB/README.md)の実装例です。Flutter 3.47.2／Flutter Scene 0.23.0を基に、修正を含む`vendor/flutter_scene`をpath依存で使用しています。以下はこの構成向けで、別バージョンではAPI・ビルド方法を確認してください。

1. `assets/models/yametaro.glb`などから採用GLBへ相対symlinkを張る。
2. [hook/build.dart](../../21_SOBAYA_HAZARD_LAB/hook/build.dart)の`buildScenes(inputFilePaths: [...])`へパスを明示する。自動探索はsymlinkを除外するため、この指定が必要。[pubspec.yaml](../../21_SOBAYA_HAZARD_LAB/pubspec.yaml)で`flutter_scene_generated/`をassetsへ登録する。GLBのパスを登録するだけではなく、ビルド時に生成されるシーンを読み込む構成。
3. 非同期の初期化処理で読み込み、シーンへ追加して動作を再生する。

```dart
import 'package:flutter_scene/scene.dart';

// 非同期の初期化処理内。Widgetのbuild()内で毎回読み込まない。
final scene = Scene();
final model = await loadScene('assets/models/yametaro.glb');
scene.add(model);
final idle = model.findAnimationByName('Idle');
if (idle != null) {
  final clip = model.createAnimationClip(idle)
    ..loop = true
    ..weight = 1;
  clip.play();
}
```

表示側は`SceneView(scene, cameraBuilder: (_) => camera)`でカメラを指定し、必要な照明・環境も設定します（`camera`はアプリ側で用意）。実際の[ロード・カメラ・解放処理](../../21_SOBAYA_HAZARD_LAB/lib/lab/lab_controller.dart)、[SceneViewの配置](../../21_SOBAYA_HAZARD_LAB/lib/main.dart)、[アニメーション切替](../../21_SOBAYA_HAZARD_LAB/lib/lab/rig_actor.dart)を参照してください。利用後はノードをシーンから外し、ロードに対応して`releaseScene('assets/models/yametaro.glb')`を呼びます。初回のGLB変換・テクスチャ圧縮には時間がかかります。

## 制作方法とTripo API費用

基本の流れは **正典の写真・キャラクターシート → Imagegenで3D生成用の参照画像 → Tripo APIで形状・PBR材質を生成 → Blenderで形状・材質・リグ・動作を調整 → GLB → 実際の表示先で確認**。生成されたモデルをそのまま完成品として配布したわけではありません。

### 実績クレジットと日本円の目安

下表のクレジットは、現在の採用モデルの元になった生成回の記録です。モデルは`P2-20260801`、詳細PBR・quad指定で、生成1回120クレジット、利用した自動リグは1回25クレジットでした。**今後のすべてのモデル・設定で同額になるという意味ではありません。**

API単価は[Tripo公式料金表](https://docs.tripo3d.ai/get-started/pricing.html)の **100 credits = US$1.00**（2026-09-16確認）を使用。Web版Studioの月額プランとは分けて考えます。円換算は比較用に**1米ドル＝150円と仮定**した参考額で、当日の為替や実際のカード請求額ではありません。

`参考円額 = 消費クレジット ÷ 100 × 150`（四捨五入）。実際の費用は購入条件・為替・税・決済手数料・無料枠の利用で変わります。

| キャラ・生成回 | Tripo API内訳 | 消費 | API単価換算 | 参考円額 | 実績の根拠 |
| --- | --- | ---: | ---: | ---: | --- |
| たこさん・2026-09-06 | 正面＋背面の複数画像から1体生成120。リグはBlenderで制作 | 120 | $1.20 | 約180円 | [生成記録](characters/takosan/tripo_sheet_p2_20260906/provenance.json)、[制作記録](characters/takosan/README.md) |
| やめ太郎・2026-09-06 | 正面＋背面から生成120＋自動リグ25 | 145 | $1.45 | 約218円 | [生成記録](characters/yametaro/tripo_sheet_p2_20260906/provenance.json)、[リグを含む費用記録](characters/yametaro/README.md) |
| そば屋v2・2026-09-13 | 体120＋頭（髪・仮面込み）120＋体の自動リグ25 | 265 | $2.65 | 約398円 | [費用・タスク記録](characters/sobaya/v2_20260913/provenance.json) |
| 福ちゃんv2・2026-09-13 | 体120＋髪のない頭120＋髪120＋体の自動リグ25 | 385 | $3.85 | 約578円 | [費用・タスク記録](characters/fukuchan/v2_20260913/provenance.json) |
| **上記の採用生成回の合計** | 生成7回＋自動リグ3回 | **915** | **$9.15** | **約1,373円** | 丸め前の合計から換算 |

**全開発費の合計ではありません。** 旧版や不採用の試行、Imagegen等の参照画像生成費、作業者・AIエージェントの費用、Blenderでの調整時間は含めていません。そば屋v2は採用前の不採用試行240クレジット（$2.40／参考約360円）が別途記録されており、これだけを足すとそば屋v2関連は505クレジットです。全キャラの過去試行を網羅した総額ではありません。

たこさんの脚・手、やめ太郎の鼻、そば屋の仮面の後修正はローカルのBlender処理で、**追加のTripoクレジットは0**。AR変換の修正もTripo APIを呼びません。人手・計算資源まで無料という意味ではなく、作業時間の実測記録はありません。

### 実際に行った工程

1. **参照を揃える。** 非実写キャラは標準キャラクターシート、実写由来は正典写真を基準に、全身・手足が欠けないAポーズと必要な背面／側面画像を用意。Imagegenの入力画像・プロンプトも保存する。そば屋v2は全身参照3候補からユーザーがCを選択。
2. **TripoをAPIから呼ぶ。** [単画像用スクリプト](../../tools/tripo_generate.py)と[複数画像用スクリプト](../../tools/tripo_multiview.py)を使用。各生成フォルダの`config.json`にモデル・入力・seed・face_limit・材質設定を保存。前後の残高、task ID、入力ハッシュ、取得物の記録を残す。
3. **取得物と必要なリグを揃える。** 人型では無料のrig-check後に自動リグを使用した例がある。たこさんの触手はBlenderで専用骨格を制作。GLB指定でも取得実体がFBXだった例があるため、ファイルの実体を確認してBlenderへ読み込む。
4. **Blenderで整える。** パーツ接合、余分な形状の除去、裏地・切断面の補完、骨の位置、ウェイト、肌色・法線、表情や動作を調整。繰り返す処理はBlender Pythonのスクリプトに残す。
5. **GLBに書き出し、使用先で確認する。** ファイル構造だけでなく、正面・側面・背面、手足の動作、口パクを確認。ゲーム採用時は追加動作を転写し、ARは変換済みUSDZをiPhone Safariで確認する。Blenderで正しくても別の描画環境で同じとは限らない。

### キャラごとの調整と得られた知見

| キャラ | 生成後にBlenderで行ったこと | 今回の制作から得た知見 |
| --- | --- | --- |
| たこさん | 余分な触手の除去、6本を放射状に配置、中央残骸の除去、袖の裏地、丸い手＋突起1本、触手リグとIdle/Talk/Wave制作 | 脚の本数・方向や手の突起は参照だけでは狙いどおりにならず、形状を直接修正した。非人型の触手は専用リグをローカル制作 |
| やめ太郎 | 顔の不要な黒い帯と溝を除去、肌と襟の色補修、頬・髪が腕について伸びるウェイト修正、口モーフ、黒点鼻を肌色の膨らみに変更 | 不要な線は形状・色・法線の複数に残る場合がある。顔を直す際は形状だけでなく材質も確認。自動リグは頭部のウェイト検査が必要 |
| そば屋 | 体と頭を接合、首・襟の補完、頭ボーン位置・肩ウェイト調整、仮面の縁と顎を修正、既存モーションの転写 | 顔・仮面の同一性が品質を左右する。体と頭を分けると個別に調整できるが、接合・首・動作転写の作業は増える。現状も改善余地あり |
| 福ちゃん | 体・頭・髪の3パーツを接合、首・肩・手首と腕の長さを調整、両手の指ボーン・ウェイト追加、表情・挨拶の制作 | 部位別生成でも実写人物の顔・髪・体格・関節の自然さが自動で完成するわけではない。API消費が増えても完成度を保証せず、現状は課題が多い |

これはこの4体での制作経験です。Tripo全般の実写人物への性能を断定する比較試験ではありません。今回の傾向として、**たこさん・やめ太郎は後調整でかなり良い仕上がりになり、そば屋・福ちゃんは引き続き調整が必要**です。生成クレジットだけでなく、参照準備と後調整・検証も制作コストとして見積もります。

### 再利用・再生成時の注意

- 既存モデルを使うだけなら、新しいTripo生成は不要。まず上表の採用GLBを取得する。
- 元の取得物が必要な場合は記録済みtask IDからの取得可否を確認する。通信失敗だけで`submit`をやり直さず、先に既存タスクの状態を確認する。
- 新規生成を行う際は、その時点のAPIモデル・料金と予算を確認する。このMarkdownの120クレジットは過去の実績値。
- `face_limit`の要求値と実際の面数は一致するとは限らない。用途の負荷は最終GLBの面数・材質数・容量と実機表示で判断する。
- APIキー・期限付きダウンロードURLは共有MarkdownやGitへ記載しない。再現用の入力・設定・スクリプトと採用GLBを残す。

## Blender編集ファイル

GLB4体はGitから取得できます。`.blend`の共有状況は異なります。**ローカル保持のファイルは、リポジトリをcloneしても取得できません。必要な場合は制作担当者から別途共有してください。**

| キャラ | 編集ファイル（リポジトリルートから） | 共有状況・詳細 |
| --- | --- | --- |
| たこさん | `04_GAME_ASSETS/3d/characters/takosan/rig_radial_v4_hands/takosan.blend` | ローカル保持。[修正記録](characters/takosan/rig_radial_v4_hands/README.md) |
| やめ太郎 | `04_GAME_ASSETS/3d/characters/yametaro/rig_nose_v3/yametaro.blend` | ローカル保持。[修正記録](characters/yametaro/rig_nose_v3/README.md) |
| そば屋 | `04_GAME_ASSETS/3d/characters/sobaya/v2_20260915_mask/sobaya_v2.blend` | Git管理済み。[編集ファイル](characters/sobaya/v2_20260915_mask/sobaya_v2.blend)。配布GLBへのゲーム動作追加は別工程 |
| 福ちゃん | `04_GAME_ASSETS/3d/characters/fukuchan/v2_20260913/fukuchan_v2.blend` | ローカル保持。[制作・再現手順](characters/fukuchan/v2_20260913/README.md) |

## ARで使う場合

AR用USDZは固定ファイルとして管理せず、GLBから**ブラウザ内で生成**しています。AppleのQuick Lookへ渡すときだけポーズを固定するため、元GLBのアニメーションは残っています。写真・カメラ映像をサーバーへ送信する処理はありません。

- 初期サイズは等身大。そば屋180cm、福ちゃん170cm、たこさん約143cm、やめ太郎130cm。ぬいぐるみ20cm、自撮り用12cmも選択可能。
- 変換はThree.js `USDZExporter`と補助処理を使用。元の法線の保持、両面材質の裏面追加、肌色と反射・光沢のUV分離、テクスチャ上限4096pxを反映済み。
- 修正前の変換を再実装すると、フードの内側の消失や肌の三角形状のムラが再発します。共有の[AR変換実装](../../16_MADOGIWA_STUDIO/src/official/character-ar-export.ts)を参照してください。
- SafariのAR画面から「オブジェクト」表示に切り替えると、カメラ背景なしで回転・拡大確認できます。Androidは動作未保証。
- ローカル試作の起動方法は[ARプレビューREADME](../../16_MADOGIWA_STUDIO/ar-preview/README.md)。たこさん・やめ太郎の改善版はユーザーのiPhone確認を経て本番反映済み（`3f759c4`）。

モーションの出典・利用条件は[モーションライブラリ](motion_library/README.md)と各モデルの制作記録を引き継ぎます。モデル一式を一律にCC0として扱わないでください。
