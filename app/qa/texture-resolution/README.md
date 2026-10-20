# テクスチャ解像度比較 2026-10-20

- iPhone 18 Proシミュレーター、2622×1206px、標準画質、seed 1、CTOおだてつ、ゲーム内5.983秒・正面を固定。before/afterのday/night画像は元キャプチャと同じ寸法のJPEG quality 95。
- Dart MCPでアプリを停止・再ビルド・起動して比較。hot restartのみではアセットが更新されなかったため、その比較は破棄。ビルド成果物のGLBと正典GLBのSHA256一致を確認。
- 日中の外壁、窓枠、手前の鉄骨、道路、看板と夜の発光を目視比較。細部はやや柔らかくなるが、主要な模様・窓の配置・看板の読みやすさを維持。夜の約60度旋回時も確認（after-night-angle）。
- JPEG化前の全画面RGB平均絶対差（0〜255）は昼0.415/0.409/0.403、夜0.467/0.378/0.280。画面全体には不変のUIや空も含まれるため、局所品質を保証する指標ではない。目視確認の補助記録。
- GLB内の画像以外の全bufferViewバイト列、およびmeshes/nodes/materials/accessors/textures/samplersが高解像度版と一致。再実行でも出力バイト列は一致。元PNGに変更なし。
- `audit_stage_asset.py`合格。39プリミティブ・71,872三角形、RGBA8ベース44.2578→13.1328MiB、GLB9,911,924→7,154,292 bytes。詳細は `../texture-resolution.json`。
- 実機GPUメモリ・FPS改善量は未計測。今回Dartソースの変更なし。テクスチャの展開量はmipmap・GPU形式・ドライバ管理分を含まない理論値。

高解像度版を試す場合は元PNGからBlenderで再書き出しし、optimize_stage_textures.pyを省略する。通常の配布では最適化後に監査を実行する（高解像度版は14MiB上限に失敗する）。
