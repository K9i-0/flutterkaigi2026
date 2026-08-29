# そば屋→たこさん→福ちゃん 擬態連結

## 目的

2本のWan 3.0擬態動画をRemotionで編集し、1体が連続して「そば屋→たこさん→福ちゃん」の順に変化する映像へまとめる。

## 入力

1. `../56_takosan_sobaya_mimic_test/wan3_takosan_sobaya_normal_mimic_twist_v2_seed560828_480p.mp4`
   - 元の順序: たこさん→そば屋
   - 映像と音声を事前に逆再生し、そば屋→たこさんとして使用
2. `../57_takosan_fukuchan_liveaction_mimic_test/wan3_takosan_fukuchan_liveaction_mimic_seed570828_480p.mp4`
   - 元の順序どおり、たこさん→福ちゃんとして使用

両入力は832×480、30fps、約8.034秒、H.264 + AAC 44.1kHz stereo。

## 編集仕様

- composition ID: `SobayaTakosanFukuchanChain`
- 832×480、30fps、446フレーム（14.867秒）
- そば屋側の逆再生クリップは末尾15フレームを省き、226フレーム使用
- 福ちゃん側は冒頭15フレームを省き、226フレーム使用
- 接続区間: 220〜225フレームの6フレーム（0.2秒）
- 接続方法: 同じ小型たこさん構図同士の映像・音声クロスフェード
- 字幕、ロゴ、追加BGMなし。各Wan動画の環境音・変形音を使用
- タイミングの正本: `remotion/src/edit-manifest.json`

## 再現手順

```bash
cd 03_SCRIPTS/58_sobaya_takosan_fukuchan_mimic_chain/remotion
npm run prepare:media
npm run validate
npm run typecheck
npm run render
```

## 出力

- `final_remotion_mimic_chain.mp4`
- ステータス: レンダー・監査完了

## 素材復元記録

- Remotion用hardlinkへ前処理出力を重ねた際、エピソード57の福ちゃん元動画と同じinodeへ干渉したため、既存Qwen task ID `c86118c0-ef93-4c07-817a-a2261c335ab2`の出力から追加課金なしで即時復元した。
- 復元後SHA-256: `6c97c75fd664593ac761ebf563911542d247be77b9d565fabd757c8dc716ac2a`（初回生成時と一致）
- 以後の`public/input_fukuchan.mp4`は別inodeの作業用コピーとし、元動画を上書きしない。

## 最終監査

- 出力SHA-256: `2a225c6fca2fb68efd1a2baa94aa77ac626e1ad0254e910e6e01395457b4fccd`
- 映像: H.264、832×480、30fps、446フレーム
- 音声: AAC、48kHz、stereo
- コンテナ尺: 14.912秒（映像446フレームは14.867秒。末尾差はAACパケット長）
- ファイルサイズ: 3,348,888 bytes
- 冒頭: 通常シートの完成そば屋を全身で保持
- 前半: 色変化と形状変化が逆向きに進み、小型の標準たこさんへ戻る
- 接続: 7.33秒付近。6フレームのクロスディゾルブ中も、たこさんの濃度、輪郭、位置、体格を維持。二重像、背景への消失、ハードカットなし
- 後半: 小型たこさんが成長・変形し、福ちゃん型の中間形を経て実写福ちゃんになる
- 完成: 正典の顔・髪・細身体格を維持した実写福ちゃんを全身で保持
- 音声: そば屋側は映像と同時に逆再生。接続区間は同じ6フレームで相互フェードし、二重音量を抑制
- 全尺デコード: エラーなし
- 総合判定: **合格**。指定順「そば屋→たこさん→福ちゃん」が1本の連続擬態として成立

## 監視カメラ版

### 演出仕様

- composition ID: `TakosanSurveillanceReveal`
- 入力: `final_remotion_mimic_chain.mp4`を`public/surveillance_source.mp4`へ作業コピー
- 出力: `final_remotion_surveillance_reveal.mp4`
- 固定記録日時: `2026-08-28 02:17:43 JST`からフレーム進行に合わせて加算
- カメラ表示: `CAM 03` / `SERVER ROOM B-17` / `REC` / `ARCHIVE // MOTION REC`
- 映像処理: 低彩度の緑灰色、コントラスト強調、走査線、粒状ノイズ、周辺減光、微小スケール拡大
- 通常追跡: 人物の体格変化へ追従する淡緑色の`MOTION TRACK`枠
- 異常検知: 174〜275フレーム。赤色の`形態異常を検出 / IDENTITY SHIFT`枠と2回の短い警告ビープ
- 瞬間グリッチ: 197、198、218〜221フレーム。人物を隠さない範囲の微小な水平ノイズと位置ずれ
- 生体照合: 366〜445フレーム。赤色の`生体照合：福ちゃん / MATCH CONFIRMED`表示
- 音声: 元の変形音を82%で維持し、48kHzの低い監視機器ノイズと短い電子ビープを追加
- タイミングの正本: `remotion/src/surveillance-manifest.json`

### 監査結果

- 出力SHA-256: `e4917b807317bcbee22952b9e8590bdd5bd25497b08adb5f12f3f34c3f33906d`
- 映像: H.264、832×480、30fps、446フレーム
- 音声: AAC、48kHz、stereo、平均`-27.7 dB`、最大`-2.3 dB`
- コンテナ尺: 14.912秒、2,789,984 bytes
- セーフエリア: REC、カメラ番号、日時、アーカイブ表示、警告表示は上下左右5%以上の安全域内。人物の顔を覆わない
- 境界監査: 異常検知は173→174フレーム、生体照合は365→366フレームで仕様どおり切替
- 変身監査: そば屋→たこさん→福ちゃんの順序、接続点、人物同一性を維持。走査線・ノイズ・グリッチによる重要動作の隠蔽なし
- 全尺デコード: エラーなし
- 総合判定: **合格**。監視カメラがたこさんの擬態と最終正体を偶然記録した「流出衝撃映像」として成立
