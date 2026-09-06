# そば屋ハザード：音楽・戦闘音

## 作曲

オリジナル曲「閉店後」（探索、80 BPM・16小節）と「ラストオーダー・追い込み」（追跡、160 BPM・32小節）。4/4、各48秒、D Phrygian。共通のD/E♭/Aを中心に構成し、任意の位置でクロスフェードしても機能和声の進行が衝突しない設計。2曲の再生時計は独立し、拍同期は要求しない。

探索はフェルトピアノを模した減衰弦、擦弦の倍音、空気音と低い持続音。追跡は左右に分けた弦の速い刻み、3+3+2の低い太鼓、金管の不協和音、工場の打音、ジョッキを連想させるガラス音。8小節ごとに密度を変え、息継ぎと追い込みを作る。サンプルや既存ゲームの音源を使わず、NumPy/SciPyのDSPで楽器を合成。生演奏・録音オーケストラではない。音符・音色・定位・ミックスは `tools/build_hazard_score.py` と `score-manifest.json` に保存。

44.1kHz、ステレオPCM16。探索 -24 LUFS、追跡 -19 LUFS、静的ゲインで調整。各音の減衰・残響をループ先頭へ回し、端点フェードによる周期的な音量低下を避ける。探索の採用音源は今回変更していない。

### 発見と音量の制御（2026-09-07）

追跡曲は時定数0.28秒で立ち上げ、脅威が途切れても3.5秒保持してから2.4秒の時定数で探索へ戻す。ループは裏で走らせ、切り替えで曲頭へ戻さない。新しい遭遇だけ短い警告音を鳴らし、10秒の間隔・追跡強度が下がるまでの再発音制限で乱打を防ぐ。

台詞中は背景を26%へ下げる。新しく発生するそば屋のうめき声は28%、他の効果音は65%へ下げて台詞を優先しつつ攻撃予告を残す。足音の基準ゲインは0.34。ロケット発射／着弾時は距離に応じてBGMを最大42%下げ、0.1秒保持＋0.32秒の時定数で復帰。設定の各音量は引き続き個別に適用する。

### ロケットランチュア

発射1.8秒、爆発2.8秒、各3バリエーション。発射は点火、低い圧力音、中低域の胴鳴り、噴射、タービン、機構音、反射音。爆発は破裂、衝撃波、低中域の噴出、空気・破片、低い残響を重ねる。44.1kHzモノPCM16。遠近はランタイムで計算し、爆発だけ基準距離10m／可聴範囲45m、壁越し55%とする（通常音は4m／24m、35%）。

`tools/build_hazard_rocket_audio.py` と `rocket-audio-manifest.json` に再生成条件を保存。真のピークを-4.5 dBTP以下へ静的調整し、至近距離の発射・着弾の重なりに余裕を確保する。LUFS目標よりピーク上限を優先し、実測値は `qa/audio-polish-assets-20260907.json` に記録。旧ルートWAV名は採用バリエーション0への相対symlinkとして保持する。

## 戦闘効果音

発射音は破裂音、低い圧力音、機構音、短い残響の4層。ハンドガンとショットガンの低音・減衰を分ける。各3種類を順番に切り替える。ジョッキは構えのガラス/衣擦れ、振り抜く空気音、命中時の鈍い打撃を分離し、各3種類。ガラスが割れる音や流血音は入れない。振り抜き音は命中判定の0.12秒前、打撃音は実際の命中時だけ鳴らす。射撃で構えが中断された場合は後続の振り抜き/打撃も発生しない。

## そば屋のビール声

正典参照 `02_CHARACTERS/Sobaya_voice.wav`、SHA-256 `976916e670fea5fcf0f741d45e150eaf055c3b0e11d240e3be656dd724166b58`、Irodori `Aratako/Irodori-TTS-v4.1-Small`、seed42、エンジン `8224dafb46d0aba89209a8f905f1cb7e3299d9c1`。生成後に正典の -5半音/70Hz tremolo処理を適用。聞き取りやすい2テイクから、遅い遠距離声も派生させた計3バリエーション。採用前の候補と未処理音声は `.local/hazard-score/grunts/` のみ。

### combat/enemy_0.wav

- 台詞: ビール！
- Caption: 相手に迫りながら、低く荒い声で短く叫ぶ。
- seed: 42
- 実測尺: 1.354875 秒
- SHA-256: `837fa4a6a0c3f03bcf06c8ba6be5fbe7653876bbbfaaf8c678773704c4f06f05`
- 加工: canonical -5 semitones/70Hz tremolo; HP65 LP6500; 43/89ms room; -20 LUFS / -3 dBTP
- 派生: combat/enemy_2.wav / tempo 0.78 without pitch shift, lowpass 4800Hz, -21 LUFS; two canonical takes yield three gameplay variants

### combat/enemy_1.wav

- 台詞: ビール、ビール。
- Caption: 息を切らし、ビールを求める低い声。二回のビールを、それぞれはっきり発音する。
- seed: 42
- 実測尺: 2.525750 秒
- SHA-256: `7b8d18090d4c2fd5081762b431afe590e5393d2e9057c911fcf77255da2edf10`
- 加工: canonical -5 semitones/70Hz tremolo; HP65 LP6500; 43/89ms room; -20 LUFS / -3 dBTP

### combat/enemy_2.wav

- 台詞: ビール！
- Caption: 相手に迫りながら、低く荒い声で短く叫ぶ。
- seed: 42
- 実測尺: 1.075042 秒
- SHA-256: `14b499afa551e742204bf8063fa9a485427c6959e59461b5997b5a942daef563`
- 加工: canonical -5 semitones/70Hz tremolo; HP65 LP6500; 43/89ms room; -20 LUFS / -3 dBTP

## 再生成

リポジトリ直下、NumPy/SciPyを利用できるPython環境で実行する。Irodoriは既存の正典ラッパーとローカル環境を使用する。

```sh
python tools/build_hazard_soundscape.py
python tools/build_hazard_score.py
python tools/build_hazard_rocket_audio.py
python tools/build_hazard_sobaya_grunts.py
python tools/audit_hazard_score.py
python tools/audit_hazard_audio.py
```

追跡だけ改訂するときは `python tools/build_hazard_score.py --pursuit-only`。探索と銃声などの採用WAVを保持し、追跡の譜面・マニフェストだけ更新する。新しい検査記録の出力先は `python tools/audit_hazard_score.py --output 21_SOBAYA_HAZARD_LAB/qa/audio-polish-assets-20260907.json` で指定できる。

ゲームから `assets/audio/combat` と `assets/audio/soundscape` の相対symlinkで参照。音声の本人らしさや音楽の好みは自動検査で承認しない。ローカルASRは3バリエーションの「ビール」を照合する補助検査。
