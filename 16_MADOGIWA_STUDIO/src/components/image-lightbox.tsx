import { Maximize2, X } from "lucide-react";
import { createContext, useCallback, useContext, useEffect, useRef, useState, type CSSProperties, type ImgHTMLAttributes, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { cn } from "@/lib/utils";

type LightboxImage = {
  src: string;
  alt: string;
  caption?: string;
};

type LightboxContextValue = {
  openImage: (image: LightboxImage, trigger?: HTMLElement | null) => void;
};

type DragState = {
  active: boolean;
  x: number;
  y: number;
};

const ImageLightboxContext = createContext<LightboxContextValue | null>(null);
const DISMISS_DISTANCE = 80;

export function ImageLightboxProvider({ children }: { children: ReactNode }) {
  const [image, setImage] = useState<LightboxImage | null>(null);
  const [drag, setDrag] = useState<DragState>({ active: false, x: 0, y: 0 });
  const pointerStart = useRef<{ id: number; x: number; y: number } | null>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const triggerRef = useRef<HTMLElement | null>(null);

  const closeImage = useCallback(() => {
    setImage(null);
    setDrag({ active: false, x: 0, y: 0 });
    pointerStart.current = null;
    window.requestAnimationFrame(() => triggerRef.current?.focus());
  }, []);

  const openImage = useCallback((nextImage: LightboxImage, trigger?: HTMLElement | null) => {
    triggerRef.current = trigger ?? null;
    setDrag({ active: false, x: 0, y: 0 });
    setImage(nextImage);
  }, []);

  useEffect(() => {
    if (!image) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButtonRef.current?.focus();

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") closeImage();
    }

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [closeImage, image]);

  function handlePointerDown(event: React.PointerEvent<HTMLDivElement>) {
    if (!event.isPrimary || (event.pointerType === "mouse" && event.button !== 0)) return;
    pointerStart.current = { id: event.pointerId, x: event.clientX, y: event.clientY };
    event.currentTarget.setPointerCapture(event.pointerId);
    setDrag({ active: true, x: 0, y: 0 });
  }

  function handlePointerMove(event: React.PointerEvent<HTMLDivElement>) {
    const start = pointerStart.current;
    if (!start || start.id !== event.pointerId) return;
    setDrag({ active: true, x: event.clientX - start.x, y: event.clientY - start.y });
  }

  function finishPointer(event: React.PointerEvent<HTMLDivElement>, cancelled = false) {
    const start = pointerStart.current;
    if (!start || start.id !== event.pointerId) return;
    pointerStart.current = null;
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId);
    const distance = Math.hypot(drag.x, drag.y);
    if (!cancelled && distance >= DISMISS_DISTANCE) closeImage();
    else setDrag({ active: false, x: 0, y: 0 });
  }

  const dragDistance = Math.hypot(drag.x, drag.y);
  const dragScale = Math.max(0.86, 1 - dragDistance / 900);
  const backdropOpacity = Math.max(0.34, 0.94 - dragDistance / 500);
  const stageStyle = {
    "--lightbox-drag-x": `${drag.x}px`,
    "--lightbox-drag-y": `${drag.y}px`,
    "--lightbox-drag-scale": dragScale,
  } as CSSProperties;

  return <ImageLightboxContext.Provider value={{ openImage }}>
    {children}
    {image ? createPortal(
      <div
        className="image-lightbox"
        role="dialog"
        aria-modal="true"
        aria-label={`${image.alt || "画像"}の拡大表示`}
        style={{ backgroundColor: `rgba(0, 0, 0, ${backdropOpacity})` }}
        onClick={(event) => { if (event.target === event.currentTarget) closeImage(); }}
      >
        <button ref={closeButtonRef} type="button" className="image-lightbox-close" onClick={closeImage} aria-label="拡大表示を閉じる"><X /></button>
        <div
          className={cn("image-lightbox-stage", drag.active && "image-lightbox-stage-dragging")}
          style={stageStyle}
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={(event) => finishPointer(event)}
          onPointerCancel={(event) => finishPointer(event, true)}
        >
          <img src={image.src} alt={image.alt} draggable={false} />
          {image.caption ? <p>{image.caption}</p> : null}
        </div>
        <div className="image-lightbox-hint" aria-hidden="true"><span />どの方向にもドラッグして閉じる</div>
      </div>,
      document.body,
    ) : null}
  </ImageLightboxContext.Provider>;
}

export function useImageLightbox() {
  const context = useContext(ImageLightboxContext);
  if (!context) throw new Error("useImageLightbox must be used inside ImageLightboxProvider");
  return context;
}

type ZoomableImageProps = Omit<ImgHTMLAttributes<HTMLImageElement>, "src" | "alt"> & {
  src: string;
  alt: string;
  caption?: string;
  buttonClassName?: string;
};

export function ZoomableImage({ src, alt, caption, buttonClassName, className, ...imageProps }: ZoomableImageProps) {
  const { openImage } = useImageLightbox();
  return <button
    type="button"
    className={cn("zoomable-image-trigger", buttonClassName)}
    onClick={(event) => openImage({ src, alt, caption }, event.currentTarget)}
    aria-label={`${alt}を拡大表示`}
  >
    <img src={src} alt={alt} className={className} {...imageProps} />
    <span className="zoomable-image-cue" aria-hidden="true"><Maximize2 /></span>
  </button>;
}
