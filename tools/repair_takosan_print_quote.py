"""Unsigned surface voxelization preserves tentacles with inconsistent source winding.

Requires trimesh, scipy, scikit-image. Input surfaces exported by Blender.
"""
from pathlib import Path
import json,hashlib
import numpy as np
import trimesh
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'04_GAME_ASSETS/3d/print/takosan_50_70mm_20260918'
reports=[]
for height,diameter in [(50,45),(70,60)]:
 source=trimesh.load(OUT/f'takosan_{height}mm_surface.stl',force='mesh')
 pitch=.15
 vox=source.voxelized(pitch,method='subdivide')
 matrix=np.pad(vox.matrix,3)
 matrix=ndimage.binary_closing(matrix,iterations=1)
 matrix=ndimage.binary_fill_holes(matrix)
 # Original closed voxel surfaces remain inside the filled volume, independent of normals.
 mesh=trimesh.voxel.ops.matrix_to_marching_cubes(matrix,pitch=pitch)
 mesh.apply_translation(vox.transform[:3,3]-3*pitch)
 components=mesh.split(only_watertight=False)
 components=sorted(components,key=lambda m:abs(m.volume),reverse=True)
 assert all(abs(m.volume)<.1 for m in components[1:]),'Substantial detached part'
 mesh=components[0]
 mesh.fix_normals()
 assert mesh.is_watertight and mesh.is_winding_consistent
 # Maintain target total height after voxelization and place bottom at Z=0.
 mesh.apply_translation([0,0,-mesh.bounds[0,2]])
 mesh.apply_scale(height/mesh.extents[2])
 filename=f'takosan_{height}mm_base{diameter}_v2.stl'
 mesh.export(OUT/filename)
 reports.append({'file':filename,'height_mm':height,'dimensions_mm':mesh.extents.tolist(),'volume_cm3':abs(mesh.volume)/1000,'watertight':bool(mesh.is_watertight),'components':1,'voxel_pitch_mm':pitch,'sha256':hashlib.sha256((OUT/filename).read_bytes()).hexdigest()})
 print(reports[-1],flush=True)
(OUT/'report_v2.json').write_text(json.dumps({'status':'quote prototype; six-tentacle geometry repaired; vendor review pending','models':reports},indent=2)+'\n')
