"""Sobaya Hazard original score and combat Foley. Deterministic, no samples.
NumPy/SciPy instrument synthesis; editable note score and mix provenance emitted.
"""
from pathlib import Path
import hashlib,json,subprocess,wave
import numpy as np
from scipy.signal import butter,sosfilt
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'04_GAME_ASSETS/audio/hazard';TMP=ROOT/'.local/hazard-score';TMP.mkdir(parents=True,exist_ok=True)
SR=44100;BPM=80;BEAT=60/BPM;DURATION=48;N=int(SR*DURATION)
rng=np.random.default_rng(60649);notes=[];files=[]
def band(x,lo=40,hi=10000):return sosfilt(butter(2,[lo,hi],fs=SR,btype='bandpass',output='sos'),x)
def noise(n,lo=40,hi=10000):return band(rng.normal(0,1,n),lo,hi)
def hz(m):return 440*2**((m-69)/12)
def piano(m,dur,vel):
 t=np.arange(int(dur*SR))/SR;f=hz(m);v=np.zeros(len(t))
 for k in range(1,9):
  fk=f*k*np.sqrt(1+.00015*k*k)
  v+=np.sin(2*np.pi*fk*t+rng.uniform(0,.05))*np.exp(-t*(.7+k*.31))/k**1.65
 v+=noise(len(t),1300,7500)*np.exp(-t*100)*.08
 return v*(1-np.exp(-t*500))*vel

def bowed(m,dur,vel):
 t=np.arange(int(dur*SR))/SR;f=hz(m);v=np.zeros(len(t))
 for k in range(1,12):
  v+=(np.sin(2*np.pi*f*k*t+.018*k*np.sin(2*np.pi*4.5*t))+
      .55*np.sin(2*np.pi*f*k*1.0017*t+.3))/(k**1.7)
 env=np.sin(np.pi*np.minimum(1,t/dur))**1.6
 return v*env*vel

def metal(m,dur,vel):
 t=np.arange(int(dur*SR))/SR;v=np.zeros(len(t));f=hz(m)
 for k,(ratio,amp) in enumerate([(1,1),(2.71,.5),(4.08,.2),(5.43,.13)]):
  v+=np.sin(2*np.pi*f*ratio*t)*amp*np.exp(-t*(1.5+k*.8))
 return v*(1-np.exp(-t*1400))*vel

def drum(kind,vel):
 dur=1.7 if kind=='taiko' else .55;t=np.arange(int(dur*SR))/SR
 if kind=='taiko':
  phase=2*np.pi*(48*t+6*(1-np.exp(-t*35)))
  v=np.sin(phase)*np.exp(-t*5)+.45*np.sin(phase*1.51)*np.exp(-t*8)+.3*noise(len(t),120,3000)*np.exp(-t*38)
 else:
  v=noise(len(t),300,6500)*np.exp(-t*44)+.5*np.sin(2*np.pi*560*t)*np.exp(-t*65)
 return v*(1-np.exp(-t*2500))*vel

def add(dst,source,seconds,pan=0,wrap=True):
 pos=int(seconds*SR);l=np.sqrt((1-pan)/2);r=np.sqrt((1+pan)/2)
 if wrap:
  idx=(np.arange(len(source))+pos)%len(dst);dst[idx,0]+=source*l;dst[idx,1]+=source*r
 else:
  n=min(len(source),len(dst)-pos)
  if n>0:dst[pos:pos+n]+=source[:n,None]*np.array([l,r])

def room(x,wet,loop):
 result=x.copy();mono=(x[:,0]+x[:,1])*.5
 for i in range(30):
  delay=int((.043+i*.077+(i%3)*.011)*SR);gain=wet*np.exp(-i/7.5)*(.7 if i%2 else 1)
  for ch in range(2):
   d=delay+ch*int(.013*SR)
   if loop:result[:,ch]+=np.roll(mono,d)*gain
   else:result[d:,ch]+=mono[:-d]*gain if d<len(mono) else 0
 return result

def save(relative,x,loop=False,lufs=-20):
 dest=OUT/relative;dest.parent.mkdir(parents=True,exist_ok=True)
 # One static gain for music avoids pumping or mismatched loudness at loop seam.
 if x.ndim==1:x=x[:,None]
 peak=float(np.max(np.abs(x)));x=x/max(1,peak/0.88)
 raw=TMP/'master-input.wav'
 with wave.open(str(raw),'wb') as f:f.setparams((x.shape[1],2,SR,0,'NONE',''));f.writeframes((x*32767).astype('<i2').tobytes())
 analysis=subprocess.run(['ffmpeg','-hide_banner','-i',str(raw),'-af',f'loudnorm=I={lufs}:TP=-2:LRA=15:print_format=json','-f','null','-'],capture_output=True,text=True,check=True).stderr
 met=json.JSONDecoder().raw_decode(analysis[analysis.rindex('{'):])[0];gain=min(10**((lufs-float(met['input_i']))/20),.88/max(1e-9,float(np.max(np.abs(x)))))
 x*=gain
 if not loop:
  fade=min(len(x)//2,int(.006*SR));x[:fade]*=np.linspace(0,1,fade)[:,None];x[-fade:]*=np.linspace(1,0,fade)[:,None]
 pcm=(x*32767).astype('<i2')
 with wave.open(str(dest),'wb') as f:f.setparams((x.shape[1],2,SR,0,'NONE',''));f.writeframes(pcm.tobytes())
 files.append({'file':relative,'seconds':len(x)/SR,'channels':x.shape[1],'sample_rate':SR,'loop':loop,'peak':float(np.max(np.abs(x))),'rms':float(np.sqrt(np.mean(x*x))),'seam_delta':int(np.max(np.abs(pcm[0].astype(int)-pcm[-1].astype(int)))) if loop else None,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'target_lufs':lufs})
 print(relative,flush=True)

explore=np.zeros((N,2));chase=np.zeros_like(explore)
# D Phrygian pedal: two pieces may overlap anywhere without chord-phase clashes.
t=np.arange(N)/SR
for m,amp,pan in [(26,.055,-.2),(38,.035,.2),(45,.025,0),(50,.012,-.6)]:
 f=round(hz(m)*DURATION)/DURATION
 drone=amp*(np.sin(2*np.pi*f*t)+.22*np.sin(2*np.pi*f*2*t))*(.7+.3*np.cos(2*np.pi*t/16))
 add(explore,drone,0,pan);add(chase,drone*.8,0,pan)
# Symmetric periodic air is intentionally quiet; the regional ambience is separate.
freq=np.fft.rfftfreq(N,1/SR);spec=(rng.normal(size=len(freq))+1j*rng.normal(size=len(freq)))*np.exp(-(freq/1700)**2)*(1-np.exp(-(freq/180)**2))
air=np.fft.irfft(spec,n=N);air=air/max(np.std(air),1e-9)*.007
add(explore,air,0,-.65);add(explore,np.roll(air,7001),0,.65)
melody=[(0,62),(2.5,63),(6,57),(10.5,58),(16,62),(19,69),(22.5,63),(28,60),(32,62),(34.5,63),(38,57),(42.5,53),(48,57),(52,58),(56.5,63),(61,62)]
for beat,m in melody:
 pan=rng.uniform(-.4,.4);velocity=rng.uniform(.13,.19)
 add(explore,piano(m,5.5,velocity),beat*BEAT,pan)
 notes.append({'piece':'exploration','instrument':'felt piano','beat':beat,'midi':m,'velocity':round(velocity,3)})
for beat,m in [(5,74),(21,75),(37,81),(53,74)]:add(explore,metal(m,5,.014),beat*BEAT,.65 if beat%3 else -.65)
for beat,m in [(0,50),(8,57),(16,53),(24,51),(32,50),(40,57),(48,58),(56,51)]:
 add(explore,bowed(m,8,.023),beat*BEAT,-.4)
 add(chase,bowed(m,7,.047),beat*BEAT,.25)
# 16-bar percussion phrase with rests, grace hits, and 3+3+2 subdivisions.
for bar in range(16):
 energy=[.74,.78,.80,.87][bar%4]
 for off in [0,1.5,3]:
  add(chase,drum('taiko',.27*energy*rng.uniform(.9,1.08)),(bar*4+off)*BEAT+rng.uniform(-.009,.009),rng.uniform(-.15,.15))
 for off in [.75,2.5,3.5]:
  add(chase,drum('wood',.065*rng.uniform(.75,1)),(bar*4+off)*BEAT+rng.uniform(-.009,.009),(-.5 if off<2 else .5))
 for off,m in zip([0,.75,1.5,2.5,3,3.5],[38,38,39,45,38,46 if bar%4==3 else 45]):
  add(chase,piano(m,1.9,.14*energy),(bar*4+off)*BEAT,rng.uniform(-.22,.22))
  notes.append({'piece':'pursuit','instrument':'low plucked ostinato','beat':bar*4+off,'midi':m})
 if bar%4==3:
  for off in [2.75,3.25,3.75]:add(chase,drum('wood',.06),(bar*4+off)*BEAT,.6)
for beat,m in [(0,74),(6.5,75),(12,69),(18,70),(32,74),(38.5,75),(44,69),(58,75)]:
 add(chase,metal(m,4,.035),beat*BEAT,-.45)
 notes.append({'piece':'pursuit','instrument':'struck glass','beat':beat,'midi':m})
save('soundscape/exploration.wav',room(explore,.115,True),True,-24)
save('soundscape/tension.wav',room(chase,.055,True),True,-21)

for kind in ['shot','shotgun','mug_ready','mug_swing','mug_hit']:
 for variant in range(3):
  dur={'shot':1.1,'shotgun':1.55,'mug_ready':.36,'mug_swing':.32,'mug_hit':.62}[kind]
  n=int(dur*SR);u=np.arange(n)/SR
  if kind in ['shot','shotgun']:
   heavy=kind=='shotgun';pitch=(58 if heavy else 94)*rng.uniform(.93,1.06)
   crack=noise(n,750,17000)*np.exp(-u*(55 if heavy else 100))
   body=np.sin(2*np.pi*(pitch*u+1.4*(1-np.exp(-u*70))))*np.exp(-u*(15 if heavy else 25))
   blast=noise(n,90,1800)*np.exp(-u*(13 if heavy else 23))
   tail=noise(n,350,5000)*np.exp(-u*8)*(1-np.exp(-u*80))*.14
   mono=crack*.65+body*.65+blast*.9+tail
   # Breech/clack occurs after the main transient, not as a second explosion.
   start=.08 if heavy else .045;k=u-start
   mono+=np.where(k>0,noise(n,1800,12000)*np.exp(-np.maximum(k,0)*85)*.17,0)
  elif kind=='mug_ready':
   mono=noise(n,200,2700)*.08*np.sin(np.pi*u/dur)**2
   for start in [.025,.17]:
    q=np.maximum(0,u-start);env=(u>=start)*np.exp(-q*55)
    mono+=env*(np.sin(2*np.pi*1250*q)+.3*np.sin(2*np.pi*3130*q))*.05
  elif kind=='mug_swing':
   env=np.exp(-((u-.105)/.041)**2)
   mono=noise(n,180,6000)*env*.38+np.sin(2*np.pi*(130*u-30*u*u))*env*.07
  else:
   mono=noise(n,200,1800)*np.exp(-u*48)*.7+np.sin(2*np.pi*95*u)*np.exp(-u*27)*.58
   mono+=noise(n,1800,8500)*np.exp(-u*140)*.14
   # Intact thick glass rings briefly; no shattering or blood Foley.
   for ratio in [1,2.71,4.08]:mono+=np.sin(2*np.pi*(970+variant*43)*ratio*u)*np.exp(-u*35)*.022/ratio
  mono*=1-np.exp(-u*7000)
  # Spatial game attenuation is applied later; keep combat source mono.
  signal=room(np.column_stack([mono,mono]),.055,False).mean(axis=1)
  save(f'combat/{kind}_{variant}.wav',signal,lufs=-17 if kind in ['shot','shotgun'] else -23)
manifest={'version':2,'generator':'tools/build_hazard_score.py','seed':60649,'music':{'bpm':BPM,'meter':'4/4','bars':16,'seconds':DURATION,'mode':'D Phrygian','titles':{'exploration':'閉店後','pursuit':'ラストオーダー'},'instruments':'Felt piano, bowed partials, sub pedal, struck glass, membrane drum, wood percussion; original DSP synthesis','loop':'Circular note tails and stereo room; no repeated end fades'},'files':files,'score':notes}
(OUT/'score-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
# Existing regional beds and Takosan response keep their provenance.
p=OUT/'soundscape-manifest.json';existing=json.loads(p.read_text());existing['files']=[r for r in existing['files'] if r['file'] not in ['soundscape/tension.wav','soundscape/exploration.wav']];existing['files'] += [r for r in files if r['loop']];existing['score_manifest']='score-manifest.json';p.write_text(json.dumps(existing,ensure_ascii=False,indent=2)+'\n')
