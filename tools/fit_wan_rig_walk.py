"""Fit a comparison gait from the rig-highlight video's BODY pose estimates.
The generated colored lines are never interpreted as a correct skeleton.
"""
from pathlib import Path
import json,hashlib
import numpy as np
from scipy.signal import find_peaks
ROOT=Path(__file__).resolve().parents[1]
obs=json.loads((ROOT/'.local/wan_rig_motion/observations.json').read_text());fps=obs['fps']
p=np.array([f.get('points',[[0]*4]*33) for f in obs['frames']]);world=np.array([f.get('worldPoints',[[0]*4]*33) for f in obs['frames']]);indices=np.arange(40,140)
assert all('points' in obs['frames'][i] for i in indices),'Missing pose in fitted range'
hip=p[:,23:25,:2].mean(axis=1);peaks=[]
for a in [27,28]:
 found,_=find_peaks((p[:,a,0]-hip[:,0])[35:145],distance=25,prominence=35);peaks.append(found+35)
assert all(len(k)>=2 for k in peaks)
period=int(round(np.median(np.concatenate([np.diff(k) for k in peaks]))));origin=int(peaks[0][0]);phase=(indices-origin)/period
leg=float(np.median([np.linalg.norm(p[indices,h,:2]-p[indices,k,:2],axis=1)+np.linalg.norm(p[indices,k,:2]-p[indices,a,:2],axis=1) for h,k,a in [(23,25,27),(24,26,28)]]))
speed=float(np.polyfit(indices/fps,hip[indices,0],1)[0])
def design(t):return np.array([np.ones_like(t)]+[f(t*n*2*np.pi) for n in range(1,4) for f in [np.sin,np.cos]]).T
def fit(values,phases=phase,weights=None):
 a=design(phases);b=np.asarray(values)
 if weights is not None:a=a*np.sqrt(weights)[:,None];b=b*np.sqrt(weights)
 return np.linalg.lstsq(a,b,rcond=None)[0].tolist()
# Remove the image-plane floor slope along the oblique walking direction.
ground=np.polyval(np.polyfit(hip[indices,0],np.max(p[indices,27:29,1],axis=1),1),hip[indices,0])
phases=np.concatenate([phase,phase+.5]);ankle_x=[];lift=[];pitch=[]
for ankle,heel,toe in [(27,29,31),(28,30,32)]:
 ankle_x.extend((p[indices,ankle,0]-hip[indices,0])/leg)
 residual=p[indices,ankle,1]-ground;floor=ground+np.percentile(residual,85)
 lift.extend((floor-p[indices,ankle,1])/leg)
 pitch.extend(np.arctan2(-(p[indices,toe,1]-p[indices,heel,1]),p[indices,toe,0]-p[indices,heel,0]))
# Torso-relative arm directions give separate shoulder and elbow articulation.
# MediaPipe depth is uncertain: lateral components are bounded during retargeting.
left=world[indices,11,:3]-world[indices,12,:3];left[:,1]=0;left/=np.linalg.norm(left,axis=1)[:,None]
up=np.tile([0.,-1.,0.],(len(indices),1));forward=np.cross(left,up)
arms={}
for part,endpoints in [('upper',[(11,13),(12,14)]),('lower',[(13,15),(14,16)])]:
 vectors=[];weights=[]
 for sign,(a,b) in zip([1,-1],endpoints):
  delta=world[indices,b,:3]-world[indices,a,:3];delta/=np.linalg.norm(delta,axis=1)[:,None]
  vectors.extend(np.column_stack([np.sum(delta*left,axis=1)*sign,np.sum(delta*forward,axis=1),np.sum(delta*up,axis=1)]))
  weights.extend(np.minimum(p[indices,a,3],p[indices,b,3])**2)
 vectors=np.array(vectors);arms[part]={axis:fit(vectors[:,n],phases,np.maximum(weights,.02)) for n,axis in enumerate(['out','forward','up'])}
pelvis=-((hip[indices,1]-ground)-np.mean(hip[indices,1]-ground))/leg
video=ROOT/'03_SCRIPTS/62_hazard_motion_reference_wan3/wan3_01_walk_clay_rig_seed620102_480p.mp4'
result={'schema':2,'videoSha256':hashlib.sha256(video.read_bytes()).hexdigest(),'taskId':'b70461e5-53e7-49ef-bec3-d15bb2f54637','model':'wan3.0-video','poseModel':'MediaPipe pose_landmarker_full float16 v1','posePackage':'mediapipe==0.10.32','fps':fps,'size':[obs['width'],obs['height']],'trackedFrames':sum('points'in f for f in obs['frames']),'fittedFrames':[40,139],'leftPeakFrames':peaks[0].tolist(),'rightPeakFrames':peaks[1].tolist(),'periodFrames':period,'duration':period/fps,'legPixels':leg,'rootPixelsPerSecond':speed,'rootLegsPerSecond':speed/leg,'stanceFraction':.60,'armMedianVisibility':dict(zip(['leftShoulder','rightShoulder','leftElbow','rightElbow','leftWrist','rightWrist'],np.median(p[indices][:,[11,12,13,14,15,16],3],axis=0).tolist())),'coefficients':{'ankleForward':fit(ankle_x,phases),'ankleLift':fit(lift,phases),'footPitch':fit(pitch,phases),'pelvisUp':fit(pelvis)},'armDirections':arms,'limitations':['Exploratory body-pose reconstruction, not exact tracking of the generated colored skeleton.','Single-camera depth, source yaw changes and occlusion limit accuracy; arm observations are confidence-weighted and symmetrized.','Oblique image-floor drift removed; absolute scale is uncalibrated and is normalized by projected leg chain length.','Foot support regularized by IK. No start or stop reconstruction. Lateral arm range is bounded and hand orientation is completed from the rest rig.','This trial changes both source video and arm reconstruction, so it does not isolate the causal benefit of skeleton highlights.']}
out=ROOT/'04_GAME_ASSETS/3d/motion_library/source/wan_walk_clay_rig.json';out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k not in ['coefficients','armDirections']},indent=2))
