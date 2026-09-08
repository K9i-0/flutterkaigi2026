import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import DocumentContent from "../src/components/document-content";

describe("document preview rendering", () => {
  it("renders Japanese headings, lists and tables without executing embedded content", () => {
    const text = '# 採用台本\n\n- 日本語のセリフ\n\n| 人物 | 台詞 |\n| --- | --- |\n| そば屋 | 冷えてる。 |\n\n<script>alert(1)</script>\n\n[危険](javascript:alert%281%29)\n\n![外部画像](https://example.com/tracker.png)\n\n[資料](https://example.com/reference)';
    const html = renderToStaticMarkup(<DocumentContent text={text} format="markdown" />);
    expect(html).toContain("<h1>採用台本</h1>");
    expect(html).toContain("<li>日本語のセリフ</li>");
    expect(html).toContain("<table>");
    expect(html).toContain("冷えてる。");
    expect(html).not.toContain("<script");
    expect(html).not.toContain("javascript:");
    expect(html).not.toContain("<img");
    expect(html).toContain('href="https://example.com/reference"');
  });

  it("formats JSON and keeps invalid JSON readable with markup escaped", () => {
    expect(renderToStaticMarkup(<DocumentContent text={'{"台詞":"冷えてる。"}'} format="json" />)).toContain('\n  &quot;台詞&quot;: &quot;冷えてる。&quot;\n');
    const html = renderToStaticMarkup(<DocumentContent text={'{broken: "<script>"}'} format="json" />);
    expect(html).toContain("&lt;script&gt;");
    expect(html).not.toContain("<script>");
  });
});
