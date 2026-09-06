# 福ちゃん — そば屋ハザード用

正典 `02_CHARACTERS/Fukuchan.jpg` の顔を参照し、built-in Imagegenで正面・背面のAポーズ画像を作成。入力正本は `tripo_p2_20260905/inputs/`、プロンプトは同ディレクトリの `imagegen_prompt.txt`。

Tripo P2 (`P2-20260801`) の複数画像入力で生成。12,000 face上限・quad・詳細PBR。生成 task `c7ffd494-5af3-4fac-b31b-dcd834c1caf0` は120クレジット。無料rig-checkでbiped可能を確認し、v1.0-20240301 / biped / Mixamo rig task `6697bd45-e6a8-4f49-8d2e-3d317a1ba4ee` は25クレジット。開始480→残335。2026-09-06確認。`out_format=glb`指定でも取得実体はFBXだったためBlenderで変換した。

ゲーム正本は `rig_v1/fukuchan.glb`。身長1.7m、24,857三角面、1材質、23骨、12クリップ（Idle / Walk / Run / Aim / AimShotgun / ReloadHandgun / ReloadShotgun / Hit / Evade / Kick / Climb / Vault）。カラー4K、その他PBR2K。GunSocketへ共通の銃モデルを装着する。

Walk / Runは手元のMixamoダウンロードを骨格へ転写。足の接地高と頭の正面向きを補正し、ゲーム移動速度へ再生速度を合わせる。Aimは両腕IKで作った構え。Reload / Hit / Evade / Kick はBlenderで制作した専用アクションで、モーションキャプチャーではない。ゲームでは反動と上下の照準を上半身に加算する。指ボーンはなく、指の個別把持、マガジンの出し入れ、足の実時間IKは今後の改善対象。

再生成:

```sh
# raw FBXがない場合は同じ生成済みtaskを取得（新規生成ではない）
python3 tools/tripo_generate.py download 04_GAME_ASSETS/3d/characters/fukuchan/rig_source/config.json
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_fukuchan_game_rig.py
```

上記downloadはローカルのtask.jsonを参照する。別環境では記載のrig task IDをtask.jsonへ設定する。Mixamo元ファイル `.local/mixamo_sobaya/source/walk_standard.fbx` と `run_weighted.fbx` も必要。元FBX・署名URL・APIキーはGitへ含めず、採用GLBと再生成コード・入力画像だけを保持する。

窓越え用に`Vault`（1.6秒、実行時にそば屋は2.1秒へ速度調整）を追加。`tools/hazard_vault_motion.py`の手付けIKで膝を折り畳み、ゲーム側の`WindowTraversal`と同期する。MixamoのWalk／Runは維持する。手の窓台接触は今後の仕上げ対象。
