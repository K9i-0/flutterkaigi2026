# そば屋 · ゲーム用リグ v1

Tripo P2.0の採用済みモデルをBlenderでスキニングし、手続き的にアニメーションを付けた派生GLB。原型・UV・4K PBR画像を維持する。今回の骨格・モーション制作では外部生成API／Tripoクレジットを使用していない。

- 正本: `sobaya_rig.glb`。1.8m、21,066三角面、1材質。
- 41ボーン（変形39、Rootと小道具用PropSocket.R）、頂点あたり最大4ウェイト。
- 頭・仮面は剛体として保持。胴体のウェイトを補正し、腕・脚・指をスキニング。
- 移動はin-place。地面上の位置・向き・衝突はゲーム側で制御する。
- glTFはY-up。Blenderで編集するとZ-up／-Yが正面になる。
- 右手の`PropSocket.R`に[共通ビールジョッキ](../../../props/beer_mug/README.md)の`Grip`を合わせる。ソケットのボーン座標から小道具への補正はglTFで+90° X回転（Flutter Sceneでは-90° X）。

| クリップ | 秒 | ループ | 内容 |
| --- | ---: | --- | --- |
| Idle | 2.4 | ○ | 呼吸・待機 |
| Walk | 1.0 | ○ | 通常歩行 |
| Run | 0.7 | ○ | 腕振り・脚上げを強くした走行 |
| ZombieWalk | 1.8 | ○ | 腕を前に出す、左右非対称の歩行 |
| DanceStep | 2.0 | ○ | 左右のステップ |
| DanceDisco | 2.4 | ○ | 片手を上げるディスコ風 |
| DanceVictory | 2.0 | ○ | 両腕を上げる勝利エモート |
| Toast | 2.6 | — | ジョッキを持ち上げて乾杯、戻す |
| MugAttack | 1.4 | — | 振りかぶり→前方へ振り下ろし→戻す |

30fpsでベイク。Toast/MugAttackは右手の指を曲げた握りを含む。攻撃の接触目安はクリップの55%（約0.77秒）で、ダメージ・当たり判定・命中音は本編側の実装事項。

再生成（リポジトリルート）:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_sobaya_rig.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/review_sobaya_motion.py
python3 tools/validate_sobaya_rig.py
```

編集用`.blend`はローカル生成物として保持し、Gitではスクリプト・GLB・仕様を管理する。Blender 5.1.2で生成。形状・テクスチャ原型は`../tripo_p2_20260905/`。ゲームからは相対symlinkで参照する。

これはゲーム検証向けの初版。生成元のAポーズ形状を変形するため、肩を上げたときに袖が伸びる。衣服シミュレーション、接地IKのランタイム補正、他キャラクターへの自動リターゲットは含まない。走行時の裾と腿の干渉を含め、キャラクター固有の肩・指の仕上げは本編のカメラ距離に合わせて追加調整できる。
