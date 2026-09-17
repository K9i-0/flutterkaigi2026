"""Adopt the reviewed Sobaya motion asset without rebuilding the older rig."""
import hashlib
import json
import shutil
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / '04_GAME_ASSETS/3d/characters/sobaya/motion_v3_20260917/sobaya_motion.glb'
manifest = ROOT / '04_GAME_ASSETS/3d/hazard_adopted/manifest.json'
data = source.read_bytes()
digest = hashlib.sha256(data).hexdigest()
review = json.loads((source.parent / 'qa/review.json').read_text())
assert review['sha256'] == digest, 'Review the current GLB before adopting'
doc = json.loads(data[20:20 + struct.unpack_from('<I', data, 12)[0]])
state = json.loads(manifest.read_text())
entry = state['sobaya']
shutil.copyfile(source, ROOT / entry['file'])
entry.update(source=str(source.relative_to(ROOT)), sourceSha256=digest, sha256=digest,
             revision='mug-motion-greeting-20260917', clips=sorted(a['name'] for a in doc['animations']))
entry['sources']['Idle'] = 'CharacterSheet_MugStand'
manifest.write_text(json.dumps(state, indent=2) + '\n')
print('Adopted', digest)
