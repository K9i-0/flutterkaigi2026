import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
const m=JSON.parse(fs.readFileSync('src/edit-manifest.json','utf8'));let cursor=0;
for(const s of m.shots){if(s.startFrame!==cursor||s.endFrame<=s.startFrame)throw Error('Shot gap/overlap');cursor=s.endFrame;const info=JSON.parse(execFileSync('ffprobe',['-v','error','-show_entries','format=duration','-of','json',`public/${s.source}`]));if((s.trimBefore+s.endFrame-s.startFrame)/m.composition.fps>Number(info.format.duration))throw Error('Source too short');}
if(cursor!==m.composition.durationInFrames)throw Error('Wrong total');
let last=0;for(const c of m.captions){if(c.startFrame<last||c.endFrame>cursor)throw Error('Caption overlap/out of range');const seconds=Number(execFileSync('ffprobe',['-v','error','-show_entries','format=duration','-of','csv=p=0',`public/${c.audio}`]));if(seconds*m.composition.fps>c.endFrame-c.startFrame)throw Error('Clipped speech');last=c.endFrame;}
console.log('Timeline, source lengths and narration windows OK.');
