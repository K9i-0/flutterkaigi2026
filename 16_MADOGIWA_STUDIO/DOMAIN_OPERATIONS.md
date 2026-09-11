# ドメイン運用メモ

更新: 2026-09-11

## madogiwa.work

- Cloudflareで取得・決済済み。公式サイトの正規URLは `https://madogiwa.work`。
- Worker: `madogiwa-studio`。Custom Domainは `wrangler.jsonc` で管理。
- 旧workers.devは既存管理画面・Remote MCPの互換性のため維持する。
- canonical、OGP、共有URL、サイトマップは `src/lib/public-data.ts` の `SITE_ORIGIN` を参照。

検証・公開済み:
- `https://madogiwa.work/` はHTTPS 200。canonical / OGP / robots.txtは新URL。
- 既存13テスト、型検査、lint、build、startup、dry-run通過。
- 未認証の `/mcp` は401。管理画面の入口は既存Access付きworkers.devを使用。
- AI bot policies: Search / Agent / Training はAllow。旧Block AI botsはDo not block。
- 9月15日のMixed purpose crawlersは「continue to be allowed」に変更済み。
- Cloudflare managed rulesetはAlways activeを維持。

## k9i.app: 移管未完了

ユーザーの方針: ほぼ未使用。Cloudflareへ管理を統一する。公式サイトの作業を優先。

完了:
- Cloudflare同一アカウントに無料プランで追加。
- SquarespaceのDNSSECを承認を得てOFF。公開DNSのDS消失を確認。
- ネームサーバーを `may.ns.cloudflare.com` / `rene.ns.cloudflare.com` に変更。
- Squarespaceの移管ロックOFFを確認。
- 移管認証コードを登録メールへ送付する操作を実行。
- 下記DNS3件をCloudflareへ登録（すべてDNS only、TTL Auto）。

| Type | Name | Value | 元TTL |
|---|---|---|---|
| A | @ | 199.36.158.100 | 4時間 |
| CNAME | jgie2s2nry7i | gv-zucqmz4qzvxyke.dv.googlehosted.com | 4時間 |
| CNAME | _domainconnect | _domainconnect.domains.squarespace.com | 1時間 |

残作業:
- [x] CloudflareでActiveになったことを確認。
- [ ] ユーザーに届いた移管コードをCloudflareの移管画面へ入力。
- [ ] 移管価格・更新価格・1年延長を確認してユーザーが決済・規約同意。
- [ ] 必要なメール承認を実施し、RegistrarがCloudflareになったことを確認。
- [ ] 移管完了後にCloudflareでDNSSECを再有効化、DS反映・DNS正常性を確認。
- [ ] 自動更新・有効期限・元レジストラの移管完了状態を確認。

Squarespace表示の有効期限: 2027-09-11、更新料金: 1,600円。Cloudflareの移管価格は未確認。
移管コード・個人住所・決済情報はこのメモに記録しない。
