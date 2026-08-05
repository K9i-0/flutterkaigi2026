# そば屋 Live2D リグ仕様

Cubism Editor 5.3.03で `cubism/sobaya_live2d_source.psd` を読み込んだ後の初版リグ仕様。
仮面・ジョッキ・手は柔らかく曲げず、剛体寄りの動きにする。

## パーツと描画順

背面から前面へ次の順序を維持する。

| Part | Draw order | Notes |
| --- | ---: | --- |
| `BodyPlate` | 100 | 胸、肩、腕、白Tシャツ |
| `HeadUnit` | 200 | 首、頭、耳、髪、仮面を一体で扱う |
| `EyeLidL` | 240 | 左眼窩を閉じる仮面色のシャッター |
| `EyeLidR` | 241 | 右眼窩を閉じる仮面色のシャッター |
| `MouthSlot` | 250 | 音量連動で縦へ広げる黒い口スロット |
| `MugHand` | 300 | 右手とビールジョッキを一体で扱う |

## デフォーマ階層

```text
Root
└─ BodySway (Warp Deformer)
   ├─ BodyPlate
   ├─ HeadPosition (Rotation Deformer)
   │  └─ HeadWarp (Warp Deformer)
   │     ├─ HeadUnit
   │     ├─ EyeLidL
   │     ├─ EyeLidR
   │     └─ MouthSlot
   └─ MugPosition (Rotation Deformer)
      └─ MugWarp (Warp Deformer)
         └─ MugHand
```

- `BodySway` は3×3分割で胸上全体を穏やかに動かす。
- `HeadWarp` は4×4分割。変形は首元から上だけに収める。
- `MugWarp` は3×3分割。ガラスを歪ませず、上下移動とごく小さい回転を主体にする。

## パラメータとキーフォーム

| ID | Min / Default / Max | Target | Keyform intent |
| --- | --- | --- | --- |
| `ParamAngleX` | -18 / 0 / 18 | `HeadPosition`, `HeadWarp` | 左右移動 ±16 px、仮面の横圧縮は最大2% |
| `ParamAngleY` | -12 / 0 / 12 | `HeadWarp` | 上下移動 ±10 px、首元を固定気味にする |
| `ParamAngleZ` | -10 / 0 / 10 | `HeadPosition` | 回転のみ |
| `ParamBodyAngleX` | -6 / 0 / 6 | `BodySway` | 肩を左右へ最大10 px |
| `ParamBreath` | 0 / 0 / 1 | `BodySway` | 胸郭を上へ最大4 px、横へ最大0.8% |
| `ParamMugBounce` | -1 / 0 / 1 | `MugPosition` | 上下 ±7 px、回転 ∓1.5° |
| `ParamEyeLOpen` | 0 / 1 / 1 | `EyeLidL` | 0で不透明度100%、0.5で35%、1で0% |
| `ParamEyeROpen` | 0 / 1 / 1 | `EyeLidR` | 0で不透明度100%、0.5で35%、1で0% |
| `ParamMouthOpenY` | 0 / 0 / 1 | `MouthSlot` | 中心固定で縦寸法を1.0倍から2.1倍へ拡大 |

眼窩そのものは `HeadUnit` に残し、閉眼時だけ仮面色のシャッターを前面表示する。
口は元の短いスロットを残し、発話時だけ `MouthSlot` を縦へ広げる。

## メッシュ

1. 6アートメッシュすべてに「自動生成・標準」を適用する。
2. `HeadUnit` は髪先と耳周辺に頂点を追加する。
3. `MugHand` はジョッキ外周、取っ手、指の隙間に頂点を追加する。
4. 透明余白へ大きくはみ出した三角形は削除する。

## 保存先

- 編集モデル: `cubism/sobaya_live2d.cmo3`
- 書き出し先: `cubism/runtime/`
- 推奨モデル名: `sobaya_live2d`
