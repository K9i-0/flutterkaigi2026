# CTOおだてつ：静的モデル仕上げ

`flutterkaigi2026` 専用。PR #20で管理し、mainへマージしない。

## 成果物

- `cto_odatetsu_static.glb`: テクスチャ内蔵の静的モデル。1メッシュ・1材質。リグとアニメーションは未追加。
- `cto_odatetsu_finished.blend`: 編集用ローカルファイル（再生成可能なためGit対象外）。
- `preview.png`: 書き出したGLBを再読込したレビュー画像。
- 原型は `../tripo_multiview_20261014/raw/output_model_url.fbx`。原型を上書きしていない。

## 修正

1. 目の白目、肌、衣服、靴が金属に見えていたため、生成された金属マップを解除。metallic=0、roughness=0.72、specular IOR level=0.28へ統一。過剰な凹凸が眼球などを汚く見せていた生成ノーマルマップも解除した。
2. 胸文字と靴の内外側の崩れたマークだけをImagegenの局所修復素材で清掃。Blenderの文字オブジェクトから生成した正確な `GROW with YUMEMI`（withは小さめ）と `A` を元のUVへ投影した。顔・髪・フードのテクスチャは投影範囲外。
3. 衣服のシワにある細い隙間16か所だけを四角面で閉じた。元の頂点座標・既存面の構成・既存UVは不変。首、袖、目、髪、靴紐の開口部を一律に塞いでいない。
4. 表示基準として高さ1.75m、接地Z=0、前方-Yへ統一。本人の実測身長を示すものではない。GLBの座標変換はBlender標準エクスポートによる。

## 検証

- `inspection.json` と `mesh_audit.json` は修正前の原型記録。以下の `finish_report.json` と `export_validation.json` が修正後の記録。
- `finish_report.json`: 16面追加、0頂点追加、元の頂点・UV不変、局所テクスチャ編集。
- `export_validation.json`: 最終GLB再読込の材質・テクスチャ・境界寸法を確認。
- 正面・背面・両側面・斜め、顔・胸・手・靴の拡大を `qa/after_*.png` に再描画。
- 全身16,456元頂点。GLBはUV/法線境界で37,121頂点、32,346三角面。4096×4096のBase Colorを内蔵。
- 手・手首の監査領域は境界0、3面以上の共有辺0。指の作り直しは行っていない。
- 修正後も髪・服の開口部などに584境界辺・30本の3面以上共有辺が残る。完全閉曲面／3D印刷用モデルの合格を意味しない。
- 胸の文字は実際の紐で一部が隠れる。文字を紐の上へ描いていない。
- リグ変形・実ゲーム表示・カメラ装備は未検証。

## 再生成

Blender 5.1.2、Python標準ライブラリとBlender同梱numpy。文字にはmacOSのArial Bold Italicを利用する。Imagegenで採用した修復素材とそのプロンプトは `repair_inputs/` に保持。

仕上げの再生成にはローカルの `../tripo_multiview_20261014/raw/output_model_url.fbx` が必要。元FBXはGit対象外のため、Git cloneだけでは仕上げを再実行できない。追跡済みの完成GLBは単体で利用でき、回転動画の再レンダーにも元FBXは不要。

1. `Blender -b -t 6 --python import_source.py`
2. `Blender -b -t 6 --python prepare.py`
3. `Blender -b -t 6 --python finish.py`
4. `Blender -b -t 6 --python verify.py`

各スクリプトはこのディレクトリのパスを渡して実行する。`import_source.py` は原型FBXから始め、各修正を不変のベースへ一度だけ適用する。`qa/` と中間blend、独立albedoは再生成可能なローカル成果物。
