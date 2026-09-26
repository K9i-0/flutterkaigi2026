# Tidewater沿岸環境音（採用正本）

Tidewater `4811ba48d795197de5621985f404e765c0b7c0ef` の採用済み実録音から変換。元の音源クレジット・CC0表記は [CREDITS-Tidewater.md](CREDITS-Tidewater.md)。各音源のFreesoundリンクと作者名を保持する。

- 遠い波音、沿岸の風、桟橋の水音: 元のクロスフェード済みループ全長。
- 砕ける波、寄せ波、引き波、カモメ、森の鳥、砂・濡れ砂・木・草・岩の足音: soundBank.jsの区間で独立したWAVへ切り出し。冒頭15ms・末尾40msのフェード追加。
- PCM 16bit・mono・32kHz。Appleネイティブ再生でもOgg/Opusのデコーダーを必要としない。
- `bank.json`: 元素材SHA256、切出し区間、元のLUFS、固定リビジョン。採用WAVのみGit管理。原OggはTidewaterの固定版から再取得できる。
- アプリから `23_SOBAYA_TIDEWATER/assets/audio` の相対symlinkで参照。

再生成（ffmpeg必須）:

```sh
cd 23_SOBAYA_TIDEWATER
node tools/export_tidewater_audio.mjs /path/to/pinned/tidewater
```

環境音の実装コードは新規Dart実装。原作のWeb Audio HRTF・クジラ・船・釣り・時刻別生態系の完全移植ではない。
