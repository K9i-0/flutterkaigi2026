# セットと動作の再利用

## 最小プロジェクト

リポジトリルートで実行:

```sh
python3 .claude/skills/threejs-video/scripts/init_project.py 03_SCRIPTS/<episode>/remotion
cd 03_SCRIPTS/<episode>/remotion
npm ci
npm run typecheck
npm run render
```

初期化は既存ディレクトリを上書きしない。73/74で使用した固定依存とlockfileを再利用する。最新バージョンを意味しない。依存を更新するときだけ公式情報を確認し、全@remotionパッケージを揃える。初期状態は無音8秒の背景＋そば屋DogSniff確認用。完成台本ではない。

assets.jsonはsource（repo root相対）とtarget（public相対）の一覧。prepare_assets.pyがhardlink、別filesystemではcopyし、素材hashをasset-lock.jsonへ記録する。コピー先を編集するとhardlink元も変わるのでpublicを編集しない。モデル正本は画像から毎回作り直さない。

共有コードは04_GAME_ASSETS/3d/stage_video/motion-player.ts。立ち演技と犬の使い方・対象リグは同ディレクトリREADME。TypeScript pathsとwebpack aliasは利用側のthree・React・fiberへ解決し、共有コードの位置にnode_modulesを増設しない。

## Imagegen背景壁

- 背景は人物・文字なし。舞台のカメラ高さ、消失点、照明方向を画像生成指示へ含める。床は別の真上視点テクスチャにする。画像と実プロンプトを作品内へ保存。
- 背景画像をMeshBasicMaterialの壁へ貼る。床はMeshStandardMaterialで人物の影を受ける。sRGB、繰り返しと粗さを設定。背景に描かれた地面を縦壁として露出させない。
- 舞台の原点・単位はメートル。壁の大きさ・位置・画像の地平線、床のrepeatは作品ごとに調整。草、家具などで接続部を隠せるが、見えない箇所へ過剰な作り込みをしない。
- 一枚の壁は大きな横移動・周回に弱い。固定・寄り引き中心。必要なら背景を複数planeに分離するか、別画角用画像を作る。
- 雛形の背景は74の採用画像を参照。密林を新作品の既定世界観にしない。入れ替えはassets.jsonとBackgroundの寸法で行う。

## 動作を増やす

catalogのactor/base/durationに加え、restからかclip上からか、移動経路、接触点、ループ可否、対象モデルの版を残す。小道具はboneの子へ追従。接地型動作は足滑りと膝・肘の反転を複数方向から確認。

DogSniffは内groupの移動＋リグ姿勢を一対で評価。親groupのworld matrixを更新してからIKを評価する。外groupごと役者と匂いの対象を動かすと、別セットでも同じ動きを流用できる。小道具位置だけをずらすと嗅ぐ対象が外れる。

任意時刻を前後にseekして同じ姿勢になることを検査。既存clipを無言で別clipへfallbackしない。犬から直立への遷移は未提供であり、新規制作またはカットによる接続を明記する。
