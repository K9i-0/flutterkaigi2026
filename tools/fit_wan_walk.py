"""Fit cyclic sagittal observations; never interpret monocular depth as 3D truth."""
from pathlib import Path
import json, hashlib
import numpy as np
from scipy.signal import find_peaks
ROOT=Path(__file__).resolve().parents[1]
obs=json.loads((ROOT/'.local/wan_motion/observations.json').read_text())
p=np.array([f.get('points',[[0]*4]*33) for f in obs['frames']]);fps=obs['fps']
hip=p[:,23:25,:2].mean(axis=1)
peaks,_=find_peaks((p[:,27,0]-hip[:,0])[35:135],distance=30,prominence=40)
peaks+=35;period=int(round(np.median(np.diff(peaks))));origin=int(peaks[0])
legs=[np.linalg.norm(p[45:135,h,:2]-p[45:135,k,:2],axis=1)+np.linalg.norm(p[45:135,k,:2]-p[45:135,a,:2],axis=1) for h,k,a in [(23,25,27),(24,26,28)]]
leg=float(np.median(legs));indices=np.arange(45,135);phase=(indices-origin)/period
speed=float(np.polyfit(indices/fps,hip[indices,0],1)[0]);duration=period/fps

def design(t):return np.array([np.ones_like(t)]+[f(t*n*2*np.pi) for n in range(1,4) for f in [np.sin,np.cos]]).T

def fit(values,phases=phase):return np.linalg.lstsq(design(phases),values,rcond=None)[0].tolist()
# Pool both visible half-cycles; side identities and the original sample indices remain in provenance.
phases=np.concatenate([phase,phase+.5]);ankle_x=[];lift=[];wrist_x=[];wrist_z=[];pitch=[]
for ankle,heel,toe,shoulder,elbow,wrist in [(27,29,31,11,13,15),(28,30,32,12,14,16)]:
    floor=np.percentile(p[indices,ankle,1],85)
    ankle_x.extend((p[indices,ankle,0]-hip[indices,0])/leg)
    lift.extend((floor-p[indices,ankle,1])/leg)
    arm=np.median(np.linalg.norm(p[indices,shoulder,:2]-p[indices,elbow,:2],axis=1)+np.linalg.norm(p[indices,elbow,:2]-p[indices,wrist,:2],axis=1))
    wrist_x.extend((p[indices,wrist,0]-p[indices,shoulder,0])/arm)
    wrist_z.extend((p[indices,shoulder,1]-p[indices,wrist,1])/arm)
    pitch.extend(np.arctan2(-(p[indices,toe,1]-p[indices,heel,1]),p[indices,toe,0]-p[indices,heel,0]))
markers=np.array([f['markers'] for f in obs['frames'] if len(f['markers'])==3]);motion=float(np.max(np.linalg.norm(markers-markers[0],axis=2)))
video=ROOT/'03_SCRIPTS/62_hazard_motion_reference_wan3/wan3_01_walk_clay_seed620102_480p.mp4'
result={'schema':1,'videoSha256':hashlib.sha256(video.read_bytes()).hexdigest(),'taskId':'364a188a-4a1d-4468-85bb-86384b1c938d','model':'wan3.0-video','poseModel':'MediaPipe pose_landmarker_full float16 v1','posePackage':'mediapipe==0.10.32','fps':fps,'size':[obs['width'],obs['height']],'trackedFrames':sum('points'in f for f in obs['frames']),'fittedFrames':[45,134],'leftPeakFrames':peaks.tolist(),'periodFrames':period,'duration':duration,'legPixels':leg,'rootPixelsPerSecond':speed,'rootLegsPerSecond':speed/leg,'markerTrackedFrames':len(markers),'maxMarkerDisplacementPx':motion,'stanceFraction':.60,'stanceNote':'Regularized from observed ankle forward maxima and following backward extrema; 60% support, symmetric left/right reconstruction.','coefficients':{'ankleForward':fit(ankle_x,phases),'ankleLift':fit(lift,phases),'wristForward':fit(wrist_x,phases),'wristUp':fit(wrist_z,phases),'footPitch':fit(pitch,phases),'pelvisUp':fit(-(hip[indices,1]-np.mean(hip[indices,1]))/leg)},'limitations':['No calibrated absolute scene scale: displacement is normalized by observed hip-knee-ankle chain length, then scaled to target skeleton.','Lateral sway, pelvis yaw, hidden-side depth and hand orientation are authored constraints, not captured measurements.','A periodic fit and a linear stance trajectory remove tracking noise and source foot drift. Only steady walking is reconstructed; start/stop is not included.']}
out=ROOT/'04_GAME_ASSETS/3d/motion_library/source/wan_walk_clay.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='coefficients'},indent=2))
