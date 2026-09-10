"""Deterministic original three-cue SF score; preserve narration/cards and picture.
Requires local htdemucs stems in out/rescore. Separation is imperfect: retain vocals,
attenuate steady harmonic accompaniment, keep transient texture, add designed Foley.
"""
from pathlib import Path
import json,subprocess,hashlib
import numpy as np
from scipy import signal,ndimage
from scipy.io import wavfile
P=Path(__file__).resolve().parents[2];O=P/'remotion/out/rescore';SR=44100
rng=np.random.default_rng(660910);events=[]
def read(p):
 b=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ar',str(SR),'-ac','2','-f','f32le','-']);return np.frombuffer(b,'<f4').reshape(-1,2).copy()
def hz(n):return 440*2**((n-69)/12)
def tone(note,d,kind):
 t=np.arange(round(d*SR))/SR;f=hz(note);x=np.zeros(len(t))
 if kind=='brass':
  for k in range(1,10):x+=np.sin(2*np.pi*f*k*t+.013*k*np.sin(t*29))/k**1.25
  x*= (1-np.exp(-t*20))*np.exp(-t*1.3)*np.minimum(1,(d-t)*8)
 elif kind=='glass':
  for ratio,g in [(1,1),(2.71,.3),(4.08,.1)]:x+=g*np.sin(2*np.pi*f*ratio*t)*np.exp(-t*4)
  x*=1-np.exp(-t*300)
 else:
  for k in range(1,6):
   x+=(np.sin(2*np.pi*f*k*t+.2*np.sin(t*3))+np.sin(2*np.pi*f*k*1.002*t+.4))/k**2
  x*=np.sin(np.pi*t/d)**1.5
 return x

def noise(d,lo,hi):
 x=rng.normal(size=round(d*SR));return signal.sosfilt(signal.butter(2,[lo,hi],fs=SR,btype='bandpass',output='sos'),x)
def impact(d=1.8):
 t=np.arange(round(d*SR))/SR;return (np.sin(2*np.pi*(43*t+1.8*(1-np.exp(-t*25))))*np.exp(-t*4)+noise(d,100,2400)*np.exp(-t*20)*.55)*(1-np.exp(-t*700))
def add(dst,x,start,g=.1,pan=0):
 a=round(start*SR);n=min(len(x),len(dst)-a)
 if n>0:dst[a:a+n]+=x[:n,None]*g*np.sqrt(np.array([(1-pan)/2,(1+pan)/2]))
def note(dst,n,start,d,g,kind,pan=0):add(dst,tone(n,d,kind),start,g,pan);events.append(dict(note=n,start=start,duration=d,gain=g,instrument=kind))
def verb(x,wet):
 y=x.copy()
 for i in range(12):
  d=round((.09+i*.13)*SR)
  if d<len(x):y[d:]+=x[:-d,::-1]*wet*np.exp(-i/3)
 return y

def transients(x):
 result=np.zeros_like(x)
 for c in range(2):
  _,_,z=signal.stft(x[:,c],SR,nperseg=2048,noverlap=1536);mag=np.abs(z)
  h=ndimage.median_filter(mag,size=(1,31));p=ndimage.median_filter(mag,size=(31,1));mask=p**2/(p**2+2*h**2+1e-10)
  _,y=signal.istft(z*(.10+.62*mask),SR,nperseg=2048,noverlap=1536);result[:,c]=y[:len(x)]
 return result
# Three original compositions for hangar through beer commercial finale.
C=O/'candidates';C.mkdir(exist_ok=True)
source=read(P/'final_remotion_cm.mp4');voc=read(O/'vocals.wav');base=read(P/'final_remotion_trailer_rescore.mp4')[:round(61.2*SR)]
original=read(P/'final_remotion_trailer_voice-v3.mp4')[:len(base)]
start=723;split=987;end=1200;dur=(end-start)/30
x=source[round(start/30*SR):round(end/30*SR)];v=voc[round(start/30*SR):round(end/30*SR)]
residual=transients(x-v);clean=v+residual*.8
# Keep narration and original dark-card effects sample-for-sample; cue continues after card.
spans=[(1161,264,0),(1623,213,264)]
records=[]
def string(n,d):
 t=np.arange(round(d*SR))/SR;f=hz(n);y=np.zeros(len(t))
 for k in range(1,9):y+=(np.sin(2*np.pi*f*k*t+.022*k*np.sin(t*31))+np.sin(2*np.pi*f*k*1.003*t+.7))/k**1.65
 return y*(1-np.exp(-t*70))*np.exp(-t*8)*np.minimum(1,(d-t)*20)
def cymbal(d):
 t=np.arange(round(d*SR))/SR;return noise(d,4000,16000)*np.exp(-t*2)*(1-np.exp(-t*300))
for number,name,bpm in [(1,'艦隊の凱旋',108),(2,'星々の祝杯',78),(3,'ビール回収作戦',144)]:
 rng=np.random.default_rng(660920+number);events=[];score=np.zeros((round(dur*SR),2));beat=60/bpm
 # Four evolving harmonies, final D major arrival supports the product reveal.
 chords=([[50,57,62,65],[46,53,58,62],[48,55,60,64],[50,57,62,66]] if number!=2 else [[50,57,61,64],[47,54,59,62],[43,50,57,62],[50,57,62,66]])
 times=[0,3.2,6.4,8.8,12.5]
 for j in range(4):
  onset=times[j];length=times[j+1]-onset+.7
  for k,n in enumerate(chords[j]):note(score,n,onset,min(length,dur-onset),.04 if number==2 else .027,'pad',(k-1.5)*.4)
 # final chord under product shot (source 36.6 => cue12.5)
 for k,n in enumerate([38,50,57,62,66,69]):note(score,n,12.5,dur-12.5,.037 if number==2 else .03,'pad',(k-2.5)*.25)
 if number==1:
  melody=[(0,62,.8),(1.1,69,.8),(2.2,74,1),(3.3,70,.7),(4.4,69,.7),(5.5,65,1),(6.6,67,.65),(7.5,72,1),(8.8,74,1.1),(10.0,76,.9),(11.1,78,1),(12.5,74,2.5)]
  for t,n,d in melody:note(score,n,t,d,.072,'brass',-.12);note(score,n-12,t,d,.035,'brass',.12)
  for i,t in enumerate(np.arange(0,12.5,beat)):
   add(score,impact(),t,.24 if i%4==0 else .10,(-1)**i*.25)
   n=chords[min(3,int(t/3.2))][i%4];add(score,string(n+12,.32),t+.22,.038,(-1)**i*.5)
 elif number==2:
  for j,(t,n) in enumerate([(0,74),(1.5,81),(3.1,78),(4.7,74),(6.3,79),(7.8,83),(9.4,81),(11,86),(12.5,86)]):note(score,n,t,min(2.7,dur-t),.035,'glass',(-1)**j*.55)
  for t in [0,3.2,6.4,8.8,12.5]:add(score,impact(2.5),t,.15)
  for t,n in [(6.4,67),(8.8,69),(10.4,73),(12.5,74)]:note(score,n,t,min(3.0,dur-t),.052,'brass',0)
 else:
  for i,t in enumerate(np.arange(0,12.5,beat/2)):
   ch=chords[min(3,int(t/3.2))];n=ch[[0,2,1,3,2,1,3,2][i%8]]
   add(score,string(n+12,.25),t,.047*(.7+.3*t/12.5),(-1)**i*.6)
   if i%2==0:add(score,impact(.7),t,.19 if i%8==0 else .085)
   if i%4==2:add(score,noise(.1,1800,10000)*np.exp(-np.arange(round(.1*SR))/SR*40),t,.065,.3)
  for t,n in [(0,50),(3.2,58),(6.4,60),(8.8,62),(10.4,69),(12.5,74)]:note(score,n,t,1.5,.068,'brass',0)
 # Arrival accent and tail; never a constant full-volume drone.
 add(score,impact(2),12.5,.30);add(score,cymbal(2.8),12.5,.12)
 score=verb(score,.20 if number==2 else .1)
 fade=round(.55*SR);score[-fade:]*=np.linspace(1,0,fade)[:,None]
 # Equal integrated musical RMS among candidates for fair comparison, peak-safe.
 gain=min(.095/max(1e-9,np.sqrt(np.mean(score**2))),.62/max(1e-9,np.abs(score).max()));score*=gain
 # Dialogue intelligibility: beer speech source33.1–35.9, announcer36.6 onward.
 t=np.arange(len(score))/SR+24.1;duck=np.interp(t,[24.1,32.9,33.0,33.1,35.9,36.1,36.5,36.6,39.0,39.2,40],[1,1,1,.33,.33,1,1,.32,.32,1,1]);mus=score*duck[:,None]
 combined=clean+mus
 # Reduce only new mix if necessary; do not touch earlier scenes/cards.
 peak=np.abs(combined).max()
 if peak>.91:combined*=.91/peak
 mix=base.copy();isolated=np.zeros_like(base)
 for destf,nf,off in spans:
  a=round(destf/30*SR);n=round(nf/30*SR);o=round(off/30*SR);repl=combined[o:o+n].copy();w=np.ones(n);f=round(.055*SR);w[:f]=np.linspace(0,1,f);w[-f:]=np.linspace(1,0,f)
  mix[a:a+n]=base[a:a+n]*(1-w[:,None])+repl*w[:,None];isolated[a:a+n]=mus[o:o+n]
 # Final black card preserved; prior section preserved.
 assert np.array_equal(mix[1425*1470:1623*1470],base[1425*1470:1623*1470])
 assert np.array_equal(mix[:1161*1470],base[:1161*1470])
 wavfile.write(C/f'candidate_{number}_mix.wav',SR,mix.astype('float32'));wavfile.write(C/f'candidate_{number}_music.wav',SR,score.astype('float32'))
 output=P/f'final_remotion_trailer_score_{number}.mp4'
 subprocess.run(['ffmpeg','-v','error','-i',str(P/'final_remotion_trailer_rescore.mp4'),'-i',str(C/f'candidate_{number}_mix.wav'),'-map','0:v','-map','1:a','-c:v','copy','-c:a','aac','-b:a','192k','-ar','48000','-t','61.2','-movflags','+faststart','-y',str(output)],check=True)
 preview=P/f'preview_trailer_score_{number}.mp4'
 subprocess.run(['ffmpeg','-v','error','-ss','38.7','-i',str(output),'-t','22.5','-c:v','libx264','-crf','18','-c:a','aac','-b:a','192k','-movflags','+faststart','-y',str(preview)],check=True)
 records.append(dict(candidate=number,title=name,bpm=bpm,seed=660920+number,notes=events,musicGain=float(gain),peak=float(np.abs(mix).max()),fullVideo=output.name,preview=preview.name));print(name,flush=True)
(P/'remotion/src/score-candidates-manifest.json').write_text(json.dumps(dict(status='three unadopted candidates',source='final_remotion_trailer_rescore.mp4',sourceFrames=[723,1200],trailerSpans=spans,method='original DSP synthesis; htdemucs voice plus transient residual; dark card untouched',candidates=records),ensure_ascii=False,indent=2)+'\n')
