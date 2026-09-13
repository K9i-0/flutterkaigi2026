# そば屋ハザード採用モデル

2026-09-13にユーザー指定で、そば屋・福ちゃんの両方をTripo v2へ切り替えた。本編用の派生正本は `v2_20260913/`。ゲームの `assets/models/` から相対symlinkで参照する。現在のファイルパス・ハッシュ・動作は `manifest.json` を正本とする。

直下の `sobaya.glb` / `fukuchan.glb` はv1の動作入力として保持し、ゲームから直接参照しない。v1の台帳は `v1_manifest.json`。新しい派生モデルを元入力へ上書きしない。

## v2の採用

- そば屋：承認済み参照Cから制作した、髪と仮面が一体の頭部。目と口の浅い黒い裏面も保持。
- 福ちゃん：承認済みの体・頭・髪・まぶた。発話・笑顔・瞬きの表情を保持。
- v1とv2の全クリップIDを保持し、v2に不足していたゲーム用動作はバインド姿勢と脚長を考慮してリターゲット。
- そば屋は `PropSocket.R`、福ちゃんは `GunSocket` を追加し、全クリップで手に追従するようベイク。
- 歩行・走行の足の後退速度を新しい体格で再計測し、ゲームのモーション再生速度を更新。

福ちゃんv2にはWeb確認後の53ボーンと指の把持を採用。そば屋v2には指の個別リグがないため、そば屋用のv1指姿勢オーバーライドは対応ボーンがあるモデルだけに適用する。小道具の接続点の追従と、指で自然に握れているかは別に評価する。v1の指・裾の細かい調整をすべて移植したものではない。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_hazard_v2_models.py
node tools/validate_hazard_adopted.mjs
```

ビルダーは有料APIを呼ばず、派生GLB・manifest・相対symlink・計測済みの歩走速度を更新する。`validation.json` は実際にゲームが参照するv2を検査する。起動・描画の今回の記録は `v2_20260913/runtime_review.json` に保持する。

## v1の履歴

以下はv1の採用内容。`build_hazard_adopted_motion.py` はv2採用中の上書きを防ぐため停止する。

- 福ちゃん：公開ライブラリの待機・歩行、既存Mixamo Run。
- そば屋：公開ライブラリの歩行、Jogを調整した逃走・追跡版。ジョッキ握りは本編の指姿勢オーバーライドを併用。
- ダンス3種：確認済みのねじれ補正版をDanceStep / DanceDisco / DanceVictoryへ割り当て。
- 回避、射撃、ジョッキ保持・3攻撃、掴み、窓越え、梯子など既存のゲーム専用動作は保持。
- 両モデルの肩ウェイトを局所平滑化。形状や顔を作り替えない。

`manifest.json` に入力ハッシュ・採用クリップ・足の低い区間の後退速度から測った再生速度基準を記録する。ゲーム内の移動速度自体は変更せず、衝突解決後の移動距離に合わせて再生速度を調整する。

```sh
# 先にVRMモデル・モーション・走り候補の各ビルダーを実行
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_hazard_adopted_motion.py
node tools/validate_hazard_adopted.mjs
```

`validation.json` はglTFエラー0、元ゲームの全クリップID保持、確認用ベイクとの骨位置・回転の比較。描画とジョッキ追従はFlutter本編で別途確認する。素材条件は元ライブラリを引き継ぎ、既存Mixamo動作をCC0とは扱わない。
