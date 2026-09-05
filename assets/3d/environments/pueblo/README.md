# 村の広場

そば屋ハザード第一章の共有正本。`village.glb` は9,922三角面・19材質、5軒の民家、2階へ続く階段、見張り塔、井戸、荷車、農場側の門、6枚の収集ポスターを含む。`village.json` は衝突・階段・敵・拾得物・ポスターの配置正本。ゲームから相対symlinkで参照する。

原作バイオハザード4の[公式ガイド抜粋](https://static.capcom.com/residentevil/files/ResEvil2.pdf)掲載の村を配置関係の参考にして新規制作。ゲームデータから抽出したマップではなく、縮尺・建物の細部・全導線は一致していない。

`textures/stone.png` / `earth.png` はbuilt-in Imagegenによる専用アルベド。最終プロンプトを `textures/prompts.json` に保存。壁3m／地面5mの周期で適用する。その他の木材・瓦・漆喰は生成コードの手続きテクスチャ。ポスター画像は03_SCRIPTSの採用画像を768px幅でGLBに埋め込み、拡大ギャラリーは元画像の相対symlinkを参照する。

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_hazard_village.py
```

同時に `../../props/hazard_kit/items.glb` を生成する。建物ごとに静的メッシュをまとめ、屋根・門・収集ポスターは独立ノードとして表示制御できる。視点遮蔽のため家に入ると屋根を隠す。
