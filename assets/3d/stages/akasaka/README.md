# 赤坂ステージ（昼・夜）

採用した `26_YUMEMI_RECRUIT_EXAM/design/stage_concepts/D_akasaka_prompt.txt` の方向性を、Flutter Sceneで動く3D背景にしたもの。実在街区の測量再現ではなく、赤坂の飲食店街と東京タワーを組み合わせたゲーム用の構成。

- `akasaka.glb`: 39メッシュ（34マテリアル、車の走行グループ6本を含む）の静的背景、35,936四角面（書き出し時に三角化）。東京タワー、鉄骨と支えビル、道路網（大通り・路地・車線・横断歩道・歩道）、街灯、首都高の高架、区画割りした街並み、笠木・ライトアップ帯、屋上設備・屋上広告・ゆめみんの看板5基・航空障害灯、外周のスカイラインを含む。車は `traffic_zpos` / `traffic_zneg` / `traffic_xpos` / `traffic_xneg` / `traffic_hwy_xpos` / `traffic_hwy_xneg` の6ノードで、各ノードは周期（24・30・27単位）で繰り返す配置。ゲームがノードを動かして走らせる。
- PNG: 手続き生成と採用したImagegen素材を組み合わせたテクスチャ（`ad_yumemin.png` はリポジトリ内の正典 `02_CHARACTERS/Yumemin.jpg` を合成）。外装6種（`facade_0`〜`5`、4×8単位で反復）は昼の窓の色、`facade_*_emit.png` は点灯した窓だけの発光マップ。ほかに鋼材の錆止め塗装、アスファルト、歩道、遠景（`skyline` / `skyline_emit`）、車のアトラス（車体2色・ヘッドライト・テールランプ）、縦看板6種、屋上広告3種（「採用試験会場」、`ACCIDENCHUA`、「安全第一」）とゆめみんの看板（`ad_yumemin`）。
- 時間帯（昼・夜）による発光の強さはGLBに焼き込まず、ゲーム側（`26_YUMEMI_RECRUIT_EXAM/lib/stage_lighting.dart`）でマテリアルごとに設定する。
- 再生成: リポジトリルートで Pillow入りPythonから `26_YUMEMI_RECRUIT_EXAM/tool/build_akasaka_textures.py`、`prepare_stage_surfaces.py`（同じtoolディレクトリ、Pillow/NumPyが必要）、続いて Blender `-b -P 26_YUMEMI_RECRUIT_EXAM/tool/build_akasaka_stage.py`。
- ゲームは `assets/models/akasaka.glb` の相対symlinkで参照。GLTF読込時の座標系に合わせ、シーン側でY軸180度回転する。
- 背景には衝突・転落判定を追加しない。空と霞はFlutter SceneのSkybox / Fogで描画。


## 表面品質の改善（2026-10-20）

- `source_imagegen/`: built-in image_genの採用原画5枚、外壁の生成入力3枚、実際のプロンプト。外壁0/3/4は窓・階の配置を保ったタイル外壁／ガラスカーテンウォール／集合住宅。steelは赤錆止め塗装と擦り傷、asphaltは骨材と微細な補修跡。
- `prepare_stage_surfaces.py`は原画の通常縮小とPBRデータマップ生成を行う。色画像の描き直しはしない。窓と壁の粗さ・金属度を分けたMRマップ6枚、鉄骨と路面のMR/浅い法線マップを追加。法線は画像輝度からの控えめな近似で、実測スキャンではない。夜の発光は従来の点灯部屋を維持し、窓内部へ制限。
- 建物の外形・衝突・鉄骨寸法・マテリアルによるバッチ分割は維持。高架の路面もstreet材質へ変更。全ステージ材質を片面描画にし、裏面の不要なピクセル処理を削減。
- 39プリミティブ、71,872三角形を維持。GLBは約6.70→9.91MB。画像をRGBA8へ展開したベースレベル概算は36.51→44.26MiB（mipmap・ドライバ管理分を除く）。追加の昼夜環境マップは128px/面の静的キューブ各1MiB程度＋入力画像。画像はすべて長辺1024px以下。`tool/audit_stage_asset.py`で上限を検査。
- ガラスの映り込みは、生成画像にある静的模様＋昼夜の小さな環境マップによる視点依存の光沢。周囲のゲームオブジェクトや人物を正確に映すリアルタイム反射ではない。追加の反射カメラ・街の再描画・透明ガラスの重ね描きはない。
- 共通のスタジオ照明はアイテム選択プレビューに保持し、ステージには昼夜の屋外照明を使う。これにより商品プレビューと屋外の材質感を分ける。
