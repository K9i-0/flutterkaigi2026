# たこさん — そば屋ハザード用

正典 `02_CHARACTERS/02_Takosan.md` と `03_SCRIPTS/00_TEMPLATES/characters/character_takosan_basic_sheet.png` を参照し、Blenderで直接制作した滑らかな3Dモデル。ボクセルやTripoの生成形状は使わず、追加クレジット消費はない。

ゲーム正本は `rig_v1/takosan.glb`。身長1.433m、19,870三角面、27骨、6材質。白い顔・黒い丸目、黒いフードとローブ、人間型の腕2本、指の分かれていない白い手2つ、下半身の巻いた触手6本を別構造で制作。

- フードは後頭部が閉じたシェルと奥行きのある開口部。目は穴のない黒い面。
- 布の微細な織り模様は再現可能な128pxテクスチャ。ローブの大きな模様と吸盤の輪は実形状。
- 触手は各3関節。断面の向きを連続して引き継ぎ、カーブの先端がねじれないようにする。
- Idle / Talk / Wave は各3秒の専用ループ。胴体と頭の小さな身振り、白い丸い手、触手のうねりを使う。モーションキャプチャーではない。
- 接地位置が原点、Blender Z-up / 正面-Y。GLB書き出しでゲーム座標へ変換。

村の南西、入口の家の外側で補給を担当する。ビールと弾・ハーブを交換。在庫と所持ビールはチェックポイントに含まれる。

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_takosan_game_rig.py
```

外部ダウンロード不要。再生成コードと採用GLBが正本で、中間blendはGit対象外。歩行・走行・戦闘用クリップと音声は未制作。

BlenderでIdle / Talk / Waveの形状を確認後、macOSのFlutter Sceneでも顔・会話画角・交換UIを確認。実E入力から交換ボタンを押し、ビール8→6、予備弾40→50、弾在庫3→2を確認した。
