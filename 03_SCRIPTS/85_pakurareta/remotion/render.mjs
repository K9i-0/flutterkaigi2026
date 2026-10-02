import {execFileSync} from 'node:child_process';
import {mkdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const cwd=fileURLToPath(new URL('.',import.meta.url));
mkdirSync(new URL('out',import.meta.url),{recursive:true});
execFileSync('npx',['remotion','render','src/index.ts','PakuraretaAudioEdit','out/rendered.wav','--codec=wav','--overwrite'],{cwd,stdio:'inherit'});
// Export directly from the original 480p source to the standard 720p deliverable.
execFileSync('ffmpeg',['-y','-v','error','-i','public/input.mp4','-i','out/rendered.wav','-map','0:v:0','-map','1:a:0','-vf','scale=1280:720:flags=lanczos,setsar=1','-c:v','libx264','-preset','slow','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart','../final_remotion_audio_v2_720p.mp4'],{cwd,stdio:'inherit'});
