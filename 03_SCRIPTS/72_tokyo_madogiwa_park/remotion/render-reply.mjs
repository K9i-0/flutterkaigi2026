import {bundle} from '@remotion/bundler';
import {openBrowser,selectComposition,renderMedia} from '@remotion/renderer';
import fs from 'node:fs';
import path from 'node:path';
const m=JSON.parse(fs.readFileSync('src/reply-clip.json','utf8'));
fs.mkdirSync('public',{recursive:true});
if(!fs.existsSync('public/'+m.publicSource))fs.linkSync('../'+m.source,'public/'+m.publicSource);
const outputLocation=path.resolve('../../00_REPLY_CLIPS',m.output);
fs.mkdirSync(path.dirname(outputLocation),{recursive:true});
const serveUrl=await bundle({entryPoint:path.resolve('src/reply-clip.tsx')});
const browser=await openBrowser('chrome',{browserExecutable:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try{
 const composition=await selectComposition({serveUrl,id:m.id,puppeteerInstance:browser});
 await renderMedia({serveUrl,composition,puppeteerInstance:browser,codec:'h264',pixelFormat:'yuv420p',outputLocation});
 console.log(outputLocation);
}finally{await browser.close({silent:true});}
process.exit(0);
