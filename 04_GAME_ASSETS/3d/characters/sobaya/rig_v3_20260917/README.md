# そば屋 v3：姿勢補正とゲーム用リグ

入力は公式サイトで採用済みの `../wan_multiview_20260916/face_red_edge_20260917/sobaya_front_matched.blend`。仮面外周、90%縮小済みの顔パーツ、目の縁まで延長した赤模様を保持。

## 姿勢とスキニング

- 正面の向きを揃え、全身を約10度後ろへ戻して前傾と靴底の傾きを補正。これは剛体変換と一様スケールで、顔の比率や体格を局所変形しない。
- `SobayaV3Rig`：24骨。体幹、首・頭、肩・上腕・前腕・手、腿・膝・足首・爪先、`PropSocket.R`。
- 仮面・目・鼻・口・額の丸・髪は頭に追従。仮面用材質の頂点を頭へ固定し、首のウェイトで輪郭を変形させない。
- 体と腕、膝・足首は連続した解剖学的ウェイト。ズボン・靴は連結成分で識別し、近くに垂れた手指へ脚のウェイトが混ざるのを防ぐ。最大4影響、正規化。
- 手指は左右それぞれ手ボーンに固定。指ごとの開閉・握り込みは今回のリグに含めない（旧ゲーム採用v2も同方式）。

## モーション

元入力は `hazard_adopted/v2_20260915_mask/sobaya.glb`。103クリップのIDを保持。初期姿勢と関節位置の違いを考慮してワールド姿勢から再計算し、歩走・待機の接地を補正。ジャンプ・登攀等の浮上は一律に地面へ固定しない。

歩行・追跡の実測足速度は `rig_report.json`。ゲーム側の再生速度定数とmanifestを同時更新。ジョッキソケットは手に追従し、元クリップの小道具の向きを引き継ぐ。

## ファイルと再現

- `sobaya_animated.blend`：テクスチャ・リグ・103モーション入り編集用正本。
- `sobaya_rig.glb`：配布用。ゲームは `hazard_adopted/v3_20260917/sobaya.glb` 経由で参照。
- `posture_before_side.png` / `posture_after_side.png`：同視点の姿勢比較。
- `qa/`：GLB再読込後、ジョッキ付き6動作×2位相。
- `skinning_report.json` / `rig_report.json`：構成・出典・速度・ハッシュ。

順にBlenderで `tools/build_sobaya_v3_rig.py`、同スクリプト `-- --rig`、`tools/retarget_sobaya_v3.py`、`tools/review_sobaya_v3.py`。Pythonで `tools/adopt_sobaya_v3.py`。最後に `node tools/validate_hazard_adopted.mjs`。

MCPによる本編での検証記録は `21_SOBAYA_HAZARD_LAB/qa/sobaya-v3-20260917.json`。公式サイトも同日の追加依頼で本GLBへ更新（URL世代 `v3-rig-upright-20260917`）。

モーションの利用条件は元ライブラリの条件を引き継ぐ。Mixamo由来を含むため一式をCC0として扱わない。

## 股周りの追加修正（2026-09-17）

ダンスで股下が三角形に尖る原因は、ズボン中央で左右の腿ウェイトが急に切り替わること。細分化後に `tools/sobaya_pelvis_weights.py` で中心15cm幅を滑らかにつなぎ、骨盤の影響を中央へ補う。顔・体格・頂点位置・UV・骨・モーションは維持。修正前後3ダンス×4位相を正面・背面で比較（`qa/pelvis_comparison.png`）。この処置はベースウェイトへ一度だけ適用し、修正済みウェイトへ累積しない。

公式サイト公開世代: `v3-rig-pelvis-20260917`。公開GLBのSHA-256は `qa/pelvis_invariants.json` のcorrectedSha256と一致。公開3Dビューのダンスを正面・背面から拡大確認済み。ゲームの連続再生記録: `21_SOBAYA_HAZARD_LAB/qa/sobaya-pelvis-20260917.json`。

## 挨拶時の上腕の追加修正（2026-09-17）

腕の内側に残った胴体ウェイトが、挨拶で肉を脇へ引き下げていた。`tools/sobaya_arm_weights.py` でメッシュ表面の距離を用いて上腕と胴体を分離し、袖・肩へは補正を弱める。UV境界の重複点と非連結部分は同じ連続場から補間し、最大4影響に正規化。肘の混合範囲も局所化。頂点・UV・骨格・103モーションは保持。挨拶8位相の同視点比較は `qa/greeting_comparison.png`。前回の股周り修正も保持。

公開世代は `v3-rig-arm-20260917`。公開GLBのハッシュを配布用GLBと照合し、公式サイトで挨拶の連続再生を拡大確認。検証記録は `21_SOBAYA_HAZARD_LAB/qa/sobaya-arm-20260917.json`。袖下の小さな折れは残るため、衣服シミュレーション相当の品質を保証するものではない。GLBの挨拶8位相は `tools/review_sobaya_greeting.py` で再確認できる。

## 挨拶の手のひら方向（2026-09-17）

`tools/sobaya_greeting_palm.py` でGreetingだけの前腕・手首に軸回りの補正をベイク。元の変換は肘→手首の方向を合わせるが、メッシュの手のひら方向までは校正していなかった。前腕-58.5度、手首-31.5度を分担し、開始・終了へsmoothstepで戻す。現モデルの画像比較で選んだ補正量であり、全モーション共通の自動校正ではない。再生成はretargetスクリプトに組み込み済み。

`qa/palm_phases.jpg` はGLB再読込後の8位相。`qa/palm_invariants.json` で頂点・法線・UV・面・スキニング・初期骨格および他102クリップのバイト一致を確認。前回の腕と股周り修正を維持。公開世代 `v3-rig-palm-20260917`。

ジョッキ握りは別工程：現状は指の個別骨がないため、指リグ・ウェイトと持ち手への接触位置を一緒に整える必要がある。今回はジョッキ／攻撃のクリップを変更しない。

## 軽い挨拶への作り直し（2026-09-17）

上記の旧Greetingと手首補正は `casual-hey-20260917` で置換。短く片手を上げて応える2.2秒の新規動作。手の表裏を修正し、上げ下げを同じ関節経路に揃える。福ちゃんも同時更新。正本・再生成・QAは `04_GAME_ASSETS/3d/motions/casual_greeting_20260917/README.md`。`sobaya_animated.blend` とフルリターゲット経路も更新済み。
