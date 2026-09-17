# 福ちゃんv3の公式サイト配信版

元: `../rig_v3_20260917/fukuchan.glb`。首補修・腰ひねりまでの承認済み版。
`node build.mjs` でテクスチャだけを可逆WebPに再符号化し、EXT_texture_webpを付与する。全画素一致を検証。形状・スキン・モーションのバイナリはそのまま保持。全20クリップ・54骨。

Sharpは16_MADOGIWA_STUDIOのインストール済み依存から使用。出力GLBはローカル保持、公式サイトpublicから相対symlinkで参照する。24,183,360 bytes。SHAはvalidation.json。

サイトの39テスト、型・lint・build・startup・deploy dry-run通過。Chromeの公式サイト3DビューでWebP復号とギュンギュン表示を確認。
