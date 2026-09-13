import { useEffect } from "react";

// Embedded iOS browsers can resize their visible area independently of dvh.
// Keep controls inside that area and make every surface behind it opaque.
export function useMediaViewport(open: boolean) {
  useEffect(() => {
    if (!open) return;
    const root = document.documentElement;
    const viewport = window.visualViewport;
    const mobile = window.matchMedia("(max-width: 760px), (max-height: 500px) and (pointer: coarse)");
    const themeColor = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]');
    const originalColor = themeColor?.getAttribute("content");
    let frame = 0;
    const update = () => {
      root.classList.toggle("media-viewer-open", mobile.matches);
      if (!mobile.matches) {
        if (originalColor != null) themeColor?.setAttribute("content", originalColor);
        return;
      }
      themeColor?.setAttribute("content", "#000000");
      // Let native pinch zoom work without resizing the content underneath it.
      if (viewport && Math.abs(viewport.scale - 1) > 0.01) return;
      const height = viewport?.height ?? window.innerHeight;
      const width = viewport?.width ?? window.innerWidth;
      if (height <= 0 || width <= 0) return;
      root.style.setProperty("--media-viewport-height", `${height}px`);
      root.style.setProperty("--media-viewport-width", `${width}px`);
      root.style.setProperty("--media-viewport-top", `${viewport?.offsetTop ?? 0}px`);
      root.style.setProperty("--media-viewport-left", `${viewport?.offsetLeft ?? 0}px`);
    };
    const schedule = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(update);
    };
    update();
    viewport?.addEventListener("resize", schedule);
    viewport?.addEventListener("scroll", schedule);
    window.addEventListener("resize", schedule);
    window.addEventListener("pageshow", schedule);
    mobile.addEventListener("change", schedule);
    return () => {
      cancelAnimationFrame(frame);
      viewport?.removeEventListener("resize", schedule);
      viewport?.removeEventListener("scroll", schedule);
      window.removeEventListener("resize", schedule);
      window.removeEventListener("pageshow", schedule);
      mobile.removeEventListener("change", schedule);
      root.classList.remove("media-viewer-open");
      for (const name of ["height", "width", "top", "left"]) root.style.removeProperty(`--media-viewport-${name}`);
      if (originalColor != null) themeColor?.setAttribute("content", originalColor);
    };
  }, [open]);
}
