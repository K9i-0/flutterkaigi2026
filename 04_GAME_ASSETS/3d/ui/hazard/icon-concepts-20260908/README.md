# そば屋ハザード：アプリアイコン原案

2026-09-08制作。ユーザー指定で**C案「暗闇からの視線」を採用**し、iOS・Android・macOSのランチャーアイコンへ反映した。原画3案は比較履歴として残す。内蔵 `image_gen` を使用し、そば屋の正典写真 `02_CHARACTERS/Sobaya.jpg` を人物同一性の参照にした。

| 案 | 原画 | 狙い | 生成プロンプト |
| --- | --- | --- | --- |
| A 仮面の迫力 | [A-mask.png](A-mask.png) | 白い仮面と赤い縁光。縮小時の識別性を優先。 | [prompt-A.txt](prompt-A.txt) |
| B ビールと炎 | [B-beer-fire.png](B-beer-fire.png) | ジョッキと炎で、そば屋らしさを強調。 | [prompt-B.txt](prompt-B.txt) |
| C 暗闇からの視線（採用） | [C-stalker.png](C-stalker.png) | 冷たい光と深い影でステルスホラーを表現。 | [prompt-C.txt](prompt-C.txt) |

原画はすべて1254×1254pxの不透明RGB PNG。背景は四辺まで描き、角丸・円形・アプリの枠・文字は焼き込まない。寸法とSHA256は[manifest.json](manifest.json)に記録。

## Android Adaptive Iconへの展開

Android 8以降にはAdaptive Iconを追加した。C原画の周囲を内蔵画像生成で拡張した[C-adaptive.png](C-adaptive.png)を使い、顔・髪を108×108dpレイヤー中央の66×66dp内へ収める。[専用プロンプト](prompt-C-adaptive.txt)。背景色と不透明の肖像画レイヤーを指定する構成で、人物だけが背景から独立して動く奥行き表現はない。

人物の透過抽出を2回試したが、内蔵画像生成がチェック模様を描いた不透明RGBを返したため不採用とし、アプリへ含めていない。採用したのは上記の不透明な背景拡張版のみ。原画の雰囲気を保ちつつ、OSによる形状マスクへ対応する。

Android 13以降のテーマ用に、仮面の目・赤い模様・額の丸・口を抜いた白い単色VectorDrawableも用意した。iOS・macOS・旧Androidは承認済みC原画のサイズ変換のみ。角丸・円形・外枠は画像へ描き込まない。

再書き出しはリポジトリルートで `python3 tools/export_hazard_icons.py` を実行する。標準のmacOS `sips` を使い、28枚を各OSの既存カタログへ出力する。出力サイズとSHA256は[adopted-C-exports.json](adopted-C-exports.json)を参照。

仕様参照：[Android公式 Adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)（2026-09-08確認）。

## アプリ名

表示名はiOS・Android・macOSとも「そば屋ハザード」。macOSのビルド成果物名も「そば屋ハザード.app」に統一する。既存セーブの参照先を維持するためbundle IDは変更せず、Swiftモジュール名と実行ファイル名も従来の `sobaya_hazard_lab` を維持する。
