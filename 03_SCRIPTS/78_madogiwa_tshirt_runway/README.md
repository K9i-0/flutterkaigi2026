# 窓際族Tシャツ・ランウェイCM

[台本](script.md) / [Wanプロンプト](prompt_wan3.txt) / [設定](wan3_config.json)

Wan生成成功。完成版は `final_remotion_runway.mp4`。生成元は27秒・480P、Remotion編集後は30秒・720P（本編を拡大）。

## 検証（リポジトリルート）

```sh
python3 03_SCRIPTS/78_madogiwa_tshirt_runway/generate.py
```

生成済みのため再送しない。タスクと条件は `generation-record.json` を参照。

## Remotion

```sh
cd 03_SCRIPTS/78_madogiwa_tshirt_runway/remotion
npm ci
npm run typecheck
npm run stills
npm run preview
```

`out/endcard-preview.mp4` は締め3秒だけの確認用。完成動画ではない。
本編生成・監査後は同フォルダで次を実行する。

```sh
ln ../wan3_runway_seed26092478_480p.mp4 public/input.mp4
python3 ../finish_audio.py --music-start-frame 180
npm run render
```

`ln` はhardlink。別ファイルシステムの場合はコピーする。人物修復などで採用元が変わった場合はその採用映像を入力にする。
完成出力は `../final_remotion_runway.mp4`。入力がない場合は完成版レンダーを明示的に拒否する。

依存は2026-09-24の `npm view remotion version` で確認した4.0.527へ固定。ローカルQAでは75話の同バージョンnode_modulesをsymlinkで再利用（Git管理外）。別環境では `npm ci` で再現する。レンダーはmacOSのGoogle Chromeとヒラギノフォントを使用する。

現行設定：Wan 27秒・480P＋Remotion締め3秒＝30秒。締めにもWan生成の音楽を編集で接続済み。外部素材送信をユーザーが明示承認し、タスク受理済み。二重送信しない。
