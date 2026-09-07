"""Round-trip QA of delivered GLBs, not just the source Blender scene.
blender -b --factory-startup --python tools/audit_humanoid_motion.py
"""
import json
import math
from pathlib import Path
import sys
import struct
import bpy

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from build_humanoid_motion import Body, use_action, clear_pose, FPS

OUT=ROOT/'04_GAME_ASSETS/3d/motion_library'
report={'roundTrip':True,'fps':FPS,'characters':[],'failures':[]}
def glb_animation_names(path):
    data=path.read_bytes();size=struct.unpack_from('<I',data,12)[0]
    return {a['name'] for a in json.loads(data[20:20+size]).get('animations',[])}
for name in ['sobaya','fukuchan']:
    profile=json.loads((OUT/name/'profile.json').read_text())
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=FPS
    bpy.ops.import_scene.gltf(filepath=str(OUT/name/f'{name}.glb'))
    rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
    for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
    use_action(rig,None);clear_pose(rig)
    body=Body(rig,meshes,name)
    max_weights=0;max_error=0;unweighted=0;finite=True
    shapes=[]
    for mesh in meshes:
        if mesh.data.shape_keys: shapes.extend(k.name for k in mesh.data.shape_keys.key_blocks[1:])
        for vertex in mesh.data.vertices:
            weights=[g.weight for g in vertex.groups if g.weight>0 and mesh.vertex_groups[g.group].name in body.rest]
            max_weights=max(max_weights,len(weights));max_error=max(max_error,abs(sum(weights)-1))
            unweighted+=int(not weights);finite &= all(math.isfinite(v) for v in vertex.co)
    char=dict(id=name,bones=len(rig.data.bones),maxInfluences=max_weights,maxWeightError=max_error,
              unweightedVertices=unweighted,finite=finite,morphTargets=shapes,clips=[])
    required=glb_animation_names(ROOT/profile['source'])
    delivered=glb_animation_names(OUT/name/f'{name}.glb')
    char['originalGameClips']=len(required)
    char['deliveredGlbClips']=len(delivered)
    char['missingGameClips']=sorted(required-delivered)
    if required-delivered:report['failures'].append(name+': lost original game clips')
    if max_weights>4 or max_error>1e-4 or unweighted or not finite: report['failures'].append(name+': skin weights/finite')
    if name=='fukuchan' and not {'SpeechOpen','SpeechNarrow'}<=set(shapes): report['failures'].append(name+': speech morphs lost')
    for spec in profile['clips']:
        action=bpy.data.actions.get(spec['name'])
        if not action:
            report['failures'].append(name+': missing '+spec['name']);continue
        use_action(rig,None);clear_pose(rig);use_action(rig,action);start,end=action.frame_range
        floors=[];nonfinite=False;first=None;last=None
        # Nine poses per clip, including loop boundary and subframe interpolation.
        for step in range(9):
            f=start+(end-start)*step/8
            bpy.context.scene.frame_set(int(f),subframe=f-int(f))
            floors.append(min(body.skin_floor('l'),body.skin_floor('r')))
            poses={b.name:(b.location.copy(),b.rotation_quaternion.copy()) for b in rig.pose.bones}
            nonfinite |= any(not math.isfinite(v) for p,q in poses.values() for v in [*p,*q])
            if step==0:first=poses
            if step==8:last=poses
        angles=[first[n][1].rotation_difference(last[n][1]).angle for n in first]
        seam_angle=max(min(a,abs(math.tau-a)) for a in angles)
        seam_translation=max((first[n][0]-last[n][0]).length for n in first)
        # Quaternion signs are equivalent; rotation_difference may report 2pi.
        record=dict(name=spec['name'],method=spec['method'],poses=9,minSoleM=min(floors),
            maxLowestSoleM=max(floors),
            loop=spec['loop'],seamRadians=seam_angle,seamTranslationM=seam_translation,finite=not nonfinite)
        char['clips'].append(record)
        if nonfinite:report['failures'].append(name+': nonfinite '+spec['name'])
        if spec['method'] in ['hybrid','procedural'] and min(floors)<-.002:
            report['failures'].append(name+': ground penetration '+spec['name'])
        if spec['method']=='hybrid' and spec.get('sourceClip',spec['action']) not in ['Jog','Sprint'] and max(floors)>.04:
            report['failures'].append(name+': floating support '+spec['name'])
        if spec['loop'] and spec['method'] in ['hybrid','procedural'] and (seam_angle>.12 or seam_translation>.012):
            report['failures'].append(name+': loop seam '+spec['name'])
    report['characters'].append(char)
report['passed']=not report['failures']
(OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('MOTION_AUDIT',json.dumps({'passed':report['passed'],'clips':sum(len(c['clips']) for c in report['characters']),'failures':report['failures']}),flush=True)
if not report['passed']:raise SystemExit(1)
