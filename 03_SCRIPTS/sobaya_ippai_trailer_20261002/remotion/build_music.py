"""Original quiet mallet/bass groove. Rebuildable soundtrack, no sampled music."""
import numpy as np,wave
from pathlib import Path
sr=48000;duration=34;n=sr*duration;mix=np.zeros(n,dtype=np.float64);rng=np.random.default_rng(42)
def add(start,frequency,length,gain,kind='mallet'):
 count=int(length*sr);t=np.arange(count)/sr
 if kind=='hat': sound=rng.normal(size=count)*np.exp(-t*65)*.2
 elif kind=='kick':sound=np.sin(2*np.pi*(45*t+2*(1-np.exp(-t*35))))*np.exp(-t*15)
 elif kind=='bass':sound=(np.sin(2*np.pi*frequency*t)+.2*np.sin(4*np.pi*frequency*t))*np.exp(-t*5)*(1-np.exp(-t*100))
 else:sound=(np.sin(2*np.pi*frequency*t)+.3*np.sin(2*np.pi*frequency*2.76*t))*np.exp(-t*7)*(1-np.exp(-t*180))
 i=int(start*sr);end=min(n,i+count)
 if i<n:mix[i:end]+=sound[:end-i]*gain
freq=lambda midi:440*2**((midi-69)/12)
beat=60/110
chords=[[62,65,69,72],[59,65,69,74],[60,64,67,71],[61,64,67,69]]; roots=[38,43,36,45]
for b in range(int(duration/beat)):
 chord=chords[(b//4)%4];start=b*beat
 add(start,0,.25,.16,'kick') if b%2==0 else None
 add(start+.5*beat,0,.15,.14,'hat')
 add(start,freq(roots[(b//4)%4]),.5,.13,'bass')
 if b%2==0:
  for j,midi in enumerate(chord):add(start+j*.018,freq(midi),1.2,.027)
 if b%4==3:add(start+.5*beat,freq(chord[2]+12),.7,.025)
fade=np.minimum(1,np.arange(n)/sr)*np.minimum(1,(n-np.arange(n))/sr/2)
mix=np.clip(mix*fade,-.8,.8)
with wave.open(str(Path(__file__).parent/'public/music.wav'),'wb') as f:f.setparams((1,2,sr,0,'NONE','not compressed'));f.writeframes((mix*32767).astype('<i2').tobytes())
