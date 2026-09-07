"""Fetch the pinned CC0 animation inputs; no account or paid service required."""
import hashlib
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '04_GAME_ASSETS/3d/motion_library/source'
REVISION = '2d3d1ff03247d9e7e830d1ae375653da4e2146e2'
FILES = {
    'human-base-animations.glb': '406eb0a8dc4ab366e623b79b6e3005a4951392e1bda78ae39c1099d31147733c',
    'human-addon-animations.glb': 'a0d64d555e0d492026b72d58bf8e16c5e86779295f9093e376dcc001915c2c95',
}


def fetch():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, expected in FILES.items():
        path = OUT / name
        url = f'https://raw.githubusercontent.com/Mesh2Motion/mesh2motion-app/{REVISION}/static/animations/{name}'
        data = path.read_bytes() if path.exists() else urllib.request.urlopen(url, timeout=60).read()
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(f'Input checksum mismatch: {name}')
        path.write_bytes(data)
        print(name, expected)
    license_url = 'https://raw.githubusercontent.com/Mesh2Motion/mesh2motion-assets/9ba82162522213f3226c099ce6d0576179556a35/LICENSE'
    (OUT / 'CC0-1.0.txt').write_bytes(urllib.request.urlopen(license_url, timeout=60).read())


if __name__ == '__main__':
    fetch()
