# そば屋ハザード：アプリアイコン原案

2026-09-08制作。iOS・Android・macOS共通の原画候補3案。内蔵 `image_gen` を使用し、そば屋の正典写真 `02_CHARACTERS/Sobaya.jpg` を人物同一性の参照にした。まだ採用案は選んでおらず、各OSのランチャーアイコンへは適用していない。

| 案 | 原画 | 狙い | 生成プロンプト |
| --- | --- | --- | --- |
| A 仮面の迫力（推奨） | [A-mask.png](A-mask.png) | 白い仮面と赤い縁光。縮小時の識別性を優先。 | [prompt-A.txt](prompt-A.txt) |
| B ビールと炎 | [B-beer-fire.png](B-beer-fire.png) | ジョッキと炎で、そば屋らしさを強調。 | [prompt-B.txt](prompt-B.txt) |
| C 暗闇からの視線 | [C-stalker.png](C-stalker.png) | 冷たい光と深い影でステルスホラーを表現。 | [prompt-C.txt](prompt-C.txt) |

原画はすべて1254×1254pxの不透明RGB PNG。背景は四辺まで描き、角丸・円形・アプリの枠・文字は焼き込まない。寸法とSHA256は[manifest.json](manifest.json)に記録。

## Android Adaptive Iconへの展開

原画は比較用の一枚絵で、完成したAdaptive Icon用のレイヤーではない。採用後、人物・ジョッキの前景と背景を分離し、108×108dpのレイヤーに配置する。顔とジョッキなどの重要部分は中央66×66dpへ収める。今回の原画をそのまま全面の前景として設定すると髪やジョッキが切れ得るため、特にB案では前景全体を縮小して配置する。

背景は全面を埋め、外周に枠や外部シャドウを付けない。円・角丸・スクワークルでプレビューし、テーマ用の単色レイヤーも別途用意する。iOS・macOSには採用原画から各OS向けのサイズとアセット構成で出力する。原画自体にOSのマスクを描き込まない。

仕様参照：[Android公式 Adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)（2026-09-08確認）。

## アプリ名

表示名はiOS・Android・macOSとも「そば屋ハザード」。macOSのビルド成果物名も「そば屋ハザード.app」に統一する。既存セーブの参照先を維持するためbundle IDは変更せず、Swiftモジュール名と実行ファイル名も従来の `sobaya_hazard_lab` を維持する。
