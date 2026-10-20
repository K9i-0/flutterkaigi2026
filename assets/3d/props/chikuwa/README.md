# ちくわ / 毒ちくわ — Blender試作

鉄骨ゲームのCTOおだてつ用の候補モデル。2026-10-20制作。ゲームにはまだ組み込んでいない。

- `chikuwa.glb`: 通常色。白い身、中央の茶色い焼き皮。
- `chikuwa_toxic.glb`: 紫色の身と濃紫の皮。参照は `03_SCRIPTS/88_doku_chikuwa/oden_toxic_c_reference.png`。
- 2体はメッシュ・UV・スキンウェイト・骨格・アニメーションを共用し、ベースカラーだけ異なる。粗さ・ノーマルは共通。
- 1体15,552三角形、Root＋8変形骨、`Wiggle` 1.6秒ループ。GLBでは長手方向がY、全長2.6単位。ゲーム採用時にサイズを合わせる。
- 中央の焼き皮は不規則なリング状の盛り上がりを実メッシュに造形。両端と貫通穴の内面を持つ。細かな表面は1024角のテクスチャで補う。
- 手続き的なBlender生成。Tripoや画像生成サービスは使用していない。テクスチャ中間PNGは再生成可能でGLBにも埋め込まれるため追跡しない。

## 再生成・検証

リポジトリルートで実行:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_chikuwa.py
python3 tools/validate_chikuwa.py
```

Blender 5.1.2で生成。検証は2体の形状・UV・ウェイト・骨格・動作の一致、ウェイト合計、骨参照、ループ端点と尺を確認する。

## プレビュー

非公開の確認用ページ: https://madogiwa-chikuwa-lab.geukfyger.chatgpt.site

Sites project ID: `appgprj_6ad712b7ddc481919d8d0dc220f43c53`。公開用チェックアウトは `.local/chikuwa-site/`。修正はこのディレクトリの正本へ行い、公開用へ必要ファイルをコピーする。

```sh
cd 04_GAME_ASSETS/3d/props/chikuwa/preview
npm ci
npm run dev
```

`http://127.0.0.1:8766` を開く。通常版・毒版の比較、単体拡大、再生停止、速度・振幅調整、ボーン、ワイヤーフレーム、色を外した凹凸確認、端面視点、縮小表示を備える。モデルと参照画像は相対symlink、Three.jsは固定版0.180.0をローカルへ準備する。

ブラウザ上の振幅調整はGLBクリップの回転を各ボーンのバインド姿勢から補間する。GLBに収録した動き自体は標準振幅。ゲーム内サイズのボタンは縮小表示の目安であり、実ゲームのカメラ・照明の再現ではない。

2026-10-20: Chromeで2体のロード・全操作・390px幅の表示を確認。ページエラー・HTTPエラーなし。Flutter Sceneへの組み込み、同時落下時の実機負荷、ゲーム内での識別性は未検証。
