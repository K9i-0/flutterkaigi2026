"""Original deterministic loop beds and Takosan's nonverbal response.
Run with an environment containing numpy. No sampled or third-party audio.
"""
from pathlib import Path
import hashlib, json, wave
import numpy as np
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT/'04_GAME_ASSETS/audio/hazard'
RATE = 24000
DURATION = 16
N = RATE * DURATION
rng = np.random.default_rng(90449)
t = np.arange(N) / RATE

def noise(lo, hi):
    frequencies = np.fft.rfftfreq(N, 1/RATE)
    spec = rng.normal(size=len(frequencies)) + 1j*rng.normal(size=len(frequencies))
    spec *= np.exp(-np.square(frequencies/hi)) * (1-np.exp(-np.square(frequencies/lo)))
    result = np.fft.irfft(spec, n=N)
    return result / np.std(result)

def pulse(center, width):
    distance = (t-center+DURATION/2) % DURATION-DURATION/2
    return np.exp(-np.square(distance/width))

rows=[]
def save(relative, samples, peak, loop=False):
    samples=samples/max(1e-9, np.max(np.abs(samples)))*peak
    pcm=(samples*32767).astype('<i2')
    dest=OUT/relative;dest.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(dest),'wb') as f:
        f.setparams((1,2,RATE,0,'NONE','not compressed'));f.writeframes(pcm.tobytes())
    rows.append({'file':relative, 'seconds':len(pcm)/RATE,
       'peak':float(np.max(np.abs(samples))), 'rms':float(np.sqrt(np.mean(samples*samples))),
       'loop':loop, 'seam_delta':int(abs(int(pcm[0])-int(pcm[-1]))) if loop else None,
       'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})

wind=noise(35,850)*(.13+.045*np.sin(2*np.pi*t/16))
wood=sum(.13*pulse(c,.4)*np.sin(2*np.pi*hz*t+1.2*np.sin(2*np.pi*t/16)) for c,hz in [(3,147),(9,193),(13,161)])
save('soundscape/village.wav',wind+wood,.5,True)
wind=noise(70,1400)*(.09+.035*np.sin(2*np.pi*t/8))
insects=.014*np.sin(2*np.pi*3210*t)*np.power(.5+.5*np.sin(2*np.pi*7*t),8)*(.5+.5*np.sin(2*np.pi*t/16))
metal=sum(.06*pulse(c,.13)*np.sin(2*np.pi*hz*t) for c,hz in [(5,771),(11,1123)])
save('soundscape/farm.wav',wind+insects+metal,.5,True)
wind=noise(25,470)*(.14+.06*np.sin(2*np.pi*t/16))
water=noise(300,3600)*.018
for c,hz in [(1,921),(4.4,1237),(8.8,853),(13,1161)]:
    water+=.10*pulse(c,.027)*np.sin(2*np.pi*hz*t)
save('soundscape/mountain.wav',wind+water,.5,True)
# 90 BPM, 24 beats, sparse low D-minor ostinato; each oscillator is periodic.
score=np.zeros(N)
for beat in range(24):
    center=beat*2/3
    score+=.14*pulse(center,.065)*np.sin(2*np.pi*48*t)
    if beat%2==0:
        hz=[73.4375,87.3125,110,82.4375][(beat//2)%4]
        score+=.11*pulse(center+.13,.24)*(np.sin(2*np.pi*hz*t)+.17*np.sin(2*np.pi*hz*2*t))
score+=.035*np.sin(2*np.pi*36.6875*t)*(.6+.4*np.sin(2*np.pi*t/8))
save('soundscape/tension.wav',score,.65,True)
u=np.arange(int(.85*RATE))/RATE
response=np.zeros_like(u)
for start,hz in [(0.06,320),(.28,410),(.49,285)]:
    local=np.maximum(0,u-start)
    envelope=np.where(u>=start,np.exp(-local*20)*(1-np.exp(-local*120)),0)
    response+=envelope*np.sin(2*np.pi*(hz*local+35*(1-np.exp(-local*15))))
response*=np.sin(np.pi*u/.85)**.5
save('voice/takosan_response.wav',response,.55)
(OUT/'soundscape-manifest.json').write_text(json.dumps({'version':1,'generator':'tools/build_hazard_soundscape.py','seed':90449,'sample_rate':RATE,'files':rows},ensure_ascii=False,indent=2)+'\n')
print(json.dumps(rows,indent=2))
