# おかやまん — 大型モニターモデル v1

Blender/Pythonで構築した非ボクセルの自立式大型モニター。正典写真 `02_CHARACTERS/Okayaman.jpg` を加工せず内蔵し、顔・全体の縦横比を保持して表示する。16:9画面の左右は白い余白。

- `okayaman_monitor.glb`: テクスチャ内蔵、モニター・台座のみ。ゲーム・Three.js等への読込用。
- `okayaman_monitor.blend`: 写真をパック済み。プレビュー用の照明・カメラ・床を含む。
- `preview.png` / `front.png` / `rear.png`: 斜め前・正面・背面の確認画像。
- `build.py`: 元の正典写真から再生成するPythonスクリプト。

画面の有効幅2.0m、高さ1.125m。筐体幅2.075m、全高2.085m。Blenderではメートル、Z上、正面-Y、底面原点。GLBは標準のY上へ変換される。全パーツは `Okayaman_Monitor_Root` 配下。リグ・アニメーションは未実装。

黒い角丸筐体、背面排熱口・端子、金属製支柱・台座、ゴム脚、電源LEDを備える。正典写真は発光マテリアルで照明による陰影の影響を受けずに表示。既存のボクセル版とは別アセット。

リポジトリルートから再生成:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python 04_GAME_ASSETS/3d/characters/okayaman/monitor_v1/build.py
```
