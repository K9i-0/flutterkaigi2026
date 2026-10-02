import {bundle} from '@remotion/bundler';
import {openBrowser,selectComposition,renderStill,renderMedia} from '@remotion/renderer';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import path from 'node:path';
fs.mkdirSync('out',{recursive:true});
const serveUrl=await bundle({entryPoint:path.resolve('src/index.tsx')});
const browser=await openBrowser('chrome',{browserExecutable:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try {
 const composition=await selectComposition({serveUrl,id:'IppaiTrailer',puppeteerInstance:browser});
 const common={serveUrl,composition,puppeteerInstance:browser,timeoutInMilliseconds:120000};
 if(process.argv[2]==='stills')for(const frame of [45,200,370,520,700,900])await renderStill({...common,frame,imageFormat:'png',output:`out/frame-${frame}.png`});
 else await renderMedia({...common,codec:'h264',pixelFormat:'yuv420p',crf:18,audioCodec:'aac',audioBitrate:'192k',concurrency:1,offthreadVideoThreads:1,outputLocation:'out/render-master.mp4',onProgress:({progress})=>{if(Math.round(progress*100)%10===0)process.stdout.write(`\r${Math.round(progress*100)}%`);}});
 if(process.argv[2]!=='stills')execFileSync('ffmpeg',['-v','error','-y','-i','out/render-master.mp4','-c:v','copy','-af','volume=3.5dB','-c:a','aac','-b:a','192k','-ar','48000','-movflags','+faststart','../final_remotion_trailer.mp4']);
}finally{await browser.close({silent:true});}
