# 「よっ」— そば屋・福ちゃんの軽い挨拶

両キャラクターの `Greeting` を2.2秒の新規動作へ置換。旧Greetingの軌道や、終盤に90度の補正を戻す処理は使わない。Idleの最初の姿勢から、二関節IKで作った顔横の姿勢へ各関節の短い四元数経路で移る。

- 0.12〜0.62秒：片手を上げる。
- 0.62〜1.12秒：手のひらを前へ向けて短く止める。小さな会釈。
- 1.12〜1.94秒：同じ経路を少しゆっくり戻る。
- 1.94〜2.20秒：待機。開始と終了の姿勢・速度がつながる。
- そば屋は肩に対して手首を4cm高く、福ちゃんは7cm高く設定。
- 福ちゃんは既存の指リグで右手を軽く開く。そば屋の指はメッシュの既存形状を保持。
- 手の表裏は、右手の親指が正面から見て右に来ることと、手のひら面を画像で確認。そば屋のpalmar normalは旧補正で取り違えていたため反転して校正し直した。

`tools/casual_greeting.py` が動作の正本。`*_greeting.blend` はアクションのみのBlenderライブラリ。モデルの骨格・ウェイト・顔・メッシュは変更しない。`tools/replace_glb_animation.py` でGreetingのトラックだけを差し替え、他の全クリップと元バイナリは完全一致で保持。そば屋102、福ちゃん98クリップは不変。

## 再生成

Blenderで `tools/build_casual_greetings.py -- --character sobaya --input <更新前GLB> --output <更新先GLB>` を実行。福ちゃんは `--character fukuchan`。出力はそば屋 `characters/sobaya/rig_v3_20260917/sobaya_rig.glb`、福ちゃん `hazard_adopted/v2_20260913/fukuchan.glb`。同じファイルへの出力も可能。入力のIdleが中立姿勢となる。GLBの元データを保持するため、繰り返し実行する場合は未更新の入力を利用する。

そば屋の `tools/retarget_sobaya_v3.py` にも同じ作者関数を組み込み、編集用 `sobaya_animated.blend` のGreetingを更新。福ちゃんの元モデル生成物は入力資産として維持し、ゲーム採用時にこの工程を最後に実行する。更新後はモデルハッシュとmotionRevisionを各manifestへ記録。

## 確認

- `tools/review_casual_greetings.py`：最終GLBを30fps設定で再読込し、正面11姿勢・斜め4姿勢ずつ描画。qaの一覧画像に保存。
- `tools/preview_casual_greeting.html`：リポジトリをHTTP配信し、両者を同期再生。正面・斜め、停止・時刻・速度で確認。`?candidate` は `.local/casual_greeting/` の試作を読む。
- 各report：入力・出力SHA-256、他クリップ／元バイナリ不変の検証結果。

ジョッキ握りは別工程。今回の動作で既存の握り・攻撃・歩走・ダンスを変更しない。
