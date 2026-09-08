import * as Dialog from "@radix-ui/react-dialog";
import { Copy, Download, FileText, X } from "lucide-react";
import { lazy, Suspense, useEffect, useState } from "react";
import { toast } from "sonner";
import type { PublicInputAsset } from "@/lib/public-data";
import { inputAssetUrl, inputPreviewFormat, MAX_TEXT_PREVIEW_BYTES } from "@/lib/input-preview";

const DocumentContent = lazy(() => import("./document-content"));

type LoadState = { status: "loading" } | { status: "ready"; text: string } | { status: "error"; message: string };

function PreviewBody({ asset, format }: { asset: PublicInputAsset; format: "markdown" | "json" | "text" }) {
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [attempt, setAttempt] = useState(0);
  const [raw, setRaw] = useState(false);
  useEffect(() => {
    const controller = new AbortController();
    async function load() {
      try {
        const response = await fetch(inputAssetUrl(asset.url, "preview"), { signal: controller.signal });
        if (response.status === 413) throw new Error("この資料はサイズが大きいため、ダウンロードしてご覧ください。");
        if (!response.ok) throw new Error("資料を読み込めませんでした。もう一度お試しください。");
        const reader = response.body?.getReader();
        if (!reader) throw new Error("資料を読み込めませんでした。");
        const decoder = new TextDecoder("utf-8", { fatal: true });
        let text = "";
        let size = 0;
        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            size += value.byteLength;
            if (size > MAX_TEXT_PREVIEW_BYTES) throw new Error("この資料はサイズが大きいため、ダウンロードしてご覧ください。");
            text += decoder.decode(value, { stream: true });
          }
          text += decoder.decode();
        } finally {
          await reader.cancel();
          reader.releaseLock();
        }
        if (!controller.signal.aborted) setState({ status: "ready", text });
      } catch (error) {
        if (!controller.signal.aborted) setState({ status: "error", message: error instanceof TypeError
          ? "資料を表示できませんでした。通信状態を確認するか、ダウンロードしてご覧ください。"
          : error instanceof Error ? error.message : "資料を読み込めませんでした。" });
      }
    }
    void load();
    return () => controller.abort();
  }, [asset.url, attempt]);

  async function copy() {
    if (state.status !== "ready") return;
    try {
      await navigator.clipboard.writeText(state.text);
      toast.success("原文をコピーしました");
    } catch { toast.error("コピーできませんでした。原文を選択してコピーしてください。"); }
  }

  return <>
    <div className="document-preview-actions">
      {format === "markdown" ? <button type="button" aria-pressed={raw} onClick={() => setRaw(!raw)}>{raw ? "読みやすい表示" : "原文を見る"}</button> : null}
      <button type="button" disabled={state.status !== "ready"} onClick={() => void copy()}><Copy />原文をコピー</button>
      <a href={inputAssetUrl(asset.url, "download")} download={asset.filename}><Download />ダウンロード</a>
    </div>
    <div className="document-preview-body" tabIndex={0} aria-label="資料の内容" aria-busy={state.status === "loading"}>
      {state.status === "loading" ? <p role="status">資料を読み込んでいます…</p> : null}
      {state.status === "error" ? <div role="alert"><p>{state.message}</p><button type="button" onClick={() => { setState({ status: "loading" }); setAttempt(attempt + 1); }}>再読み込み</button></div> : null}
      {state.status === "ready" ? state.text.length
        ? <Suspense fallback={<p role="status">表示を準備しています…</p>}><DocumentContent text={state.text} format={raw ? "text" : format} /></Suspense>
        : <p>この資料には本文がありません。</p> : null}
    </div>
  </>;
}

export function DocumentPreview({ asset }: { asset: PublicInputAsset }) {
  const format = inputPreviewFormat(asset.filename, asset.content_type);
  if (!format) return <a className="episode-input-file" href={inputAssetUrl(asset.url, "download")} download={asset.filename}><Download /><span>ダウンロード</span></a>;
  return <Dialog.Root>
    <Dialog.Trigger className="episode-input-file" aria-label={`${asset.label}をプレビュー`}><FileText /><span>{format === "markdown" ? "台本・資料を読む" : format === "json" ? "設定を見る" : "資料を読む"}</span></Dialog.Trigger>
    <Dialog.Portal>
      <Dialog.Overlay className="document-preview-overlay" />
      <Dialog.Content className="document-preview-dialog">
        <header className="document-preview-header">
          <div><Dialog.Title>{asset.label}</Dialog.Title><Dialog.Description>{asset.filename}</Dialog.Description></div>
          <Dialog.Close className="document-preview-close" aria-label="プレビューを閉じる"><X /></Dialog.Close>
        </header>
        <PreviewBody asset={asset} format={format} />
      </Dialog.Content>
    </Dialog.Portal>
  </Dialog.Root>;
}
