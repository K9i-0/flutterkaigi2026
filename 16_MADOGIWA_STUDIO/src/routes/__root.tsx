import { HeadContent, Scripts, createRootRoute } from "@tanstack/react-router";
import type { ReactNode } from "react";
import { Toaster } from "sonner";
import { ImageLightboxProvider } from "@/components/image-lightbox";
import { Layout } from "@/components/layout";
import { NotFoundPage } from "@/pages/not-found-page";
import { DEFAULT_DESCRIPTION, DEFAULT_OG_IMAGE, SITE_NAME, absoluteUrl } from "@/lib/public-data";
import "../styles.css";

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { title: `${SITE_NAME}｜公式サイト` },
      { name: "description", content: DEFAULT_DESCRIPTION },
      { name: "theme-color", content: "#080807" },
      { property: "og:type", content: "website" },
      { property: "og:locale", content: "ja_JP" },
      { property: "og:site_name", content: SITE_NAME },
      { property: "og:title", content: `${SITE_NAME} 公式サイト` },
      { property: "og:description", content: DEFAULT_DESCRIPTION },
      { property: "og:image", content: absoluteUrl(DEFAULT_OG_IMAGE) },
      { name: "twitter:card", content: "summary_large_image" },
    ],
    links: [{ rel: "icon", href: "/site/sobaya-icon.jpg" }],
  }),
  component: RootDocument,
  notFoundComponent: NotFoundPage,
});

function RootDocument() {
  return <Document>
    <ImageLightboxProvider><Layout /><Toaster theme="dark" richColors position="bottom-right" /></ImageLightboxProvider>
  </Document>;
}

function Document({ children }: { children: ReactNode }) {
  return <html lang="ja"><head><HeadContent /></head><body>{children}<Scripts /></body></html>;
}
