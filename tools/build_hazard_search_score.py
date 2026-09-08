"""Author the original beat-free Sobaya Hazard search layer, deterministically.

Run with NumPy. No samples, speech synthesis or third-party score is used.
The adopted exploration/pursuit and character voice masters stay untouched.
"""
from pathlib import Path
import hashlib
import json
import wave

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / '04_GAME_ASSETS/audio/hazard'
RATE = 44100
SECONDS = 48
SEED = 90608
N = RATE * SECONDS
rng = np.random.default_rng(SEED)
t = np.arange(N) / RATE
stereo = np.zeros((N, 2))


def periodic_hz(hz):
    # An integer number of periods keeps every layer continuous at the seam.
    return round(hz * SECONDS) / SECONDS


def pan_add(samples, pan):
    stereo[:, 0] += samples * np.sqrt((1 - pan) / 2)
    stereo[:, 1] += samples * np.sqrt((1 + pan) / 2)


voices = [(38, .032, -.10), (50, .024, -.50), (51, .014, .50),
          (57, .018, .20), (62, .013, -.25), (75, .0035, .65)]
for index, (midi, level, pan) in enumerate(voices):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    # Slow, overlapping swells have no metrical attacks. Upper partials keep
    # the unease audible on a phone while leaving footsteps' transients clear.
    swell = .30 + .70 * (.5 + .5 * np.sin(
        2 * np.pi * (index % 3 + 1) * t / SECONDS + index * 1.37)) ** 2
    tone = np.zeros(N)
    for partial in range(1, 7):
        hz = periodic_hz(frequency * partial)
        detuned = periodic_hz(frequency * partial * 1.0021)
        phase = rng.uniform(0, 2 * np.pi)
        tone += (np.sin(2 * np.pi * hz * t + phase) +
                 .32 * np.sin(2 * np.pi * detuned * t - phase)) / partial ** 2.1
    pan_add(tone * swell * level, pan)

# Quiet bow/air grain is an environmental texture, not a new character breath
# recording. Its periodic spectrum and envelope have no repeating inhale beat.
frequencies = np.fft.rfftfreq(N, 1 / RATE)
for channel in range(2):
    spectrum = rng.normal(size=len(frequencies)) + 1j * rng.normal(size=len(frequencies))
    spectrum *= np.exp(-(frequencies / 1250) ** 4) * (1 - np.exp(-(frequencies / 280) ** 4))
    grain = np.fft.irfft(spectrum, n=N)
    grain /= max(1e-9, np.std(grain))
    envelope = .5 + .5 * np.sin(2 * np.pi * t / SECONDS + channel * 2.1)
    stereo[:, channel] += grain * envelope * .002

# A static gain preserves dynamics and loop continuity. Runtime mix leaves this
# below pursuit and ducks all musical layers under canonical dialogue.
target_rms = .071
stereo *= min(target_rms / np.sqrt(np.mean(stereo ** 2)), .70 / np.max(np.abs(stereo)))
pcm = (stereo * 32767).astype('<i2')
dest = OUT / 'soundscape/searching.wav'
dest.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(dest), 'wb') as f:
    f.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
    f.writeframes(pcm.tobytes())
row = {
    'file': 'soundscape/searching.wav', 'seconds': SECONDS,
    'sample_rate': RATE, 'channels': 2, 'loop': True,
    'peak': float(np.max(np.abs(stereo))),
    'rms': float(np.sqrt(np.mean(stereo ** 2))),
    'seam_delta': int(np.max(np.abs(pcm[0].astype(int) - pcm[-1].astype(int)))),
    'sha256': hashlib.sha256(dest.read_bytes()).hexdigest(),
}
manifest = {
    'version': 1, 'generator': 'tools/build_hazard_search_score.py', 'seed': SEED,
    'music': {'title': '戸口の向こう', 'mode': 'D Phrygian', 'seconds': SECONDS,
              'meter': 'unmetered', 'percussion': False,
              'instruments': 'Sustained detuned harmonic strings, sub pedal and quiet periodic bow air; original DSP synthesis',
              'voices_midi': [v[0] for v in voices],
              'loop': 'Integer-period oscillators, cyclic grain and slow periodic swells'},
    'files': [row],
}
(OUT / 'search-score-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
p = OUT / 'soundscape-manifest.json'
soundscape = json.loads(p.read_text())
soundscape['files'] = [r for r in soundscape['files'] if r['file'] != row['file']] + [row]
soundscape['search_score_manifest'] = 'search-score-manifest.json'
p.write_text(json.dumps(soundscape, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(manifest, ensure_ascii=False, indent=2))
