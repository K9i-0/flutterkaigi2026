# 返信用セリフ動画

Xの返信などで使いやすい、窓際族物語らしい短編と音声付きのセリフ動画を集める。完成MP4の置き場はこのディレクトリ。編集コード・入力素材は各エピソードの `remotion/` に保持する。MP4はGit管理外、一覧と再出力設定はGit管理する。

| 動画 | キャラクター | 尺 | 用途の目安 |
| --- | --- | --- | --- |
| [これは、流行るわね。](78_福ちゃん_これは流行るわね.mp4) | 福ちゃん | 3.1秒 | 賛同・流行の予感 |
| [ギュンギュンどころじゃないわね](80_福ちゃん_ギュンギュンどころじゃないわね.mp4) | 福ちゃん | 2.5秒 | 驚き・想定以上の状況 |
| [窓際族、増やしてどうすんねん](80_やめ太郎_窓際族増やしてどうすんねん.mp4) | やめ太郎 | 3.0秒 | 増員・増殖へのツッコミ |

| [おかやまん。大変驚いております](72_おかやまん_おかやまん大変驚いております.mp4) | おかやまん | 4.70秒 | 名乗り付きの驚き・拍手 |
| [大変驚いております！](66_おかやまん_大変驚いております.mp4) | おかやまん | 1.87秒 | 強い驚き |
| [冷えてる。待遇も。](63_そば屋_冷えてる待遇も.mp4) | そば屋 | 2.60秒 | 待遇・労働への自虐 |

## 再出力

リポジトリルートから実行。元の完成動画と各Remotionプロジェクトの依存関係が必要。出力はこのディレクトリへ直接保存される。

```sh
npm --prefix 03_SCRIPTS/78_madogiwa_tshirt_runway/remotion run render:fukuchan
npm --prefix 03_SCRIPTS/80_sobaya_clone_lab/remotion run render:dialogues
npm --prefix 03_SCRIPTS/72_tokyo_madogiwa_park/remotion run render:reply
npm --prefix 03_SCRIPTS/66_madogiwa_super_try_invasion/remotion run render:reply
npm --prefix 03_SCRIPTS/63_madogiwa_super_try_commute/remotion run render:reply
```

80話のやめ太郎は、本人が映るカット先頭から始まる修正版。素材を追加するときは `話数_キャラクター_セリフ.mp4` で保存して、この一覧へ追記する。

## 素材待ち

選択候補29：31話・福ちゃん＋一同「ギュン謝ギュン謝ギュンギュンでーす！」。2026-09-29、エピソード内・ローカル保管先・Studio一覧で元動画を確認できず、切り抜き未作成。元動画の保存先またはURL待ち。

## 状況とオチのある短編

番号は2026-09-29に提示した短編候補の番号（以前のセリフ候補番号とは別）。

| 候補 | 動画 | 出典 | 尺 |
| --- | --- | --- | --- |
| 1 | [パトカーで連行](71_そば屋_パトカーで連行.mp4) | 71話 | 4.57秒 |
| 2 | [タクシーちゃうねん](82_やめ太郎_タクシーちゃうねん.mp4) | 82話 | 2.10秒 |
| 4 | [昼休み終わっちゃうからの連行](81_そば屋_昼休み終わっちゃうからの連行.mp4) | 81話 | 8.73秒 |
| 5 | [モデル歩きで連行](78_そば屋_モデル歩きで連行.mp4) | 78話 | 7.77秒 |
| 7 | [ビールのために脱獄](79_そば屋_ビールのために脱獄.mp4) | 79話 | 4.27秒 |
| 10 | [あいつらクビ](76_よーたん_あいつらクビ.mp4) | 76話 | 5.27秒 |
| 11 | [ビール切れでオフィス地震](76_そば屋_ビール切れでオフィス地震.mp4) | 76話 | 6.63秒 |
| 12 | [指示どおり働くなんてそば屋さんやない](80_やめ太郎_指示どおり働くなんてそば屋さんやない.mp4) | 80話 | 6.77秒 |
| 15 | [宇宙侵略に大変驚いております](66_おかやまん_宇宙侵略に大変驚いております.mp4) | 66話 | 6.17秒 |
| 追加 | [一流の窓際族は窓際を作り出す](59_そば屋_一流の窓際族は窓際を作り出す.mp4) | 59話 | 7.40秒 |

追加の「一流の窓際族」は59話の「窓際に追い込まれてるうちは二流。一流の窓際族は、窓際を作り出す。」を前半から収録。

```sh
npm --prefix 03_SCRIPTS/71_hisoba_memory_review/remotion run render:stories
npm --prefix 03_SCRIPTS/82_last_train_police_taxi/remotion run render:stories
npm --prefix 03_SCRIPTS/81_sobaya_yakumi_shopping/remotion run render:stories
npm --prefix 03_SCRIPTS/78_madogiwa_tshirt_runway/remotion run render:stories
npm --prefix 03_SCRIPTS/79_madogiwa_tshirt_prison_break/remotion run render:stories
npm --prefix 03_SCRIPTS/76_sobaya_yakisoba_quake/remotion run render:stories
npm --prefix 03_SCRIPTS/80_sobaya_clone_lab/remotion run render:stories
npm --prefix 03_SCRIPTS/66_madogiwa_super_try_invasion/remotion run render:stories
npm --prefix 03_SCRIPTS/59_sobaya_professional_window_side/remotion run render:stories
```

## ヒソバ回の迷言（2026-09-29追加）

| セリフ | キャラクター | 尺 |
| --- | --- | --- |
| [うーん、君は不合格♥](71_そば屋_うーん、君は不合格♥.mp4) | そば屋 | 3.27秒 |
| [君の敗因はメモリの無駄遣い♠](71_そば屋_君の敗因はメモリの無駄遣い♠.mp4) | そば屋 | 2.93秒 |
| [誰やお前！](71_やめ太郎_誰やお前！.mp4) | やめ太郎 | 1.73秒 |
| [僕？ 僕はヒソバ](71_そば屋_僕？ 僕はヒソバ.mp4) | そば屋 | 3.50秒 |

再出力は71話の `npm run render:stories`。字幕・元音声を保持。
