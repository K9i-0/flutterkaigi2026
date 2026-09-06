"""Deterministic original launcher ignition / impact, mono PCM16 at 24 kHz."""
from pathlib import Path
import math, random, struct, wave
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '04_GAME_ASSETS/audio/hazard'
for name, duration in [('rocket_launch', .8), ('rocket_blast', 1.15)]:
    rng = random.Random(807 if name.endswith('launch') else 809)
    samples, low = [], 0.0
    for i in range(int(24000 * duration)):
        t = i / 24000
        noise = rng.uniform(-1, 1)
        low = low * .87 + noise * .13
        attack = min(1, t / .004)
        if name.endswith('launch'):
            value = (.35 * noise * math.exp(-t * 6) + .55 * low * math.exp(-t * 3)
                     + .18 * math.sin(2 * math.pi * (130*t-45*t*t)) * math.exp(-t * 12))
        else:
            value = (.85 * low * math.exp(-t * 3.5) + .13 * noise * math.exp(-t * 22)
                     + .42 * math.sin(2 * math.pi * (62*t-14*t*t)) * math.exp(-t * 6))
        samples.append(value * attack * min(1, (duration-t)/.04))
    gain = .76 / max(abs(s) for s in samples)
    dest = OUT / (name + '.wav')
    with wave.open(str(dest), 'wb') as f:
        f.setparams((1, 2, 24000, 0, 'NONE', 'not compressed'))
        f.writeframes(b''.join(struct.pack('<h', round(s*gain*32767)) for s in samples))
    link = ROOT / '21_SOBAYA_HAZARD_LAB/assets/audio' / dest.name
    if not link.exists(): link.symlink_to('../../../04_GAME_ASSETS/audio/hazard/' + dest.name)
    print(dest.name, duration)
