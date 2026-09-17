from pathlib import Path
import os
P=Path(__file__).resolve().parent;web=P.parents[4]/'16_MADOGIWA_STUDIO/public';folder=web/'.local/fukuchan-rig';folder.mkdir(parents=True,exist_ok=True)
for name,src in {'index.html':P/'preview.html','fukuchan.glb':P/'fukuchan.glb','gyungyun_pose.png':P/'inputs/gyungyun_pose.png'}.items():
 d=folder/name;t=d.with_suffix(d.suffix+'.next');t.symlink_to(os.path.relpath(src,d.parent));t.replace(d)
d=web/'models/characters/fukuchan.glb';assert d.is_symlink();t=d.with_suffix('.next');t.symlink_to(os.path.relpath(P/'fukuchan.glb',d.parent));t.replace(d)
print('http://127.0.0.1:5173/.local/fukuchan-rig/index.html')
