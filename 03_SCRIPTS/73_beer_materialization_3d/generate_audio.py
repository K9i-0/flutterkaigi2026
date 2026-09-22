from pathlib import Path
import subprocess,json,os
ROOT=Path(__file__).resolve().parents[2]
EP=Path(__file__).resolve().parent
lines=json.loads((EP/'remotion/src/dialogue.json').read_text())
(EP/'voice_candidates').mkdir(exist_ok=True)
(EP/'remotion/public/audio').mkdir(parents=True,exist_ok=True)
tail_edits={x['line']:x for x in json.loads((EP/'audio-tail-edits.json').read_text())} if (EP/'audio-tail-edits.json').exists() else {}
for row in lines:
 raw=EP/'voice_candidates'/f"{row['id']}.wav"
 out=EP/f"line{row['id']}_{row['speaker']}.wav"
 soba=row['speaker']=='sobaya'
 caption='大真面目に修業の経験を語る。落ち着いて、少し誇らしげに。' if soba else '脱力した関西弁で、呆れたようにユーモラスにツッコむ。'
 caption=row.get('caption',caption)
 if not out.exists() and not raw.exists():
  subprocess.run([str(ROOT/'tools/irodori_speak.sh'),row['text'].replace('\n',''),str(raw),str(ROOT/'02_CHARACTERS'/('Sobaya_voice.wav' if soba else 'Yametaro_voice.wav')),'42' if soba else '7',caption],cwd=ROOT,env={**os.environ,'HF_HUB_OFFLINE':'1'},check=True)
 if not out.exists():
  if soba: subprocess.run([str(ROOT/'tools/sobaya_monsterize.sh'),str(raw),str(out)],check=True)
  else: out.write_bytes(raw.read_bytes())
  if row['id'] in tail_edits:
   edit=tail_edits[row['id']];end=edit['keepThroughSeconds'];fade=edit['fadeOutSeconds']
   filtered=EP/'voice_candidates'/f"{row['id']}_trimmed.wav"
   af=f"atrim=end={end},afade=t=out:st={end-fade}:d={fade}"
   if edit.get('trailingSilenceSeconds'):af+=f",apad=pad_dur={edit['trailingSilenceSeconds']}"
   subprocess.run(['ffmpeg','-y','-v','error','-i',str(out),'-af',af,'-c:a','pcm_s16le',str(filtered)],check=True)
   os.replace(filtered,out)
 dest=EP/'remotion/public/audio'/out.name
 if dest.exists() and not os.path.samefile(out,dest):dest.unlink()
 if not dest.exists():os.link(out,dest)
 print('READY',out.name,flush=True)
