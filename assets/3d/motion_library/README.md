# 体格対応の人型モーションライブラリ

そば屋ハザードと[そば屋モーションラボ](../../../22_HUMANOID_MOTION_LAB/README.md)が共有するGLB正本。そば屋の人物同一性、福ちゃんの正典頭部、既存ゲームのクリップ名・骨名・発話モーフを維持する。

**そば屋74・福ちゃん69比較クリップ**。このほか従来ゲーム用の動作もGLB内に保持する。すべてが別々の行動という意味ではなく、同じ歩行などを異なる手法で作ったバリエーションを含む。

| 手法 | 数 / 人 | 内容 |
| --- | ---: | --- |
| `captured` | 2 | 既存のライセンス済みMixamo Walk / Run。実演収録由来。OSSとは扱わない |
| `library` | 39 | Mesh2Motion / QuaterniusのCC0手付け動作。バインド姿勢の差を補正したFKリターゲット。接地拘束なしの比較基準 |
| `procedural` | 9 | 呼吸、歩行、走行、しゃがみ、横移動、リーチ、見回し、段差への足上げ、前方ローリング。関節長と2ボーンIKから生成 |
| `hybrid` | そば屋22 / 福ちゃん17 | 公開動作の演技を保ち、接地中の水平軌道、靴底高さ、腕の長さと体幹付近の手の通過位置を補正 |
| `video` | 1 | Wan 3.0クレイ見本の周期・側面軌道をMediaPipeで観測し、体格別IKで歩行を再構成 |

| `videoRig` | 1 | 骨格ハイライト版の身体姿勢から再構成。肩・肘・手首の方向を信頼度で補完した比較用試作 |

移動、しゃがみ、左右回避、パンチ、被弾、拳銃、座る・立つ、会話、飲食、挨拶など。GLB内は `Library_Walk` / `Hybrid_Walk` / `Procedural_Walk` のように接頭辞を分ける。名前・秒数・出典・適用手法は `catalog.json` を正本とする。

## 視線と追加アクション（2026-09-07）

しゃがみ移植時の約67〜69度の俯角を修正。首と頭に補正を分散し、通常動作は俯角10度〜仰角16度を維持する。横を見る演技は保ち、お辞儀・物を拾う・ローリングの意図的な視線は除外する。飲食等は俯角25度まで許容する。旧版の比較検査に加え、数値監査で視線の上下角を検証する。

- `Procedural_RollForward`：両キャラの前方ローリング。脚長に応じた膝の抱え込み、背中の丸め、復帰。頭・背中も含む全身スキン頂点で床を検査する。GLBはインプレースで、台帳の `rootTravelM` を比較アプリが前進に使用する。
- `Hybrid_MugHold`：`02_CHARACTERS/Sobaya.jpg`の胸前・右手の正典構え。
- `Hybrid_MugRun`：右手を保持し、左腕と脚を使って走る。
- `Hybrid_MugPunch` / `Hybrid_MugHook` / `Hybrid_MugSmash`：正面パンチ、横フック、重い打ち下ろし。予備動作・打点・復帰の位相を `events` に記録。腰・胸の回転と支持脚IKを含む。
- ジョッキ5本はそば屋用。既存の `PropSocket.R` と指の接触IKを使い、モデルを外付けする。比較アプリはゲームと同じ `props/beer_mug_v2/beer_mug.glb` を相対symlinkで参照する。
- ゲーム側の旧クリップ名と戦闘の当たり判定タイミングは保持する。新クリップは共通GLB・比較アプリに加え、ゲーム本編にも割り当て済み。ローリングの移動量・攻撃の打点をゲーム側で同期する。詳細は[本編仕様](../../../21_SOBAYA_HAZARD_LAB/GAMEPLAY.md)を参照。

再生成本体が `tools/humanoid_action_refinement.py` を呼び出す。既存の全ライブラリへの差分ベイクは `blender -b --factory-startup --python tools/humanoid_action_refinement.py`。再実行で視線補正を重ねない。姿勢画像の再検査は `blender -b --factory-startup --python tools/review_humanoid_actions.py`。

## 体格とリグ

| モデル | 身長 | 脚長 | 腕長 | 肩関節の幅 | ボーン |
| --- | ---: | ---: | ---: | ---: | ---: |
| そば屋 | 1.80 m | 0.823 m | 0.582 m | 0.534 m | 45 |
| 福ちゃん | 1.70 m | 0.749 m | 0.511 m | 0.345 m | 23 |

脚長は股関節→膝→足首、腕長は肩→肘→手首。代表値は左側、IK自体は左右それぞれの関節距離を使う。身長比だけで手足の動きを縮めない。各 `profile.json` の `boneMap` が共通の解剖学的役割と既存の骨名を対応づける。

- Tポーズの素材からAポーズの人物への補正を腕の軸ごとに求める。
- 移動はインプレース。骨盤の上下動と重心移動を保ち、移動量はゲーム側で管理できる。
- 靴底のスキン頂点と全ウェイトを使い、つま先も含めて床を評価する。接地中の水平移動は支持区間ごとに推定した床速度へ合わせる。
- 最大4ウェイトの正規化、クォータニオン符号の連続性、ループ末尾、定数キーの書き出し最適化を共通処理にする。入力リグも既に最大4ウェイトだったため、ウェイト削減数は0。ボーン削減を実施したという意味ではない。
- ゲーム側は歩行⇄走行の位相を維持し、衝突後の実移動量へ歩行再生速度を合わせる。消えたクリップのウェイトを正確に0へ落とす。
- ビューアはモデルを共有・複製し、各個体は表示中の1クリップだけを評価する。一時停止中の連続描画を止め、骨格は2Dの透視オーバーレイで確認する。

## OSS素材・利用条件

素材：[Mesh2Motion source assets](https://github.com/Mesh2Motion/mesh2motion-assets)、[Mesh2Motion公式説明](https://mesh2motion.org/)、[Quaternius](https://quaternius.com/)。アニメーション素材は **CC0 1.0**。ツールコードのMITと素材のCC0を区別している。公式はこれらを手付けアニメーションと説明しており、モーションキャプチャやAI生成とは表記しない。

入力は `mesh2motion-app` のコミット `2d3d1ff03247d9e7e830d1ae375653da4e2146e2` に固定。`source/CC0-1.0.txt` を同梱。2つのソースGLBのSHA-256をダウンローダとビルダの双方で照合する。外部アカウント・課金API・モデルの外部送信は不要。

今回検討したLaFAN1やBandai Namcoのデータは、このゲームへ組み込んでいない。それぞれの[LaFAN1利用条件](https://github.com/ubisoft/ubisoft-laforge-animation-dataset)と[Bandai Namco利用条件](https://github.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset)は、CC0の素材とは別に確認が必要なため。

## 再生成

リポジトリルートで実行する。Blender 5.1.2で検証。

```sh
python3 tools/fetch_humanoid_motion.py
blender -b --factory-startup --python tools/build_humanoid_motion.py
blender -b --factory-startup --python tools/audit_humanoid_motion.py
```

入力は以前の正本 `characters/sobaya/rig_v3/sobaya_rig.glb` と `characters/fukuchan/rig_v1/fukuchan.glb`。未追跡のblendは必要ない。出力blendは編集・調査用のローカルファイル。`--preview` は開発用の小規模版、`--hybrid-only` は既存出力からIK群を再ベイクする開発用オプション。正式再生成はオプションなしで行う。

`validation.json` は**書き出したGLBを再インポート**して生成する。全143クリップについて各9姿勢・補間途中・ループ端・有限値、スキンウェイト、福ちゃんの `SpeechOpen` / `SpeechNarrow` を検査する。IK版は床へのめり込みと不自然な浮きを検査する。Sprintのみ、30 Hzのキー間で靴底が回転するため14 mmの接地余裕を設けた。他のIK版は4 mm程度。台帳の `minSoleM` は全キー、監査の値は9姿勢の補間も含むため一致しないことがある。

## 適用範囲

現在のIK補正は平地用のオフラインベイク。任意の階段・坂・障害物への実行時IK、物理ラグドール、学習型の実行時モーション生成は含まない。`StepUp` は20 cmの段差への足上げ例で、登段シミュレーションではない。着席動作には別途そのキャラに合う座面が必要。FK比較版には接地のずれが残る。福ちゃんは指骨がないため指の個別屈伸はなく、衣服の大変形や手と小道具の接触は用途ごとの仕上げが必要。

## Wanクレイ歩行

`Wan_Walk` は40フレーム / 1.333秒。福ちゃん0.859586 m/s、そば屋0.945316 m/sを再生速度1倍の基準とする。平地・定速区間のみを再構成。比較アプリの同速度モードでは1.25 m/sに合わせて再生する。動画の絶対スケールは未校正で、脚長に対する移動量から換算した値。左右の遮蔽・奥行きは補完している。

`source/wan_walk_clay.json` は追跡する再生成入力。`tools/humanoid_video_walk.py` で差分再生成。`tools/extract_wan_walk.py` / `tools/fit_wan_walk.py` がローカル動画からの観測・周期フィット。新クリップは `tools/audit_wan_walk.py` で161時刻/人の接地・視線・支持中盤の足首滑りを監査する。支持中盤の値は踵の着地とつま先の離地を含む足裏全体の誤差ではない。

[生成・解析記録](../../../03_SCRIPTS/62_hazard_motion_reference_wan3/WALK_CLAY_RESULT.md)。動画生成は承認済みWan API、姿勢推定はローカルMediaPipe。既存CC0素材の出典とは区別する。

## 骨格ハイライト動画の試作歩行

`WanRig_Walk` は42フレーム / 1.4秒。福ちゃん0.708770 m/s、そば屋0.779458 m/s。実際の各モデルの関節長に合わせて再構成し、`Wan_Walk` と別に保持する。ゲーム本編の歩行割り当ては従来の `Wan_Walk` を維持。

入力は `source/wan_walk_clay_rig.json`。再観測は `tools/extract_wan_walk.py --rig-highlight` と `tools/fit_wan_rig_walk.py`、差分ベイクは `blender -b --factory-startup --python tools/humanoid_video_walk.py -- --rig-highlight`。全生成からも再現できる。監査は `tools/audit_wan_walk.py -- --rig-highlight` で169時刻/人。

色付き骨格線を直接追跡せず、MediaPipe 0.10.32による身体姿勢を使う。隠れる左肘の信頼度中央値は0.418、右肘は0.991。左右を半周期ずらして補完し、腕の横への広がりを制限する。単眼の奥行きと手首の向きは正確に復元できず、手指は既存リグの姿勢を保つ。動画と再構成方式の両方が変わっているので、骨格表示だけの効果を判定する比較ではない。
