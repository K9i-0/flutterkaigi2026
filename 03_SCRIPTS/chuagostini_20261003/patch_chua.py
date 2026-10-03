"""Replace the opening only; preserve the accepted suffix samples verbatim."""
from pathlib import Path
import json
import hashlib
import subprocess
import numpy as np
import soundfile as sf
import parselmouth
from parselmouth.praat import call

ROOT = Path(__file__).resolve().parents[2]
P = ROOT / '.local/chuagostini-20261003'
SR = 44100
original, sr = sf.read(P / 'deagostini_seedvc_sobaya.wav')
assert sr == SR
donor, sr = sf.read(P / 'ending_raw.wav')
if sr != SR:
    import librosa
    donor = librosa.resample(donor, orig_sr=sr, target_sr=SR)

# MMS forced alignment puts the g token at 0.423s; the closure precedes it.
# Keep the original g release and every later sample, beginning at 0.390s.
join = .390
crossfade = .012
donor_start, donor_end = .070, .470
segment = donor[round(donor_start*SR):round(donor_end*SR)]
sound = parselmouth.Sound(segment, SR)
manip = call(sound, 'To Manipulation', .005, 65, 500)
tier = call(manip, 'Extract pitch tier')
call(tier, 'Remove points between', 0, sound.duration)
pitch = parselmouth.Sound(original, SR).to_pitch(time_step=.005, pitch_floor=100, pitch_ceiling=350)
freq = pitch.selected_array['frequency']
valid = (freq > 120) & (pitch.xs() >= .100) & (pitch.xs() <= join)
for t in np.arange(.005, sound.duration, .005):
    destination_t = t/sound.duration*join
    f = np.interp(destination_t, pitch.xs()[valid], freq[valid])
    call(tier, 'Add point', float(t), float(f))
call([tier, manip], 'Replace pitch tier')
duration = call(manip, 'Extract duration tier')
call(duration, 'Add point', sound.duration/2, join/sound.duration)
call([duration, manip], 'Replace duration tier')
resynth = call(manip, 'Get resynthesis (overlap-add)').values[0]
n = round(join*SR)
resynth = np.pad(resynth, (0, max(0, n-len(resynth))))[:n]
old_rms = np.sqrt(np.mean(original[round(.12*SR):round(.32*SR)]**2))
new_rms = np.sqrt(np.mean(resynth[round(.12*SR):round(.32*SR)]**2))
gain = min(old_rms/new_rms, .98/(np.max(np.abs(resynth))+1e-10))
resynth *= gain
fade = round(.004*SR)
resynth[:fade] *= np.linspace(0, 1, fade)
x = original.copy()
x[:n] = resynth
c = round(crossfade*SR)
mix = np.linspace(0, 1, c)
x[n-c:n] = resynth[n-c:n]*(1-mix) + original[n-c:n]*mix
sf.write(P/'chuagostini_seedvc_v2.wav', x, SR, subtype='FLOAT')
assert np.array_equal(x[n:], original[n:])
subprocess.run([str(ROOT/'tools/sobaya_monsterize.sh'), str(P/'chuagostini_seedvc_v2.wav'), str(P/'chuagostini_seedvc_v3_processed.wav')], check=True)
processed, sr = sf.read(P/'chuagostini_seedvc_v3_processed.wav')
old3, _ = sf.read(P/'deagostini_seedvc_sobaya_monster.wav')
y = old3.copy()
n3 = round(.420*SR)
y[:n3] = processed[:n3]
y[n3-c:n3] = processed[n3-c:n3]*(1-mix) + old3[n3-c:n3]*mix
sf.write(P/'chuagostini_seedvc_v3.wav', y, SR, subtype='FLOAT')
assert np.array_equal(y[n3:], old3[n3:])
rows=[]
for version, data, boundary in [('v2', x, n/SR), ('v3', y, n3/SR)]:
    # Same gains as the previous comparison, keeping the suffix PCM identical.
    gain_db = -6.0 if version == 'v2' else -5.534191341939935
    path = P/f'chuagostini_seedvc_{version}_preview.wav'
    sf.write(path, data*10**(gain_db/20), SR, subtype='PCM_16')
    rows.append({'file':str(path.relative_to(ROOT)), 'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'duration':len(data)/SR, 'unchanged_suffix_from':boundary, 'suffix_samples_equal':True, 'preview_gain_db':gain_db})
report={'method':'Irodori prefix, Praat PSOLA pitch/duration matching, prefix splice', 'donor_file':'ending_raw.wav', 'donor_interval':[donor_start,donor_end], 'v2_join':join, 'crossfade':crossfade, 'prefix_gain':float(gain), 'files':rows, 'listening_verified':False}
(ROOT/'03_SCRIPTS/chuagostini_20261003/chua-patch.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
