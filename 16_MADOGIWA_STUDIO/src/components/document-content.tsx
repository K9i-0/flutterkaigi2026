import Markdown from "react-markdown";
import remarkGfm from "remark-gfm";

export default function DocumentContent({ text, format }: { text: string; format: "markdown" | "json" | "text" }) {
  if (format === "markdown") return <div className="document-markdown"><Markdown
    remarkPlugins={[remarkGfm]}
    skipHtml
    components={{
      a: ({ href, children }) => href && /^https?:\/\//i.test(href)
        ? <a href={href} target="_blank" rel="noreferrer">{children}</a>
        : <span>{children}</span>,
      img: ({ alt }) => <span>{alt ? `［画像: ${alt}］` : "［画像］"}</span>,
      table: ({ children }) => <div className="document-table-scroll"><table>{children}</table></div>,
    }}
  >{text}</Markdown></div>;
  let formatted = text;
  if (format === "json") {
    try { formatted = JSON.stringify(JSON.parse(text), null, 2); }
    catch { /* Keep malformed documents readable as their original text. */ }
  }
  return <pre className="document-code"><code>{formatted}</code></pre>;
}
