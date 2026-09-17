"""Stage a minimal localhost-only review site, without exposing the repository."""
import argparse
from functools import partial
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=8877);parser.add_argument('--stage-only',action='store_true');args=parser.parse_args()
web=ROOT/'.local/sobaya-grip/web';web.mkdir(parents=True,exist_ok=True)
html=(ROOT/'tools/preview_sobaya_grip.html').read_text()
html=html.replace('/.local/vrm-validation/node_modules/three/','/three/')
html=html.replace('/04_GAME_ASSETS/3d/characters/sobaya/grip_v3_20260917/sobaya_grip.glb','/sobaya_grip.glb')
html=html.replace('/04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb','/beer_mug.glb')
(web/'index.html').write_text(html)
shutil.copy2(ROOT/'04_GAME_ASSETS/3d/characters/sobaya/grip_v3_20260917/sobaya_grip.glb',web/'sobaya_grip.glb')
shutil.copy2(ROOT/'04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb',web/'beer_mug.glb')
standing=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/standing_v3_20260917/sobaya_standing.glb'
if standing.exists():shutil.copy2(standing,web/'sobaya_standing.glb')
three=ROOT/'.local/vrm-validation/node_modules/three'
for folder in ['build','examples/jsm']:shutil.copytree(three/folder,web/'three'/folder,dirs_exist_ok=True)
if not args.stage_only:
 print(f'Grip preview: http://127.0.0.1:{args.port}/',flush=True)
 ThreadingHTTPServer(('127.0.0.1',args.port),partial(SimpleHTTPRequestHandler,directory=str(web))).serve_forever()
