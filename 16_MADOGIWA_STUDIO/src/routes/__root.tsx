import { HeadContent, Scripts, createRootRoute } from "@tanstack/react-router";
import type { ReactNode } from "react";
import { Toaster } from "sonner";
import { ImageLightboxProvider } from "@/components/image-lightbox";
import { Layout } from "@/components/layout";
import { NotFoundPage } from "@/pages/not-found-page";
import { DEFAULT_DESCRIPTION, SITE_NAME, socialMeta } from "@/lib/public-data";
import "../styles.css";
import { getHomeData, getInitialSiteTheme } from "@/server/public-data.functions";
import { validTheme } from "@/official/site-theme";

export const Route = createRootRoute({
  loader: async ({ location }) => {
    const path = location.pathname.replace(/\/$/, "") || "/";
    const official = ["/", "/episodes", "/story", "/gallery"].includes(path) || path.startsWith("/characters");
    if (!official) return { official: null };
    const [data, savedTheme] = await Promise.all([getHomeData(), getInitialSiteTheme()]);
    const explicit = new URL(location.href, "https://madogiwa.work").searchParams.get("theme");
    return { official: { data, theme: validTheme(explicit) ? explicit : savedTheme, href: location.href } };
  },
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { name: "theme-color", content: "#080807" },
      ...socialMeta({
        title: `${SITE_NAME}｜公式サイト`,
        description: DEFAULT_DESCRIPTION,
        path: "/",
        imageAlt: "高層ビル外側のベランダ席でビールを飲むそば屋、窓の中の福ちゃん、宙に浮くたこさんとやめ太郎の指名手配ポスター",
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
  const { official } = Route.useLoaderData();
  return <html lang="ja" className={official ? "journal-document" : undefined} data-mode={official ? "paper" : undefined} data-theme={official?.theme} suppressHydrationWarning><head><HeadContent />{official && <><style>{'html[data-theme-pending] body{visibility:hidden}'}</style><script dangerouslySetInnerHTML={{ __html: `try{var v=['sakaba','excel','underground'],t=new URLSearchParams(location.search).get('theme');if(!v.includes(t))t=localStorage.getItem('madogiwa-site-theme');if(v.includes(t)&&t!==document.documentElement.dataset.theme){document.documentElement.setAttribute('data-theme-pending','');setTimeout(function(){document.documentElement.removeAttribute('data-theme-pending')},4000);}}catch(e){}` }} /></>}</head><body>{children}<Scripts /></body></html>;
}
