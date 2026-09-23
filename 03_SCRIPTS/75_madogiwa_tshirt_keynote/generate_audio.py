"""Canonical character TTS; validate content/settings fingerprints before reuse."""
from pathlib import Path
import hashlib,json,os,subprocess,argparse
EP=Path(__file__).resolve().parent;ROOT=EP.parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--variant',choices=['sobaya','nojobs'],default='sobaya');args=parser.parse_args();is_nojobs=args.variant=='nojobs';suffix='-nojobs' if is_nojobs else '';speaker='yametaro' if is_nojobs else 'sobaya'
rows=json.loads((EP/f'remotion/src/dialogue{suffix}.json').read_text());record=EP/f'audio-generation{suffix}.json'
old={r['id']:r for r in json.loads(record.read_text())} if record.exists() else {}
candidates=EP/'voice_candidates';candidates.mkdir(exist_ok=True)
reference='02_CHARACTERS/Yametaro_voice.wav' if is_nojobs else '02_CHARACTERS/Sobaya_voice.wav'
ref=ROOT/reference;refsha=hashlib.sha256(ref.read_bytes()).hexdigest();log=[]
for row in rows:
 ident={'text':row['text'],'speechText':row['speechText'],'reference':reference,'referenceSha256':refsha,'model':'Aratako/Irodori-TTS-v4.1-Small','seed':row['seed'],'caption':row['caption'],'durationScale':row.get('durationScale',1.0),'textCFG':row.get('textCFG',5.0 if is_nojobs else 3.0),'uncut':is_nojobs,'postprocess':None if is_nojobs else 'tools/sobaya_monsterize.sh'}
 fingerprint=hashlib.sha256(json.dumps(ident,ensure_ascii=False,sort_keys=True).encode()).hexdigest()
 raw=candidates/f"{row['id']}{suffix}_raw.wav";out=EP/f"line_{row['id']}_{speaker}.wav"
 if out.exists() and old.get(row['id'],{}).get('fingerprint')!=fingerprint:
  previous=hashlib.sha256(out.read_bytes()).hexdigest()[:12]
  out.rename(candidates/f"{row['id']}{suffix}_previous_{previous}.wav")
  if raw.exists():raw.rename(candidates/f"{row['id']}{suffix}_previous_{previous}_raw.wav")
 if not out.exists():
  subprocess.run([str(ROOT/'tools/irodori_speak.sh'),row['speechText'],str(raw),str(ref),str(row['seed']),row['caption']],cwd=ROOT,env={**os.environ,'HF_HUB_OFFLINE':'1','UV_CACHE_DIR':str(ROOT/'.local/keynote-uv-cache'),'IRODORI_UNCUT':'1' if is_nojobs else '0','IRODORI_DURATION_SCALE':str(ident['durationScale']),'IRODORI_CFG_SCALE_TEXT':str(ident['textCFG'])},check=True)
  if is_nojobs:out.write_bytes(raw.read_bytes())
  else:subprocess.run([str(ROOT/'tools/sobaya_monsterize.sh'),str(raw),str(out)],check=True)
 duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(out)]))
 log.append({'id':row['id'],'speaker':speaker,**ident,'fingerprint':fingerprint,'duration':duration,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
 record.write_text(json.dumps(log,ensure_ascii=False,indent=2)+'\n')
 print('READY',row['id'],round(duration,2),flush=True)
record.write_text(json.dumps(log,ensure_ascii=False,indent=2)+'\n')
