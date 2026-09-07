# 体格別 VRM Animation

そば屋と福ちゃんに、公開ライブラリの待機・歩行・ダッシュ・ダンス3種を適用する。各6ファイル、計12の `.vrma`。入力は既存のMesh2Motion / Quaternius素材（CC0 1.0）。新たな動画生成は使用しない。

| 表示 | 元クリップ |
| --- | --- |
| 待機 | Idle_A |
| 歩行 | Walk |
| ダッシュ | Sprint |
| ダンス：シンプル | Dance_Simple |
| ダンス：チャールストン | Dance Charleston |
| ダンス：ボディロール | Dance Body Roll |

## 再生

既存の `tools/preview_humanoid_vrm.html` にモーション選択、2人比較・単独表示、速度0.5/1/1.5倍、一時停止、シーク、正面・側面表示を追加。初期表示は歩行。各モデルは同じ経過秒で再生する。その場再生で、ゲーム内移動速度の検証機能ではない。

```sh
npm install --prefix .local/vrm-validation @pixiv/three-vrm-animation@3.5.5
python3 -m http.server 8766 --bind 127.0.0.1
# http://127.0.0.1:8766/tools/preview_humanoid_vrm.html
```

他の依存とモデルの再生成は [characters/README.md](../characters/README.md) を参照。モデル・素材はローカルから読み、外部アップロードしない。

## 変換

`tools/build_vrm_motions.py` をBlender 5.1.2で実行する。既存の `build_humanoid_motion.retarget` の公開ライブラリ移植方式を使い、各モデルの肩・腕の初期姿勢と関節長を補正してからVRMAに変換する。骨格名ではなくVRM人型ボーンの役割を記録し、`VRMAnimationLoaderPlugin` → `createVRMAnimationClip` → `AnimationMixer` → `vrm.update` の標準経路で適用する。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_vrm_motions.py
node tools/validate_vrm_motions.mjs
```

`.local/vrm-validation/*_motions.glb` は変換前との比較用中間生成物。追跡しない。ソースのSHA-256は既存ダウンローダの固定値で照合する。`catalog.json` にソースコミット、クリップ、各VRMAのハッシュを記録。

VRMAは回転とhipsの平行移動を格納し、非対応のscaleやhips以外の平行移動トラックを除去する。各ファイルは1動作のみ。初期姿勢・比率の補正済みなので、まず対応するキャラのフォルダのファイルを使う。他体格のVRMへ適用可能な形式だが、その見た目まで保証するものではない。

## 検証と限界

`validation.json`：12ファイルの公式VRMAスキーマ・glTFエラー0・Three-VRMのロード・全人型ボーンの有限値を検査。30 Hzの各時刻で変換前のベイク済み骨格と適用後の位置・回転を比較する。WebGLで歩行・ダッシュ・ダンスの表示と切り替えを確認。

自然に感じられた公開ライブラリ版の演技を比較基準として保持するため、追加の足IK・頭の向き補正は行っていない。平地への食い込み・浮きが残る場合があり、各クリップの `minSoleM` に記録する。最大の食い込みはそば屋チャールストン約63 mm。移動ゲームへ本採用する際には接地調整が別途必要。ゲーム本編およびFlutter比較アプリの採用モーションはこの変更で差し替えない。

ライセンス本文：[CC0-1.0](../../3d/motion_library/source/CC0-1.0.txt)。キャラクターモデル自体の利用条件とは別。仕様：[VRM Animation 1.0](https://github.com/vrm-c/vrm-specification/tree/master/specification/VRMC_vrm_animation-1.0)。

## 変形の診断表示

確認ページの「ボーン・関節をハイライト」で、実メッシュを変形するraw humanoid骨の現在の関節位置を透視表示する。正規化された制御骨や推測線ではない。左は水色、右は桃色、体幹は黄色。「肩関節」はupperArmの原点で、shoulder（鎖骨側）の原点と区別する。肩・肘・手首の回転軸（赤X・緑Y・青Z）と、元の姿勢との比較も可能。元の姿勢の比較はモデルの表示姿勢だけを切り替え、モーションデータを改変しない。

チャールストン／ボディロールの肩・腕の見た目は「スキニングの変形崩れ」と表現できる。VRMA変換前のベイクとの数値一致は確認済みだが、これは解剖学的な関節位置やウェイトの良さを保証しない。現在のモデルは上腕・前腕の専用ツイスト補助骨を持たず、初期姿勢補正も手足の方向中心。関節の回転軸、軸回りのひねり、胸・鎖骨・上腕のウェイト分布を切り分ける必要がある。現在は肩ウェイトの局所平滑化と、ダンス3種の鎖骨・上腕・前腕のねじれ制限を適用済み。補正は体幹に対する初期姿勢からの軸回り成分に限定し、肩・肘・手首の軌道を保つ。上限は鎖骨10°、上腕45°、前腕60°。これはこの2モデルで選んだ調整値であり、人間の医学的な可動域ではない。

## 修正前との比較

確認ページの「モデル・モーション」で修正前後を切り替える。停止位置と視点を引き継ぐ。比較用ファイルはローカル生成物で、以下で再生成する。修正版のモデル・モーションの再生成も必要。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/improve_vrm_deformation.py
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_vrm_motions.py -- --baseline
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_vrm_motions.py
```

[変形の比較検証](../DEFORMATION_REVIEW.md) に候補ごとの観察と再現手順を記録。足IK・演技のタイミング・歩行とダッシュの駆動は今回のねじれ補正の対象外。
