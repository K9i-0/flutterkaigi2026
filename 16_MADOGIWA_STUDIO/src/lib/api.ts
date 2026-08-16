export type EpisodeStatus = "draft" | "generated" | "published" | "archived";
export type VideoStatus = "upload_pending" | "ready" | "published" | "archived";
export type InputAssetKind = "image" | "audio" | "document" | "other";
export type InputAssetStatus = "upload_pending" | "ready" | "archived";

export type Member = { id: string; slug: string; name: string; sort_order: number };

export type Episode = {
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

export type EpisodeSummary = Episode & {
  generation_count: number;
  video_count: number;
  input_count: number;
  primary_video_id: string | null;
  prompt_label: string | null;
  members: Member[];
};

export type PromptVersion = {
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

export type Video = {
  id: string;
  episode_id: string;
  generation_id: string;
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

export type InputAsset = {
  id: string;
  episode_id: string;
  generation_id: string;
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

export type Generation = {
  id: string;
  episode_id: string;
  version: number;
  label: string;
  model_name: string | null;
  notes: string;
  created_by: string | null;
  created_at: string;
  updated_at: string;
  prompt: PromptVersion | null;
  promptHistory: PromptVersion[];
  videos: Video[];
  inputAssets: InputAsset[];
};

export type EpisodeDetail = { episode: Episode; members: Member[]; generations: Generation[] };
type ApiErrorBody = { error?: string };

export class AdminAuthenticationRequiredError extends Error {
  constructor() {
    super("管理画面の認証が必要です");
    this.name = "AdminAuthenticationRequiredError";
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const isAdminRequest = path === "/admin-api" || path.startsWith("/admin-api/");
  let response: Response;
  try {
    response = await fetch(path, init);
  } catch (error) {
    if (isAdminRequest) throw new AdminAuthenticationRequiredError();
    throw error;
  }
  if (isAdminRequest && response.status === 401) {
    throw new AdminAuthenticationRequiredError();
  }
  if (!response.ok) {
    const body = (await response.json().catch(() => ({}))) as ApiErrorBody;
    throw new Error(body.error ?? `Request failed (${response.status})`);
  }
  return response.json() as Promise<T>;
}

function jsonInit(method: string, body: unknown): RequestInit {
  return { method, headers: { "content-type": "application/json" }, body: JSON.stringify(body) };
}

export const api = {
  listMembers: () => request<{ members: Member[] }>("/api/members"),
  listEpisodes: () => request<{ episodes: EpisodeSummary[] }>("/api/episodes"),
  getEpisode: (slug: string) => request<EpisodeDetail>(`/api/episodes/${encodeURIComponent(slug)}`),
  getSession: () => request<{ admin: { email: string; source: "access" } | null }>("/admin-api/session"),
  createEpisode: (input: { slug: string; title: string; summary: string; memberIds: string[] }) =>
    request<Episode>("/admin-api/episodes", jsonInit("POST", input)),
  updateEpisode: (slug: string, input: Partial<{ title: string; summary: string; status: EpisodeStatus }>) =>
    request<Episode>(`/admin-api/episodes/${encodeURIComponent(slug)}`, jsonInit("PATCH", input)),
  updateEpisodeMembers: (episodeId: string, memberIds: string[]) =>
    request<{ members: Member[] }>(`/admin-api/episodes/${episodeId}/members`, jsonInit("PUT", { memberIds })),
  createGeneration: (episodeId: string, input: { label: string; modelName: string | null; notes: string }) =>
    request<Generation>(`/admin-api/episodes/${episodeId}/generations`, jsonInit("POST", input)),
  updateGeneration: (generationId: string, input: Partial<{ label: string; modelName: string | null; notes: string }>) =>
    request<Generation>(`/admin-api/generations/${generationId}`, jsonInit("PATCH", input)),
  upsertPrompt: (generationId: string, input: { label: string; body: string }) =>
    request<PromptVersion>(`/admin-api/generations/${generationId}/prompts`, jsonInit("POST", input)),
  createUpload: (generationId: string, input: { filename: string; label: string; contentType: string }) =>
    request<{ videoId: string; uploadUrl: string; expiresAt: string }>(
      `/admin-api/generations/${generationId}/uploads`,
      jsonInit("POST", input),
    ),
  createInputUpload: (
    generationId: string,
    input: {
      filename: string;
      label: string;
      kind: InputAssetKind;
      referenceLabel: string | null;
      groupLabel: string | null;
      notes: string;
      contentType: string;
      displayOrder: number;
    },
  ) =>
    request<{ assetId: string; uploadUrl: string; expiresAt: string }>(
      `/admin-api/generations/${generationId}/input-uploads`,
      jsonInit("POST", input),
    ),
  uploadFile: async (uploadUrl: string, file: File) => {
    const response = await fetch(uploadUrl, {
      method: "PUT",
      headers: { "content-type": file.type || "video/mp4" },
      body: file,
    });
    if (!response.ok) {
      const body = (await response.json().catch(() => ({}))) as ApiErrorBody;
      throw new Error(body.error ?? "動画のアップロードに失敗しました");
    }
    return response.json() as Promise<{ videoId: string; mediaUrl: string; size: number }>;
  },
  uploadInputFile: async (uploadUrl: string, file: File) => {
    const response = await fetch(uploadUrl, {
      method: "PUT",
      headers: { "content-type": file.type || "application/octet-stream" },
      body: file,
    });
    if (!response.ok) {
      const body = (await response.json().catch(() => ({}))) as ApiErrorBody;
      throw new Error(body.error ?? "入力アセットのアップロードに失敗しました");
    }
    return response.json() as Promise<{ assetId: string; assetUrl: string; size: number }>;
  },
};
