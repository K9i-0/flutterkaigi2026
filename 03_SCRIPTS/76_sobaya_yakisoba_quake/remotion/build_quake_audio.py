from pathlib import Path
import subprocess, json, wave, hashlib
import numpy as np
ROOT=Path(__file__).resolve().parent
m=json.loads((ROOT/'src/edit-manifest-revision04.json').read_text());q=m['earthquake'];sr=48000
source=ROOT/'public'/q['source']
# Reuse existing Wan earthquake noise, with no new synthesized sound.
def extract(filt):
 cmd=['ffmpeg','-v','error','-ss',str(q['sourceSampleStart']),'-i',str(source),'-t',str(q['sourceSampleDuration']),'-af',filt,'-ac','2','-ar',str(sr),'-f','f32le','-']
 return np.frombuffer(subprocess.check_output(cmd),dtype='<f4').reshape(-1,2).copy()
def tiled(x,n):
 cross=round(.045*sr);out=x.copy()
 while len(out)<n:
  fade=np.linspace(0,1,cross)[:,None]
  out[-cross:]=out[-cross:]*(1-fade)+x[:cross]*fade
  out=np.concatenate([out,x[cross:]])
 return out[:n]
start=round(q['startFrame']/30*sr);end=round(q['stopFrame']/30*sr);n=end-start
low=extract('highpass=f=32,lowpass=f=145,lowpass=f=145')
upper=extract('highpass=f=1800,lowpass=f=6500')
def rms(x):return float(np.sqrt(np.mean(x*x)))
low=tiled(low,n);upper=tiled(upper,n)
low*=0.047/max(rms(low),1e-8);upper*=0.014/max(rms(upper),1e-8)
fx=low+upper
# Duck beneath Fukuchan, Yametaro and Sobaya dialogue. Time values are in original replacement video.
duck=np.ones(n)
for a,b in [(4.25,6.55),(6.65,9.05),(10.5,12.4),(12.75,13.65)]:
 a=round((a+277/30)*sr)-start;b=round((b+277/30)*sr)-start
 a=max(0,a);b=min(n,b)
 if b>a:
  edge=min(round(.065*sr),(b-a)//2)
  duck[a:b]*=.48
  if edge:
   duck[a:a+edge]=np.linspace(1,.48,edge);duck[b-edge:b]=np.linspace(.48,1,edge)
fx*=duck[:,None]
fade=round(.18*sr);fx[:fade]*=np.linspace(0,1,fade)[:,None]
# Two-millisecond terminal fade avoids clicks while keeping an abrupt stop.
fade=round(.002*sr);fx[-fade:]*=np.linspace(1,0,fade)[:,None]
assert np.max(np.abs(fx))<.99
out=np.zeros((30*sr,2));out[start:end]=fx
path=ROOT/'public'/q['soundFile']
with wave.open(str(path),'wb') as f:
 f.setnchannels(2);f.setsampwidth(2);f.setframerate(sr);f.writeframes((np.clip(out,-1,1)*32767).astype('<i2').tobytes())
record={'source':str(source.relative_to(ROOT)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sample_start':q['sourceSampleStart'],'sample_duration':q['sourceSampleDuration'],'output':str(path.relative_to(ROOT)),'peak':float(np.max(np.abs(out))),'zero_before_start':bool(np.all(out[:start]==0)),'zero_after_stop':bool(np.all(out[end:]==0)),'processing':'band filtering, crossfade loops, dialogue ducking; no speed or pitch changes, no synthesis'}
(ROOT/'quake-audio-manifest.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
