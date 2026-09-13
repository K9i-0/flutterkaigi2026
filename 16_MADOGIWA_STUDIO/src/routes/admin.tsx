import { createFileRoute } from "@tanstack/react-router";
import { AdminPage } from "@/pages/admin-page";

type AdminSearch = { episode?: string; section?: "gallery" | "articles" };

export const Route = createFileRoute("/admin")({
  ssr: false,
  validateSearch: (search: Record<string, unknown>): AdminSearch => ({
    episode: typeof search.episode === "string" ? search.episode : undefined,
    section: search.section === "gallery" || search.section === "articles" ? search.section : undefined,
  }),
  head: () => ({ meta: [{ title: "コンテンツ管理｜Madogiwa Studio" }, { name: "robots", content: "noindex,nofollow" }] }),
  component: AdminPage,
});
