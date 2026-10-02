// Recreate local public hardlinks. Recorded videos must exist in ../capture/.
import fs from 'node:fs';
import path from 'node:path';
const pairs=[['../capture/perfect.mp4','perfect.mp4'],['../capture/spill2.mp4','spill.mp4']];
for(const name of fs.readdirSync('..').filter(n=>/^clip.*\.wav$/.test(n)))pairs.push([`../${name}`,name]);
for(const name of ['pour','clink','spill'])pairs.push([`../../../25_SOBAYA_IPPAI/assets/audio/${name}.wav`,`${name}.wav`]);
fs.mkdirSync('public',{recursive:true});
for(const [src,name]of pairs){const target=path.join('public',name);if(fs.existsSync(target))fs.unlinkSync(target);try{fs.linkSync(src,target);}catch{fs.copyFileSync(src,target);}}
