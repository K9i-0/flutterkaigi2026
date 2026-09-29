# Madogiwa Engine

Madogiwa作品向けの共有Dart/Flutterパッケージ。初版0.1は `24_SOBAYA_HAZARD` を最初の利用作品とする。pub.dev公開はしていない。

- `madogiwa_engine.dart`: 衝突とレイ判定、視認・聴覚の認知記憶、モーション時計、速度制御、ワールド時計。
- `scene.dart`: Flutter Sceneのクリップを共有時計で再生するCharacterMotionPlayer。
- 描画依存はFlutter Sceneの固定コミット。SDKと外部ライブラリのライセンスは各依存のものを維持する。

作品のキャラクター名・マップ・武器威力・勝利条件は利用側へ置く。元ネタの固有名詞・モデル・マップ・アニメーションファイルはこのパッケージへ含めない。未完成の登攀実験、特定リグの補正値、作品のシナリオも含めない。

## 利用

```yaml
dependencies:
  madogiwa_engine:
    path: ../packages/madogiwa_engine
```

衝突は水平面の矩形、射撃判定は2Dレイ。高低差・ナビメッシュ・物理剛体はまだ対象外。認知記憶と移動経路探索は別で、Awarenessは障害物を迂回する経路を生成しない。CharacterMotionPlayerはモデル用に変換済みの動作を再生するもので、任意VRMへのリターゲット機能ではない。

`mise exec -- flutter test` と `mise exec -- flutter analyze` で検証する。新しい作品の必要性が確認できた機能を順に共通化し、利用作品のない抽象機能の追加を初版の完了条件にしない。
