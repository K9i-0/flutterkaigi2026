import { Archive, Clapperboard, LockKeyhole, Menu } from "lucide-react";
import { useEffect } from "react";
import { Link, NavLink, Outlet, useLocation } from "react-router-dom";
import { cn } from "@/lib/utils";

export function Layout() {
  const { pathname, hash } = useLocation();
  const admin = pathname.startsWith("/admin");

  useEffect(() => {
    if (!hash) window.scrollTo({ top: 0 });
  }, [pathname, hash]);

  if (admin) return <StudioLayout />;

  return (
    <div className="official-shell">
      <header className="official-header">
        <Link to="/" className="official-logo" aria-label="窓際族物語 ホーム">
          <img src="/site/sobaya-icon.jpg" alt="" />
          <span><b>窓際族物語</b><small>MADOGIWAZOKU MONOGATARI</small></span>
        </Link>
        <nav className="official-nav" aria-label="作品メニュー">
          {[["CHARACTER", "#character"], ["COMIC", "#comic"], ["GALLERY", "#gallery"], ["MOVIE", "#movie"], ["GAME", "#game"], ["ARTICLE", "#article"]].map(([label, href]) => <a key={label} href={`/${href}`}>{label}</a>)}
        </nav>
        <details className="mobile-menu">
          <summary aria-label="メニュー"><Menu /></summary>
          <nav>{[["CHARACTER", "#character"], ["COMIC", "#comic"], ["GALLERY", "#gallery"], ["MOVIE", "#movie"], ["GAME", "#game"], ["ARTICLE", "#article"]].map(([label, href]) => <a key={label} href={`/${href}`}>{label}</a>)}</nav>
        </details>
      </header>
      <main className={pathname === "/" ? "" : "official-inner"}><Outlet /></main>
      <footer className="official-footer">
        <div className="official-logo"><img src="/site/sobaya-icon.jpg" alt="" /><span><b>窓際族物語</b><small>MADOGIWAZOKU MONOGATARI</small></span></div>
        <p>働かない。でも、物語は動き出す。</p>
        <Link to="/admin" reloadDocument aria-label="管理画面"><LockKeyhole className="size-3.5" /> MANAGE</Link>
        <small>© MADOGIWAZOKU MONOGATARI · Powered by Cloudflare</small>
      </footer>
    </div>
  );
}

function StudioLayout() {
  return <div className="min-h-screen bg-stone-950 text-stone-100">
    <div className="pointer-events-none fixed inset-x-0 top-0 h-[32rem] bg-[radial-gradient(circle_at_15%_10%,rgba(245,158,11,0.13),transparent_35%)]" />
    <header className="sticky top-0 z-40 border-b border-white/6 bg-stone-950/75 backdrop-blur-xl"><div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-5 lg:px-8"><Link to="/" className="group flex items-center gap-3"><span className="grid size-9 place-items-center rounded-xl border border-amber-300/20 bg-amber-400/10 text-amber-300"><Clapperboard className="size-4" /></span><span><span className="block text-sm font-semibold tracking-[0.16em]">MADOGIWA</span><span className="block text-[9px] tracking-[0.38em] text-stone-500">STUDIO</span></span></Link><nav className="flex items-center gap-1 rounded-full border border-white/7 bg-white/[0.025] p-1"><NavItem to="/" icon={<Archive className="size-3.5" />}>Official</NavItem><NavItem to="/admin" reloadDocument icon={<LockKeyhole className="size-3.5" />}>Manage</NavItem></nav></div></header>
    <main className="relative mx-auto max-w-7xl px-5 py-10 lg:px-8 lg:py-14"><Outlet /></main>
    <footer className="relative mx-auto max-w-7xl border-t border-white/6 px-5 py-8 text-xs text-stone-600 lg:px-8">窓際族物語 Production Archive · Powered by Cloudflare</footer>
  </div>;
}

function NavItem({ to, end, reloadDocument, icon, children }: { to: string; end?: boolean; reloadDocument?: boolean; icon: React.ReactNode; children: React.ReactNode }) {
  return (
    <NavLink
      to={to}
      end={end}
      reloadDocument={reloadDocument}
      className={({ isActive }) => cn("flex items-center gap-2 rounded-full px-3.5 py-2 text-xs font-medium transition", isActive ? "bg-white/10 text-white" : "text-stone-500 hover:text-stone-200")}
    >
      {icon}
      <span className="hidden sm:inline">{children}</span>
    </NavLink>
  );
}
