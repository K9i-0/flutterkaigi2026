# CTOおだてつ：カメラ装備用GLB

`flutterkaigi2026` 専用。mainへマージしない。

`odatetsu_camera.glb` は、架空表記へ置換した α7 V＋FE 70–200mm F2.8 GM OSS II 相当のカメラ。人物と独立した、テクスチャ内蔵の静的アセット。ストラップは装備プレビュー側の別部品とする。

## 形状・文字

- 2枚の採用Imagegen入力から生成したTripo原型を使用。元FBXは `../tripo_20261014/raw/output_model_url.fbx` にローカル保持し、上書きしない。
- 本体幅を130.3mm基準へ均等縮尺。生成では望遠部が短くなったため、マウント前のレンズだけ光軸方向1.5倍、半径方向最大1.25倍へ補正した。マウント付近の半径補正は滑らかにつなぐ。本体・グリップを鏡像化しない。
- レンズ＋フードの長いシルエットを再現。全長339.6mm、フード部約70mm。三脚座・EVF・液晶・ダイヤル・端子カバーは元生成形状を保持する。
- 前側フォーカスリングを20mm幅の薄い黒ゴム部品で補い、前後2本の黒リングを明確にした。
- `ODATETSU`、`O7 V`、赤地の `O` は正確な文字メッシュを使用。厚さ0.4mmの面で元の崩れた文字を隠す。元画像をPythonで編集せず、すべてBlender内で生成する。
- 生成された金属・粗さ・法線マップを解除し、metallic=0、roughness=0.54で塗装・ゴム・樹脂として仕上げる。Base Colorは維持する。

寸法は指定製品の外観比率へ寄せたもので、CAD精度の複製ではない。元の生成に由来する小ボタンや印字の簡略化は残る。実機の寸法参照は [本体仕様](https://www.sony.jp/ichigan/products/ILCE-7M5/spec.html)、[レンズ仕様](https://www.sony.jp/ichigan/products/SEL70200GM2/)。

## 座標とアンカー

glTFの右手系、単位メートル。**+Y上、+Zレンズ前、-Xグリップ側**。本体中心付近を原点にし、光軸は本体中心から+X側にある。レンズを正面から見たグリップは画面左なので、+Zレンズ前と+Xグリップを同時に要求して鏡像化しない。

`GripAnchor`、`LensTip`、`StrapAnchorLeft`、`StrapAnchorRight` はGLB内の空ノード。回転identity、scale=1。位置と用途は `asset.json` を正本とする。Left/Rightはそれぞれ負X/正X側を意味する。装備側では `GripAnchor` を取得し、人物の手の姿勢に合わせた位置・回転補正を加える。

## 検証と再生成

`validate.py` はBlenderを使用せず、Python標準ライブラリでGLBのバイナリとノード階層を検証する。最終SHA、頂点・三角面数、実測bounds、埋め込み画像、アンカーのワールド座標は `validation.json`。`asset.json` とSHAが一致する。

四方向と斜め・文字近接の再読込レンダーは `qa/`、選択した斜め画像は `preview.png` にローカル保持し、いずれもGit対象外。構造検証は文字認識や完全閉曲面の保証ではない。

Blender 5.1.2、macOS Arialを使用する。

```sh
Blender -b -t 6 --python build.py
python3 validate.py
Blender -b -t 6 --python review.py
```

各スクリプトには、このディレクトリからの実行または絶対パスを指定する。仕上げ再生成にはローカルの元FBXが必要。Git cloneだけで元FBXは入手できないが、完成GLBの表示・装備・レビュー再描画は完成GLB単体から実行できる。`inspect_source.py` は元FBXの監査用で、通常の表示には不要。`qa/`、`preview.png` と中間blendはGit対象外。
