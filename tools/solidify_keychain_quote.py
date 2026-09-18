from pathlib import Path
import trimesh,numpy as np,json
from scipy import ndimage
OUT=Path(__file__).resolve().parents[1]/'04_GAME_ASSETS/3d/print/keychains_20260918'
reports=[]
for name,height in [('takosan',30),('sobaya',40)]:
 source=trimesh.load(OUT/f'{name}_{height}mm_surface.stl',force='mesh')
 pitch=.1;vox=source.voxelized(pitch)
 grid=ndimage.binary_fill_holes(ndimage.binary_closing(np.pad(vox.matrix,3),iterations=1))
 mesh=trimesh.voxel.ops.matrix_to_marching_cubes(grid,pitch=pitch);mesh.apply_translation(vox.transform[:3,3]-3*pitch)
 parts=sorted(mesh.split(),key=lambda x:abs(x.volume),reverse=True)
 print(name,'components',[(len(x.faces),abs(x.volume)) for x in parts],flush=True)
 assert all(abs(p.volume)<.05 for p in parts[1:]),'Detached feature or eyelet'
 mesh=parts[0];trimesh.smoothing.filter_taubin(mesh,iterations=5)
 mesh.fix_normals();assert mesh.is_watertight
 file=f'{name}_{height}mm_keychain_quote.stl';mesh.export(OUT/file)
 reports.append(dict(file=file,body_height_mm=height,dimensions_mm=mesh.extents.tolist(),volume_cm3=abs(mesh.volume)/1000,watertight=bool(mesh.is_watertight),components=1))
(OUT/'report.json').write_text(json.dumps(dict(status='geometry quote only; thin features, strength and color data not approved',models=reports),indent=2)+'\n')
