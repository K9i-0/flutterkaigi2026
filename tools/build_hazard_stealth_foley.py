"""Reproducible nonverbal stealth Foley: shoes, cloth, intact glass and liquid.

Run with NumPy. No recordings, sampled game audio or generated dialogue.
"""
from pathlib import Path
import hashlib
import json
import wave

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / '04_GAME_ASSETS/audio/hazard'
RATE = 24000
SEED = 90609
rng = np.random.default_rng(SEED)
rows = []


def noise(t, low, high):
    freqs = np.fft.rfftfreq(len(t), 1 / RATE)
    spec = rng.normal(size=len(freqs)) + 1j * rng.normal(size=len(freqs))
    spec *= np.exp(-(freqs / high) ** 4) * (1 - np.exp(-(freqs / low) ** 4))
    result = np.fft.irfft(spec, n=len(t))
    return result / max(1e-9, np.std(result))


def impulse(t, start, decay, attack=700):
    local = np.maximum(0, t - start)
    return (t >= start) * (1 - np.exp(-attack * local)) * np.exp(-decay * local)


def save(name, audio, rms):
    audio *= min(rms / np.sqrt(np.mean(audio ** 2)), .8 / np.max(np.abs(audio)))
    fade = min(len(audio) // 2, int(.008 * RATE))
    audio[:fade] *= np.linspace(0, 1, fade)
    audio[-fade:] *= np.linspace(1, 0, fade)
    dest = OUT / f'combat/{name}.wav'
    pcm = (audio * 32767).astype('<i2')
    with wave.open(str(dest), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(pcm.tobytes())
    rows.append({'file': f'combat/{name}.wav', 'sample_rate': RATE, 'channels': 1,
                 'seconds': len(audio) / RATE, 'loop': False,
                 'rms': float(np.sqrt(np.mean(audio ** 2))),
                 'peak': float(np.max(np.abs(audio))),
                 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()})


t = np.arange(int(.42 * RATE)) / RATE
step = (np.sin(2 * np.pi * (78 * t + .14 * (1 - np.exp(-40 * t)))) * .34 +
        noise(t, 90, 1100) * .20) * impulse(t, .01, 30)
step += noise(t, 460, 2300) * .08 * impulse(t, .035, 22)
for hz, amplitude in [(1130, .016), (1821, .009), (3041, .005)]:
    step += np.sin(2 * np.pi * hz * t) * amplitude * impulse(t, .075, 29)
save('enemy_step', step, .082)

t = np.arange(int(.38 * RATE)) / RATE
throw = noise(t, 180, 1800) * .25 * np.exp(-((t - .14) / .065) ** 2)
throw += noise(t, 900, 3700) * .027 * impulse(t, .095, 22)
save('beer_throw', throw, .052)

t = np.arange(int(.75 * RATE)) / RATE
land = noise(t, 150, 1800) * .25 * impulse(t, .008, 35)
for hz, amp in [(712, .19), (1929, .09), (2905, .035), (3866, .014)]:
    land += np.sin(2 * np.pi * hz * t) * amp * impulse(t, .012, 19)
# Spread droplets and a short wet slosh follow the intact mug's initial clink.
for start, hz in [(.075, 720), (.13, 1130), (.24, 920), (.34, 630)]:
    local = np.maximum(0, t - start)
    bubble = np.sin(2 * np.pi * (hz * local - hz * .12 * local ** 2))
    land += bubble * .024 * impulse(t, start, 45)
land += noise(t, 500, 2900) * .036 * impulse(t, .055, 9)
save('beer_land', land, .090)
manifest = {'version': 1, 'generator': 'tools/build_hazard_stealth_foley.py',
            'seed': SEED, 'files': rows,
            'note': 'Original DSP synthesis only. These effects do not replace character voices.'}
(OUT / 'stealth-foley-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(manifest, ensure_ascii=False, indent=2))
