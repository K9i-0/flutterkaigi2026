# 村の広場

そば屋ハザード第一章の共有正本。`village.glb` は26,068三角面・21材質、5軒の民家、2階へ続く階段、見張り塔、井戸、荷車、農場側の門、6枚の収集ポスターを含む。`village.json` は衝突・階段・敵・拾得物・ポスターの配置正本。ゲームから相対symlinkで参照する。

原作バイオハザード4の[公式ガイド抜粋](https://static.capcom.com/residentevil/files/ResEvil2.pdf)掲載の村を配置関係の参考にして新規制作。ゲームデータから抽出したマップではなく、縮尺・建物の細部・全導線は一致していない。

`textures/stone.png` / `earth.png` はbuilt-in Imagegenによる専用アルベド。最終プロンプトを `textures/prompts.json` に保存。壁3m／地面5mの周期で適用する。木材 `oak-v1.png`、瓦 `roof-v1.png`、漆喰 `plaster-v1.png` もbuilt-in Imagegenで生成。プロンプトは `textures/detail-prompts-v1.json`。木材1.4m／瓦1.5m／漆喰3m周期、UV方向は木目・屋根勾配に合わせる。ポスター画像は03_SCRIPTSの採用画像を768px幅でGLBに埋め込み、拡大ギャラリーは元画像の相対symlinkを参照する。

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_hazard_village.py
```

同時に `../../props/hazard_kit/items.glb` を生成する。静的な建物本体を材質ごとにまとめ、屋根・門・収集ポスターは独立ノードとして表示制御できる。視点遮蔽のため家に入ると屋根を隠す。

2026-09-12: [Imagegenの目標画](../../../../21_SOBAYA_HAZARD_LAB/design/graphics-20260912/village-target.png)を参考に、青灰寄りの瓦、漆喰・暗い梁の面分け、窓格子、軒の垂木、側面の腰板と低い植生を追加。道・苔・建物際の接地陰を1.5mグリッドの頂点色へ焼き込み、共有アルベドへ乗算する。テクスチャ枚数12・ランタイム光源数は増やさず、79 meshes / 127 primitives。旧来の石柱状外周は連続した森林の稜線に変更し、北の遠景樹木120本は2枚カード・1本4三角面を1ノードにまとめた。歩行範囲の遮蔽物には使用しない。

生成のアート処理は `tools/hazard_environment_art.py`。環境だけの再生成には上記コマンド末尾へ `-- --environment-only` を付ける。glTFの `COLOR_0` を名前指定で書き出し、Blenderの「材質ノードで未使用」の既定除外を防いでいる。[3章の独立GLB監査](../../../../21_SOBAYA_HAZARD_LAB/qa/environment-art-20260912.json)で配置JSON同一性、扉・窓180本のレイ、屋内で隠す屋根ノード、画像枚数・描画予算を確認。画像は制作上の目標で、実機性能の証明ではない。

2026-09-06: 窓台・四分割の窓枠・雨戸・軒・ランタン・食器・棚・戸棚の細部を追加。床面は歩行面Y=0へ整合。遠景樹木は `textures/pine-v1.png`（プロンプト `textures/pine-prompt-v1.json`）の3枚の交差カード、1本6三角面。alphaMode MASK／cutoff 0.45／両面、空間ごとにまとめて可視判定する。プレイ領域の遮蔽物には使わない。草は曲がった細い葉の輪郭へ変更。

2026-09-06: 導入の切り返しで地面の端が見えないよう、南入口の外に林道・丘・48本の樹木・石柱・木柵を追加。`tools/hazard_entrance_backdrop.py` で生成し、地形と樹木は空間ごとにまとめる。追加は1,224三角面・102,456 bytesで、材質20種・画像12枚は共用のまま。`village.json` の衝突・敵・拾得物・収集品は変更していない。

2026-09-12 第2パス: 実ゲーム画面で目立った三角板状の草を、細長い2面の折れ葉と暗い低彩度オリーブへ変更。根元の陰・配置密度・不規則な基礎石も調整し、画像とprimitive数を維持したまま3章全ての三角面数を第1パス以下に収めた。監査JSONに比較値と実画面の参照を記録。

2026-09-12 描画負荷パス: House_本体は各家の頂点色を焼いた後、`tools/hazard_environment_batch.py` で材質ごとに `StaticArchitecture` へ結合する。村は40・農場は30のprimitiveを削減。屋根・門・収集物・標的・炎・樹木patchは独立した表示ノードを保持する。建物ごとのカリングは行わず、最大26,068三角面の小さな村でCPU描画処理を優先した。結合前後の全コーナーの位置・面方向・UV・色・材質の署名が一致し、[独立GLB比較](../../../../21_SOBAYA_HAZARD_LAB/qa/environment-batching-20260912.json)でも結合対象の全三角面の属性と個数、全ての非Houseノード名の保持を確認した。
