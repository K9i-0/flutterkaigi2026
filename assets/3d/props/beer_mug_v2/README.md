# Beer mug v2 — shared prop

`tools/build_beer_mug_v2.py`によるパラメトリック生成。約503KB、8,276三角面、4材質。元のジョッキは`../beer_mug/`へ保持。

`BeerMugRoot`下に`GlassBody` / `Handle` / `BeerVolume` / `LiquidSurface` / `Foam` / `Carbonation` / `Grip`を分離。底と口縁に実厚を持つガラス、丸いD型取っ手、メニスカス、細かな泡、18個の気泡を備える。単位m、原点は底中央。GripはBlender `(0.155,0,0.117)`、glTF `(0.155,0.117,0)`。

- ガラス: 非金属、粗さ0.045、Transmission 1、IOR 1.5、厚み0.007m。
- ビール: Transmission 1、IOR 1.333、琥珀色の吸収、減衰距離0.14m。
- 液体3パーツには`TiltX` / `TiltZ` / `Fill`のモーフ。初期値は全て0。
- Flutterの`BeerMugComponent`が重力方向・加速度に応じた減衰する傾斜、液量、気泡、近遠材質を管理。検証カメラの注視点距離が5m以上では屈折パスを省き、軽いアルファガラスとビール色へ切り替える。

傾斜を内壁・底・口縁の範囲に制限する視覚表現であり、こぼれる液体や正確な体積保存はシミュレートしない。大きく逆さにした場合も容器内へ収める。多層ガラスの正確な光線追跡ではない。

`python3 tools/validate_beer_mug.py`は実GLBの疎モーフを展開し、液量10/50/100%・傾斜8方向で96,816頂点サンプルの有限値・内壁範囲・底と口縁を検査する。証跡は`validation.json`。
