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
