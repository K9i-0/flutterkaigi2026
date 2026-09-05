# 共通小道具 · ビールジョッキ

`beer_mug.glb`をゲーム用正本とする。Blenderの手続き生成モデルで、そば屋以外にも再利用可能。

- ガラスの胴・底・縁、D字の持ち手、琥珀色のビール、泡と小さな泡粒。
- 約21cm高、3,120三角面、3材質。画像テクスチャ不要。
- ガラスのみalpha blend。ビール・泡はopaque、背面カリングあり。物理的な屈折や液体シミュレーションは使用しない。
- 原点は底面中央。`Grip`は持ち手の握り位置。glTF座標で`(0.155, 0.117, 0)`m。
- スキニングやアニメーションを小道具自体には持たせず、手のソケットへ親子付けする。

Flutter Sceneではモデル原点の変換を含むため、`inverse(grip.globalTransform) * mugRoot.globalTransform`をジョッキルートのlocalTransformに設定してから、手のソケットへaddする。そば屋リグのソケットはBlenderのボーン座標系なので、その左にglTFでは+90° X回転（Flutter SceneではZ反転を考慮して-90° X回転）を掛ける。取り付け後に手・ソケットの回転へ追従する。実装例: `21_SOBAYA_HAZARD_LAB/lib/lab/rig_actor.dart`。

再生成（リポジトリルート）:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_beer_mug.py
```

`.blend`はローカル生成物。寸法や色の調整はスクリプトへ反映して再生成する。ゲーム側へコピーせず、正本GLBへの相対symlinkで参照する。
