"""Generate the approved Japanese lines with the canonical Irodori voice cast."""
from pathlib import Path
import subprocess,json,os
E=Path(__file__).resolve().parent
ROOT=E.parents[1]
(E/'voice_candidates/battle').mkdir(parents=True,exist_ok=True)
cast={'sobaya':('Sobaya',42),'yametaro':('Yametaro',7),'fukuchan':('Fukuchan',100),'yotan':('Yotan',100)}
for r in json.loads((E/'battle-dialogue.json').read_text()):
 name,seed=cast[r['speaker']];seed=r.get('seed',seed)
 out=E/f"battle_line{r['id']}_{r['speaker']}.wav"
 raw=E/'voice_candidates/battle'/f"{r['id']}.wav"
 if out.exists():continue
 if not raw.exists():
  subprocess.run([str(ROOT/'tools/irodori_speak.sh'),r.get('speechText',r['text']),str(raw),str(ROOT/f'02_CHARACTERS/{name}_voice.wav'),str(seed),r['caption']],cwd=ROOT,env={**os.environ,'HF_HUB_OFFLINE':'1'},check=True)
 if name=='Sobaya':subprocess.run([str(ROOT/'tools/sobaya_monsterize.sh'),str(raw),str(out)],check=True)
 else:out.write_bytes(raw.read_bytes())
 edits=json.loads((E/'battle-audio-tail-edits.json').read_text()) if (E/'battle-audio-tail-edits.json').exists() else {}
 if r['id'] in edits:
  end=edits[r['id']]['keepThroughSeconds'];fade=edits[r['id']]['fadeOutSeconds'];tmp=E/'voice_candidates/battle'/f"trim_{r['id']}.wav"
  subprocess.run(['ffmpeg','-y','-v','error','-i',str(out),'-af',f'atrim=end={end},afade=t=out:st={end-fade}:d={fade}','-c:a','pcm_s16le',str(tmp)],check=True);out.unlink();out.write_bytes(tmp.read_bytes())
 print('READY',out.name,flush=True)
