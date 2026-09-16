import { Link, Outlet, useRouterState } from "@tanstack/react-router";
import { LockKeyhole, Menu } from "lucide-react";
import { useEffect } from "react";
import { Route as RootRoute } from "@/routes/__root";
import { OfficialSite } from "../official/site";
import { cn } from "@/lib/utils";

const publicLinks = [
  { label: "EPISODES", to: "/episodes" as const },
  { label: "STORY", to: "/story" as const },
  { label: "GALLERY", to: "/gallery" as const },
];

export function Layout() {
  const { official } = RootRoute.useLoaderData();
  const { pathname, hash } = useRouterState({
    select: (state) => ({ pathname: state.location.pathname, hash: state.location.hash }),
  });
  const admin = pathname.startsWith("/admin");

  useEffect(() => {
    if (!hash) window.scrollTo({ top: 0 });
  }, [pathname, hash]);

  if (admin) return <StudioLayout />;
  if (pathname.startsWith("/camera/")) return <Outlet />;
  if (/^\/episodes\/[^/]+\/?$/.test(pathname)) return <main className="production-shell"><Outlet /></main>;

  const classic = <div className="official-shell">
    <header className="official-header">
      <Link to="/" className="official-logo" aria-label="窓際族物語 ホーム">
        <img src="/site/sobaya-icon.jpg" alt="" />
        <span><b>窓際族物語</b><small>MADOGIWAZOKU MONOGATARI</small></span>
      </Link>
      <nav className="official-nav" aria-label="作品メニュー">
        <Link to="/episodes">EPISODES</Link><Link to="/characters/$slug" params={{ slug: "sobaya" }}>CHARACTERS</Link>
        {publicLinks.slice(1).map((item) => <Link key={item.label} to={item.to}>{item.label}</Link>)}
        <a href="/#game">GAME</a><a href="/#article">ARTICLE</a>
      </nav>
      <details className="mobile-menu">
        <summary aria-label="メニュー"><Menu /></summary>
        <nav><Link to="/episodes">EPISODES</Link><Link to="/characters/$slug" params={{ slug: "sobaya" }}>CHARACTERS</Link>{publicLinks.slice(1).map((item) => <Link key={item.label} to={item.to}>{item.label}</Link>)}<a href="/#game">GAME</a><a href="/#article">ARTICLE</a></nav>
      </details>
    </header>
    <main className={pathname === "/" ? "" : cn("official-inner", (pathname === "/episodes" || pathname === "/gallery") && "official-inner-archive")}><Outlet /></main>
    <footer className="official-footer">
      <div className="official-logo"><img src="/site/sobaya-icon.jpg" alt="" /><span><b>窓際族物語</b><small>MADOGIWAZOKU MONOGATARI</small></span></div>
      <p>働かない。でも、物語は動き出す。</p>
      <a href="https://madogiwa-studio.madogiwa-studio.workers.dev/admin" target="_blank" rel="noopener noreferrer" aria-label="管理画面（新しいタブで開く）"><LockKeyhole className="size-3.5" /> MANAGE</a>
      <small>© MADOGIWAZOKU MONOGATARI · Powered by Cloudflare</small>
    </footer>
  </div>;
  const journalRoute = pathname === "/" || pathname === "/episodes" || pathname === "/episodes/" || pathname.startsWith("/characters") || pathname === "/story" || pathname === "/gallery" || pathname === "/gallery/";
  return journalRoute && official ? <OfficialSite data={official.data} initialTheme={official.theme} initialHref={official.href} /> : classic;
}

function StudioLayout() {
  return <div className="admin-shell"><header className="admin-topbar"><Link to="/admin">Madogiwa Studio</Link><a href="https://madogiwa.work" target="_blank" rel="noopener noreferrer">公式サイト ↗</a></header><main className="admin-main"><Outlet /></main></div>;
}
