# そば屋 v3：胸元でジョッキを構える立ちポーズ

ユーザー提供の `inputs/standing_reference.jpg` をポーズの参照にした静止姿勢。右手でジョッキを胸元に垂直に持ち、左腕は腰の横へ下ろす。元モデルの直立した胴体・脚を使う。顔・体格・衣装・靴・完了扱いの握りは最新モデルを維持する。

- `sobaya_standing.glb`：`CharacterSheet_MugStand` を追加した104クリップ入りモデル。新しいクリップは2秒間同じ姿勢を保つ。
- `sobaya_standing.blend`：新規立ちポーズを選択した編集用ファイル。ジョッキを手へ追従させた確認用の配置を含む。
- `qa/front.png`、`three_quarter.png`、`side.png`、`back.png`：最終GLB再読込後の画像。
- `report.json`：元入力・出力のハッシュ、不変条件、制作時の骨行列。`qa/review.json`：GLB再読込後の行列誤差とジョッキの垂直確認。

元入力は `../grip_v3_20260917/sobaya_grip.glb` / `.blend`（指先修正版）。ソケットと握りを保持し、ジョッキの位置・方向から右手と二関節の腕姿勢を求める。左腕はわずかに肘を曲げて下ろす。骨の表示軸をそのままglTFの軸とみなさず、インポート後のレスト行列を介して元glTF座標へ戻す。

元GLBのバイナリ、既存103クリップ、メッシュ、握りモーフ、材質、骨格、スキニングを保持し、静止クリップだけを追加する。ゲーム本編・公式サイトへの採用は行っていない。歩行・ダッシュの手首方向や攻撃モーションはこの変更の対象外。

## 正面の垂直軸の補正

元の生成形状では、骨が中央にあっても顔の中心が約38.5mm横へ寄っていた。立ちポーズ内で背骨〜首の位置を段階的に補正し、頭部は向きを保ったまま中央へ戻す。ジョッキ中心もX=0へ合わせ、右腕を再計算する。ベース形状と握りモーフは変更しない。

GLB再読込後、額・鼻・ジョッキの中心が同じ垂直線に揃うことを測定。胴体の断面中心も合わせて `qa/review.json` の `visualAxisXM` に記録し、正面画像で確認する。

## 再生成と確認

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/build_sobaya_standing.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/review_sobaya_standing.py
python3 tools/serve_sobaya_grip.py --port 8877
```

確認ページ：`http://127.0.0.1:8877/?pose=standing`。初期表示は正面の全身。回転して斜め・側面・背面を確認できる。
