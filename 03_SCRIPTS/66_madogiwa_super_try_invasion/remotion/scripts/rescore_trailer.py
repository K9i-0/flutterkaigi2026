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
src=read(P/'final_remotion_cm.mp4');base=read(P/'final_remotion_trailer_voice-v3.mp4');voc=read(O/'vocals.wav');manifest=json.loads((P/'remotion/src/trailer-voice-v3-manifest.json').read_text());base=base[:round(manifest['durationInFrames']/30*SR)];mix=base.copy();music40=np.zeros_like(src);rows=[]
for name,start,end in [('tokyo',143,279),('pilot',551,600),('hangar',723,987)]:
 a=round(start/30*SR);b=round(end/30*SR);d=(b-a)/SR;score=np.zeros((b-a,2));foley=np.zeros_like(score);events=[]
 if name=='tokyo':
  for n,g,pan in [(26,.16,-.2),(38,.07,.2),(45,.04,0)]:note(score,n,.06,2.4,g,'brass',pan)
  for t,g in [(.05,.40),(1.55,.19),(2.8,.31)]:add(score,impact(),t,g)
  for i,n in enumerate([50,51,50,45,50,51]):note(score,n,1.7+i*.28,.3,.035,'brass',(-1)**i*.45)
  add(foley,noise(d,280,6500),0,.018)
 elif name=='pilot':
  # Deliberately nearly silent, brief glass controls instead of invasion drone.
  for t,n in [(.15,74),(.72,69)]:note(score,n,t,.6,.028,'glass',-.3 if t<.5 else .3)
  add(foley,noise(d,170,900),0,.012)
  for t in [.12,.55,1.12]:add(foley,noise(.045,700,3500)*np.exp(-np.arange(round(.045*SR))/SR*100),t,.075)
 else:
  # Wide slow suspended harmony, no drum loop and no bass horn.
  for n,g,pan in [(50,.040,-.6),(57,.035,.6),(64,.028,-.25)]:note(score,n,0,5.4,g,'pad',pan)
  for n,g,pan in [(53,.038,.6),(60,.033,-.6),(67,.022,.25)]:note(score,n,4.0,d-4.0,g,'pad',pan)
  for t,n in [(1.0,74),(2.0,77),(2.8,81)]:note(score,n,t,2,.017,'glass',-.6+t*.4)
  for t in [1,2,2.8]:
   dur=d-t;tt=np.arange(round(dur*SR))/SR;flow=noise(dur,400,4800)*np.minimum(tt*2,1)*(.7+.3*np.sin(tt*9)**2);add(foley,flow,t,.014,-.5+t*.3)
 score=verb(score,.18 if name=='hangar' else .08)
 # Brief edge fades; retain all source speech, cautiously preserve end of city.
 clean=voc[a:b]+transients(src[a:b]-voc[a:b])+foley
 cue_gain={'tokyo':1.65,'pilot':.45,'hangar':1.4}[name]
 replacement=voc[a:b]+(clean-voc[a:b]+score)*cue_gain
 weight=np.ones(b-a);fade=round(.10*SR);weight[:fade]=np.linspace(0,1,fade);weight[-fade:]=np.linspace(1,0,fade)
 if name=='tokyo':
  fade=round(.4*SR);weight[-fade:]=np.linspace(1,0,fade)
 s=next(s for s in manifest['segments'] if s['kind']=='video' and s['sourceStart']<=start and s['sourceStart']+s['duration']>=end)
 dest=round((s['from']+start-s['sourceStart'])/30*SR);mix[dest:dest+b-a]=base[dest:dest+b-a]*(1-weight[:,None])+replacement*weight[:,None]
 music40[a:b]=score;wavfile.write(O/f'{name}_music.wav',SR,score.astype('float32'));wavfile.write(O/f'{name}_comparison_original.wav',SR,src[a:b]);wavfile.write(O/f'{name}_replacement.wav',SR,replacement.astype('float32'))
 rows.append(dict(name=name,sourceStartFrame=start,sourceEndFrame=end,trailerStartFrame=s['from']+start-s['sourceStart'],notes=events,originalRms=float(np.sqrt(np.mean(src[a:b]**2))),newRms=float(np.sqrt(np.mean(replacement**2)))))
peak=float(np.max(np.abs(mix)));assert peak<.98,peak
wavfile.write(O/'trailer_rescore_mix.wav',SR,mix.astype('float32'));wavfile.write(O/'original_score_40s.wav',SR,music40.astype('float32'))
# Verify all samples outside the three selected intervals are untouched before AAC encoding.
mask=np.zeros(len(base),bool)
for r in rows:
 a=round(r['trailerStartFrame']/30*SR);b=a+round((r['sourceEndFrame']-r['sourceStartFrame'])/30*SR);mask[a:b]=True
assert np.array_equal(base[~mask],mix[~mask])
record=dict(seed=660910,sampleRate=SR,method='NumPy/SciPy original synthesis; htdemucs voice + harmonic/transient residual; incomplete music/SFX separation',peak=peak,cues=rows,untouchedOutsideCues=True)
(P/'remotion/src/rescore-manifest.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
subprocess.run(['ffmpeg','-v','error','-i',str(P/'final_remotion_trailer_voice-v3.mp4'),'-i',str(O/'trailer_rescore_mix.wav'),'-map','0:v','-map','1:a','-c:v','copy','-c:a','aac','-b:a','192k','-ar','48000','-t','61.2','-movflags','+faststart','-y',str(P/'final_remotion_trailer_rescore.mp4')],check=True)
print(json.dumps(record,ensure_ascii=False))
