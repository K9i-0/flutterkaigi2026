export const episodeStatuses = ["draft", "generated", "published", "archived"] as const;
export type EpisodeStatus = (typeof episodeStatuses)[number];

export const videoStatuses = ["upload_pending", "ready", "published", "archived"] as const;
export type VideoStatus = (typeof videoStatuses)[number];

export const inputAssetKinds = ["image", "audio", "document", "other"] as const;
export type InputAssetKind = (typeof inputAssetKinds)[number];
export const inputAssetStatuses = ["upload_pending", "ready", "archived"] as const;
export type InputAssetStatus = (typeof inputAssetStatuses)[number];

export type EpisodeRow = {
  id: string;
  studio_id: string;
  slug: string;
  episode_number: number | null;
  title: string;
  summary: string;
  status: EpisodeStatus;
  created_at: string;
  updated_at: string;
  published_at: string | null;
};

export type MemberRow = { id: string; slug: string; name: string; sort_order: number };

export type GenerationRow = {
  id: string;
  episode_id: string;
  version: number;
  label: string;
  model_name: string | null;
  notes: string;
  created_by: string | null;
  created_at: string;
  updated_at: string;
};

export type PromptRow = {
  id: string;
  episode_id: string;
  generation_id: string;
  label: string;
  body: string;
  version: number;
  is_current: number;
  created_by: string | null;
  created_at: string;
};

export type VideoRow = {
  id: string;
  episode_id: string;
  generation_id: string;
  r2_key: string;
  filename: string;
  label: string;
  content_type: string;
  size_bytes: number | null;
  status: VideoStatus;
  is_primary: number;
  uploaded_by: string | null;
  created_at: string;
  updated_at: string;
};

export type InputAssetRow = {
  id: string;
  episode_id: string;
  generation_id: string;
  r2_key: string;
  filename: string;
  label: string;
  kind: InputAssetKind;
  reference_label: string | null;
  group_label: string | null;
  notes: string;
  content_type: string;
  size_bytes: number | null;
  status: InputAssetStatus;
  display_order: number;
  uploaded_by: string | null;
  created_at: string;
  updated_at: string;
};

export type GenerationDetail = GenerationRow & {
  prompt: PromptRow | null;
  promptHistory: PromptRow[];
  videos: VideoRow[];
  inputAssets: InputAssetRow[];
};

export type EpisodeSummary = EpisodeRow & {
  generation_count: number;
  video_count: number;
  input_count: number;
  primary_video_id: string | null;
  prompt_label: string | null;
  members: MemberRow[];
};

export type EpisodeDetail = {
  episode: EpisodeRow;
  members: MemberRow[];
  generations: GenerationDetail[];
};
