"""Original layered launcher / explosion / detection Foley, no external samples.

NumPy/SciPy + ffmpeg. Static loudness mastering preserves the transient and tail.
Three variations per rocket cue; compatible legacy aliases point to variant 0.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import wave

import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '04_GAME_ASSETS/audio/hazard'
TMP = ROOT / '.local/audio-polish-20260907'
TMP.mkdir(parents=True, exist_ok=True)
SR = 44100
rows = []


def filtered_noise(rng, n, lo, hi):
    return sosfilt(butter(3, [lo, hi], fs=SR, btype='bandpass', output='sos'), rng.normal(size=n))


def master(name, x, target, layers):
    x *= np.minimum(1, np.arange(len(x)) / (SR * .001))
    x *= np.minimum(1, np.arange(len(x))[::-1] / (SR * .12))
    # Warm saturation thickens the midrange; the final stage is static gain.
    x = np.tanh(x * 1.35)
    raw = TMP / 'rocket-master-input.wav'
    def write(p, values):
        with wave.open(str(p), 'wb') as f:
            f.setparams((1, 2, SR, 0, 'NONE', 'not compressed'))
            f.writeframes(np.round(values * 32767).astype('<i2').tobytes())
    write(raw, x * .8)
    log = subprocess.run(['ffmpeg', '-hide_banner', '-i', str(raw), '-af',
                          f'loudnorm=I={target}:TP=-2:LRA=15:print_format=json',
                          '-f', 'null', '-'], capture_output=True, text=True, check=True).stderr
    measured = json.JSONDecoder().raw_decode(log[log.rindex('{'):])[0]
    gain = min(10 ** ((target - float(measured['input_i'])) / 20),
               10 ** ((-4.5 - float(measured['input_tp'])) / 20),
               .86 / max(float(np.max(np.abs(x * .8))), 1e-9))
    x *= .8 * gain
    dest = OUT / 'combat' / (name + '.wav')
    dest.parent.mkdir(exist_ok=True)
    write(dest, x)
    rows.append({'file': str(dest.relative_to(OUT)), 'seconds': len(x) / SR,
                 'channels': 1, 'sample_rate': SR, 'loop': False,
                 'peak': float(np.max(np.abs(x))), 'rms': float(np.sqrt(np.mean(x*x))),
                 'target_lufs': target, 'layers': layers,
                 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()})
    print(name, flush=True)


for variant in range(3):
    rng = np.random.default_rng(90780 + variant)
    duration = 1.8
    t = np.arange(round(duration * SR)) / SR
    n = len(t)
    # Ignition pressure wave, gritty backblast and a jet that accelerates away.
    pitch = 1 + (variant - 1) * .035
    ignition = filtered_noise(rng, n, 650, 13500) * np.exp(-t*95) * .72
    pressure = np.sin(2*np.pi*pitch*(48*t+1.9*(1-np.exp(-t*35)))) * np.exp(-t*9) * .75
    chest = np.sin(2*np.pi*pitch*135*t) * np.exp(-t*15) * .22
    jet = filtered_noise(rng, n, 110, 4800) * (1-np.exp(-t*130)) * np.exp(-t*4.7) * .80
    jet *= .8 + .2*np.sin(2*np.pi*(31*t+16*t*t))
    turbine = np.sin(2*np.pi*(640*t+430*t*t)) * (1-np.exp(-t*90))*np.exp(-t*8)*.055
    latch = np.zeros(n)
    for start in [.012, .075]:
        q = np.maximum(0, t-start)
        latch += (t>=start)*filtered_noise(rng, n, 1800, 8800)*np.exp(-q*105)*.11
    dry = ignition + pressure + chest + jet + turbine + latch
    x = dry.copy()
    for seconds, gain in [(.061,.18),(.137,.12),(.227,.07),(.389,.035)]:
        offset = round(seconds*SR)
        x[offset:] += dry[:-offset]*gain
    master(f'rocket_launch_{variant}', x, -15.5,
           ['ignition crack', '48–115 Hz pressure', '135 Hz body', 'turbulent jet', 'rising turbine', 'latch', 'early reflections'])

    duration = 2.8
    t = np.arange(round(duration*SR))/SR
    n = len(t)
    impact = filtered_noise(rng,n,800,14000)*np.exp(-t*65)*.60
    bass = np.sin(2*np.pi*pitch*(37*t+1.3*(1-np.exp(-t*24))))*np.exp(-t*4.5)*.90
    body = filtered_noise(rng,n,55,1300)*np.exp(-t*3.7)*1.10
    debris = filtered_noise(rng,n,350,6200)*(1-np.exp(-t*70))*np.exp(-t*6)*.21
    rumble = filtered_noise(rng,n,35,280)*(1-np.exp(-t*35))*np.exp(-t*1.9)*.55
    x = impact+bass+body+debris+rumble
    dry = x.copy()
    for seconds,gain in [(.095,.19),(.181,.14),(.313,.10),(.487,.07),(.731,.04)]:
        offset=round(seconds*SR)
        x[offset:]+=dry[:-offset]*gain
    master(f'rocket_blast_{variant}',x,-17,
           ['impact crack','37–68 Hz shockwave','low-mid blast','air/debris scatter','rolling rumble','outdoor reflections'])

rng=np.random.default_rng(90799)
t=np.arange(round(1.25*SR))/SR
x=filtered_noise(rng,len(t),400,5200)*np.exp(-t*12)*.09
for f,amp in [(73.416,.27),(110,.13),(155.563,.09),(622.254,.025)]:
    x+=np.sin(2*np.pi*(f*t+1.4*(1-np.exp(-t*15))))*np.exp(-t*5)*amp
master('alert',x,-22,['short low brass sting','tritone scrape','air transient'])

for cue in ['rocket_launch','rocket_blast']:
    alias=OUT/(cue+'.wav')
    if alias.exists() or alias.is_symlink():
        alias.unlink()
    alias.symlink_to(f'combat/{cue}_0.wav')

(OUT/'rocket-audio-manifest.json').write_text(json.dumps({
    'version':2,'generator':'tools/build_hazard_rocket_audio.py',
    'seeds':[90780,90781,90782,90799], 'files':rows,
    'mastering':'44.1 kHz mono PCM16, layered synthesis, soft saturation then static gain; sample peak <= 0.86 and true peak <= -4.5 dBTP to allow near-instant launch/impact overlap; loudness target is subordinate to headroom',
},ensure_ascii=False,indent=2)+'\n')
