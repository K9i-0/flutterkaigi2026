# 返信用セリフ動画

Xの返信などで使いやすい、音声付きの短いセリフ動画を集める。完成MP4の置き場はこのディレクトリ。編集コード・入力素材は各エピソードの `remotion/` に保持する。MP4はGit管理外、一覧と再出力設定はGit管理する。

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
