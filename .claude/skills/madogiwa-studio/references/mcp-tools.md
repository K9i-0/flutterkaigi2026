# Madogiwa Studio MCP reference

## Connection

Endpoint:

```text
https://madogiwa-studio.madogiwa-studio.workers.dev/mcp
```

Codex project config (`.codex/config.toml`):

```toml
[mcp_servers.madogiwa-studio]
url = "https://madogiwa-studio.madogiwa-studio.workers.dev/mcp"
auth = "oauth"
default_tools_approval_mode = "writes"
```

Claude-compatible project config (`.mcp.json`) inside `mcpServers`:

```json
"madogiwa-studio": {
  "type": "http",
  "url": "https://madogiwa-studio.madogiwa-studio.workers.dev/mcp"
}
```

For Codex CLI, run `codex mcp login madogiwa-studio` after adding the config. Complete Cloudflare Access OAuth with an allowed email address, then restart the agent session if the tools are not discovered. Do not copy another user's OAuth cache. A new colleague must first be added to the Cloudflare Access allow policy.

The skill's `agents/openai.yaml` also declares this Remote MCP dependency for clients that support skill tool dependencies.

## Tools

- `list_members({})`: return canonical member IDs and display names.
- `list_episodes({ featuredOnly? })`: return episode summaries, Studio IDs, counts, members, primary video IDs, and featured-video flags. Set `featuredOnly: true` to filter.
- `get_episode({ slug })`: return one episode with generations, prompt history, input assets, and videos.
- `create_episode({ slug, title, summary?, status?, memberIds? })`: create an episode and its automatic v1. Status is `draft`, `generated`, `published`, or `archived`.
- `set_episode_members({ episodeId, memberIds })`: replace the member set.
- `create_generation({ episodeId, label?, modelName?, notes? })`: append the next version. Never pass a version number.
- `update_generation({ generationId, label?, modelName?, notes? })`: update generation metadata.
- `upsert_prompt({ generationId, label?, body })`: add a new current prompt revision and retain history.
- `create_video_upload({ generationId, filename, label?, contentType?, featured? })`: create a video row and return `{ videoId, uploadUrl, expiresAt }`. Use `featured: true` for an official-site pick-up video.
- `create_input_upload({ generationId, filename, label, kind, referenceLabel?, groupLabel?, notes?, contentType?, displayOrder? })`: create an input row and return `{ assetId, uploadUrl, expiresAt }`. Kind is `image`, `audio`, `document`, or `other`.
- `set_video_status({ videoId, status })`: set `upload_pending`, `ready`, `published`, or `archived`.
- `set_video_featured({ videoId, featured })`: enable or disable official-site pick-up priority for an existing video.

IDs accepted by mutation tools are UUIDs returned by earlier tools. `studio_id` is user-facing and is not a mutation ID.

## Binary PUT

Send the file body to the returned one-time URL with its actual MIME type. Keep the URL out of command output.

```sh
curl --fail-with-body --silent --show-error \
  --request PUT \
  --header 'Content-Type: video/mp4' \
  --data-binary @path/to/video.mp4 \
  '<one-time-upload-url>'
```

Typical MIME types:

- MP4: `video/mp4`
- PNG: `image/png`
- JPEG: `image/jpeg`
- WAV: `audio/wav`
- MP3: `audio/mpeg`
- Plain prompt or notes: `text/plain; charset=utf-8`
- PDF: `application/pdf`

After PUT, verify with `get_episode`: status must be `ready` and `size_bytes` must be nonnull. Public media URLs are `/media/<videoId>` and `/inputs/<assetId>`.
