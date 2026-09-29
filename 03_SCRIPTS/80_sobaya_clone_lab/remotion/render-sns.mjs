import {bundle} from '@remotion/bundler';
import {openBrowser, selectComposition, renderMedia} from '@remotion/renderer';
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';

const m = JSON.parse(fs.readFileSync('src/sns-first-frame.json', 'utf8'));
const source = path.resolve('..', m.source);
const target = path.resolve('public', m.publicSource);
fs.mkdirSync('out', {recursive: true});
if (fs.existsSync(target)) fs.unlinkSync(target);
try { fs.linkSync(source, target); } catch { fs.copyFileSync(source, target); }
const serveUrl = await bundle({entryPoint: path.resolve('src/sns-first-frame.tsx')});
const browser = await openBrowser('chrome', {browserExecutable: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const picture = path.resolve('out/sns-picture.mp4');
try {
  const composition = await selectComposition({serveUrl, id: 'CloneLabSns', puppeteerInstance: browser});
  await renderMedia({serveUrl, composition, puppeteerInstance: browser, codec: 'h264', crf: 18, pixelFormat: 'yuv420p', outputLocation: picture});
} finally { await browser.close({silent: true}); }
// Keep the original AAC packets and timing; Remotion only renders the picture.
execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-i', picture, '-i', source, '-map', '0:v:0', '-map', '1:a:0', '-c', 'copy', '-movflags', '+faststart', path.resolve('..', m.output)], {stdio: 'inherit'});
console.log(m.output);
process.exit(0);
