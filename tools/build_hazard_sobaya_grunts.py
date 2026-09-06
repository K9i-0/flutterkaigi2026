"""Canonical Sobaya beer moans, resumable Irodori generation and provenance."""
from pathlib import Path
import hashlib,json,os,subprocess,wave
ROOT=Path(__file__).resolve().parent.parent
RAW=ROOT/'.local/hazard-score/grunts';RAW.mkdir(parents=True,exist_ok=True)
OUT=ROOT/'04_GAME_ASSETS/audio/hazard/combat';OUT.mkdir(parents=True,exist_ok=True)
ref=ROOT/'02_CHARACTERS/Sobaya_voice.wav'
assert hashlib.sha256(ref.read_bytes()).hexdigest()=='976916e670fea5fcf0f741d45e150eaf055c3b0e11d240e3be656dd724166b58'
rows=[]
for i,(text,caption) in enumerate([
 ('ビール、ビール。','息を切らし、ビールを求める低い声。二回のビールを、それぞれはっきり発音する。'),
 ('ビール！','相手に迫りながら、低く荒い声で短く叫ぶ。'),
], start=1):
 request={'text':text,'caption':caption,'seed':42,'reference':'02_CHARACTERS/Sobaya_voice.wav','model':'Aratako/Irodori-TTS-v4.1-Small'}
 ident=hashlib.sha256(json.dumps(request,ensure_ascii=False).encode()).hexdigest()[:16]
 raw=RAW/f'{ident}.wav'
 if not raw.exists():
  with (RAW/f'{ident}.log').open('w') as log:
   subprocess.run([str(ROOT/'.claude/skills/seedance/scripts/irodori_speak.sh'),text,str(raw),str(ref),'42',caption],cwd=ROOT,env={**os.environ,'HF_HUB_OFFLINE':'1'},stdout=log,stderr=subprocess.STDOUT,check=True)
 monster=RAW/f'{ident}-monster.wav'
 subprocess.run([str(ROOT/'.claude/skills/seedance/scripts/sobaya_monsterize.sh'),str(raw),str(monster)],check=True)
 dest=OUT/f'enemy_{i}.wav'
 # Retain the voice identity and canonical monster processing. Short room tail.
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(monster),'-af','highpass=f=65,lowpass=f=6500,aecho=0.85:0.8:43|89:0.12|0.06,loudnorm=I=-20:TP=-3:LRA=9','-ar','24000','-ac','1','-c:a','pcm_s16le',str(dest)],check=True)
 with wave.open(str(dest)) as f:seconds=f.getnframes()/f.getframerate()
 rows.append({**request,'file':f'combat/{dest.name}','seconds':seconds,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'raw_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'postprocess':'canonical -5 semitones/70Hz tremolo; HP65 LP6500; 43/89ms room; -20 LUFS / -3 dBTP'})
 print(dest.name,seconds,flush=True)
# Derive a slower, darker distance moan from the clearly articulated single word.
source=OUT/'enemy_2.wav';dest=OUT/'enemy_0.wav'
subprocess.run(['ffmpeg','-y','-v','error','-i',str(source),'-af','atempo=0.78,lowpass=f=4800,loudnorm=I=-21:TP=-3:LRA=9','-ar','24000','-ac','1','-c:a','pcm_s16le',str(dest)],check=True)
with wave.open(str(dest)) as f:seconds=f.getnframes()/f.getframerate()
rows.insert(0, {**rows[-1], 'file':'combat/enemy_0.wav','seconds':seconds,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'derived_from':'combat/enemy_2.wav','variation':'tempo 0.78 without pitch shift, lowpass 4800Hz, -21 LUFS; two canonical takes yield three gameplay variants'})
(OUT/'grunts-manifest.json').write_text(json.dumps({'version':1,'clips':rows},ensure_ascii=False,indent=2)+'\n')
