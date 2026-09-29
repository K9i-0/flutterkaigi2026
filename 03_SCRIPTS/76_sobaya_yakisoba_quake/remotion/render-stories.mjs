import {bundle} from '@remotion/bundler';
import {openBrowser,selectComposition,renderMedia} from '@remotion/renderer';
import fs from 'node:fs';
import path from 'node:path';
const m=JSON.parse(fs.readFileSync('src/story-clips.json','utf8'));
fs.mkdirSync('public',{recursive:true});
for(const clip of m.clips)if(!fs.existsSync('public/'+clip.publicSource))fs.linkSync('../'+clip.source,'public/'+clip.publicSource);
const serveUrl=await bundle({entryPoint:path.resolve('src/story-clips.tsx')});
const browser=await openBrowser('chrome',{browserExecutable:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try{
 for(const clip of m.clips){
  const outputLocation=path.resolve('../../00_REPLY_CLIPS',clip.output);
  fs.mkdirSync(path.dirname(outputLocation),{recursive:true});
  const composition=await selectComposition({serveUrl,id:clip.id,puppeteerInstance:browser});
  await renderMedia({serveUrl,composition,puppeteerInstance:browser,codec:'h264',pixelFormat:'yuv420p',concurrency:2,outputLocation});
  console.log(clip.output);
 }
}finally{await browser.close({silent:true});}
process.exit(0);
