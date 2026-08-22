# Flutter Scene VRM two-layer lab

FlutterだけでVRMアバターを描画し、カメラ由来の顔情報で動かす2層構成の検証アプリ。

```text
Flutter UI + Camera / ML Kit / Marionette MCP
  -> flutter_scene_vrm (VRM解釈・表情・Humanoid駆動)
    -> K9i-0/flutter_scene fork (glTF morph targets + rendering)
```

## 検証済み

- 公式VRM 1.0モデルの実行時ロードと描画
- VRM表情、口パク`aa`、まばたき
- Humanoidの`head` / `neck`回転
- 顔入力の正面補正、指数平滑化、向きと値の制限
- iOS / Androidの前面カメラ → ML Kit顔検出 → VRM駆動経路
- macOSの同一入力契約シミュレーション
- Dart MCPでの起動・接続とMarionette MCPによる決定論的な顔入力

実カメラ経路は`camera`と`google_mlkit_face_detection`を使用する。カメラ映像を
直接VRM層へ渡さず、正規化した`FaceTrackingSignal`を境界にしているため、将来
ARKitやMediaPipeへ検出器を差し替えられる。

## 実行

```bash
mise exec flutter@3.47.1 -- flutter pub get
mise exec flutter@3.47.1 -- flutter run -d macos --debug
```

macOSでは「追跡開始」でシミュレーションが始まる。iOS / Androidではカメラ権限を
許可すると前面カメラを使用する。

## Dart MCP / Marionette MCP

モノレポルートの`.mcp.json`と`.codex/config.toml`にあるDart MCP / Marionette MCPを
17と共用する。debugネイティブビルドだけが`MarionetteBinding`と次のextensionを登録する。

- `madogiwa.inspectVrm`: モデル、表情、追跡値、検出器状態を取得
- `madogiwa.setFaceTracking`: カメラまたはシミュレーション追跡を開始・停止
- `madogiwa.injectFace`: 顔角度・目・口を同一VRMドライバへ決定論的に注入
- `madogiwa.calibrateFace`: 最新の顔向きを正面として補正
- `madogiwa.setVrmExpression`: VRM表情を名前とweightで指定
- `madogiwa.resetVrm`: 追跡、頭、首、表情を初期化

`madogiwa.injectFace`の例:

```json
{
  "yaw": 28,
  "pitch": -10,
  "roll": 7,
  "leftEyeOpen": 0.15,
  "rightEyeOpen": 0.8,
  "mouthOpen": 0.7
}
```

通常のMarionette操作用に`face-tracking-toggle`、`face-tracking-calibrate`、
`vrm-emotion`、`vrm-mouth`、`vrm-auto-blink`の`ValueKey`も設定している。

## プラットフォーム注意点

- iOSはML Kitラッパーの要件に合わせdeployment target 15.5。
- `google_mlkit_face_detection`がまだSwiftPM非対応のため、このプロジェクトだけ
  CocoaPodsを指定している。
- iOS 26のApple SiliconシミュレータではML Kitのarm64警告が出る。ビルドは成功するが、
  実カメラ検証は物理iPhoneで行う。
- カメラ映像をアップロード・保存する処理はない。

詳細な結果と残課題は[VALIDATION_REPORT.md](VALIDATION_REPORT.md)を参照。
