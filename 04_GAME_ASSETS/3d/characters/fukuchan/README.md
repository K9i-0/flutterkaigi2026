# 福ちゃん — そば屋ハザード用

正典 `02_CHARACTERS/Fukuchan.jpg` の顔を参照し、built-in Imagegenで正面・背面のAポーズ画像を作成。入力正本は `tripo_p2_20260905/inputs/`、プロンプトは同ディレクトリの `imagegen_prompt.txt`。

Tripo P2 (`P2-20260801`) の複数画像入力で生成。12,000 face上限・quad・詳細PBR。生成 task `c7ffd494-5af3-4fac-b31b-dcd834c1caf0` は120クレジット。無料rig-checkでbiped可能を確認し、v1.0-20240301 / biped / Mixamo rig task `6697bd45-e6a8-4f49-8d2e-3d317a1ba4ee` は25クレジット。開始480→残335。2026-09-06確認。`out_format=glb`指定でも取得実体はFBXだったためBlenderで変換した。

ゲーム正本は `rig_v1/fukuchan.glb`。2026-09-06に頭部を独立生成して置換。身長1.7m、25,571三角面、5材質、23骨、14クリップ（Idle / Walk / Run / Aim / AimShotgun / ReloadHandgun / ReloadShotgun / Hit / Evade / Kick / Climb / Vault / Struggle / BreakFree）。頭と体それぞれカラー4K、その他PBR2K。GunSocketへ共通の銃モデルを装着する。

Walk / Runは手元のMixamoダウンロードを骨格へ転写。足の接地高と頭の正面向きを補正し、ゲーム移動速度へ再生速度を合わせる。Aimは両腕IKで作った構え。Reload / Hit / Evade / Kick はBlenderで制作した専用アクションで、モーションキャプチャーではない。ゲームでは反動と上下の照準を上半身に加算する。指ボーンはなく、指の個別把持、マガジンの出し入れ、足の実時間IKは今後の改善対象。

再生成:

```sh
# raw FBXがない場合は同じ生成済みtaskを取得（新規生成ではない）
python3 tools/tripo_generate.py download 04_GAME_ASSETS/3d/characters/fukuchan/rig_source/config.json
# 頭部rawがない場合。生成済みタスクの再取得であり新規生成ではない。
python3 tools/tripo_multiview.py download 04_GAME_ASSETS/3d/characters/fukuchan/head_p2_20260906/config.json
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_fukuchan_game_rig.py
```

上記downloadはローカルのtask.jsonを参照する。別環境では記載のrig task IDをtask.jsonへ設定する。Mixamo元ファイル `.local/mixamo_sobaya/source/walk_standard.fbx` と `run_weighted.fbx` も必要。元FBX・署名URL・APIキーはGitへ含めず、採用GLBと再生成コード・入力画像だけを保持する。

## 頭部の独立生成（2026-09-06）

正典写真を参照してbuilt-in Imagegenで頭部の正面・左側面・背面を制作し、Tripo P2のmultiviewへ入力した。髪は頭部と一体生成、体は既存モデルを使用。入力・プロンプト・設定とタスクIDは[head_p2_20260906](head_p2_20260906/README.md)を参照。

`tools/fukuchan_head_assembly.py`で古い頭と露出した首を除去し、新しい首を襟の内側まで接続。ジャケットの切断縁に裏地を追加し、頭・首の2骨へウェイトを設定する。FBXインポート時のFPS変更を復元し、元の14モーションの全チャンネル・時間・補間・出力値の完全一致を検査した。

`tools/fukuchan_head_speech.py`は閉じた唇を基準に`SpeechOpen` / `SpeechNarrow`、口内の内張りと上歯を作成する。口元の分割後は元ポリゴン内でUVを再投影し、隣のUV島が混じる細い白線を防ぐ。音量連動の簡易口パクであり、音素別の口形、表情・瞬き、揺れる髪は未実装。髪の大きな束と肌の滑らかさは生成モデル由来で残る。

構造・姿勢・macOS描画検証は `21_SOBAYA_HAZARD_LAB/qa/fukuchan-head-20260906.json`。モデル変更後のprofile性能測定、全編通し、配布ZIPの更新はこの検証に含まない。

窓越え用に`Vault`（1.6秒、実行時にそば屋は2.1秒へ速度調整）を追加。`tools/hazard_vault_motion.py`の手付けIKで膝を折り畳み、ゲーム側の`WindowTraversal`と同期する。MixamoのWalk／Runは維持する。手の窓台接触は今後の仕上げ対象。

Vaultは片手を窓枠に添え、左右の足を順に抜く軌道へ改訂。書き出し後の97姿勢の検査条件と限界は `21_SOBAYA_HAZARD_LAB/qa/window-contact-20260906.json` を参照。最終版のmacOS debugで、福ちゃんの窓の往復とそば屋の順次追跡を実描画フレームで確認済み。そば屋の掌の隙間と腰・裾の服の変形、全編通し・profileは仕上げ対象。
