import {execFileSync} from 'node:child_process';
import {mkdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const cwd=fileURLToPath(new URL('.',import.meta.url));
mkdirSync(new URL('out',import.meta.url),{recursive:true});
execFileSync('npx',['remotion','render','src/index.ts','PakuraretaAudioEdit','out/rendered.wav','--codec=wav','--overwrite'],{cwd,stdio:'inherit'});
// Audio-only edit: retain the original video bitstream, including every frame.
execFileSync('ffmpeg',['-y','-v','error','-i','public/input.mp4','-i','out/rendered.wav','-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','192k','-movflags','+faststart','../final_remotion_audio_v2.mp4'],{cwd,stdio:'inherit'});
