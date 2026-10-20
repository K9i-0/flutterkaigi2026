# 赤坂・夕景ステージ

採用した `26_SOBAYA_BEER_RAIN/design/stage_concepts/D_akasaka_prompt.txt` の方向性を、Flutter Sceneで動く3D背景にしたもの。実在街区の測量再現ではなく、赤坂の飲食店街と東京タワーを組み合わせたゲーム用の構成。

- `akasaka.glb`: 38メッシュ（32マテリアル＋車の走行グループ6本）の静的背景、35,816四角面（書き出し時に三角化）。東京タワー、鉄骨と支えビル、道路網（大通り・路地・車線・横断歩道・歩道）、街灯、首都高の高架、区画割りした街並み、笠木・ライトアップ帯、屋上設備・屋上広告・航空障害灯、外周のスカイラインを含む。車は `traffic_zpos` / `traffic_zneg` / `traffic_xpos` / `traffic_xneg` / `traffic_hwy_xpos` / `traffic_hwy_xneg` の6ノードで、各ノードは周期（24・30・27単位）で繰り返す配置。ゲームがノードを動かして走らせる。
- PNG: Pillowによる手続き生成テクスチャ。外部写真や生成画像の貼り付けは使用していない。外装6種（`facade_0`〜`5`、4×8単位で反復）は昼の窓の色、`facade_*_emit.png` は点灯した窓だけの発光マップ。ほかに鋼材の錆止め塗装、アスファルト、歩道、遠景（`skyline` / `skyline_emit`）、車のアトラス（車体2色・ヘッドライト・テールランプ）、縦看板6種、屋上広告3種（「祝 ご入社」、`ACCIDENCHUA`、「安全第一」）。
- 時間帯（昼・夕・夜）による発光の強さはGLBに焼き込まず、ゲーム側（`26_SOBAYA_BEER_RAIN/lib/stage_lighting.dart`）でマテリアルごとに設定する。
- 再生成: リポジトリルートで Pillow入りPythonから `26_SOBAYA_BEER_RAIN/tool/build_akasaka_textures.py`、続いて Blender `-b -P 26_SOBAYA_BEER_RAIN/tool/build_akasaka_stage.py`。
- ゲームは `assets/models/akasaka.glb` の相対symlinkで参照。GLTF読込時の座標系に合わせ、シーン側でY軸180度回転する。
- 背景には衝突・転落判定を追加しない。空と夕霞はFlutter SceneのSkybox / Fogで描画。
