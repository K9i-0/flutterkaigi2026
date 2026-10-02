"""Reproduce the voice-only patch; requires NumPy, FFmpeg and the recorded Demucs bed."""
from pathlib import Path
import json,subprocess,hashlib
import numpy as np
EP=Path(__file__).resolve().parent; ROOT=EP.parents[1]; WORK=ROOT/'.local/ep84-takosan-patch'; SR=48000
VIDEO=EP/'wan3_past_v2_seed840102_480p.mp4'; OUT=EP/'final_past_takosan_irodori.mp4'
def read(p):
 return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ar',str(SR),'-ac','2','-']),dtype='<f4').reshape(-1,2).copy()
def write(p,x):
 subprocess.run(['ffmpeg','-y','-v','error','-f','f32le','-ar',str(SR),'-ac','2','-i','-','-c:a','pcm_s16le',str(p)],input=x.astype('<f4').tobytes(),check=True)
original=read(WORK/'original.wav'); voice=read(EP/'takosan_irodori_line.wav'); bed=read(WORK/'separated/htdemucs/target/no_vocals.wav'); oldvoice=read(WORK/'separated/htdemucs/target/vocals.wav')
# Source boundaries are inside detected inter-phrase silences. Target anchors are frames at 30fps.
segments=[(0,1.0,585),(1.45,2.50,620),(3.20,3.84,666)]
start_frame,end_frame=580,690; a=round(start_frame/30*SR); b=round(end_frame/30*SR)
mix=original.copy(); background=bed[a-18*SR:b-18*SR].copy()
# Crossfade only ambience/room-tone at silent replacement boundaries, never phonemes.
n=round(.05*SR);fade=np.ones((b-a,1));fade[:n]=np.linspace(0,1,n)[:,None];fade[-n:]=np.linspace(1,0,n)[:,None]
mix[a:b]=original[a:b]*(1-fade)+background*fade
# Fixed gain match using active-voice samples, excluding inter-phrase silence.
def rms_active(x):
 mono=np.mean(x*x,axis=1); active=mono>10**(-35/10); return np.sqrt(np.mean(mono[active]))
gain=float(rms_active(oldvoice[round(1.5*SR):round(4.75*SR)])/rms_active(voice))
for lo,hi,frame in segments:
 clip=voice[round(lo*SR):round(hi*SR)]*gain;at=round(frame/30*SR);mix[at:at+len(clip)]+=clip
assert np.max(np.abs(mix))<1,'clipping'
assert np.array_equal(mix[:a],original[:a]) and np.array_equal(mix[b:],original[b:])
write(WORK/'patched.wav',mix)
subprocess.run(['ffmpeg','-y','-v','error','-i',str(VIDEO),'-i',str(WORK/'patched.wav'),'-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','192k','-movflags','+faststart',str(OUT)],check=True)
report=dict(output=OUT.name,model='Aratako/Irodori-TTS-v4.1-Small',model_reason='reproduce episode80 user-adopted A voice',seed=43,text='なかまなる。ぎゅんされる。えらべ。',caption='',cfg_text=5,uncut=True,duration_scale=1,reference='takosan_irodori_reference_ep80.wav',source_audio='takosan_irodori_line.wav',reference_sha256=hashlib.sha256((EP/'takosan_irodori_reference_ep80.wav').read_bytes()).hexdigest(),source_sha256=hashlib.sha256((EP/'takosan_irodori_line.wav').read_bytes()).hexdigest(),replacement_frames=[start_frame,end_frame],fps=30,segments=[dict(source_start=x,source_end=y,target_start_frame=z) for x,y,z in segments],gain_db=20*np.log10(gain),time_stretch=False,pitch_shift=False,outside_interval_pcm_identical=True,video='stream copy',ambience='htdemucs no_vocals from source seconds18-24, shifts0 CPU; 50ms ambience-only boundary fades',auditory_review='not independently verified',lip_sync='phrase anchors aligned; exact phoneme sync not guaranteed')
(EP/'takosan_audio_patch.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False,indent=2))
