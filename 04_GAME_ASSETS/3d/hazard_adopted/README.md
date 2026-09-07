# そば屋ハザード採用モデル

確認ページで採用したVRMモーションと肩ウェイト改善を、本編用GLBへ組み込んだ派生正本。ゲームから相対symlinkで参照する。元の比較ライブラリとVRMの再生成入力は変更しない。

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
