# 第2話 椅子の表記修正

2026-09-13。内蔵Imagegenで原作画像を編集。「アーロンチェア」を作品固有の「アーロンチュア」へ修正。
正本: episode_02.png。公式サイト用: ../../16_MADOGIWA_STUDIO/public/site/comic/episode-02-chua.webp。
変更前の画像はGit履歴に保持。

## 使用プロンプト
Use case: text-localization. Edit the provided original manga episode image with a single extremely localized correction. On the cardboard chair front between the seated masked man's legs, the handwritten black Japanese currently says アーロン on first line and チェア on second line. Change ONLY the small ェ in チェア to small ュ so the inscription reads exactly アーロンチュア, arranged first line アーロン, second line チュア. This intentionally misspelled fictional chair name must NOT be corrected to アーロンチェア. Preserve the original rough handwritten black marker style, size, placement, perspective and cardboard texture. Preserve the entire original square image: identical man face mask body hands pose beer mug, cardboard chair shape, desk, 窓際族 sign, windows, background people, lighting, color, composition and bottom-right white sparkle. No new objects, no reframing, no aesthetic enhancement. Return the complete square image with only this tiny lettering fix.

## 再修正
内蔵Imagegenで「チュア」を幅広く描き直し、小さい「ュ」の縦線を右端へ明確化。配信用は episode-02-chua-v2.webp。

Prompt: Rewrite ONLY the lower word as チュア in highly legible black handwritten BLOCK katakana, slightly wider and larger. Draw ュ as unmistakable small ユ with a long horizontal top, vertical downstroke at the far right end, and horizontal baseline extending left. No central vertical stroke. Preserve all other content and square framing.
