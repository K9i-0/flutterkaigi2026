# 福ちゃん v2 — Astra / Tripo 3パーツ制作

[Tripo公式の手順](https://www.tripo3d.ai/blog/gpt-6-astra-3d-character-workflow)に沿い、正典写真から全身基準を作り、**体・髪のない頭・髪を別々に生成**したモデル。体のTripoリグへ頭と髪を接続し、Blenderで首・肩・手首を調整した。

- 完成モデル: [fukuchan_v2.glb](fukuchan_v2.glb)
- 編集用: fukuchan_v2.blend（全テクスチャをpack、ローカル保持）
- 確認ページ: [localhost:8766](http://127.0.0.1:8766/tools/preview_fukuchan_v2.html)
- 3秒の挨拶: preview/greeting.mp4（ローカル保持）
- 基準写真: [Fukuchan.jpg](../../../../../02_CHARACTERS/Fukuchan.jpg)
- 入力・費用・タスクID: [provenance.json](provenance.json)
- 形状・材質・動作の生成記録: [assembly_report.json](assembly_report.json)
- GLB検証: [validation.json](validation.json)

## 仕様

身長1.7m、23ボーン、69,413三角面、4つの独立メッシュオブジェクト（Body / Head / Hair / Eyelids）。GLB上では材質単位で8描画メッシュになる。カラー4K、非カラーPBRマップ2K。ファイルは約15.2MB。

髪はHeadボーンに追従する。頭部との隙間を覆う下地もHair内に保持。首の下端を襟内へ延長し、ジャケット切断縁には裏地を追加した。全身基準から生成された短い腕は、メッシュとバインド骨格を一緒に補正。袖と内部の腕に同じ手首ウェイト遷移を使い、手首の回転による肌の飛び出しを修正した。

表情は Smile / SpeechOpen / SpeechNarrow と、上下のまぶたが連続的に閉じる Blink / BlinkLeft / BlinkRight。初期値は全て0。口内の内張りと上歯を含む。全て0〜1で操作し、全眼のBlinkと片眼のBlinkは同時に加算しない。

## 動作と出典

22クリップ、30fps。既存本編GLBの必要な17クリップだけを読み込み、バインド姿勢・腕軸・脚長差を考慮して再ベイクした。元モデルの全クリップや未使用バッファは含めない。

| 区分 | クリップ | 出典 |
| --- | --- | --- |
| 既存CC0ライブラリ | Idle / Walk / DanceStep / DanceDisco / DanceVictory | Mesh2Motion / Quaternius。元データとCC0 1.0条件は [motion_library](../../../motion_library/README.md) |
| 既存Mixamo | Run | 本編のAdopted_Candidate_Mixamo_Run。CC0ではなく元のMixamo利用条件を引き継ぐ |
| 既存の専用動作 | Aim / AimShotgun / ReloadHandgun / ReloadShotgun / Hit / Evade / Kick / Climb / Vault / Struggle / BreakFree | 本リポジトリで制作したゲーム用動作 |
| v2の新規制作 | Greeting / Test_HeadTurn / Test_ArmRaise / Test_ElbowBend / Test_KneeBend | Blenderで手付け。各3秒 |

Idle・Walk・Runなどは接地高を補正。検査用に首振り±35°、腕上げ160°、肘・膝曲げを収録。Greetingは右手を上げて振る3秒の挨拶。動画と確認ページでは笑顔と瞬きを別途加える。GLBのGreeting自体はボーン動作で、表情カーブを含まない。

## 確認した範囲

Blenderで正面・側面・背面、表情、首・腕・肘・膝、待機・歩行・走行・挨拶をレンダリング。ChromeのThree.js表示でも表情と動作を確認した。

形式検査はエラー0。7件の警告は実行環境側の接線生成3件と、親を持つスキンメッシュ4件。170cm、分離パーツ、6つの有効な表情、ウェイトの正規化、全22クリップを5時点ずつ検査する。これらは全関節・全フレームの非貫通や自然さの保証ではない。

髪には生成由来の大きな束が残る。視線移動、指の個別把持、髪の物理揺れ、音素別の口形は含まない。v1より面数が多い。本編への切り替え、武器ソケットの調整、Flutterの負荷測定はこの比較モデルの制作には含めていない。

## 再現

リポジトリルートから:

~~~sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_fukuchan_v2.py
node tools/validate_fukuchan_v2.mjs
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/render_fukuchan_v2.py -- --movie
python3 -m http.server 8766 --bind 127.0.0.1
~~~

Blender 5.1.2、Node.js、既存の .local/vrm-validation/node_modules（three / gltf-validator）、ffmpegを使用。ビルド・検証・レンダリングはローカルのみで、Tripoへ生成を送信しない。

原FBXがない環境では、provenance.jsonの生成済みタスクIDを各フォルダの task.json に {"task_id":"..."} として保存し、body / rig_sourceは tools/tripo_generate.py download <config.json>、head / hairは tools/tripo_multiview.py download <config.json> で再取得する。新規submitは不要。既存本編の 04_GAME_ASSETS/3d/hazard_adopted/fukuchan.glb も必要。

採用入力PNG、設定、プロンプト、コード、GLB、軽量な記録をGit管理する。生FBX、署名URL、APIキー、候補入力、Blender編集ファイル、QA画像、挨拶動画はローカル保持。

## クレジット

開始685 → 体120 + 頭120 + 髪120 + リグ25 = **385消費** → **残300**。rig-checkは0。生成後のAPI照会で凍結0を確認。追加購入・追加有料生成は行っていない。
