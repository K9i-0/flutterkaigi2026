"""Derive 50 Hz mouth-opening envelopes from the exact bundled speech WAVs.

Uses only local PCM samples. No generated audio is replaced or uploaded.
Energy tracking is not phoneme recognition or forced alignment.
"""
import array
import hashlib
import json
import math
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / '21_SOBAYA_HAZARD_LAB/assets'
manifest = json.loads((ASSETS / 'audio/voice-manifest.json').read_text())
clips = []
for clip in manifest['clips']:
    if clip['kind'] != 'speech':
        continue
    path = ASSETS / clip['asset']
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest == clip['sha256'], path
    with wave.open(str(path)) as audio:
        assert audio.getsampwidth() == 2 and audio.getnchannels() == 1
        rate = audio.getframerate()
        samples = array.array('h', audio.readframes(audio.getnframes()))
        if sys.byteorder != 'little':
            samples.byteswap()
    hop = rate // 50
    rms = [math.sqrt(sum((v / 32768) ** 2 for v in samples[i:i + hop]) /
                     len(samples[i:i + hop])) for i in range(0, len(samples), hop)]
    reference = max(.015, sorted(rms)[int(len(rms) * .90)])
    values = []
    previous = 0
    for value in rms:
        target = min(1, max(0, (value - .006) / reference)) ** .7
        alpha = 1 - math.exp(-.02 / (.025 if target > previous else .045))
        previous += (target - previous) * alpha
        values.append(round(previous, 4))
    values.extend([0, 0, 0])
    clips.append({'asset': clip['asset'], 'speaker': clip['speaker'],
                  'sha256': digest, 'seconds': len(samples) / rate,
                  'open': values})
result = {'version': 1, 'hz': 50, 'method': 'PCM RMS, noise floor and attack/release smoothing; not phonemes', 'clips': clips}
output = ASSETS / 'audio/speech-envelopes.json'
output.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
print(json.dumps({'clips': len(clips), 'bytes': output.stat().st_size,
                  'samples': sum(len(c['open']) for c in clips)}, indent=2))
