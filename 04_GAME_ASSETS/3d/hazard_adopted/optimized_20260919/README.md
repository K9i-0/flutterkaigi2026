# そば屋ハザード用の軽量派生モデル

2026-09-19。承認済みv3を入力に、そば屋の頭部の剛体パーツだけを簡略化し、両モデルのPNGを可逆圧縮、未参照領域・重複アニメーションバッファを整理した。元モデルは保持し、本編の相対symlinkと親ディレクトリのmanifestをこの派生物へ変更した。

| モデル | GLB MiB 前→後 | 三角形 前→後 | 頂点 前→後 |
| --- | --- | --- | --- |
| そば屋 | 25.61 → 20.03 | 198,688 → 127,034（36.1%減） | 136,514 → 99,696 |
| 福ちゃん | 55.25 → 32.83 | 37,865 → 37,865 | 37,976 → 37,976 |

そば屋の鼻、額の黒い飾り、単色の髪だけが対象。全対象頂点が同一の頭骨に100%追従し、モーフ変位が0であることを生成時に検査する。meshoptimizer 1.1の属性付き簡略化、境界固定、絶対誤差パラメーター0.00015、法線重み0.01を使う。この値は属性を含む簡略化指標であり、表面距離の厳密な上限ではない。残した頂点の位置・法線・UV・ウェイト・モーフ値は元と一致する。

体、手、顔の赤白模様、目・口の黒いパーツ、全104＋23クリップ、ボーン、ソケット、口パク、材質値、画像の解像度・RGBA画素は保持。福ちゃんの形状は全て同一。PNGの常時255のアルファを省き、RGBで再圧縮しても復号後のRGBAが一致することを検証した。

## 効果の範囲

GLB合計は約34.6%減。ゲームはGLBをそのまま同梱せずFlutter Sceneへ変換するため、GLBの削減率をアプリ容量やGPUメモリの削減率として扱わない。今回の変換済みシーンは、そば屋25,487,488→24,545,176バイト、福ちゃん77,564,656→77,564,656バイト。GPUテクスチャの解像度・枚数は同じ。そば屋の三角形と頂点の削減が描画負荷削減の対象で、実機profileのFPS・発熱改善率は未測定。

## 再生成・検証

リポジトリルートから実行。PythonはPillow 12.3.0、数値検証はNumPyを使用。Nodeは既存 `.local/vrm-validation` のThree.js 0.185.1とgltf-validatorを使用。

```sh
.local/wan-motion-venv/bin/python tools/optimize_hazard_models.py
.local/wan-motion-venv/bin/python tools/validate_optimized_hazard_models.py
node tools/validate_hazard_optimized_format.mjs
```

生成コマンドは元ファイルや採用manifestを変更しない。入力を更新した場合は別途比較し、`manifest.json`のfile・sha256・optimizationと本編symlinkを更新する。元の制作スクリプトを再実行したときも、軽量化派生物を再生成してから採用する。

比較ページはリポジトリルートをローカル配信し、`tools/preview_hazard_optimization.html`を開く。同じカメラ・照明・クリップ時刻で正面・側面・背面、顔・全身、連続再生を確認できる。画素差は各560×620ピクセル、RGB 8bit。ゲーム固有の照明・影・TAAとは別の比較。

`semantic_validation.json`は数値・画素の保持、`format_validation.json`はglTF形式（エラー0、元モデル由来の非rootスキン警告のみ）、`optimization.json`は入力・出力ハッシュと削減値。Mac本編の巨大そば屋・連続ダンス・会話の検証は [ゲーム側の記録](../../../../21_SOBAYA_HAZARD_LAB/qa/model-optimization-20260919.json)。旧配布ZIPとiPhoneインストール済みアプリは更新していない。
