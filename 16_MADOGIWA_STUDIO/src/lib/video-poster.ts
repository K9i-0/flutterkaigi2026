function waitForVideoEvent(video: HTMLVideoElement, eventName: "loadedmetadata" | "loadeddata" | "seeked"): Promise<void> {
  return new Promise((resolve, reject) => {
    const timeout = window.setTimeout(() => finish(new Error("動画の読み込みがタイムアウトしました")), 15_000);
    const onSuccess = () => finish();
    const onError = () => finish(new Error("動画をブラウザで読み込めませんでした"));

    function finish(error?: Error) {
      window.clearTimeout(timeout);
      video.removeEventListener(eventName, onSuccess);
      video.removeEventListener("error", onError);
      if (error) reject(error);
      else resolve();
    }

    video.addEventListener(eventName, onSuccess, { once: true });
    video.addEventListener("error", onError, { once: true });
  });
}

function canvasToJpeg(canvas: HTMLCanvasElement): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob);
      else reject(new Error("サムネイル画像を作成できませんでした"));
    }, "image/jpeg", 0.86);
  });
}

export async function createVideoPoster(file: File): Promise<File> {
  const sourceUrl = URL.createObjectURL(file);
  const video = document.createElement("video");
  video.preload = "auto";
  video.muted = true;
  video.playsInline = true;

  try {
    video.src = sourceUrl;
    video.load();
    await waitForVideoEvent(video, "loadedmetadata");
    if (video.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) await waitForVideoEvent(video, "loadeddata");

    if (Number.isFinite(video.duration) && video.duration > 0.1) {
      video.currentTime = Math.min(0.5, Math.max(0.05, video.duration / 4));
      await waitForVideoEvent(video, "seeked");
    }

    if (!video.videoWidth || !video.videoHeight) throw new Error("動画の画面サイズを取得できませんでした");
    const scale = Math.min(1, 1280 / Math.max(video.videoWidth, video.videoHeight));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(video.videoWidth * scale));
    canvas.height = Math.max(1, Math.round(video.videoHeight * scale));
    const context = canvas.getContext("2d");
    if (!context) throw new Error("サムネイル描画を開始できませんでした");
    context.drawImage(video, 0, 0, canvas.width, canvas.height);

    const blob = await canvasToJpeg(canvas);
    const baseName = file.name.replace(/\.[^.]+$/, "") || "video";
    return new File([blob], `${baseName}-poster.jpg`, { type: "image/jpeg" });
  } finally {
    video.removeAttribute("src");
    video.load();
    URL.revokeObjectURL(sourceUrl);
  }
}
