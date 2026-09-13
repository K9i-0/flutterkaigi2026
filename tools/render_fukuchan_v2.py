"""Render assembled v2 views and a three-second greeting; no paid generation.

Blender --background --factory-startup --python tools/render_fukuchan_v2.py
Append -- --movie for 72 PNG frames and greeting.mp4 (requires ffmpeg).
"""
import sys,math,subprocess,json
from pathlib import Path
import bpy
sys.path.insert(0,str(Path(__file__).resolve().parent))
from fukuchan_v2_common import OUT,render_view
from build_humanoid_motion import use_action,clear_pose

bpy.ops.wm.open_mainfile(filepath=str(OUT/'fukuchan_v2.blend'))
rig=bpy.data.objects['FukuchanV2Rig']
head=bpy.data.objects['Head'];lids=bpy.data.objects['Eyelids']
def face(blink=0,smile=0,mouth=0):
    for o in [head,lids]:
        for k in o.data.shape_keys.key_blocks:k.value=0
    lids.data.shape_keys.key_blocks['Blink'].value=blink
    head.data.shape_keys.key_blocks['Smile'].value=smile
    head.data.shape_keys.key_blocks['SpeechOpen'].value=mouth
def action(name,frame):
    use_action(rig,bpy.data.actions[name] if name else None)
    clear_pose(rig);bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
    bpy.context.view_layer.update()
if '--movie-only' not in sys.argv:
    action(None,0);face()
    for name,dr in [('front',(0,-1,0)),('side',(1,0,0)),('back',(0,1,0))]:
        render_view('final_'+name+'.png',dr,target=(0,0,.86),scale=2)
        render_view('final_head_'+name+'.png',dr,target=(0,0,1.535),scale=.48)
    for name,blink,smile,mouth in [('half_blink',.5,0,0),('blink',1,0,0),('smile',0,1,0),('speech',0,0,1)]:
        face(blink,smile,mouth);render_view('final_'+name+'.png',target=(0,0,1.535),scale=.42)
    face()
    for name,frame in [('Idle',0),('Walk',12),('Run',8),('Greeting',45),('Test_HeadTurn',22),('Test_ArmRaise',45),('Test_ElbowBend',45),('Test_KneeBend',45)]:
        action(name,frame)
        render_view('final_motion_'+name+'.png',direction=(.3,-1,.08),target=(0,0,1.05),scale=2.3)
        if name in ['Walk','Greeting']:
            render_view('final_motion_'+name+'_side.png',direction=(1,0,0),target=(0,0,1.05),scale=2.3)
if '--movie' in sys.argv or '--movie-only' in sys.argv:
    bpy.context.scene.cycles.samples=12
    folder=OUT/'preview';folder.mkdir(exist_ok=True)
    for i in range(72):
        t=i/24;action('Greeting',t*30)
        blink=max(0,1-abs(t-2.1)/.125)
        face(blink,.5*math.sin(math.pi*t/3)**2)
        render_view('../preview/frame_%04d.png'%i,direction=(.18,-1,.025),target=(0,0,.90),scale=3.6,size=(1920,1080))
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','warning','-y','-framerate','24','-i',str(folder/'frame_%04d.png'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(folder/'greeting.mp4')],check=True)
    for p in folder.glob('frame_*.png'):p.unlink()
print('FUKUCHAN_V2_RENDER_DONE',flush=True)
