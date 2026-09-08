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

## 未発見ダンスの再現

`openGameScenario name=ambientDance` は未発見の通常そば屋3体へ3ダンスを割り当てるdebug専用シナリオ。通常プレイの抽選は20%。背を向けて配置するため気づかず踊る。`gameAction action=aim`、`action=fire` で銃声を出すと気づき、ダンスが止まる。`inspectHazardGame` の `enemies[].idleDance` と `enemyMotions` を確認する。

## ステルス・モバイル操作の再現（2026-09-08）

`madogiwa.openGameScenario` に以下の名前を渡す。いずれも村の検証用配置で周回をリセットし、通常のゲーム時間で動作する。イベントを既読にし、確認対象の通常そば屋1体を有効にする。キャンペーンを通常操作で通した証拠とは区別する。

| `name` | 配置と確認内容 |
| --- | --- |
| `stealthRear` | 福ちゃん `(0, -16.25)`、そば屋 `(0, -15)` で敵は背を向ける。E／タッチ「破壊」でビール破壊、撃破1体、ビールの追加ドロップなしを確認する。 |
| `stealthVision` | 福ちゃん `(0, -20)`、そば屋 `(0, -15)` で敵が福ちゃんを向く。射撃せずに疑い→発見→追跡と赤いミニマップ表示を確認し、遮蔽物と距離で逃げる。 |
| `stealthNoise` | 5m離れた敵は背を向き、ショットガンと予備弾を所持する。照準を敵から外して発砲し、音の地点へ振り向いて調べることを確認する。命中させると被弾による敵対になるため、聴覚だけの確認とは分ける。 |

例：

```json
{"extension":"madogiwa.openGameScenario","args":{"name":"stealthRear"}}
```

実際のE／タッチ操作はMarionetteのUI操作で行う。ロジックの単体確認なら `madogiwa.gameAction` の `action=interact` でも同じ距離・背後条件を再判定する。忍び足と通常移動の比較には、シナリオを毎回開き直して `action=simulate` の `sneaking=true`／`sprint=true` を使う。`x/y` はカメラ相対入力で、ワールド座標ではない。

```json
{"extension":"madogiwa.gameAction","args":{"action":"simulate","seconds":"0.5","x":"0","y":"1","sneaking":"true"}}
```

`simulate` は通常の衝突・足音・敵AIを60Hzで進め、終了時に停止する。`seconds=0..10`、`x/y=-1..1`。再開は通常UIから行う。`action=move` は位置移動の補助で敵AIを同時には進めないため、ステルスの動作証拠には `simulate` または実フレームの操作を使う。`soundCue` は可聴効果音だけの検査で、敵AIへ銃声を発生させる手段ではない。

`madogiwa.inspectHazardGame` で次を照合する。

- `stealth.sneaking`、`movementNoiseRadius`、`playerNoiseRadius`、`playerNoiseTime`、`target`：移動モード、発音の強さ、現在の背後破壊対象。
- `stealth.sounds[]` の `kind`／`position`／`radius`：直近の音の種類・発生地点・基本半径。音イベントは短時間で消えるため、遅い取得で空になる場合がある。
- `enemies[]` の `awareness`：`idle`／`suspicious`／`investigating`／`chasing`／`searching`。`alerted` は敵対、`seesPlayer` は敵からの目視。
- `discovered`／`visibleToPlayer`／`lastSeenByPlayer`：プレイヤーの目視履歴と最後の記録位置。壁越し・画面外の敵を新しく記録しないこと、見失った点が実際の敵位置を追わないことを確認する。
- `lastKnown`／`contactAge`：敵が記憶している地点と情報途絶時間。背後へ移動しただけで現在位置へ更新されないことを確認する。
- `kills`、`enemies[].alive`／`suppressBeer`と画面内の拾得表示：背後破壊が一度だけ成立し、ビールを落とさないこと。保存と再開は通常のチェックポイント経路で確認する。

PCでも設定の「タッチ操作を常に表示」でタッチUIを確認できる。縦長／横長の小さいウィンドウでスティックと視点の同時操作、忍び足切り替え、構え→射撃、文脈に応じた「破壊」、字幕と安全域を確認する。画面幅の検査とiOS／Android実機の検証結果は分けて記録し、実機の結果を得るまでは操作感やFPSの保証として扱わない。
