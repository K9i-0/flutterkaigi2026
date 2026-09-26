import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import crypto from 'node:crypto';
const source=path.resolve(process.argv[2] ?? '../.local/tidewater');
const revision='4811ba48d795197de5621985f404e765c0b7c0ef';
if(execFileSync('git',['-C',source,'rev-parse','HEAD'],{encoding:'utf8'}).trim()!==revision) throw Error('Use pinned Tidewater revision');
const {BANK}=await import(pathToFileURL(path.join(source,'src/audio/soundBank.js')));
const out=path.resolve('../04_GAME_ASSETS/audio/tidewater');
fs.mkdirSync(out,{recursive:true});
const manifest={source:'https://github.com/dgreenheck/tidewater',revision,format:'PCM s16le, mono, 32000 Hz',bank:{}};
for(const name of ['surf_far','wind','pier_lap','surf_crash','surf_wash','surf_backwash','gull','bird_forest','step_sand','step_wetsand','step_wood','step_grass','step_rock']) {
 const bank=BANK[name], input=path.join(source,'public/audio',bank.file);
 const entry={loop:bank.loop===true,clips:[],sourceSha256:crypto.createHash('sha256').update(fs.readFileSync(input)).digest('hex')};
 const slices=bank.slices ?? [null];
 for(let i=0;i<slices.length;i++) {
  const file=`${name}${bank.loop?'':`_${i}`}.wav`, slice=slices[i];
  const args=['-v','error','-y','-i',input];
  if(slice) args.push('-ss',String(slice[0]),'-t',String(slice[1]),'-af',`afade=t=in:d=0.015,afade=t=out:st=${Math.max(0,slice[1]-.04)}:d=0.04`);
  args.push('-ac','1','-ar','32000','-c:a','pcm_s16le',path.join(out,file));
  execFileSync('ffmpeg',args);
  entry.clips.push({file,lufs:bank.loop?bank.lufs:bank.lufs[i],...(slice?{start:slice[0],duration:slice[1]}:{})});
 }
 manifest.bank[name]=entry;
}
fs.copyFileSync(path.join(source,'public/audio/CREDITS.md'),path.join(out,'CREDITS-Tidewater.md'));
fs.writeFileSync(path.join(out,'bank.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(out);
