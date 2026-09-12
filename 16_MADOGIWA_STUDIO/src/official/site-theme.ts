import { useEffect, useState } from "react";

export const siteThemes = {
  sakaba: { label: "窓際酒場", ready: true, description: "赤提灯と暖簾の、いつもの酒場。" },
  excel: { label: "仕事してるふりExcel", ready: true, description: "開いたり、閉じたり。それも仕事。" },
  underground: { label: "地下労働ゆめポイント", ready: true, description: "今日の労働が、泡になる。" },
} as const;
export type SiteTheme = keyof typeof siteThemes;
export type AvailableTheme = SiteTheme;

export function validTheme(value: string | null): value is AvailableTheme {
  return value !== null && Object.hasOwn(siteThemes, value);
}
export function readSiteTheme(): AvailableTheme {
  if (typeof location === "undefined") return "sakaba";
  const explicit = new URLSearchParams(location.search).get("theme");
  if (validTheme(explicit)) return explicit;
  const cookie = document.cookie.split("; ").find((item) => item.startsWith("madogiwa-site-theme="))?.split("=")[1] ?? null;
  try {
    const saved = localStorage.getItem("madogiwa-site-theme");
    return validTheme(saved) ? saved : validTheme(cookie) ? cookie : "sakaba";
  } catch { return validTheme(cookie) ? cookie : "sakaba"; }
}

export function useSiteTheme(initialTheme?: AvailableTheme) {
  const [theme, setTheme] = useState<AvailableTheme>(() => initialTheme ?? readSiteTheme());
  useEffect(() => {
    setTheme(readSiteTheme());
  }, []);
  useEffect(() => {
    // Persist after applying a legacy localStorage preference on first hydration.
    if (theme !== readSiteTheme()) return;
    document.cookie = `madogiwa-site-theme=${theme}; Path=/; Max-Age=31536000; SameSite=Lax`;
    document.documentElement.removeAttribute("data-theme-pending");
    document.documentElement.dataset.theme = theme;
    try { localStorage.setItem("madogiwa-site-theme", theme); } catch { /* Storage may be unavailable. */ }
    const colors = { sakaba: "#142b40", excel: "#217346", underground: "#777771" };
    document.querySelector('meta[name="theme-color"]')?.setAttribute("content", colors[theme]);
    return () => { delete document.documentElement.dataset.theme; };
  }, [theme]);
  useEffect(() => {
    const restore = () => setTheme(readSiteTheme());
    window.addEventListener("popstate", restore);
    return () => window.removeEventListener("popstate", restore);
  }, []);
  function changeTheme(next: AvailableTheme) {
    const url = new URL(location.href);
    url.searchParams.set("theme", next);
    history.replaceState(null, "", url);
    try { localStorage.setItem("madogiwa-site-theme", next); } catch { /* URL still preserves choice. */ }
    setTheme(next);
  }
  return { theme, changeTheme };
}
