import { env } from 'cloudflare:workers';
import { SELF } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { createEpisode, createVideo, setVideoStatus } from '../worker/repository';
import { listCatalog, queryCatalog } from '../worker/catalog-repository';
import { renderToStaticMarkup } from 'react-dom/server';
import Journal from '../src/official/journal';

async function seed(count: number) {
  const ids: string[] = [];
  for (let i = 0; i < count; i++) {
    const episode = await createEpisode(env.DB, { slug: crypto.randomUUID(), title: `Catalog ${i}`, memberIds: ['sobaya'] }, 'test');
    const generation = await env.DB.prepare('SELECT id FROM generations WHERE episode_id = ?').bind(episode.id).first<{ id: string }>();
    const video = await createVideo(env.DB, { generationId: generation!.id, filename: 'catalog.mp4', label: 'catalog', contentType: 'video/mp4', uploadedBy: 'test', featured: i % 2 === 0 });
    await setVideoStatus(env.DB, video.id, 'ready');
    await env.DB.prepare("UPDATE episodes SET display_order = ?, created_at = '2026-09-15T00:00:00Z' WHERE id = ?").bind(i, episode.id).run();
    ids.push(episode.id);
  }
  return ids;
}

describe('bounded public catalog', () => {
  it('paginates stable ordering in both directions, filters before limiting, and invalidates cached results', async () => {
    // Isolate this catalog from migration seed content.
    await env.DB.prepare("UPDATE episodes SET status = 'archived'").run();
    const ids = await seed(40);
    const first = await listCatalog(env.DB, { all: true });
    expect(first.episodes.map(e => e.id)).toEqual(ids.slice(0, 18));
    expect(first.previous).toBeUndefined();
    expect(first.next).toBeDefined();
    expect(first.episodes[0]).not.toHaveProperty('generation_count');
    expect(first.episodes[0]).not.toHaveProperty('video_count');
    const second = await listCatalog(env.DB, { all: true, cursor: first.next });
    expect(second.episodes.map(e => e.id)).toEqual(ids.slice(18, 36));
    const last = await listCatalog(env.DB, { all: true, cursor: second.next });
    expect(last.episodes.map(e => e.id)).toEqual(ids.slice(36));
    expect(last.next).toBeUndefined();
    const back = await listCatalog(env.DB, { all: true, cursor: second.previous, backwards: true });
    expect(back.episodes.map(e => e.id)).toEqual(ids.slice(0, 18));
    expect(back.previous).toBeUndefined();
    const pickup = await listCatalog(env.DB, { member: 'sobaya' });
    expect(pickup.episodes.map(e => e.id)).toEqual(ids.filter((_, i) => i % 2 === 0).slice(0, 18));
    expect(pickup.next).toBeDefined();
    expect((await queryCatalog(env.DB, { all: true, member: 'fukuchan' })).episodes).toEqual([]);
    await env.DB.prepare("UPDATE episodes SET status = 'archived' WHERE id = ?").bind(ids[0]).run();
    expect((await listCatalog(env.DB, { all: true })).episodes.map(e => e.id)).toEqual(ids.slice(1, 19));
    const response = await SELF.fetch('http://localhost/?page=movies&scope=all');
    const html = await response.text();
    expect(response.status).toBe(200);
    expect(html.match(/class="j-movie"/g)).toHaveLength(18);
    expect(html).not.toContain('動画を検索');
    expect(html).not.toContain('ジャンルで絞り込む');
  }, 30_000);

  it('renders compact filters and cursor links for every theme', () => {
    for (const theme of ['sakaba', 'excel', 'underground'] as const) {
      const html = renderToStaticMarkup(<Journal episodes={[]} galleryItems={[]} initialTheme={theme} initialHref='/?page=movies&scope=all&member=sobaya' catalog={{ episodes: [], next: '[1,"date","id"]' }} />);
      expect(html).toContain('j-catalog-controls');
      expect(html).toContain('登場人物で絞り込む');
      expect(html).toContain('scope=all');
      expect(html).toContain('member=sobaya');
      expect(html).toContain('after=');
      expect(html).not.toContain('動画を検索');
    }
  });
});
