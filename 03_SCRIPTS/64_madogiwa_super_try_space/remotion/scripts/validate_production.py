"""Validate custom HUD manifest ranges and local production dependencies."""
import json
from pathlib import Path
r=Path(__file__).resolve().parents[1]
m=json.loads((r/'src/production-manifest.json').read_text());n=m['composition']['durationInFrames']
for group in ['comms','hud','captions']:
 last=0
 for seg in m[group]:
  assert all(isinstance(seg[k],int) for k in ['start','end'])
  assert 0<=seg['start']<seg['end']<=n and seg['start']>=last,(group,seg)
  last=seg['end']
for s in m['audioSegments']:
 assert 0<=s['from']<s['from']+s['duration']<=n
 assert s['startFrom']>=0 and s['startFrom']+s['duration']<=240
assert all(0<=f<n for f in m['events'].values())
assert all(a['frame']<b['frame'] for a,b in zip(m['tracking'],m['tracking'][1:]))
assert all(0<=p['x']<=832 and 0<=p['y']<=480 and p['size']>0 for p in m['tracking'])
for k in ['background','alertAudio']:
 assert (r/'public'/m[k]).is_file(),k
print('Custom timeline validation passed. Tracking:',m['trackingStatus'])
