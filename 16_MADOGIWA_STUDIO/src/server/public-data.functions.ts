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
