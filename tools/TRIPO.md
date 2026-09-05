# Tripo APIの準備

2026-09-05確認。必要なのはTripo APIキーと生成用のAPIクレジット残高。
REST APIを使用するため、Tripo CLI・SDK・公開サーバーの導入は必須ではない。
モデル制作の判断は[そば屋ハザード制作方針](../docs/research/sobaya_hazard_3d_pipeline.md)を参照。

## ユーザー側の準備

1. [Tripo Console](https://platform.tripo3d.ai)へログインする。
2. API Keysでキーを作成する。公式説明では作成直後に一度だけ表示される。
3. API側のクレジット残高を確認し、必要量をチャージする。
4. このリポジトリのルートで、手元のターミナルから次を実行する。

```bash
python3 tools/tripo_setup.py set-key
python3 tools/tripo_setup.py check
```

`set-key`は非表示入力でキーを受け取り、`.local/tripo/api_key`へ保存する。
再実行すると保存済みキーを置換する。ファイルは所有者だけ読み書きできる平文ファイルで、
暗号化保管ではない。`.local/`は既存の`.gitignore`で除外されている。
キーをチャット、ソースコード、Flutterアプリ、シェルコマンドの引数へ含めない。
環境変数`TRIPO_API_KEY`が設定済みの場合は、保存ファイルより環境変数を優先する。

`check`は公式ホストへ`GET /v3/account/balance`だけを送り、認証と利用可能・凍結中の残高を表示する。
生成、画像アップロード、購入、チャージは行わない。レスポンス本文やキーを診断ログへ出力しない。
Python 3.9以降の標準ライブラリだけで動作し、追加インストール不要。

## キー設定後の進め方

- まず残高照会で接続確認する。この成功だけではP2.0の実生成対応までは確認できない。
- Imagegenで本番入力画像を用意し、P2モデルID・面数・入力方向・費用を記録する。
- 最初の1体で`P2-20260801`の生成、取得形式、Blenderでの四角面・材質・リグ互換性を確認する。
- 原型と設定、task ID、実消費creditsを保存し、ゲーム向けの修正に進む。

## 画像からP2詳細テクスチャ付きモデルを生成

`tripo_generate.py`は設定JSONに指定した画像をアップロードし、1件だけ生成する。
`plan`はオフライン確認、`submit`はクレジットを消費する生成操作。

```bash
python3 tools/tripo_generate.py plan path/to/config.json
python3 tools/tripo_generate.py submit path/to/config.json
python3 tools/tripo_generate.py status path/to/config.json
python3 tools/tripo_generate.py download path/to/config.json
```

`config.json`の形式はそば屋の
`04_GAME_ASSETS/3d/characters/sobaya/tripo_p2_20260905/config.json`を参照。
`submit`は送信前に記録を作り、同じ出力ディレクトリでの重複生成を拒否する。
通信途絶でtask IDを保存できなかった場合も、自動で再送しない。
Tripoコンソールのタスク履歴を確認してから復旧する。
`status`と`download`は追加生成を行わない。
取得ファイルと署名付きURLを含むAPI応答は、各runの`.gitignore`で除外する。
ダウンロード先のCDNへAPIキーは送らない。

## 確認元

- [認証とキー作成](https://developers.tripo3d.ai/en/docs/authentication)
- [残高API](https://developers.tripo3d.ai/en/docs/account)
- [API料金](https://developers.tripo3d.ai/ja/pricing)
- [P2対応履歴](https://developers.tripo3d.ai/en/docs/changelog)
