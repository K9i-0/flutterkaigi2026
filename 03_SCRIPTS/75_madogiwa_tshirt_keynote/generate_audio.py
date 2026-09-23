"""Canonical Sobaya TTS; validate content/settings fingerprints before reuse."""
from pathlib import Path
import hashlib,json,os,subprocess
EP=Path(__file__).resolve().parent;ROOT=EP.parents[1]
rows=json.loads((EP/'remotion/src/dialogue.json').read_text());record=EP/'audio-generation.json'
old={r['id']:r for r in json.loads(record.read_text())} if record.exists() else {}
candidates=EP/'voice_candidates';candidates.mkdir(exist_ok=True)
ref=ROOT/'02_CHARACTERS/Sobaya_voice.wav';refsha=hashlib.sha256(ref.read_bytes()).hexdigest();log=[]
for row in rows:
 ident={'text':row['text'],'speechText':row['speechText'],'reference':'02_CHARACTERS/Sobaya_voice.wav','referenceSha256':refsha,'model':'Aratako/Irodori-TTS-v4.1-Small','seed':row['seed'],'caption':row['caption'],'durationScale':1.0,'textCFG':3.0,'uncut':False,'postprocess':'tools/sobaya_monsterize.sh'}
 fingerprint=hashlib.sha256(json.dumps(ident,ensure_ascii=False,sort_keys=True).encode()).hexdigest()
 raw=candidates/f"{row['id']}_raw.wav";out=EP/f"line_{row['id']}_sobaya.wav"
 if out.exists() and old.get(row['id'],{}).get('fingerprint')!=fingerprint:
  previous=hashlib.sha256(out.read_bytes()).hexdigest()[:12]
  out.rename(candidates/f"{row['id']}_previous_{previous}.wav")
  if raw.exists():raw.rename(candidates/f"{row['id']}_previous_{previous}_raw.wav")
 if not out.exists():
  subprocess.run([str(ROOT/'tools/irodori_speak.sh'),row['speechText'],str(raw),str(ref),str(row['seed']),row['caption']],cwd=ROOT,env={**os.environ,'HF_HUB_OFFLINE':'1','UV_CACHE_DIR':str(ROOT/'.local/keynote-uv-cache'),'IRODORI_UNCUT':'0','IRODORI_DURATION_SCALE':'1.0','IRODORI_CFG_SCALE_TEXT':'3'},check=True)
  subprocess.run([str(ROOT/'tools/sobaya_monsterize.sh'),str(raw),str(out)],check=True)
 duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(out)]))
 log.append({'id':row['id'],'speaker':'sobaya',**ident,'fingerprint':fingerprint,'duration':duration,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
 print('READY',row['id'],round(duration,2),flush=True)
record.write_text(json.dumps(log,ensure_ascii=False,indent=2)+'\n')
