"""Render rest/pose audits and an optional 3s greeting from Sobaya v2."""
import sys,subprocess
from pathlib import Path
import bpy
sys.path.insert(0,str(Path(__file__).resolve().parent))
from sobaya_v2_common import OUT,render_view
from build_humanoid_motion import use_action,clear_pose
bpy.ops.wm.open_mainfile(filepath=str(OUT/'sobaya_v2.blend'))
rig=bpy.data.objects['SobayaV2Rig']
def pose(name,frame):
 use_action(rig,bpy.data.actions[name] if name else None);clear_pose(rig)
 bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
bpy.context.scene.cycles.samples=16
if '--movie-only' not in sys.argv:
 pose(None,0)
 for name,direction in [('front',(0,-1,0)),('side',(1,0,0)),('back',(0,1,0))]:
  render_view('final_'+name+'.png',direction,target=(0,0,.90),scale=2.0,size=(960,960))
  render_view('head_'+name+'.png',direction,target=(0,0,1.61),scale=.48,size=(640,640))
 for name,frame in [('Idle',0),('Walk',12),('Run',8),('Greeting',45),('Test_HeadTurn',22),('Test_ArmRaise',45),('Test_ElbowBend',45),('Test_KneeBend',45)]:
  pose(name,frame)
  render_view('motion_'+name+'.png',(.3,-1,.08),target=(0,0,1.05),scale=2.3,size=(800,800))
  if name in ['Greeting','Walk','Test_HeadTurn']:
   render_view('motion_'+name+'_side.png',(1,0,0),target=(0,0,1.05),scale=2.3,size=(800,800))
if '--movie' in sys.argv or '--movie-only' in sys.argv:
 bpy.context.scene.cycles.samples=8
 folder=OUT/'preview';folder.mkdir(exist_ok=True)
 for i in range(72):
  pose('Greeting',i*30/24)
  render_view('../preview/frame_%04d.png'%i,(.18,-1,.025),target=(0,0,.94),scale=3.75,size=(1920,1080))
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','warning','-y','-framerate','24','-i',str(folder/'frame_%04d.png'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(folder/'greeting.mp4')],check=True)
 for p in folder.glob('frame_*.png'):p.unlink()
print('SOBAYA_V2_RENDER_DONE',flush=True)
