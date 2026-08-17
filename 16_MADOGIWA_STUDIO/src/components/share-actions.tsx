import { Check, Link2, Share2 } from "lucide-react";
import { useState } from "react";
import { absoluteUrl } from "@/lib/public-data";

export function ShareActions({ title, text, path }: { title: string; text: string; path: string }) {
  const [copied, setCopied] = useState(false);

  function shareUrl(): string {
    return new URL(path, window.location.origin).toString();
  }

  async function share() {
    const url = shareUrl();
    if (navigator.share) {
      await navigator.share({ title, text, url });
      return;
    }
    await navigator.clipboard.writeText(url);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1600);
  }

  async function copy() {
    await navigator.clipboard.writeText(shareUrl());
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1600);
  }

  const canonicalUrl = absoluteUrl(path);
  const xUrl = `https://twitter.com/intent/tweet?${new URLSearchParams({ text: `${title}｜窓際族物語`, url: canonicalUrl }).toString()}`;
  const lineUrl = `https://social-plugins.line.me/lineit/share?${new URLSearchParams({ url: canonicalUrl }).toString()}`;

  return <div className="share-actions" aria-label="作品を共有">
    <button type="button" onClick={() => void share()}><Share2 />共有</button>
    <a href={xUrl} target="_blank" rel="noreferrer">X</a>
    <a href={lineUrl} target="_blank" rel="noreferrer">LINE</a>
    <button type="button" onClick={() => void copy()}>{copied ? <Check /> : <Link2 />}{copied ? "コピー済み" : "リンクコピー"}</button>
  </div>;
}
