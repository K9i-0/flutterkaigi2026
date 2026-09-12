import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import Journal from "../src/official/journal";

describe("official initial HTML", () => {
  it.each(["sakaba", "excel", "underground"] as const)("renders %s without browser globals or the classic fallback", (theme) => {
    const html = renderToStaticMarkup(<Journal episodes={[]} galleryItems={[]} initialTheme={theme} initialHref="/" />);
    expect(html).toContain("j-header");
    expect(html).not.toContain("official-header");
    if (theme === "excel") expect(html).toContain("業務報告_最終_修正版.xlsx");
    if (theme === "underground") expect(html).toContain("地下売店");
  });
  it("renders the requested page on the server", () => {
    const html = renderToStaticMarkup(<Journal episodes={[]} galleryItems={[]} initialTheme="sakaba" initialHref="/gallery" />);
    expect(html).toContain("ギャラリー");
    expect(html).not.toContain("official-header");
  });
});

it("renders all comic chapters with reserved image dimensions and lazy loading", () => {
  const html = renderToStaticMarkup(<Journal episodes={[]} galleryItems={[]} initialTheme="sakaba" initialHref="/story?chapter=8" />);
  expect(html.match(/class="j-story-chapter"/g)).toHaveLength(15);
  expect(html).toContain('id="chapter-15"');
  expect(html).toContain('/site/comic/chapter-14.webp');
  expect(html).toContain('第14話 ゆめみ地下帝国 構想会議');
  expect(html).toContain('第15話 BONK');
  expect(html).toContain('width="538" height="720" loading="lazy"');
  expect(html).not.toContain('aria-label="次の話"');
});
