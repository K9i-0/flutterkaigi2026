import { createMcpHandler } from "agents/mcp/server";
import { McpServer } from "@modelcontextprotocol/server";
import { z } from "zod";
import { createInputUpload } from "./input-assets";
import {
  createEpisode,
  createGeneration,
  getEpisodeBySlug,
  listEpisodes,
  listMembers,
  setVideoStatus,
  setVideoFeatured,
  updateEpisodeMembers,
  updateGeneration,
  upsertPrompt,
} from "./repository";
import {
  createEpisodeSchema,
  generationSchema,
  inputUploadSchema,
  memberIdsSchema,
  promptSchema,
  updateGenerationSchema,
  uploadSchema,
  videoStatusSchema,
  videoFeaturedSchema,
} from "./schemas";
import { createUpload } from "./uploads";

function toolResult(value: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(value, null, 2) }] };
}

function createServer(env: Env, actor: string, origin: string): McpServer {
  const server = new McpServer({ name: "Madogiwa Studio", version: "0.2.0" });

  server.registerTool("list_members", { description: "登録可能な正典メンバー一覧を取得する", inputSchema: {} }, async () =>
    toolResult(await listMembers(env.DB)),
  );
  server.registerTool(
    "list_episodes",
    {
      description: "エピソード一覧、Studio ID、登場メンバー、生成バージョン数を取得する。イチオシ動画があるものだけにも絞り込める",
      inputSchema: { featuredOnly: z.boolean().optional().default(false) },
    },
    async ({ featuredOnly }) => toolResult(await listEpisodes(env.DB, { featuredOnly })),
  );
  server.registerTool(
    "get_episode",
    {
      description: "slugを指定し、エピソード、登場メンバー、v1/v2ごとのプロンプト・入力・動画を取得する",
      inputSchema: { slug: z.string().min(2) },
    },
    async ({ slug }) => toolResult((await getEpisodeBySlug(env.DB, slug)) ?? { error: "エピソードが見つかりません" }),
  );
  server.registerTool(
    "create_episode",
    { description: "ランダムなStudio IDとv1を持つ新しいエピソードを作成する", inputSchema: createEpisodeSchema.shape },
    async (input) => toolResult(await createEpisode(env.DB, createEpisodeSchema.parse(input), actor)),
  );
  server.registerTool(
    "set_episode_members",
    {
      description: "エピソードの登場メンバーを置き換える",
      inputSchema: { episodeId: z.string().uuid(), memberIds: memberIdsSchema },
    },
    async ({ episodeId, memberIds }) => toolResult(await updateEpisodeMembers(env.DB, episodeId, memberIds)),
  );
  server.registerTool(
    "create_generation",
    {
      description: "エピソードへ次の生成バージョン（v2、v3…）を追加する。使用モデルは任意の名前で登録できる",
      inputSchema: { episodeId: z.string().uuid(), ...generationSchema.shape },
    },
    async ({ episodeId, label, modelName, notes }) =>
      toolResult(await createGeneration(env.DB, episodeId, label, modelName, notes, actor)),
  );
  server.registerTool(
    "update_generation",
    {
      description: "生成バージョンのラベル、使用モデル、メモを更新する",
      inputSchema: { generationId: z.string().uuid(), ...updateGenerationSchema.shape },
    },
    async ({ generationId, ...input }) =>
      toolResult(await updateGeneration(env.DB, generationId, updateGenerationSchema.parse(input))),
  );
  server.registerTool(
    "upsert_prompt",
    {
      description: "指定した生成バージョンへ新しいSeedanceプロンプト版を登録する",
      inputSchema: { generationId: z.string().uuid(), ...promptSchema.shape },
    },
    async ({ generationId, label, body }) => toolResult(await upsertPrompt(env.DB, generationId, label, body, actor)),
  );
  server.registerTool(
    "create_video_upload",
    {
      description: "指定した生成バージョンへ動画を登録する一回限りのアップロードURLを発行する",
      inputSchema: { generationId: z.string().uuid(), ...uploadSchema.shape },
    },
    async ({ generationId, filename, label, contentType, featured }) =>
      toolResult(await createUpload(env, origin, { generationId, filename, label, contentType, featured, uploadedBy: actor })),
  );
  server.registerTool(
    "set_video_featured",
    {
      description: "登録済み動画のイチオシ設定を変更する",
      inputSchema: { videoId: z.string().uuid(), ...videoFeaturedSchema.shape },
    },
    async ({ videoId, featured }) => toolResult(await setVideoFeatured(env.DB, videoId, featured)),
  );
  server.registerTool(
    "create_input_upload",
    {
      description: "指定した生成バージョンへ入力画像、参照音声、資料を登録するアップロードURLを発行する",
      inputSchema: { generationId: z.string().uuid(), ...inputUploadSchema.shape },
    },
    async ({ generationId, filename, label, kind, referenceLabel, groupLabel, notes, contentType, displayOrder }) =>
      toolResult(
        await createInputUpload(env, origin, {
          generationId,
          filename,
          label,
          kind,
          referenceLabel,
          groupLabel,
          notes,
          contentType,
          displayOrder,
          uploadedBy: actor,
        }),
      ),
  );
  server.registerTool(
    "set_video_status",
    {
      description: "動画の状態をready、published、archivedへ変更する",
      inputSchema: { videoId: z.string().uuid(), ...videoStatusSchema.shape },
    },
    async ({ videoId, status }) => toolResult(await setVideoStatus(env.DB, videoId, status)),
  );
  return server;
}

export async function handleMcp(request: Request, env: Env, ctx: ExecutionContext, actor: string): Promise<Response> {
  const origin = new URL(request.url).origin;
  const handler = createMcpHandler(() => createServer(env, actor, origin), { route: "/mcp", corsOptions: false });
  return handler(request, env, ctx);
}
