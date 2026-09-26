"""Deterministic procedural rain/thunder, original synthesized audio (CC0)."""
import math, random, wave, struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1] / '04_GAME_ASSETS/audio/weather'
ROOT.mkdir(parents=True, exist_ok=True)
RATE=32000
for name,seconds in [('rain',24),('thunder',9)]:
    rng=random.Random(910 if name=='rain' else 37)
    samples=[]; low=0.; slow=0.; last=0.
    for i in range(RATE*seconds):
        t=i/RATE;noise=rng.uniform(-1,1)
        low+=.10*(noise-low);slow+=.008*(noise-slow)
        if name=='rain':
            # Wideband patter plus a darker continuous wash. Periodic envelope
            # and a crossfade below avoid an audible loop seam.
            v=(noise*.18+low*.65)*(0.85+.08*math.sin(t*math.tau/seconds))
            if rng.random()<.0008: last=rng.uniform(.08,.4)
            last*=.90;v+=last
        else:
            envelope=(1-math.exp(-t*12))*math.exp(-t*.50)*min(1,(seconds-t)/1.5)
            roll=.65+.35*math.sin(t*8+math.sin(t*3))
            v=(slow*4+low*.20)*envelope*roll
        samples.append(v)
    if name=='rain':
        n=RATE//2
        for i in range(n):
            t=i/n;samples[i]=samples[-n+i]*(1-t)+samples[i]*t
        samples=samples[:-n]
    peak=max(abs(x) for x in samples);gain=.75/peak
    with wave.open(str(ROOT/f'{name}.wav'),'wb') as f:
        f.setparams((1,2,RATE,0,'NONE','not compressed'))
        f.writeframes(b''.join(struct.pack('<h',int(x*gain*32767)) for x in samples))
(ROOT/'README.md').write_text('''# Island weather audio\n\nOriginal procedural rain and distant thunder. CC0-1.0.\nGenerated deterministically by `tools/build_tidewater_weather_audio.py`.\nPCM16 mono, 32 kHz. Rain has a 0.5-second loop crossfade.\nThese are synthesized textures, not field recordings.\n''')
