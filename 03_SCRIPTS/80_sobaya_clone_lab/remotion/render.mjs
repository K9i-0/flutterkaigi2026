import {bundle} from '@remotion/bundler';
import {openBrowser,selectComposition,renderStill,renderMedia} from '@remotion/renderer';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import path from 'node:path';
const mode=process.argv[2]||'preview';
if(mode==='full'&&!fs.existsSync('public/input.mp4'))throw new Error('本編未生成。採用した30秒映像をpublic/input.mp4へ配置してください。');
fs.mkdirSync('out',{recursive:true});
const serveUrl=await bundle({entryPoint:path.resolve('src/index.tsx')});
const browser=await openBrowser('chrome',{browserExecutable:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try{
 const id=(mode==='full'||mode==='film-stills')?'CloneLabFilm':mode==='alpha'?'ScannerOverlay':'ScannerPreview';
 const composition=await selectComposition({serveUrl,id,puppeteerInstance:browser});
 if(mode==='film-stills'){
  for(const frame of [348,360,390,432,480,486])await renderStill({serveUrl,composition,puppeteerInstance:browser,frame,imageFormat:'png',output:`out/audit/film-${frame}.png`});
 }else if(mode==='stills'){
  for(const frame of [34,35,60,79,80,84,114,115,135])await renderStill({serveUrl,composition,puppeteerInstance:browser,frame,imageFormat:'png',output:`out/v2-scan-${frame}.png`});
  const overlay=await selectComposition({serveUrl,id:'ScannerOverlay',puppeteerInstance:browser});
  await renderStill({serveUrl,composition:overlay,puppeteerInstance:browser,frame:135,imageFormat:'png',output:'out/v2-overlay.png'});
 }else await renderMedia({serveUrl,composition,puppeteerInstance:browser,codec:mode==='alpha'?'prores':'h264',...(mode==='alpha'?{proResProfile:'4444',pixelFormat:'yuva444p10le',imageFormat:'png'}:{pixelFormat:'yuv420p'}),outputLocation:mode==='full'?'../final_remotion_clone_lab.mp4':mode==='alpha'?'../scanner_overlay_alpha_v2.mov':'../final_remotion_scanner_preview_v2.mp4'});
}finally{await browser.close({silent:true});}
if(mode==='full'){
 const final='../final_remotion_clone_lab.mp4';
 const intermediate='out/film-remotion-audio.mp4';
 fs.renameSync(final,intermediate);
 // Preserve the original AAC timeline instead of Remotion's re-encoded audio delay.
 execFileSync('ffmpeg',['-v','error','-y','-i',intermediate,'-i','public/input.mp4','-map','0:v:0','-map','1:a:0','-c','copy','-t','30','-movflags','+faststart',final]);
}
// Rendering and browser cleanup are complete; release bundler handles in this CLI.
process.exit(0);
