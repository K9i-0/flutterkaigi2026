# そば屋 v2 — 参照CによるTripo / Astra制作

ユーザーが選んだ[全身参照C](reference/master_front.png)から、[Tripo公式記事](https://www.tripo3d.ai/blog/gpt-6-astra-3d-character-workflow)の参照準備・部位生成・Blender接合・リグ・材質確認・短い動作の順で制作。指定に従い、髪と仮面は頭部に含め、**BodyとHeadの2パーツ**として扱う。

Cは今回のTripoモデル制作専用。キャラクターの正典や今後の作品で使う標準画像を更新するものではない。既存の本編GLB・VRM・正典写真は変更していない。

- 完成モデル：[sobaya_v2.glb](sobaya_v2.glb)
- 編集用：sobaya_v2.blend（テクスチャをpack、ローカル保持）
- 確認ページ：[localhost:8767](http://127.0.0.1:8767/tools/preview_sobaya_v2.html)
- 3秒・24fps・1920×1080の挨拶：[preview/greeting.mp4](preview/greeting.mp4)（ローカル保持）
- 参照・タスクID・費用：[provenance.json](provenance.json)
- 生成プロンプト：[imagegen_prompts.json](imagegen_prompts.json)
- 接合と動作の記録：[assembly_report.json](assembly_report.json)
- GLBの形式・変形検査：[validation.json](validation.json)
- ブラウザ・動画の確認記録：[review.json](review.json)

## 参照と接合

正典の `02_CHARACTERS/Sobaya.jpg` と標準キャラクターシートからImagegenで全身3候補を新規生成し、ユーザーがCを採用。Cから胴体と髪・仮面付き頭部の入力画像をImagegenで新しく作成した。以前のTripo入力や廃止した頭部素材は使っていない。

Tripo P2 detailed PBR、quad指定。胴体15,000・頭部8,000のface_limitを要求した。生成結果の実面数は要求値と一致するとは限らないため、完成GLBの検査値を正本とする。

Blender MCPで専用シーンとBody / Headを確認。体のTripo二足リグを使い、頭部のない胴体に合わせて推定された首・頭ボーンを実際の頭部へ延長した。胴体側の不要な首を除去し、襟の内側と首内部を補完。後頭部下の張り出しを襟内に収めた。UV境界を考慮した肩ウェイト平滑化と、4影響への正規化を適用した。

## モデルと動作

身長1.8m、48,774三角面、23ボーン、約11.6MB。BlenderではBody / Headの2メッシュで、GLBでは補修材質を含め4描画メッシュとなる。髪はHeadに含まれる。仮面は硬い形を保ち、表情モーフは設けていない。

| 動作 | 出典 |
| --- | --- |
| Idle / Walk | 既存そば屋本編のAdopted_Library_Idle_A / Walk。元はMesh2Motion / Quaternius CC0 |
| Run | 既存そば屋のAdopted_Candidate_Chase_Run。CC0 Jogを元に調整した逃走・追跡版 |
| DanceStep / DanceDisco / DanceVictory | 既存そば屋のAdopted_Library_Dance_Simple / Charleston / Body_Roll。CC0ライブラリ由来 |
| Greeting | 新しいリグ上で制作した3秒の挨拶 |
| Test_HeadTurn / Test_ArmRaise / Test_ElbowBend / Test_KneeBend | 新しいリグ上で制作した首振り・腕上げ・肘曲げ・膝曲げの検査動作 |

既存そば屋の骨名を新しいTripoリグへ対応付け、初期姿勢・腕軸・脚長を考慮してベイクした。元モデルの全98クリップを移植したものではない。出典と元GLBのハッシュはassembly_report.jsonにも記録する。公開素材の条件は[motion_library](../../../motion_library/README.md)を参照。

## 確認範囲と制限

正面・側面・背面、顔アップ、待機・歩行・走行・挨拶、首振り±35°、腕上げ145°、肘・膝曲げをBlenderで確認。GLB形式エラー0、各11クリップを5時点でスキン変形検査した。警告4件は、実行環境での接線生成2件と親を持つスキンメッシュ2件。

袖・脇と襟に生成由来の皺や不均一な縁が残る。23ボーンのリグには指の個別ボーン・ジョッキソケット・裾補助骨がなく、v1の細かな調整をすべて引き継いだモデルではない。全関節・全フレームの非貫通や自然さは保証していない。本編採用、ジョッキ把持、ゲーム内の移動速度合わせ、Flutterの負荷測定は別工程。

## 再現

リポジトリルートから、生成済みFBXを使って実行する。これらのコマンドは有料APIを呼ばない。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_sobaya_v2.py
node tools/validate_sobaya_v2.mjs
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/render_sobaya_v2.py -- --movie
python3 -m http.server 8767 --bind 127.0.0.1
```

Blender 5.1.2、Node.js、`.local/vrm-validation/node_modules` のthree / gltf-validator、ffmpegを使用。原FBXがない環境ではprovenance.jsonの各タスクIDを各フォルダのtask.jsonへ保存し、`tools/tripo_generate.py download <folder>/config.json`で既存出力を再取得できる。新規submitは不要。モーション変換には既存 `04_GAME_ASSETS/3d/hazard_adopted/sobaya.glb` が必要。

## クレジット

今回のC採用後：1,060 → 胴体120 + 頭（髪込み）120 + リグ25 = **265消費、残795、凍結0**。以前の却下された試行240は今回の265に含めない。追加の髪生成は行っていない。
