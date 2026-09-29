import { readFile, writeFile, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';

// Run prepare:clips first. Explicit --upload publishes the exact manifest assets.
const studio = resolve(import.meta.dirname, '..');
const catalogPath = resolve(studio, 'src/features/clips/catalog.json');
const catalog = JSON.parse(await readFile(catalogPath, 'utf8'));
const manifest = [];
const seen = new Set();
for (const clip of catalog) {
  for (const [field, name] of [['video', `${clip.id}.mp4`], ['poster', `${clip.id}.jpg`], ['source', `source-${clip.episode}.mp4`]]) {
    let asset = manifest.find(item => item.name === name);
    if (!seen.has(name)) {
      const file = resolve(studio, '.local/clips', name);
      const sha256 = createHash('sha256').update(await readFile(file)).digest('hex');
      const key = `clips/${sha256}/${name}`;
      asset = { name, path: `/clip-media/${sha256}/${name}`, key, bytes: (await stat(file)).size, contentType: name.endsWith('.mp4') ? 'video/mp4' : 'image/jpeg', downloadName: field === 'video' ? clip.filename : name };
      manifest.push(asset);
      seen.add(name);
    }
    clip[field] = asset.path;
  }
}
await writeFile(catalogPath, JSON.stringify(catalog, null, 2) + '\n');
await writeFile(resolve(studio, 'worker/clip-assets.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`${manifest.length} assets, ${(manifest.reduce((sum, item) => sum + item.bytes, 0) / 1024 / 1024).toFixed(1)} MiB`);
if (process.argv.includes('--upload')) {
  for (const asset of manifest) {
    execFileSync(resolve(studio, 'node_modules/.bin/wrangler'), ['r2', 'object', 'put', `madogiwa-studio-media/${asset.key}`, '--file', resolve(studio, '.local/clips', asset.name), '--remote', '--content-type', asset.contentType, '--cache-control', 'public, max-age=31536000, immutable'], { cwd: studio, stdio: 'inherit' });
  }
}
