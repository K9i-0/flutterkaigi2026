# ゲームのMCPデバッグ

既存のDart MCPとMarionetteを使用する。設定はルートの `.mcp.json` / `.codex/config.toml` にあり、Flutter 3.47.2へ固定済み。追加のAPIキーや手動の中継サーバーは不要。

## 接続

1. Dart MCP `roots` の `command=add` に、このディレクトリの絶対file URIを渡す。
2. `launch_app` に同じ `root`、`device=macos`、`target=lib/game_main.dart` を渡す。返された起動PID・DTD URI・App URIを記録する。
3. Marionette `connect` にApp URIを渡す。
4. `call_custom_extension` で `madogiwa.debugSession` を呼ぶ。`app=sobaya_hazard`、ネイティブ `pid`、`ready=true`、`foreground=true` を確認する。

アセット検証用の `lib/main.dart` と、ゲーム本体の `lib/game_main.dart` を取り違えない。URIは起動ごとに変わるので古い値を固定しない。背景にある場合は対象ゲームウィンドウを前面にして再確認する。必要ならCUAで対象アプリだけを操作する。

## 会話を1呼び出しで確認

Marionette `call_custom_extension` の引数:

```json
{"extension":"madogiwa.runGameProbe","args":{"name":"conversation"}}
```

この検査は現在の周回をリセットし、導入会話を再生する。保存済みコレクションは保持し、終了時は会話を一時停止する。準備未完了・背景表示の場合はリセット前に失敗する。

- やめ太郎と福ちゃんの音声再生位置、実フレームの進行、口の開きの変化とSceneノードへの適用を記録する。
- 非話者の口が閉じること、停止で音声と口が止まること、再開で音声が巻き戻らないことを確認する。
- 最大12秒を目安に終了し、背景化・周回変更は理由付きで中断する。キャンペーン監査との同時起動は拒否する。
- 成否は応答本文の `success` を見る。MCP通信自体の成功だけでは合格にしない。`snapshots` に時刻・フレーム数・音声・モーフ値が残る。

2026-09-06のMac debugでは検査本体2,483ms、17スナップショットで合格した。これは実際のアプリ内の描画フレーム／音声バックエンドとコントローラー遷移の検査であり、キーやタッチ操作の検査ではない。口の自然さの目視評価や最終性能測定も別途行う。

## 使い分けと再接続

| 目的 | 使用する機能 |
| --- | --- |
| 接続先・前面状態・検査実行中の確認 | `madogiwa.debugSession` |
| 再現条件へ移動 | `madogiwa.openGameScenario` |
| 会話の構図を静止して確認 | `madogiwa.gameAction` の `action=eventFrame`、`shot`、`progress=0..1` |
| 状態・音声・口・モーションの診断 | `madogiwa.inspectHazardGame`（`voice` / `speechFaces` など） |
| 会話の回帰確認 | `madogiwa.runGameProbe` |
| 長い通し経路の自動確認 | `madogiwa.auditCampaign` |
| 実際のボタン・キー・長押しの確認 | MarionetteのUI操作とスクリーンショット |
| 描画負荷 | profileビルドの既存ベンチマーク |

Dartコード変更後はDTDへ接続してhot reloadする。extension登録の追加はhot restartまたは再起動が必要。GLB・音声など同梱素材を更新した場合はアプリを再ビルドして確認する。

終了にはDart MCP `stop_app` と記録した起動PIDを使う。ネイティブ子プロセスが残る場合があるため、同じパスの古いウィンドウに接続し続けないよう `debugSession.pid` と照合する。追加終了が必要な場合も、所有する対象PIDとコマンドを確認してから行い、他のFlutterアプリを一括終了しない。

生ログ・画像はGit対象外の `evidence/`、軽量な採用検証記録は `qa/` に保存する。

会話の構図確認は `openGameScenario name=introEvent`（または `farmEvent` / `bossEvent` / `endingEvent`）のあと、`gameAction action=eventFrame shot=2 progress=0.5` のように呼ぶ。音声と連続描画を止め、指定カットのカメラ位置と人物の向きを描画する。背景表示でも静止画は取得できるが、これは発話・実時間モーションの検証には使わない。画面の「再開」から通常の再生へ戻れる。
