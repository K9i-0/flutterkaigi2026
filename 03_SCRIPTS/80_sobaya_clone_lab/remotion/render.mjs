import {bundle} from '@remotion/bundler';
import {openBrowser,selectComposition,renderStill,renderMedia} from '@remotion/renderer';
import fs from 'node:fs';
import path from 'node:path';
const mode=process.argv[2]||'preview';
fs.mkdirSync('out',{recursive:true});
const serveUrl=await bundle({entryPoint:path.resolve('src/index.tsx')});
const browser=await openBrowser('chrome',{browserExecutable:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try{
 const id=mode==='alpha'?'ScannerOverlay':'ScannerPreview';
 const composition=await selectComposition({serveUrl,id,puppeteerInstance:browser});
 if(mode==='stills'){
  for(const frame of [29,85,120,169,170,219,220,270])await renderStill({serveUrl,composition,puppeteerInstance:browser,frame,imageFormat:'png',output:`out/scan-${frame}.png`});
  const overlay=await selectComposition({serveUrl,id:'ScannerOverlay',puppeteerInstance:browser});
  await renderStill({serveUrl,composition:overlay,puppeteerInstance:browser,frame:270,imageFormat:'png',output:'out/overlay.png'});
 }else await renderMedia({serveUrl,composition,puppeteerInstance:browser,codec:mode==='alpha'?'prores':'h264',...(mode==='alpha'?{proResProfile:'4444',pixelFormat:'yuva444p10le',imageFormat:'png'}:{pixelFormat:'yuv420p'}),outputLocation:mode==='alpha'?'../scanner_overlay_alpha.mov':'../final_remotion_scanner_preview.mp4'});
}finally{await browser.close({silent:true});}
// Rendering and browser cleanup are complete; release bundler handles in this CLI.
process.exit(0);
