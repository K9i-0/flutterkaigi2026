# そば屋・福ちゃん VRM 1.0

ゲームの共通GLBから再生成するVRM 1.0対応版。既存の顔・体格・メッシュ・テクスチャ・初期姿勢・骨名を維持し、肩周辺のスキンウェイトを局所的に整えて、VRM Humanoidの役割を明示する。ゲーム用GLBは引き続き `04_GAME_ASSETS/3d/motion_library/` が正本。

| ファイル | 人型ボーン対応 | 表情 |
| --- | ---: | --- |
| `sobaya.vrm` | 41（必須15を含む） | なし。仮面・顔の変形は追加しない |
| `fukuchan.vrm` | 22（必須15を含む） | `aa` → SpeechOpen、`ou` → SpeechNarrow |

そば屋は既存の左右2節の指骨を対応付ける。福ちゃんは指骨なし。指・眼球・まばたき・揺れ物はVRM 1.0の任意機能で、今回新設していない。そば屋の小道具ソケットと裾骨は一般ノードとして保持し、人型ボーンへ誤登録しない。そば屋のChestはVRMのchest、福ちゃんのSpine1/Spine2はchest/upperChestへ対応する。

## モーションとの関係

骨の役割を解釈するVRM対応リターゲッタで利用する。骨名の変更や全ボーンの回転軸の統一、Tポーズへの再バインドは行っていない。任意のFBXを回転値のコピーだけで適用できるという意味ではない。公開ライブラリの歩行などを移植する際は初期姿勢と体格差を考慮する。

VRM 1.0ではglTFのanimationsは使用対象外のため、このVRMのJSONから削除する。既存143比較クリップとゲーム用クリップは元GLBに保持。修正版はBlenderで肩ウェイトを調整した中間GLBから出力する。VRMラッパーはその中間GLBのバイナリチャンクを保持する。manifestの `geometryAndSkinBinaryUnchanged` は中間GLBからVRMへの変換を指し、ゲーム版とウェイトが同一という意味ではない。`deformation.json` に変更頂点数と形状・バインド姿勢の検査値を記録。

## 再生成と検証

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/improve_vrm_deformation.py
npm install --prefix .local/vrm-validation three@0.185.1 @pixiv/three-vrm@3.5.5 gltf-validator@2.0.0-dev.3.10 ajv@8.20.0
git clone https://github.com/vrm-c/vrm-specification.git .local/vrm-specification
git -C .local/vrm-specification checkout 821c11b250d8c70d5804ee13431e42bee56ea9c0
mkdir -p .local/vrm-spec
for schema in glTFProperty glTFid extension extras; do
  curl -fsSL "https://raw.githubusercontent.com/KhronosGroup/glTF/main/specification/2.0/schema/$schema.schema.json" -o ".local/vrm-spec/$schema.schema.json"
done
node tools/validate_humanoid_vrm.mjs
```

`validation.json`：公式VRM JSON Schema、必須15ボーン、一意性、親子関係、祖先を含む正のscale、glTF Validator（エラー0）、Three-VRMの読み込みと標準head駆動、福ちゃんのaa表情適用を検証する。Node検査ではテクスチャを代替し、画像の実表示はブラウザで別途確認済み。

glTF Validatorの警告は、実行時生成の接線と、恒等変換の親の下にあるスキンメッシュ。前者はVRM 1.0で許容される。Three-VRMのブラウザ表示でテクスチャ・外観・腕駆動・口パクを確認し、コンソールエラー0。すべてのVRMアプリへの互換性を保証する検証ではない。

ブラウザで再確認する場合、上記npm依存を用意し、リポジトリルートから `python3 -m http.server 8766 --bind 127.0.0.1` を起動して `http://127.0.0.1:8766/tools/preview_humanoid_vrm.html` を開く。外部サーバーへのモデル送信なし。

## メタデータ

作者は窓際族物語、VRM Public License 1.0、アバター使用は作者のみ・再配布不可・改変可として出力。公開ライブラリのCC0ライセンスをキャラクターモデル自体へ転用していない。第三者向けに公開する際は権利者の指定に合わせてメタデータを設定する。

仕様：[VRM 1.0](https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_vrm-1.0/README.md)、[Humanoid](https://github.com/vrm-c/vrm-specification/blob/master/specification/VRMC_vrm-1.0/humanoid.md)。

## ダンスの変形改善

肩のウェイトをUV境界の重複頂点も考慮して3回平滑化する。顔・体格・頂点位置・面・表情のシェイプキー・関節の初期位置は変更しない。VRMA側のねじれ補正と併用する。再生成時に未修正版も `.local/dance_deformation/baseline/characters/` に用意する。ゲーム共通GLBは変更しない。検証方法と比較結果は [DEFORMATION_REVIEW.md](../DEFORMATION_REVIEW.md) を参照。
