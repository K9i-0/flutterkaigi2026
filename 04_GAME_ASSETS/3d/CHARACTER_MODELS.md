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

## 別の制作物で使う

- **Blender:** GLBをglTF 2.0としてインポートすれば形状・材質・リグ・収録動作を利用できます。元の編集履歴やBlender固有の設定まで復元するものではありません。
- **Three.js:** `GLTFLoader`で読み込み、`gltf.scene`を配置。動作は`gltf.animations`を`AnimationMixer`で再生します。手振りは、たこさん・やめ太郎が`Wave`、そば屋・福ちゃんが`Greeting`です。
- **このモノレポの別プロジェクト:** モデルの重複コピーを避け、`public/models/`などから上記GLBへ相対symlinkを張ります。既存の[公式サイトの参照先](../../16_MADOGIWA_STUDIO/public/models/characters/)もこの方式です。
- **ゲーム用動作:** そば屋・福ちゃんは動作入りの`hazard_adopted`版を使用。制作元のGLBには同じ動作が揃っていない場合があります。[採用モデルの説明](hazard_adopted/README.md)を参照。
- **モデルの区別:** 本一覧は非ボクセル版です。ボクセル版は別の[VOXEL_CHARACTER_KIT](../voxel/VOXEL_CHARACTER_KIT.md)を使用します。

キャラクターの人物同一性は[キャラクター設定](../../02_CHARACTERS/)を参照。たこさん・やめ太郎の最新版は公式サイトに採用済みですが、各ゲームの参照先が自動でこの版になるわけではありません。

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
