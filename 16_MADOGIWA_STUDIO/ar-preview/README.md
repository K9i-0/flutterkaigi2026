# 窓際ARカメラ（ローカル試作）

既存GLBをブラウザで取得し、ポーズを固定したUSDZへ変換。写真・映像の取得やアップロードAPIは持たず、撮影はiPhoneのAR Quick Lookに委ねる。

## 起動

Node 24で、Studioディレクトリから実行する。

```sh
npm run build:ar
npm run preview:ar -- --host <MacのLANアドレス>
```

同じWi-FiのiPhoneのSafariで `http://<MacのLANアドレス>:5175/` を開く。これは静的専用ビルドで、モデル4点とサムネイル4点だけをコピーする。管理画面、DB、音声、アップロード機能は含まない。変更後は再ビルドが必要。

公式サイトは `/camera/<character>` で同じコンポーネントを使用。キャラクター紹介と3Dビューアの「いっしょに撮る」から、選択中のキャラで開く。サイズの初期選択は等身大。

## 操作

1. キャラ、サイズ、ポーズを選択。
2. 「撮る準備をする」で端末内変換。
3. 対応Safariでは、生成後のキャラ画像（`rel="ar"`）をタップ。
4. 空間配置ではAR画面で床・机を認識させて配置し、撮影する。

等身大: そば屋180cm、福ちゃん170cm、たこさん143.3cm、やめ太郎130cm。ぬいぐるみ:20cm。顔の横:12cm。等身大のスケールはポーズによって変わらないよう、静止時のモデル身長を基準にする。

## 自撮り実験版と制約

Appleの`Preliminary_AnchoringAPI`の`face`を、単一シーンに設定。顔の右方向19cm・下方向8cm・前方向2.5cmにキャラの足元を設定する。TrueDepth搭載iPhoneが対象。肩追跡ではなく顔追従。移動や回転に関する制約はQuick Look側の仕様による。

顔アンカーUSDZの作成と、iPhoneで前面カメラが起動することは別の検証項目。ユーザーによる試作の動作確認済み。端末・iOSごとの向き、遮蔽、追従、写真保存の網羅的な実機検証は未実施。実機で床配置へフォールバックする場合は対応済みとは扱わず、アンカー・シーン構造を調査する。

- ブラウザ/カメラ映像はサーバーへ送信しない。通信は静的ページ・GLB・サムネイルのみ。
- 変換はボタン操作時だけ。変更・閉じる操作で通信中断、生成済みBlob URLを解放。
- 初回はモデルの読込と端末内変換の待ち時間がある。
- ARモデルは静止ポーズ。USDZExporterがスキニングを焼き込まないため、変形後の頂点を明示的に固定している。
- 頂点色のみの肌マテリアルは小さなテクスチャへ変換し、Quick Lookの頂点色差異を回避。
- AndroidにQuick Lookはない。現試作はファイル保存案内にフォールバックし、Android ARは未実装・動作未保証。
- スマホの熱/メモリ、SafariからQuick Lookへの引き渡し、戻る・再起動は実機で確認する。

## 確認

`npm run verify`（34テスト、型、lint、ビルド、起動、dry-run）。
ブラウザで生成したUSDZに対し `xcrun usdchecker --arkit <file>` でApple形式検証。
単体テストは単位、アンカー切替、画像保存、ZIP非圧縮・64バイト整列を確認する。

参考:
- https://developer.apple.com/documentation/usd/placing-a-prim-in-the-real-world
- https://developer.apple.com/videos/play/wwdc2019/612/
- https://webkit.org/blog/8421/viewing-augmented-reality-assets-in-safari-for-ios/

## 試作時の確認記録（2026-09-16）

- Chromeでやめ太郎（20cm）、そば屋（等身大）、福ちゃん（ごあいさつ）のUSDZ生成を確認。
- やめ太郎のブラウザ生成ファイルはApple `usdchecker --arkit`でSuccess。
- ぬいぐるみの頂点座標の高さが0.2mであることを確認。
- ユーザーより試作は問題なく動作しているとの確認を受け、本番公開を承認。
