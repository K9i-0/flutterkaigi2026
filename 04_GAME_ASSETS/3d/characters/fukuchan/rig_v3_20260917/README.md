# 福ちゃんv3 — 首補修・リグ・ギュンギュン

2026-09-17。承認済み `../likeness_finish_20260917/fukuchan_final.blend` を入力に、首の斑点を補修し、既存動作を使用できる54骨のリグを追加した。全身と顔の頂点位置・面・UVは完全一致を検証済み。ローカル公式サイトの表示モデルはこのフォルダの `fukuchan.glb`。

## 首の補修

`neck.py` は首と顎下に限った滑らかなマスクで、焼き付いた灰色の筋・まだらを肌色へ置換する3D材質を作り、CyclesのEmissionベイクで既存UVへ保存する。顔の目鼻口、髪、衣装、手のテクスチャを生成し直さない。首正面の15面は顔側の同じ陰影材質へ統一し、三角形の色差も解消。ベイク先は新規画像へ元画素を複写してから作る（packed imageのcopyでは元画像が保存されるため）。

## リグとモーション

- 54骨。Mixamo系の全身骨名、左右5指×3骨、RootとPropSocket.R。最大4ウェイトで正規化。
- このAポーズの肩・肘・手首・股関節へ骨を配置。UVで分裂した同位置点のウェイトを揃え、隣り合う指は表面距離で分ける。靴を腕・腰へ誤分類しない。名札と文字は同一骨で保持。
- 旧福ちゃんの `hazard_adopted/fukuchan.glb` から、元姿勢と脚長を考慮して17動作をリターゲット。ローカル回転をそのままコピーしない。元クリップ名・SHA・長さは `motions.json`。
- 既存動作：Idle / Walk / Run / Aim / AimShotgun / ReloadHandgun / ReloadShotgun / Hit / Evade / Kick / Climb / Vault / Struggle / BreakFree / DanceStep / DanceDisco / DanceVictory。
- Greeting：新しい手の向きに合わせた2.2秒の短い挨拶。
- GyunGyunPose：1秒の固定ポーズ。頬下の両こぶし、肘を低く・前腕を立て、左膝を外へ開き、すねを下へ垂らす。右足で支持。
- GyunGyun：4秒の構える→保持→戻る動作。固定ポーズと同じ姿勢。

添付写真と追記された赤線画像を `inputs/` に保持。顔・表情の正本は引き続き承認済みfrontであり、今回の写真で顔を作り直していない。動作はPython/Blenderによるリターゲットと手付けで、写真からのモーションキャプチャではない。元動作はMixamo・CC0素材・手付けが混在し、一括してCC0とは扱わない。

## 検証と範囲

`validate.py` は形状・UV・面構成、首以外の材質割当、顔上部のUVサンプル画素、最大4影響とウェイト合計、全20クリップの各5時刻の有限座標・接地・辺の伸びを検証。`validation.json` は最終GLBのSHAを含む。ギュンギュン保持時の支持足は床から3mm。形状の保証は静止時の入力保持であり、すべての変形が完全という意味ではない。

GLB再読込後の左右の首・静止全身・待機・歩行・走行・挨拶・ギュンギュンの正面/斜め/手元/出入りをレンダリング。ローカルThree.jsでも動作切り替えと再生を確認。袖・股・指は元の生成トポロジーの粗さが残り、衣装の布シミュレーション・表情リグ・ゲーム内の移動速度や武器接触の再調整は今回の範囲外。

## 再生成

リポジトリルートから順に実行。前工程の入力blendと既存モーションGLBが必要。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/rig_v3_20260917/build.py
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/rig_v3_20260917/animate.py
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/rig_v3_20260917/review.py
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/rig_v3_20260917/validate.py
python3 04_GAME_ASSETS/3d/characters/fukuchan/rig_v3_20260917/setup_local.py
```

- 全20動作・時刻指定・骨表示： http://127.0.0.1:5173/.local/fukuchan-rig/index.html
- 公式サイト： http://127.0.0.1:5173/characters/fukuchan → 3Dで見る

GLBとblend・派生atlas・QAレンダーはローカル保持。入力写真・コード・記録をGit管理。公式サイトのモデルsymlinkはローカル確認専用でcommitしない。ゲームの採用manifestおよび本番配信モデルは変更していない。
