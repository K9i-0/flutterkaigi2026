# たこさん・5cm／7cm：見積もり準備と暫定試算

2026-09-18。台座込み5cm・7cmを各1体、JLC3DPとDMMで比較。発注・支払いはしていない。

**現状：v1の試算後、最終外観監査で触手の一部欠落を検出。v2で修復済みだが、修正版の再アップロードは自動承認レビューに拒否され、ユーザーへ明示承認を依頼中。下表は欠落を含む旧v1の暫定値で、正しい形状の最終見積もりではない。**

## 修正版v2

| 条件 | 5cm版 | 7cm版 |
|---|---:|---:|
| 全高 | 50mm | 70mm |
| 台座外径（修復後） | 約45.06mm | 約59.98mm |
| 台座厚さの設計値 | 2.5mm | 2.5mm |
| 体積 | 16.581cm³ | 42.122cm³ |
| 連結成分 | 1 | 1 |

ソース：`../../characters/takosan/rig_radial_v5_clean/takosan.glb`。
本体`TakosanBody`だけを固定し、リグ表示用Icosphereを除外。元データは変更していない。

v1の法線依存のボクセル結合は、ソースの開口・面方向により右側などの触手を欠落させたため不採用。v2は表面を符号なしでボクセル化し、小さな隙間の閉鎖と内部充填を行う。連結1・水密・面方向整合を検証し、STL再読込レンダーで触手を確認。元ソースのフード内側など埋没面は、充填後表面から離れるため、全頂点の距離だけで欠落判定しない。触手外周の表面距離を別に監査する。

最小肉厚、触手先端の強度、サポート除去、表面平滑化、フルカラーの色再現は業者の製造審査前。中空化なし。カラー参考画像はゲームのテクスチャで、色付き製造データの入稿・審査は未実施。

## 旧v1の暫定試算（再見積もり必須）

| サービス／素材 | 5cm | 7cm | 日数の表示 |
|---|---:|---:|---|
| JLC 単色9600 Resin White / General Sanding・造形費 | US$1.44 | US$3.72 | 製造3日 |
| 同上＋日本向けOCS送料 | US$8.62 | US$10.90 | 配送4〜6営業日を加算 |
| JLC WJP Full Color Resin / Oil Spraying・造形費 | US$13.57 | US$32.80 | 製造5日 |
| 同上＋日本向けOCS送料 | US$20.75 | US$39.98 | 配送4〜6営業日を加算 |
| DMM エコノミーレジン SLA | 2,162円 | 4,433円 | 発送7〜18日 |
| DMM フルカラーマルチマテリアル MJT J850 | 9,468円 | 20,819円 | 発送3〜14日 |

旧v1の体積は15.823cm³／40.847cm³。修正版の体積は約4.8%／3.1%増加しているが、金額は単純比例で推定せず再入稿して取得する。
JLC送料は各1体個別の日本向けOCS US$7.18、郵便番号未指定。税・輸入時追加費用・為替や決済手数料・形状審査の追加費用は未確認。2体同梱ではない。
DMM送料は公式ヘルプ上無料。税込／税別の明示は簡易見積もり画面では未確認。両社フルカラー価格は同じSTLにカラー素材を指定した形状ベースの概算。

## 再生成

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/build_takosan_print_quote.py
# Python環境に trimesh / scipy / scikit-image が必要
/private/tmp/takosan-print-env/bin/python tools/repair_takosan_print_quote.py
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/review_takosan_print_quote.py
```

修正版：`takosan_50mm_base45_v2.stl` / `takosan_70mm_base60_v2.stl`。
`report_v2.json`に形状・ハッシュ、`review_v2.json`に表面距離監査を記録。
`*_v2_solid.png`が正しい単色プレビュー。`*_v1_color_reference.png`は元形状・色の参考として有効。`*_v1.stl`と`*_v1_solid.png`は欠落した旧版で使用しない。
生成バイナリ・画像はローカル保持、再生成スクリプトと軽量記録のみGit管理。

## サイト

- https://jlc3dp.com/jp/3d-printing-quote
- https://quote.make.dmm.com/
- DMM送料：https://support.make.dmm.com/hc/ja/articles/360039117034
