import {bundle} from '@remotion/bundler';
import {openBrowser, selectComposition, renderMedia} from '@remotion/renderer';
import path from 'node:path';
const serveUrl = await bundle({entryPoint: path.resolve('src/okayaman-patch.tsx')});
const browser = await openBrowser('chrome', {browserExecutable: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try {
  const composition = await selectComposition({serveUrl, id: 'OkayamanPatch', puppeteerInstance: browser});
  await renderMedia({serveUrl, composition, puppeteerInstance: browser, codec: 'h264', pixelFormat: 'yuv420p', outputLocation: 'out/okayaman_large_patch_comparison.mp4'});
} finally { await browser.close({silent: true}); }
process.exit(0);
