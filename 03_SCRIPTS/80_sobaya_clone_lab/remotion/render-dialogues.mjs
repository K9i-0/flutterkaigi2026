import {bundle} from '@remotion/bundler';
import {openBrowser,selectComposition,renderMedia} from '@remotion/renderer';
import fs from 'node:fs';
import path from 'node:path';
const m=JSON.parse(fs.readFileSync('src/dialogue-clips.json','utf8'));
fs.mkdirSync('public',{recursive:true});
const source=path.resolve('..',m.source), target=path.resolve('public',m.publicSource);
if(!fs.existsSync(target))fs.linkSync(source,target);
const serveUrl=await bundle({entryPoint:path.resolve('src/dialogue-clips.tsx')});
const browser=await openBrowser('chrome',{browserExecutable:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try{
 for(const clip of m.clips){
  const composition=await selectComposition({serveUrl,id:clip.id,puppeteerInstance:browser});
  await renderMedia({serveUrl,composition,puppeteerInstance:browser,codec:'h264',pixelFormat:'yuv420p',outputLocation:path.resolve('..',clip.output)});
  console.log(clip.output);
 }
}finally{await browser.close({silent:true});}
process.exit(0);
