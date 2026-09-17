from pathlib import Path
import os
O=Path(__file__).resolve().parent
folder=O.parents[4]/'16_MADOGIWA_STUDIO/public/.local/fukuchan-skin'
folder.mkdir(parents=True,exist_ok=True)
for name,src in {'index.html':O/'preview.html','fukuchan.glb':O.parent/'web_v3_20260917/fukuchan.glb','before.glb':O.parent/'rig_v3_20260917/fukuchan.glb','gyungyun_pose.png':O.parent/'rig_v3_20260917/inputs/gyungyun_pose.png'}.items():
 dest=folder/name;tmp=dest.with_suffix(dest.suffix+'.next')
 tmp.symlink_to(os.path.relpath(src,dest.parent));tmp.replace(dest)
print('http://127.0.0.1:8789/public/.local/fukuchan-skin/index.html')
