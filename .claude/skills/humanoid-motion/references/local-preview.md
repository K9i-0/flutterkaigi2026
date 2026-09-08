# ローカル確認ページ

## 起動と比較

依存セットアップは `04_GAME_ASSETS/vrm/characters/README.md` と `04_GAME_ASSETS/vrm/motions/README.md` を参照。Three.js / Three-VRM / VRM Animationは `.local/vrm-validation/node_modules` に置く。既存環境なら再インストール不要。

リポジトリルートを配信する。既存8766番サーバーがあれば応答と配信内容を確認して再利用する。

```sh
python3 -m http.server 8766 --bind 127.0.0.1
```

確認URL：`http://127.0.0.1:8766/tools/preview_humanoid_vrm.html`

主なクエリ例：

- `?motion=Candidate_Mixamo_Run`：既存Run
- `?motion=Candidate_Chase_Run`：逃走・追跡
- `?motion=Jog`：元のJog
- `?motion=Dance%20Body%20Roll&time=2.37`：指定秒で停止
- `?motion=Dance%20Charleston&time=0&revision=baseline`：修正前。比較用ローカル素材が必要

`camera` は position / target / yaw のJSONをURLエンコードして保存できる。UIで2人比較・単独表示、速度、一時停止、シーク、正面・側面、回転・拡大、福ちゃんの口パクを操作する。両モデルは同じ経過秒で再生。その場再生なので、ゲーム内の移動速度はここでは判断しない。

実装は `tools/preview_humanoid_vrm.{html,mjs}`、骨表示は `tools/vrm_bone_overlay.mjs`。公式のVRMLoaderPlugin / VRMAnimationLoaderPlugin → createVRMAnimationClip → AnimationMixer → vrm.update の適用経路を維持する。

## 骨と肉の切り分け

「ボーン・関節をハイライト」は実際にメッシュを変形するraw humanoid骨。左が水色、右が桃色、体幹が黄色。肩関節はupperArm原点で、鎖骨側のshoulder原点とは異なる。XYZ軸は赤・緑・青。元姿勢表示も使う。

問題の秒数と視点を固定し、修正前後の骨位置・軸・袖や筋肉を比較する。骨の向きだけでなく、上腕の軸回転、胸と鎖骨と腕のウェイト、肘周辺の体積を見る。停止画だけで採用せず、前後の連続動作と反対側の腕も確認する。

修正前素材は追跡しないローカル出力。必要なときだけ生成する：

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/improve_vrm_deformation.py
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_vrm_motions.py -- --baseline
```

修正版は別途通常ビルドする。比較の両側で時刻・カメラ・照明を揃える。

## 実際に起きた表示上の落とし穴

- HTML再読込だけではIABの古いmjsが残った。配信内容と表示選択肢を照合し、必要ならHTMLのモジュールURLのバージョンクエリを更新する。候補カタログの取得はno-store。修正が効いていないと判断する前に、読み込んだ版を確認する。
- UI操作と同一ツール呼び出しの直後の画像が前フレームだったことがある。次の描画を別の状態取得で確認してから評価する。
- sourceClipの `Dance Charleston` / `Dance Body Roll` は空白入り。ファイル名のアンダースコアからキーを推測せず、catalog.json / run_candidates.jsonを読む。
- BlenderはPython例外があっても終了コード0を返すことがある。ログのTraceback、完了マーカー、生成物と検証結果まで確認する。
