import { useEffect, useState } from "react";

export const siteThemes = {
  sakaba: { label: "窓際酒場", ready: true, description: "赤提灯と暖簾の、いつもの酒場。" },
  excel: { label: "仕事してるふりExcel", ready: true, description: "開いたり、閉じたり。それも仕事。" },
  underground: { label: "地下労働ゆめポイント", ready: true, description: "今日の労働が、泡になる。" },
} as const;
export type SiteTheme = keyof typeof siteThemes;
export type AvailableTheme = SiteTheme;

function validTheme(value: string | null): value is AvailableTheme {
  return value !== null && Object.hasOwn(siteThemes, value);
}
export function readSiteTheme(): AvailableTheme {
  const explicit = new URLSearchParams(location.search).get("theme");
  if (validTheme(explicit)) return explicit;
  try {
    const saved = localStorage.getItem("madogiwa-site-theme");
    return validTheme(saved) ? saved : "sakaba";
  } catch { return "sakaba"; }
}

export function useSiteTheme() {
  const [theme, setTheme] = useState<AvailableTheme>(readSiteTheme);
  useEffect(() => {
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
