"""Render a 20-second sound demo and audit 105 loud rocket/music combinations."""
from pathlib import Path
import json, wave, hashlib
import numpy as np
from scipy.signal import resample_poly
R=Path(__file__).resolve().parents[1]; A=R/'04_GAME_ASSETS/audio/hazard'; SR=44100

def read(p):
 with wave.open(str(p)) as f:
  channels=f.getnchannels(); rate=f.getframerate()
  x=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').reshape(-1,channels)/32768
 if rate!=SR:
  from math import gcd
  g=gcd(rate,SR);x=resample_poly(x,SR//g,rate//g)
 if channels==1:x=np.repeat(x,2,axis=1)
 return x
n=SR*20;t=np.arange(n)/SR
intensity=np.where(t<3,0,1-np.exp(-np.maximum(0,t-3)/.28))
explore=read(A/'soundscape/exploration.wav')[:n]
chase=read(A/'soundscape/tension.wav')[:n]
impact=np.ones(n);fx=np.zeros((n,2))
def add(cue,sec,gain):
 x=read(A/('combat/'+cue+'.wav'));i=round(sec*SR);m=min(len(x),n-i);fx[i:i+m]+=x[:m]*gain
add('alert',3,.60)
for i,sec in enumerate([9,11,13]):
 add('rocket_launch_'+str(i),sec,.88)
 add('rocket_blast_'+str(i),sec+.45,.90/(1+(.45*14/10)**2))
 for trigger,strength in [(sec,1),(sec+.45,1/(1+(.45*14/10)**2))]:
  q=t-trigger
  duck=np.where(q<0,1,1-.42*strength*np.exp(-np.maximum(q-.1,0)/.32))
  impact=np.minimum(impact,duck)
music=(explore*(.4*np.cos(intensity*np.pi/2))[:,None]+chase*(.5*np.sin(intensity*np.pi/2))[:,None])*impact[:,None]
mix=music+fx
peak=float(np.max(np.abs(mix)))
assert peak<.98,peak
mix*=np.minimum(1,t/.03)[:,None]*np.minimum(1,(20-t)/1.3)[:,None]
p=R/'.local/audio-polish-20260907/audio-preview.wav'
p.parent.mkdir(parents=True,exist_ok=True)
with wave.open(str(p),'wb') as f:
 f.setparams((2,2,SR,0,'NONE',''));f.writeframes(np.round(mix*32767).astype('<i2').tobytes())
# Each authored offset through the full loop and all launcher variants; this is
# a finite offline mix check, not a claim that every possible runtime mix passes.
checks=[];bg=read(A/'soundscape/tension.wav')*.5
for v in range(3):
 launch=read(A/f'combat/rocket_launch_{v}.wav')*.88
 blast=read(A/f'combat/rocket_blast_{v}.wav')*.90
 for delay in [.05,.2,.5,1,1.5]:
  for sec in [0,3,7,12,24,36,43]:
   y=bg[round(sec*SR):round(sec*SR)+SR*4].copy()
   y[:len(launch)]+=launch
   start=round(delay*SR);end=min(len(y),start+len(blast))
   y[start:end]+=blast[:end-start]/(1+(14*delay/10)**2)
   checks.append({'variant':v,'delay':delay,'scoreSecond':sec,'samplePeak':float(np.max(np.abs(y))),
                  'oversampledPeak':float(np.max(np.abs(resample_poly(y,4,1))))})
report={'preview':str(p.relative_to(R)),'previewPeak':peak,'mixes':len(checks),'worst':max(checks,key=lambda c:c['oversampledPeak']),
 'note':'105 full-gain launch/impact/background combinations without music duck; no dialogue/ambience. Not a guarantee for all concurrent game audio.'}
assert report['worst']['oversampledPeak']<1, report['worst']
(R/'21_SOBAYA_HAZARD_LAB/qa/audio-polish-mix-20260907.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
