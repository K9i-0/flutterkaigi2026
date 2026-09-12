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
export const getOfficialShell = createServerFn({ method: "GET" }).handler(async () => {
  const { loadPublicEpisodes, loadPublicGallery } = await import("./public-data.server");
  const { getCookie } = await import("@tanstack/react-start/server");
  const [episodes, galleryItems] = await Promise.all([loadPublicEpisodes(), loadPublicGallery()]);
  const value = getCookie("madogiwa-site-theme");
  const theme = value === "excel" || value === "underground" ? value : "sakaba";
  return { data: { episodes, galleryItems }, theme };
});
