"""Reconstruct the observed Wan clay gait on each anatomical rig.
Standalone updates only the new action; full library builds call add_video_walk.
blender -b --factory-startup --python tools/humanoid_video_walk.py
"""
import json,math,sys
from pathlib import Path
import bpy
from mathutils import Matrix,Quaternion,Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from build_humanoid_motion import Body,OUT,FPS,use_action,clear_pose,smooth
from humanoid_action_refinement import stabilize_gaze
SOURCE=OUT/'source/wan_walk_clay.json'

def evaluate(c,p):
    return c[0]+sum(c[2*n-1]*math.sin(math.tau*n*p)+c[2*n]*math.cos(math.tau*n*p) for n in range(1,4))

def add_video_walk(body,profile):
    if not SOURCE.exists():return
    data=json.loads(SOURCE.read_text());c=data['coefficients'];frames=data['periodFrames'];duration=frames/FPS
    duty=data['stanceFraction'];speed=data['rootLegsPerSecond']*body.leg
    span=speed*duration*duty;rig=body.rig
    body.action('Wan_Walk',frames);floors=[];ankles={s:[] for s in ['l','r']};phases={s:[] for s in ['l','r']}
    for frame in range(frames+1):
        bpy.context.scene.frame_set(frame);clear_pose(rig);p=(frame%frames)/frames
        pelvis=body.bone('pelvis');position=body.point('pelvis')
        position.z+=body.leg*(-.085+max(-.018,min(.018,evaluate(c['pelvisUp'],p))))
        position.x+=body.leg*.012*math.sin(math.tau*p)
        pelvis.matrix=Matrix.Translation(position)@Quaternion((0,0,1),.022*math.sin(math.tau*p)).to_matrix().to_4x4()@body.rest[pelvis.name].to_3x3().to_4x4()
        bpy.context.view_layer.update()
        for side,offset,sign in [('l',0,1),('r',.5,-1)]:
            phase=(p+offset)%1;phases[side].append(phase)
            ankle=body.point('foot_'+side)
            if phase<duty:
                forward=span*(.5-phase/duty);lift=0
            else:
                t=(phase-duty)/(1-duty)
                # Hermite endpoints retain stance velocity through toe-off and landing.
                tangent=-speed*duration*(1-duty)
                forward=(-span/2)*(2*t**3-3*t*t+1)+(span/2)*(-2*t**3+3*t*t)+tangent*(2*t**3-3*t*t+t)
                measured=evaluate(c['ankleForward'],phase)*body.leg
                forward+=.35*math.sin(math.pi*t)**2*(measured-forward)
                lift=max(0,evaluate(c['ankleLift'],phase))*body.leg*smooth(t/.12)*smooth((1-t)/.12)
            ankle.y-=forward;ankle.z+=lift
            # Plant the sole through mid-stance. Retain measured heel/toe rotation near transitions.
            contact_edge=(1-smooth(phase/.12)) if phase<.12 else smooth((phase-.48)/.12) if phase<duty else 1
            angle=max(-.5,min(.4,evaluate(c['footPitch'],phase)))*contact_edge
            rotation=Quaternion((1,0,0),-angle).to_matrix()@body.rest[body.inverse['foot_'+side]].to_3x3()
            body.leg_ik(side,ankle,rotation)
            if phase<duty or body.skin_floor(side)<.003:body.ground_leg(side)
            shoulder=body.bone('upperarm_'+side).head.copy()
            wrist=shoulder+Vector((sign*body.arm*.13,-body.arm*max(-.38,min(.38,evaluate(c['wristForward'],phase))),body.arm*max(-.975,min(-.78,evaluate(c['wristUp'],phase)))))
            body.ik(['upperarm_'+side,'lowerarm_'+side,'hand_'+side],wrist,Vector((sign*.18,-1,-.1)))
        stabilize_gaze(body,-3,5,heading=(0,-1,0));body.key(frame)
        floors.append(min(body.skin_floor('l'),body.skin_floor('r')))
        for s in ['l','r']:ankles[s].append(body.bone('foot_'+s).head.copy())
    errors=[]
    for s in ['l','r']:
        for i in range(1,frames):
            if .12<phases[s][i-1]<phases[s][i]<.48:
                v=(ankles[s][i]-ankles[s][i-1])*FPS-Vector((0,speed,0));errors.append(math.hypot(v.x,v.y))
    entry=dict(name='Wan_Walk',action='Walk',label='クレイ動画からの歩行',method='video',category='移動',loop=True,duration=duration,source='wan_walk_clay.json / Wan 3.0 + MediaPipe + anatomical IK',sourceClip='01_walk',floor='flat',minSoleM=min(floors),groundSpeedMps=speed,contactAnkleSlipRmsMps=math.sqrt(sum(x*x for x in errors)/len(errors)),contactSamples=len(errors),gazePitchRangeDeg=[-3,5],referenceVideoSha256=data['videoSha256'])
    profile['clips']=[e for e in profile['clips'] if e['name']!='Wan_Walk']+[entry]
    print('VIDEO_WALK',body.name,json.dumps(entry),flush=True)


def measure_captured_walk(body,profile):
    # Estimate a reference playback speed from low ankle intervals, for the common-speed comparison.
    use_action(body.rig,None);clear_pose(body.rig);action=bpy.data.actions['Walk'];use_action(body.rig,action)
    start,end=action.frame_range;tracks={s:[] for s in ['l','r']}
    for i in range(round(end-start)+1):
        bpy.context.scene.frame_set(round(start+i))
        for s in tracks:tracks[s].append(body.bone('foot_'+s).head.copy())
    candidates=[]
    for points in tracks.values():
        low=min(p.z for p in points)
        candidates.extend((b.y-a.y)*FPS for a,b in zip(points,points[1:]) if max(a.z,b.z)<low+.035 and b.y>a.y)
    candidates.sort();speed=candidates[len(candidates)//2] if candidates else 1.0
    next(e for e in profile['clips'] if e['name']=='Walk')['groundSpeedMps']=speed
    use_action(body.rig,None);clear_pose(body.rig)


def main():
    for name in ['sobaya','fukuchan']:
        profile=json.loads((OUT/name/'profile.json').read_text())
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=FPS
        bpy.ops.import_scene.gltf(filepath=str(OUT/name/f'{name}.glb'))
        rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
        meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
        for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
        use_action(rig,None);clear_pose(rig);body=Body(rig,meshes,name)
        measure_captured_walk(body,profile);add_video_walk(body,profile)
        use_action(rig,None);clear_pose(rig)
        bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
        for mesh in meshes:mesh.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(OUT/name/f'{name}.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_anim_slide_to_zero=True,export_anim_single_armature=True,export_skins=True,export_all_influences=False,export_def_bones=False,export_force_sampling=True,export_extras=True,export_optimize_animation_size=True)
        profile['glbBytes']=(OUT/name/f'{name}.glb').stat().st_size
        (OUT/name/'profile.json').write_text(json.dumps(profile,ensure_ascii=False,indent=2)+'\n')
    catalog=json.loads((OUT/'catalog.json').read_text());catalog['characters']=[json.loads((OUT/n/'profile.json').read_text()) for n in ['sobaya','fukuchan']]
    (OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':main()
