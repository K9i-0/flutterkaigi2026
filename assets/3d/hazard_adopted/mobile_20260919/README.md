# スマホ向け軽量モデル（2026-09-19）

ゲーム内の全4人を対象にした別バリアント。現行GLBと標準symlinkは変更しない。入力・出力SHA256、全寸法と削減内訳は [manifest.json](manifest.json)。

| メンバー | 三角形：現行 → 軽量 | 削減 | ゲーム変換後のデータ：現行 → 軽量 |
|---|---:|---:|---:|
| そば屋 | 127,034 → 62,872 | 50.5% | 23.41 → 11.73 MiB |
| 福ちゃん | 37,865 → 31,725 | 16.2% | 73.97 → 42.20 MiB |
| やめ太郎 | 15,299 → 12,631 | 17.4% | 12.43 → 7.14 MiB |
| たこさん | 18,325 → 16,281 | 11.2% | 4.61 → 2.01 MiB |

変換後4人合計は114.42 → 63.08 MiB（44.9%減）。これは `flutter_scene_generated` の実ファイル量であり、GPU常駐量・発熱・FPSの実測ではない。既存ビルドのASTC圧縮は継続する。原GLBのやめ太郎・たこさんは、縮小画像のPNG保存とモーフの密配列化によりファイルサイズが増えるが、ゲーム変換後のデータ量は減る。

## 見た目の保護

顔・手・モーフ変形部、やめ太郎の頂点色による肌のグラデーションを優先して固定。法線・UV・骨ウェイトを考慮してメッシュを簡略化し、残す頂点の属性は変更しない。そば屋の顔マスク、福ちゃんの顔アトラス、全員の法線マップを元解像度で保持。衣服などの大きいテクスチャを半分の解像度へ縮小した。骨構成・バインド姿勢・ソケット・134アニメーションは入力と一致する。

正面・側面・背面、顔アップ、歩走・攻撃・挨拶など計120条件をブラウザーで比較。目視で目立つ差は認めなかった。背景を含むRGB平均差の最大値は0.350/255未満。これは画素一致や全距離・全照明・全クリップの知覚的同等性の保証ではない。[比較値](browser_validation.json)／[構造検証](validation.json)／[glTF検証](format_validation.json)。

Macで会話・連続ダンス・巨大そば屋を確認。iPhone 17 Proシミュレーターで自動mobile選択、4人の軽量パスのみのロード、たこさんの会話アップと音声完了を確認。被ダメージ／死亡時のたこさん音声プローブは両環境でタイムアウトし、合格扱いにしていない。[ネイティブ検証記録](../../../../21_SOBAYA_HAZARD_LAB/qa/mobile-models-20260919.json)。実機の長時間発熱・消費電力は未測定。

## ゲームでの選択

`HAZARD_MODEL_PROFILE=auto`（既定）はiOS/Androidでmobile、それ以外でstandard。`--dart-define=HAZARD_MODEL_PROFILE=standard` / `mobile` で比較用に固定できる。両版をアプリへ同梱するが、起動時に選んだ片方だけロードするため二重常駐しない。同梱容量そのものは増える。ゲームからは `assets/models/mobile/` の相対symlinkで参照する。

## 再生成・確認

リポジトリルートで実行。Python環境にはPillow 12.3とNumPy、`.local/vrm-validation/node_modules` にはthree 0.185.1とgltf-validatorが必要。

```sh
.local/wan-motion-venv/bin/python tools/build_hazard_mobile_models.py
.local/wan-motion-venv/bin/python tools/validate_hazard_mobile_models.py
node tools/validate_hazard_optimized_format.mjs --mobile
python3 -m http.server 18919 --bind 127.0.0.1
```

比較画面：`http://127.0.0.1:18919/tools/preview_hazard_optimization.html?profile=mobile`。ローカル再生成時の頂点対応表は `.local/hazard-mobile-20260919/` に出力する。
