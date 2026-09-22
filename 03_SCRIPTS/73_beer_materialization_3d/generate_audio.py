from pathlib import Path
import subprocess,json,os
ROOT=Path(__file__).resolve().parents[2]
EP=Path(__file__).resolve().parent
lines=json.loads((EP/'remotion/src/dialogue.json').read_text())
for row in lines:
 raw=EP/'voice_candidates'/f"{row['id']}.wav"
 out=EP/f"line{row['id']}_{row['speaker']}.wav"
 soba=row['speaker']=='sobaya'
 caption='大真面目に修業の経験を語る。落ち着いて、少し誇らしげに。' if soba else '脱力した関西弁で、呆れたようにユーモラスにツッコむ。'
 if not raw.exists():
  subprocess.run([str(ROOT/'tools/irodori_speak.sh'),row['text'].replace('\n',''),str(raw),str(ROOT/'02_CHARACTERS'/('Sobaya_voice.wav' if soba else 'Yametaro_voice.wav')),'42' if soba else '7',caption],cwd=ROOT,env={**os.environ,'HF_HUB_OFFLINE':'1'},check=True)
 if not out.exists():
  if soba: subprocess.run([str(ROOT/'tools/sobaya_monsterize.sh'),str(raw),str(out)],check=True)
  else: out.write_bytes(raw.read_bytes())
 dest=EP/'remotion/public/audio'/out.name
 if not dest.exists():os.link(out,dest)
 print('READY',out.name,flush=True)
