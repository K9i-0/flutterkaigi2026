"""Original procedural helmet-electronics SFX; no speech or external samples."""
import json, math, wave, struct
from pathlib import Path
root = Path(__file__).resolve().parents[1]
m = json.loads((root/'src/edit-manifest.json').read_text())
sr = 48000
fps = m['composition']['fps']
n = m['composition']['durationInFrames'] * sr // fps
a = [[0.0, 0.0] for _ in range(n)]
def tone(frame, duration, freq, amp, end=None, pan=0):
    start = round(frame * sr / fps)
    length = round(duration * sr)
    for j in range(min(length, n-start)):
        t=j/sr
        env=min(1,t/.008)*min(1,(duration-t)/.035)
        phase=2*math.pi*(freq*t+((end or freq)-freq)*t*t/(2*duration))
        v=amp*env*(math.sin(phase)+.13*math.sin(phase*2))
        a[start+j][0]+=v*math.sqrt((1-pan)/2)
        a[start+j][1]+=v*math.sqrt((1+pan)/2)
# Quiet helmet electrical floor, not exterior space sound.
tone(0,8,57,.012)
tone(0,8,113,.004)
for f in m['audio']['pulses']:
    tone(f,.11,880,.17,740,.12)
    tone(f+5,.15,660,.14,610,.12)
# Low detection impact and a restrained rising tension bed.
tone(m['events']['alert'],.65,92,.18,43)
tone(m['events']['alert'],3.5,125,.035,175)
# Identification releases tension with a softer two-note confirmation.
tone(m['events']['identified'],.16,660,.105,pan=-.1)
tone(m['events']['identified']+6,.32,990,.085,pan=-.1)
# Global short fades and deterministic stereo PCM.
peak=0
buf=bytearray()
for i,pair in enumerate(a):
    fade=min(1,i/960,(n-1-i)/2400)
    for v in pair:
        v*=max(0,fade)
        peak=max(peak,abs(v))
        buf.extend(struct.pack('<h',round(max(-1,min(1,v))*32767)))
out=root/'public/hud_sfx.wav'
with wave.open(str(out),'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr); w.writeframes(buf)
print(f'{out.name}: 8s stereo 48kHz, peak {20*math.log10(peak):.2f} dBFS')
