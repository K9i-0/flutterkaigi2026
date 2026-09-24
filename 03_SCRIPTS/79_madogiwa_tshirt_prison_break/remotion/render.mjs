import {bundle} from '@remotion/bundler';
import {openBrowser,selectComposition,renderStill,renderMedia} from '@remotion/renderer';
import fs from 'node:fs';
import path from 'node:path';
const mode=process.argv[2]||'preview';
if(mode==='full'&&(!fs.existsSync('public/input_v3.mp4')||!fs.existsSync('public/final_audio_v3.wav')))throw new Error('Wan映像を生成・監査し、public/input.mp4へhardlinkまたはコピーしてから実行してください。');
fs.mkdirSync('out',{recursive:true});
const serveUrl=await bundle({entryPoint:path.resolve('src/index.tsx')});
const browser=await openBrowser('chrome',{browserExecutable:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try{
 const composition=await selectComposition({serveUrl,id:(mode==='full'||mode==='audit')?'MadogiwaPrisonBreakV3':'PrisonBreakEndcard',puppeteerInstance:browser});
 if(mode==='audit'){
  const m=JSON.parse(fs.readFileSync('src/edit-manifest.json','utf8'));
  const frames=[...new Set([0,329,330,584,585,749,750,899,900,936,989,...m.captions.flatMap(c=>[Math.max(0,c.startFrame-1),c.startFrame,c.startFrame+4,c.endFrame-1,c.endFrame])])];
  for(const frame of frames)await renderStill({serveUrl,composition,puppeteerInstance:browser,frame,imageFormat:'png',output:`out/audit-${frame}.png`});
 }else if(mode==='stills'){
  for(const frame of [0,6,29,36,89])await renderStill({serveUrl,composition,puppeteerInstance:browser,frame,imageFormat:'png',output:`out/endcard-${frame}.png`});
 }else await renderMedia({serveUrl,composition,puppeteerInstance:browser,codec:'h264',pixelFormat:'yuv420p',outputLocation:mode==='full'?'../final_remotion_prison_break_v3.mp4':'out/endcard-preview.mp4'});
}finally{await browser.close({silent:true});}
