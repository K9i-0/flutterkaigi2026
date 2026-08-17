import { z } from "zod";
import { editorialContentStatuses, episodeStatuses, inputAssetKinds, videoStatuses } from "./domain";

const slugSchema = z
  .string()
  .min(2)
  .max(80)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "slugは半角英数字とハイフンで入力してください");

export const memberIdsSchema = z.array(z.string().trim().min(1).max(40)).max(30).default([]);

export const createEpisodeSchema = z.object({
  slug: slugSchema,
  title: z.string().trim().min(1).max(120),
  summary: z.string().trim().max(1000).optional(),
  status: z.enum(episodeStatuses).optional(),
  memberIds: memberIdsSchema.optional(),
});

export const updateEpisodeSchema = createEpisodeSchema.omit({ memberIds: true }).partial();

export const generationSchema = z.object({
  label: z.string().trim().max(120).default(""),
  modelName: z.string().trim().max(80).nullable().optional(),
  notes: z.string().trim().max(1000).default(""),
});

export const updateGenerationSchema = generationSchema.partial();

export const promptSchema = z.object({
  label: z.string().trim().min(1).max(120).default("Seedance prompt"),
  body: z.string().trim().min(1).max(100_000),
});

export const uploadSchema = z.object({
  filename: z.string().trim().min(1).max(255),
  label: z.string().trim().min(1).max(120).default("Generated video"),
  contentType: z.string().trim().regex(/^video\//, "動画のContent-Typeを指定してください").default("video/mp4"),
  featured: z.boolean().default(false),
});

export const inputUploadSchema = z.object({
  filename: z.string().trim().min(1).max(255),
  label: z.string().trim().min(1).max(120),
  kind: z.enum(inputAssetKinds),
  referenceLabel: z.string().trim().max(80).nullable().optional(),
  groupLabel: z.string().trim().max(80).nullable().optional(),
  notes: z.string().trim().max(1000).default(""),
  contentType: z.string().trim().min(1).max(120).default("application/octet-stream"),
  displayOrder: z.number().int().min(0).max(10_000).default(0),
});

export const videoStatusSchema = z.object({ status: z.enum(videoStatuses) });
export const videoFeaturedSchema = z.object({ featured: z.boolean() });

export const galleryItemSchema = z.object({
  slug: slugSchema,
  title: z.string().trim().min(1).max(160),
  kind: z.string().trim().min(1).max(80),
  displayOrder: z.number().int().min(0).max(10_000).default(0),
  status: z.enum(editorialContentStatuses).default("draft"),
});

export const updateGalleryItemSchema = galleryItemSchema.partial();

export const galleryImageUploadSchema = z.object({
  filename: z.string().trim().min(1).max(255),
  contentType: z.string().trim().regex(/^image\/(?:jpeg|png|webp)$/, "JPEG、PNG、WebP画像を指定してください"),
});

export const articleSchema = z.object({
  slug: slugSchema,
  label: z.string().trim().min(1).max(80),
  source: z.string().trim().min(1).max(80),
  title: z.string().trim().min(1).max(200),
  copy: z.string().trim().max(1000).default(""),
  url: z.url().max(2000),
  action: z.string().trim().min(1).max(80),
  displayOrder: z.number().int().min(0).max(10_000).default(0),
  status: z.enum(editorialContentStatuses).default("draft"),
});

export const updateArticleSchema = articleSchema.partial();

export const reorderContentSchema = z.object({
  itemIds: z.array(z.string().uuid()).max(200),
});
