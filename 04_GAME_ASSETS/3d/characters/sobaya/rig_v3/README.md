# そば屋 Mixamo locomotion v3

rig_v2の修復済みモデルへMixamoの歩行・走行を移植した検証用GLB。45骨（つま先2骨を追加）、28,576三角面、4材質、最大4ウェイト、9クリップ。Walk / Run以外の7クリップはv2の手続き生成を継続する。

## 入力と設定

[Mixamo歩行検索](https://www.mixamo.com/#/?page=2&query=walking)のWalking / Male Standard Walk、[走行検索](https://www.mixamo.com/#/?page=1&query=running)のRunning / Male Weighted Runを使用。検索結果の並びは変わるため説明文で識別する。

X Bot、FBX Binary、With Skin、30 fps、Keyframe Reduction None、In Place OFF、調整スライダー50。歩行38フレーム・走行26フレーム。バインド姿勢を含むため別途TポーズFBXは不要。取得済み素材のSHA256はrig.jsonに記録。

元FBXはGit管理外のローカル入力:

- `.local/mixamo_sobaya/source/walk_standard.fbx`
- `.local/mixamo_sobaya/source/run_weighted.fbx`

Mixamoから各自のAdobeアカウントで取得する。[Adobe公式FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html)。ゲームにはそば屋へベイクしたGLBを組み込み、元のX Bot FBXを素材集として配布しない。

## 調整

脚長比で軌道を縮尺し、TポーズとAポーズの差を補正。重心の上下・左右移動と腕振りを保持し、前進量を除去してその場ループへ変換。足首・つま先の捕捉軌道、二関節IK、実際のスキニング後の靴底高さから接地を補正し、裾補助骨もベイクする。足幅はそば屋の体格に合わせて調整した。

元の移動速度はWalk 1.007474632 m/s、Run 2.381708109 m/s。ゲーム移動速度は1.25 / 2.8 m/sで、実移動量に応じて再生速度を同期する。ループ尺は1.233333333 / 0.833333333秒。

## 再生成と検証

リポジトリ直下で実行。rig_v2のローカルblendがなければ先に`tools/build_sobaya_rig_v2.py`で生成する。

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/retarget_sobaya_mocap.py
python3 tools/validate_sobaya_rig.py rig_v3
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/validate_sobaya_mocap.py
```

GLBをBlenderへ再インポートして全38/26フレームの有限値と靴底を検査。`validation.json`は骨・ウェイト・9クリップ・7ループ、`locomotion_validation.json`は接地検査結果。Flutter上の結果は`21_SOBAYA_HAZARD_LAB/VALIDATION.md`。

そば屋本人と同じ体格の演者を新規収録したものではない。開始・停止・旋回専用クリップ、地形への実行時IK、全区間の足滑り定量評価は未実装。既存エモートとの遷移、肩や裾、手指の近接品質は引き続き仕上げ対象。今回のTripo利用・クレジット消費は0。
