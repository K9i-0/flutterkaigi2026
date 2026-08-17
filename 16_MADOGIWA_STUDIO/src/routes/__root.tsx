import { HeadContent, Scripts, createRootRoute } from "@tanstack/react-router";
import type { ReactNode } from "react";
import { Toaster } from "sonner";
import { ImageLightboxProvider } from "@/components/image-lightbox";
import { Layout } from "@/components/layout";
import { NotFoundPage } from "@/pages/not-found-page";
import { DEFAULT_DESCRIPTION, SITE_NAME, socialMeta } from "@/lib/public-data";
import "../styles.css";

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { name: "theme-color", content: "#080807" },
      ...socialMeta({
        title: `${SITE_NAME}｜公式サイト`,
        description: DEFAULT_DESCRIPTION,
        path: "/",
        imageAlt: "渋谷の中心に現れた巨大なそば屋と、窓際族物語の登場人物たち",
      }),
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
