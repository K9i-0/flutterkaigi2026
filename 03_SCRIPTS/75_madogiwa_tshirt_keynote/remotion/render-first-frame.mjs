import {bundle} from '@remotion/bundler';
import {renderMedia, selectComposition} from '@remotion/renderer';
import {execFileSync} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

// Run from remotion/. Preserve the adopted v3 and copy its AAC stream unchanged.
for (const [source, target] of [
  ['../final_remotion_keynote_large.mp4', 'public/keynote_large_base.mp4'],
  ['../first_frame_sobaya_v3.png', 'public/first_frame_sobaya_v3.png'],
]) {
  if (!fs.existsSync(target)) fs.linkSync(source, target);
}
const serveUrl = await bundle({entryPoint: path.resolve('src/first-frame-entry.tsx')});
const browserExecutable = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const composition = await selectComposition({serveUrl, id: 'MadogiwaKeynoteLargeFirstFrame', browserExecutable});
let last = -1;
await renderMedia({serveUrl, composition, browserExecutable, codec: 'h264', crf: 16,
  pixelFormat: 'yuv420p', imageFormat: 'png', concurrency: 3,
  outputLocation: 'out/keynote-large-first-frame-silent.mp4',
  onProgress: p => {const percent = Math.floor(p.progress * 100); if (percent !== last) {last = percent; console.log('RENDER', percent);}},
});
execFileSync('ffmpeg', ['-y', '-v', 'error', '-i', 'out/keynote-large-first-frame-silent.mp4',
  '-i', '../final_remotion_keynote_large.mp4', '-map', '0:v:0', '-map', '1:a:0',
  '-c', 'copy', '-movflags', '+faststart', '../final_remotion_sns.mp4'], {stdio: 'inherit'});
