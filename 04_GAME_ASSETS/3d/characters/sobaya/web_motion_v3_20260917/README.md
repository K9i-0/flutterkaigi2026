# 公式サイト用そば屋：ジョッキ・モーション版

入力は `../motion_v3_20260917/sobaya_motion.glb`。`node build.mjs` でテクスチャだけを可逆WebPへ変換する。全画素一致と形状・スキン・モーションのバッファ維持を検証し、約20MBにする。104クリップを保持。

公式サイトの3DとARが同じモデルを参照する。ジョッキは `props/beer_mug_v2/beer_mug.glb` を別ロードし、`Grip` を `PropSocket.R` へ合わせる。ONでは右手のMugGripを1、OFFでは0にする。ジョッキの形状は正典を使い、サイトとUSDZではガラスの透過をalpha、ビールを琥珀色で近似する。

ARの通常ポーズは `CharacterSheet_MugStand`、挨拶は `Greeting` の0.8秒。表示中の手・モーフ・ジョッキをワールド座標で固定してUSDZへ含める。高さはジョッキ追加前の身体を基準にする。ON/OFF・ポーズ・サイズ変更時は生成済みUSDZを破棄する。
