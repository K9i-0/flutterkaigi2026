# 村の広場

そば屋ハザード第一章の共有正本。`village.glb` は17,428三角面・20材質、5軒の民家、2階へ続く階段、見張り塔、井戸、荷車、農場側の門、6枚の収集ポスターを含む。`village.json` は衝突・階段・敵・拾得物・ポスターの配置正本。ゲームから相対symlinkで参照する。

原作バイオハザード4の[公式ガイド抜粋](https://static.capcom.com/residentevil/files/ResEvil2.pdf)掲載の村を配置関係の参考にして新規制作。ゲームデータから抽出したマップではなく、縮尺・建物の細部・全導線は一致していない。

`textures/stone.png` / `earth.png` はbuilt-in Imagegenによる専用アルベド。最終プロンプトを `textures/prompts.json` に保存。壁3m／地面5mの周期で適用する。木材 `oak-v1.png`、瓦 `roof-v1.png`、漆喰 `plaster-v1.png` もbuilt-in Imagegenで生成。プロンプトは `textures/detail-prompts-v1.json`。木材1.4m／瓦1.5m／漆喰3m周期、UV方向は木目・屋根勾配に合わせる。ポスター画像は03_SCRIPTSの採用画像を768px幅でGLBに埋め込み、拡大ギャラリーは元画像の相対symlinkを参照する。

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_hazard_village.py
```

同時に `../../props/hazard_kit/items.glb` を生成する。建物ごとに静的メッシュをまとめ、屋根・門・収集ポスターは独立ノードとして表示制御できる。視点遮蔽のため家に入ると屋根を隠す。

2026-09-06: 窓台・四分割の窓枠・雨戸・軒・ランタン・食器・棚・戸棚の細部を追加。床面は歩行面Y=0へ整合。遠景樹木は `textures/pine-v1.png`（プロンプト `textures/pine-prompt-v1.json`）の3枚の交差カード、1本6三角面。alphaMode MASK／cutoff 0.45／両面、空間ごとにまとめて可視判定する。プレイ領域の遮蔽物には使わない。草は曲がった細い葉の輪郭へ変更。

2026-09-06: 導入の切り返しで地面の端が見えないよう、南入口の外に林道・丘・48本の樹木・石柱・木柵を追加。`tools/hazard_entrance_backdrop.py` で生成し、地形と樹木は空間ごとにまとめる。追加は1,224三角面・102,456 bytesで、材質20種・画像12枚は共用のまま。`village.json` の衝突・敵・拾得物・収集品は変更していない。
