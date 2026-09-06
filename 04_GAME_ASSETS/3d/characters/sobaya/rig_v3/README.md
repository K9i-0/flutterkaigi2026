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

顔は進行方向の正面を基準に、元の上下変化20%・左右変化35%を残す。首にも補正を分散し、走行時の上向きを抑えた。鎖骨は演者の平均姿勢を除去してそば屋の待機姿勢へ合わせ、周期内の変化を50%保持する。上腕から手までまとめて外へ開き、肘の曲げと腕振りのタイミングを保ちながら太い胴体との間隔を確保する。

最終GLB全フレームで、顔の上下はWalk −0.29〜0.31度 / Run −0.82〜1.38度。胸基準の肩関節間隔は約0.534mで、待機時の幅との差は0.1mm以内。これらは骨格基準の値であり、肩の表面形状は正面・側面の描画でも比較する。

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

窓越え用に`Vault`（1.6秒、実行時にそば屋は2.1秒へ速度調整）を追加。`tools/hazard_vault_motion.py`の手付けIKで膝を折り畳み、ゲーム側の`WindowTraversal`と同期する。MixamoのWalk／Runは維持する。手の窓台接触は今後の仕上げ対象。

Vaultは片手を窓枠に添え、左右の足を順に抜く軌道へ改訂。書き出し後の97姿勢の検査条件と限界は `21_SOBAYA_HAZARD_LAB/qa/window-contact-20260906.json` を参照。最終版のmacOS debugで、福ちゃんの窓の往復とそば屋の順次追跡を実描画フレームで確認済み。そば屋の掌の隙間と腰・裾の服の変形、全編通し・profileは仕上げ対象。
