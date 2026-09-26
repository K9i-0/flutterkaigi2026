# Sobaya Tidewater

- Tidewaterの島を土台にした新しい一人称そば屋ハザード。既存21番のゲームは独立して維持する。
- **Flutter Sceneは `K9i-0/flutter_scene` forkを使用する。Flutter SDK / Flutter GPU / Impellerにはパッチを入れない。** SDK依存は `sdk: flutter` のままとし、Computeが必要な原作機能は頂点・フラグメント・複数の描画パス・事前生成で実装可能な範囲へ設計し直す。
- fork参照はコミット固定。汎用描画拡張はfork、島の材質・ゲームルール・入力はこのアプリ。pub cacheを直接編集しない。
- 初期到達点はマップ移植と一人称歩行。海・空の原作同等表現、キャラクター、会話、戦闘はREADMEの未実装項目を確認する。
- 3Dモデルは共通正本への相対symlink。Tidewater変換元と出力は `tools/export_tidewater.mjs` と `04_GAME_ASSETS/3d/tidewater/`。
- Dart MCPでMac debug起動、Marionetteで `madogiwa.inspectTidewater` / `madogiwa.openTidewater` と実画面を確認する。性能をdebug FPSで判定しない。
