"""Rebuild Remotion's local assets from canonical model and image sources."""
from pathlib import Path
import hashlib
import json
import os
import shutil

EP = Path(__file__).resolve().parent
ROOT = EP.parents[1]
provenance = json.loads((EP / 'asset-provenance-3d.json').read_text())

def link(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if os.path.samefile(source, destination):
            return
        destination.unlink()
    try:
        os.link(source, destination)
    except OSError:
        shutil.copy2(source, destination)

for name, source in provenance['models'].items():
    link(ROOT / source, EP / 'remotion/public/models' / f'{name}.glb')
link(EP / provenance['background']['file'], EP / 'remotion/public/backgrounds/jungle_wall_day_v1.png')
link(EP / 'backgrounds/jungle_floor_v1.png', EP / 'remotion/public/backgrounds/jungle_floor_v1.png')
hashes = {name: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for name, path in provenance['models'].items()}
hashes['background'] = hashlib.sha256((EP / provenance['background']['file']).read_bytes()).hexdigest()
hashes['floor'] = hashlib.sha256((EP / 'backgrounds/jungle_floor_v1.png').read_bytes()).hexdigest()
(EP / 'asset-sha256.json').write_text(json.dumps(hashes, indent=2) + '\n')
print('Canonical models and generated background prepared.')
