# そば屋 — Tripo P2.0 初回生成

2026-09-05。そば屋ハザード用の非ボクセル3D原型。生成・ファイル確認とFlutter Scene検証アプリへの導入は完了。ゲーム用リグ・LODは未実施。

## 結果

- モデル: `P2-20260801`、`texture_quality: detailed`、PBRあり、`quad: true`
- task ID: `523d7211-c30f-4dae-b7f4-e9f20b4f4db0`
- 状態: `success`
- 実消費: **120 credits**、残高: **600 → 480 credits**、凍結中: 0
- このアカウントのフリークレジットでP2.0詳細テクスチャ生成が成功した。
- 取得形式: テクスチャ埋め込みFBX、3,503,980 bytes
- テクスチャ: Color / Roughness / Metallic / Normal、各4096×4096
- 1メッシュ、1材質、1 UVレイヤー。骨・アニメーションなし。
- 元メッシュ: 11,008頂点、8,811四角面＋3,446三角面＝12,257面。三角面換算21,068。
- `face_limit: 10000`を指定したが実出力は12,257面。四角面のみの出力でもないため、数値指定を完成品の保証として扱わない。

## ファイル

- [確認用GLB](sobaya_preview.glb): 10,822,952 bytes。4Kを保持し、身長1.80 m・接地位置・向きを揃えたもの。モバイル向け最適化前。
- [編集用Blender](sobaya_source.blend): 元の四角面と埋め込みテクスチャを保持。
- [Tripo原本FBX](raw/output_model_url.fbx): ダウンロードしたファイルを変更せず保持。
- [正面](review/front.png) / [側面](review/side.png) / [背面](review/back.png): Blender 5.1.2・Cyclesで作成した実モデルの確認画像。
- [生成入力画像](inputs/sobaya_front.png): 内蔵Imagegenで作成した1方向の全身参照。
- [Imagegenプロンプト全文](imagegen_prompt.txt)、[Tripo設定](config.json)、[送信内容](request.json)、[タスク記録](task.json)、[形状検査結果](audit.json)

画像生成では `02_CHARACTERS/Sobaya.jpg` と
`03_SCRIPTS/00_TEMPLATES/characters/character_sobaya_basic_sheet.png` を正典参照として使った。
全身正面、両腕を胴から離した姿勢、無地背景、白Tシャツ・黒パンツ・白スニーカー、持ち物なしを指定。

GLBは`21_SOBAYA_HAZARD_LAB/assets/models/sobaya.glb`から相対symlinkで参照する正本として採用し、Git管理対象にした。原本FBX・Blender編集ファイル・レビュー画像・署名付きURLを含む応答はローカル保持し、このrunの`.gitignore`で除外する。
ゲーム出荷用の最終モデルではなく、既存ボクセル正典を置換しない。

## 確認したことと次の修正点

正面・側面・背面を目視確認。白仮面、赤模様、黒い短髪、グレーの体、筋肉質のシルエットでそば屋として識別できる。
背面の頭髪、Tシャツ、パンツも存在し、単画像から全周の形状が生成されている。
GLBの構造を読み取り、カラー・法線・金属度／粗さテクスチャが外部参照なしで埋め込まれていることを確認した。

ゲーム用完成品にする前の修正候補:

- 仮面の黒い目と額に意図しない凹凸があり、原典より立体的。仮面の別パーツ化または形状修正を検討。
- 耳と一部の指先に暖色寄りの色が混入。露出肌を正典のニュートラルグレーへ揃える。
- 指の形・関節、肩、股関節はリグ後の変形を未検証。待機・歩行・攻撃で確認する。
- 4Kテクスチャと両面材質を保持した確認用GLBなので、出荷時には2K化、不要な両面描画、LOD、影を検討。
- Flutter Scene 0.23.0での読込・PBR描画・1〜12体の配置をmacOSで確認済み。[検証アプリ](../../../../../21_SOBAYA_HAZARD_LAB/README.md)と測定記録を参照。実際の敵AI・スキニング・モバイル性能は未検証。

## 再現

追加生成をせずタスクと出力を再確認:

```bash
python3 tools/tripo_generate.py status 04_GAME_ASSETS/3d/characters/sobaya/tripo_p2_20260905/config.json
python3 tools/tripo_generate.py download 04_GAME_ASSETS/3d/characters/sobaya/tripo_p2_20260905/config.json
```

Blender派生ファイルと確認画像を再作成:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python 04_GAME_ASSETS/3d/characters/sobaya/tripo_p2_20260905/inspect_blender.py
```

このrunの`submit`は重複課金防止のため再実行不可。再生成する場合は新しいrunを作る。
