import { Archive, Clapperboard, LockKeyhole } from "lucide-react";
import { Link, NavLink, Outlet } from "react-router-dom";
import { cn } from "@/lib/utils";

export function Layout() {
  return (
    <div className="min-h-screen bg-stone-950 text-stone-100">
      <div className="pointer-events-none fixed inset-x-0 top-0 h-[32rem] bg-[radial-gradient(circle_at_15%_10%,rgba(245,158,11,0.13),transparent_35%),radial-gradient(circle_at_80%_0%,rgba(120,113,108,0.12),transparent_33%)]" />
      <header className="sticky top-0 z-40 border-b border-white/6 bg-stone-950/75 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-5 lg:px-8">
          <Link to="/" className="group flex items-center gap-3">
            <span className="grid size-9 place-items-center rounded-xl border border-amber-300/20 bg-amber-400/10 text-amber-300 transition group-hover:rotate-3">
              <Clapperboard className="size-4" />
            </span>
            <span>
              <span className="block text-sm font-semibold tracking-[0.16em]">MADOGIWA</span>
              <span className="block text-[9px] tracking-[0.38em] text-stone-500">STUDIO</span>
            </span>
          </Link>
          <nav className="flex items-center gap-1 rounded-full border border-white/7 bg-white/[0.025] p-1">
            <NavItem to="/" end icon={<Archive className="size-3.5" />}>Archive</NavItem>
            <NavItem to="/admin" reloadDocument icon={<LockKeyhole className="size-3.5" />}>Manage</NavItem>
          </nav>
        </div>
      </header>
      <main className="relative mx-auto max-w-7xl px-5 py-10 lg:px-8 lg:py-14">
        <Outlet />
      </main>
      <footer className="relative mx-auto max-w-7xl border-t border-white/6 px-5 py-8 text-xs text-stone-600 lg:px-8">
        窓際族物語 Production Archive · Powered by Cloudflare
      </footer>
    </div>
  );
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
