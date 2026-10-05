"""Rebuild the two Sobaya voice replacements; run with Irodori environment Python.
No TTS/API submission. Requires adopted WAVs, original video and cached htdemucs bed.
Recreate bed: OMP_NUM_THREADS=4 .local/Irodori-TTS/.venv/bin/python -m demucs
 --two-stems=vocals -n htdemucs --shifts 0 -d cpu
 -o .local/gyungyun86-voice/separated .local/gyungyun86-voice/original.wav
"""
from pathlib import Path
import hashlib,json,subprocess
import numpy as np
EP=Path(__file__).resolve().parent; ROOT=EP.parents[1]; WORK=ROOT/'.local/gyungyun86-voice'
SR=44100; FPS=30
VIDEO=EP/'wan3_isekai_seed861005_480p.mp4'
OUT=EP/'isekai_sobaya_irodori_720p.mp4'
MANIFEST=EP/'sobaya_audio_patch.json'
if OUT.exists(): raise SystemExit(f'Refusing overwrite: {OUT}')
def read(path):
 b=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','s16le','-ar',str(SR),'-ac','2','-'])
 return np.frombuffer(b,dtype='<i2').reshape(-1,2).copy()
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def at(frame):return round(frame/FPS*SR)
def active_rms(x):
 energy=np.mean(x.astype(np.float64)**2,axis=1);active=energy>32768**2*10**(-35/10)
 return float(np.sqrt(np.mean(energy[active])))
manifest=json.loads(MANIFEST.read_text());original=read(WORK/'original.wav');bed=read(WORK/'separated/htdemucs/original/no_vocals.wav');oldvoice=read(WORK/'separated/htdemucs/original/vocals.wav')
assert len(original)==len(bed)==len(oldvoice)
mix=original.astype(np.float64);changed=np.zeros(len(mix),dtype=bool)
first=read(EP/manifest['lines'][0]['audio'])
gain=active_rms(oldvoice[at(360):at(444)])/active_rms(first)
for line in manifest['lines']:
 a,b=map(at,line['replacement_frames']);start=at(line['insert_frame']);voice=read(EP/line['audio']).astype(np.float64)*gain
 assert a<=start and start+len(voice)<=b
 # Ambience-only boundary fades, inside inter-utterance gaps. Never fade/cut speech.
 n=round(.015*SR);fade=np.ones((b-a,1));fade[:n]=np.linspace(0,1,n)[:,None];fade[-n:]=np.linspace(1,0,n)[:,None]
 mix[a:b]=original[a:b]*(1-fade)+bed[a:b]*fade
 mix[start:start+len(voice)]+=voice;changed[a:b]=True
 line.update(audio_sha256=sha(EP/line['audio']),gain_db=float(20*np.log10(gain)),duration_seconds=len(voice)/SR,insert_sample=start,replacement_samples=[a,b])
assert np.max(np.abs(mix))<32767,'Clipping: reduce fixed gain explicitly'
pcm=np.rint(mix).astype('<i2');assert np.array_equal(pcm[~changed],original[~changed])
patched=WORK/'patched.wav'
subprocess.run(['ffmpeg','-y','-v','error','-f','s16le','-ar',str(SR),'-ac','2','-i','-','-c:a','pcm_s16le',str(patched)],input=pcm.tobytes(),check=True)
subprocess.run(['ffmpeg','-v','error','-i',str(VIDEO),'-i',str(patched),'-map','0:v:0','-map','1:a:0','-vf','scale=1280:720:flags=lanczos,setsar=1','-c:v','libx264','-crf','18','-preset','medium','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(OUT)],check=True)
manifest.update(output=OUT.name,output_sha256=sha(OUT),original_video_sha256=sha(VIDEO),pcm_frames=len(pcm),outside_intervals_pcm_identical=True,peak_dbfs=float(20*np.log10(np.max(np.abs(pcm.astype(float)))/32768)),background='source htdemucs no_vocals, CPU shifts0; 15ms boundary ambience-only fades',ordinary_timestretch=False,postprocess='canonical sobaya_monsterize.sh only: -5 semitones, atempo compensation, 70Hz tremolo, dynaudnorm',video='single Lanczos upscale from original 480p to 1280x720; original 30fps and all video frames preserved',auditory_review='not independently verified; ASR and PCM checks are separate from listening',source_video_unchanged=True)
MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'output':str(OUT),'outside_intervals_pcm_identical':True,'peak_dbfs':manifest['peak_dbfs'],'gain_db':20*np.log10(gain)},ensure_ascii=False))
