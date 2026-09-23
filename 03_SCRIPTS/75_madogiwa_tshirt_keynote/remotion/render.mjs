import {bundle} from '@remotion/bundler';
import {openBrowser,selectComposition,renderStill,renderMedia} from '@remotion/renderer';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const mode=process.argv[2]||'stills';
const noJobs=process.argv[3]==='nojobs';const suffix=noJobs?'-nojobs':'';const prefix=noJobs?'nojobs':'keynote';
const browserExecutable='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const chromiumOptions={gl:'angle'};
const serveUrl=await bundle({entryPoint:path.resolve('src/index.tsx'),webpackOverride:c=>({...c,resolve:{...c.resolve,alias:{...c.resolve?.alias,'three$':require.resolve('three').replace('three.cjs','three.module.js')}}})});
const browser=await openBrowser('chrome',{browserExecutable,chromiumOptions});
try{
 const composition=await selectComposition({serveUrl,id:noJobs?'MadogiwaNoJobs':'MadogiwaKeynote',puppeteerInstance:browser});
 const m=JSON.parse(fs.readFileSync(`src/edit-manifest${suffix}.json`,'utf8'));
 if(mode==='stills'||mode==='crop'){
  for(const id of (mode==='crop'?['first','detail']:['intro','first','repeat1','understand','reveal','arms','detail','all'])){
   const l=m.lines.find(x=>x.id===id);const frame=l.start+Math.min(25,l.end-l.start-1);
   await renderStill({serveUrl,composition,puppeteerInstance:browser,frame,imageFormat:'png',output:`out/${prefix}-check-${id}.png`});
   console.log('STILL',id,frame);
  }
  await renderStill({serveUrl,composition,puppeteerInstance:browser,frame:m.durationInFrames-28,imageFormat:'png',output:`out/${prefix}-check-endcard.png`});
 }else{
  const preview=mode==='preview';const l=m.lines.find(x=>x.id==='repeat2');
  let last=-1;
  await renderMedia({serveUrl,composition,puppeteerInstance:browser,chromiumOptions,codec:'h264',crf:18,pixelFormat:'yuv420p',audioBitrate:'192k',imageFormat:'jpeg',jpegQuality:92,concurrency:3,outputLocation:`out/${prefix}-${preview?'preview':'master'}.mp4`,...(preview?{frameRange:[l.start,m.lines.find(x=>x.id==='reveal').end+85]}:{}),onProgress:p=>{const pc=Math.floor(p.progress*100);if(pc!==last){last=pc;console.log('RENDER',pc+'%',p.renderedFrames,'frames');}}});
 }
}finally{await browser.close({silent:true});}
