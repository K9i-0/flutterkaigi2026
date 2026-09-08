export const MAX_TEXT_PREVIEW_BYTES = 1024 * 1024;

export function inputPreviewFormat(filename: string, contentType: string): "markdown" | "json" | "text" | null {
  const extension = filename.split(".").pop()?.toLowerCase();
  const mime = contentType.split(";")[0].trim().toLowerCase();
  if (extension === "md" || extension === "markdown" || mime === "text/markdown") return "markdown";
  if (extension === "json" || mime === "application/json") return "json";
  if (extension === "txt" || mime === "text/plain") return "text";
  return null;
}

export function inputAssetUrl(url: string, mode: "preview" | "download"): string {
  return `${url}${url.includes("?") ? "&" : "?"}${mode}=1`;
}
