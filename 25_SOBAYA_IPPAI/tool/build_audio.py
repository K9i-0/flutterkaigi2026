"""Original procedural effects; no sampled recordings or character speech."""
import math, random, struct, wave
from pathlib import Path
OUT = Path(__file__).resolve().parent.parent / 'assets/audio'
OUT.mkdir(parents=True, exist_ok=True)
RATE = 22050

def write(name, seconds, fn):
    rng = random.Random(25)
    with wave.open(str(OUT / (name+'.wav')), 'wb') as w:
        w.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        w.writeframes(b''.join(struct.pack('<h', int(max(-1,min(1,fn(i/RATE,rng)))*23000)) for i in range(int(RATE*seconds))))

def pour(t,rng):
    noise=rng.uniform(-1,1)*.18
    ripple=math.sin(2*math.pi*(310*t+4*math.sin(t*7)))*.04
    return (noise+ripple)*(.7+.3*math.sin(t*math.tau*3))

def clink(t,rng):
    return sum(math.sin(t*math.tau*f)*math.exp(-t*d)*a for f,d,a in [(1100,5,.3),(2370,8,.17),(3510,12,.08)])

def spill(t,rng):
    return (rng.uniform(-1,1)*.30+math.sin(math.tau*70*t)*.35)*math.exp(-t*7)
write('pour',2,pour)
write('clink',1,clink)
write('spill',.7,spill)
