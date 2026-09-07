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

`validation.json`：12ファイルの公式VRMAスキーマ・glTFエラー0・Three-VRMのロード・全人型ボーンの有限値を検査。各5時刻で変換前のベイク済み骨格と適用後の位置・回転を比較する。WebGLで歩行・ダッシュ・ダンスの表示と切り替えを確認。

自然に感じられた公開ライブラリ版の演技を比較基準として保持するため、追加の足IK・頭の向き補正は行っていない。平地への食い込み・浮きが残る場合があり、各クリップの `minSoleM` に記録する。最大の食い込みはそば屋チャールストン約63 mm。移動ゲームへ本採用する際には接地調整が別途必要。ゲーム本編およびFlutter比較アプリの採用モーションはこの変更で差し替えない。

ライセンス本文：[CC0-1.0](../../3d/motion_library/source/CC0-1.0.txt)。キャラクターモデル自体の利用条件とは別。仕様：[VRM Animation 1.0](https://github.com/vrm-c/vrm-specification/tree/master/specification/VRMC_vrm_animation-1.0)。
