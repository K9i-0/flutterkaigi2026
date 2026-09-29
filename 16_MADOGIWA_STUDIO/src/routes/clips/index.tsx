import { createFileRoute, notFound } from "@tanstack/react-router";
import { ClipsPage } from "@/features/clips/clips";

export const Route = createFileRoute("/clips/")({
  validateSearch: (search: Record<string, unknown>): { page?: number } => {
    const page = Number(search.page);
    return { page: Number.isSafeInteger(page) && page > 1 ? page : undefined };
  },
  beforeLoad: () => {
    if (!import.meta.env.DEV) throw notFound();
  },
  head: () => ({
    meta: [
      { title: "迷言・迷場面集｜窓際族物語" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: () => <ClipsPage page={Route.useSearch().page ?? 1} />,
});
