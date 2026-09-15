import { createServerFn } from "@tanstack/react-start";

function requiredSlug(value: string): string {
  const slug = value.trim();
  if (!slug || slug.length > 160) throw new Error("Invalid slug");
  return slug;
}

export const getHomeData = createServerFn({ method: "GET" }).handler(async () => {
  const { loadHomeData } = await import("./public-data.server");
  return loadHomeData();
});

export const getPublicEpisodes = createServerFn({ method: "GET" }).handler(async () => {
  const { loadPublicEpisodes } = await import("./public-data.server");
  return loadPublicEpisodes();
});

export const getPublicEpisode = createServerFn({ method: "GET" })
  .validator(requiredSlug)
  .handler(async ({ data }) => {
    const { loadPublicEpisode } = await import("./public-data.server");
    return loadPublicEpisode(data);
  });

export const getPublicGallery = createServerFn({ method: "GET" }).handler(async () => {
  const { loadPublicGallery } = await import("./public-data.server");
  return loadPublicGallery();
});

export const getPublicGalleryItem = createServerFn({ method: "GET" })
  .validator(requiredSlug)
  .handler(async ({ data }) => {
    const { loadPublicGalleryItem } = await import("./public-data.server");
    return loadPublicGalleryItem(data);
  });

export const getCharacterData = createServerFn({ method: "GET" })
  .validator(requiredSlug)
  .handler(async ({ data }) => {
    const { loadCharacterData } = await import("./public-data.server");
    return loadCharacterData(data);
  });

export const getInitialSiteTheme = createServerFn({ method: "GET" }).handler(async () => {
  const { getCookie } = await import("@tanstack/react-start/server");
  const value = getCookie("madogiwa-site-theme");
  return value === "excel" || value === "underground" ? value : "sakaba";
});

// Cookie-dependent preferences travel with the public shell in one server call.
// Only the public content loaders are shared in Cloudflare's data cache.
export const getOfficialShell = createServerFn({ method: "GET" }).validator((value: string) => {
  if (typeof value !== "string" || value.length > 2000) throw new Error("Invalid page URL");
  return value;
}).handler(async ({ data: pageUrl }) => {
  const { loadPublicGallery } = await import("./public-data.server");
  const { getCookie } = await import("@tanstack/react-start/server");
  const { listCatalog } = await import("../../worker/catalog-repository");
  const { env } = await import("cloudflare:workers");
  const url = new URL(pageUrl, "https://madogiwa.work");
  const path = url.pathname.replace(/\/$/, "");
  const page = url.searchParams.get("page") ?? (path === "/episodes" ? "movies" : path.startsWith("/characters") ? "characters" : path === "/gallery" ? "gallery" : path === "/story" ? "story" : url.searchParams.has("character") ? "characters" : "home");
  const movies = page === "movies";
  const needsEpisodes = movies || page === "home" || page === "characters";
  const [catalog, galleryItems] = await Promise.all([
    needsEpisodes ? listCatalog(env.DB, movies ? {
      all: url.searchParams.get("scope") === "all",
      member: url.searchParams.get("member") || undefined,
      cursor: url.searchParams.get("after") || url.searchParams.get("before") || undefined,
      backwards: !url.searchParams.has("after") && url.searchParams.has("before"),
    } : { all: true }, movies) : Promise.resolve({ episodes: [] }),
    page === "home" || page === "gallery" ? loadPublicGallery() : Promise.resolve([]),
  ]);
  const value = getCookie("madogiwa-site-theme");
  const theme = value === "excel" || value === "underground" ? value : "sakaba";
  return { data: { episodes: catalog.episodes, galleryItems, catalog: movies ? catalog : undefined }, theme };
});
