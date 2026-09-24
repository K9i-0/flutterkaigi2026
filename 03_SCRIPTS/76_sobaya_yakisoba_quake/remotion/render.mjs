import {bundle} from '@remotion/bundler';
import {openBrowser,selectComposition,renderMedia} from '@remotion/renderer';
import path from 'node:path';
const revision=process.argv[2] || '02';
if (!['02','03','04'].includes(revision)) throw new Error('Unknown revision');
const serveUrl=await bundle({entryPoint:path.resolve('src/index.tsx')});
const browser=await openBrowser('chrome',{browserExecutable:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try {
 const composition=await selectComposition({serveUrl,id:`SobayaQuakeRevision${revision}`,puppeteerInstance:browser});
 let last=-1;
 await renderMedia({serveUrl,composition,puppeteerInstance:browser,codec:'h264',crf:16,audioBitrate:'192k',pixelFormat:'yuv420p',concurrency:3,outputLocation:`../final_remotion_revision${revision}.mp4`,onProgress:p=>{const pc=Math.floor(p.progress*10)*10;if(pc!==last){last=pc;console.log('Render',pc+'%');}}});
} finally {await browser.close({silent:true});}
