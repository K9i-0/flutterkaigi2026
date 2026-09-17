"""Link local review assets; this does not publish the site."""
from pathlib import Path
import os
P=Path(__file__).resolve().parent;root=P.parents[4];web=root/'16_MADOGIWA_STUDIO/public';dest=web/'.local/fukuchan-final';dest.mkdir(parents=True,exist_ok=True)
links={'index.html':P/'site-review.html','front.png':P.parent/'wan_multiview_20260917/inputs/front.png','baseline.glb':P.parent/'shallow_face_20260917/fukuchan_balanced.glb','final.glb':P/'fukuchan_final.glb'}
for name,src in links.items():
 d=dest/name
 if d.exists() and not d.is_symlink():raise RuntimeError(f'Refusing to replace regular file: {d}')
 t=d.with_suffix(d.suffix+'.next');t.symlink_to(os.path.relpath(src,d.parent));t.replace(d)
d=web/'models/characters/fukuchan.glb';assert d.is_symlink();t=d.with_suffix('.next');t.symlink_to(os.path.relpath(P/'fukuchan_final.glb',d.parent));t.replace(d)
print('http://127.0.0.1:5173/.local/fukuchan-final/index.html')
