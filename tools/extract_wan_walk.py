"""Observe the fixed-camera Wan clay walk using MediaPipe (local, reproducible).
Run with .local/wan-motion-venv/bin/python tools/extract_wan_walk.py.
Raw observations/overlay are local QA, not an assertion of accurate 3D capture.
"""
from pathlib import Path
import json
import cv2
import numpy as np
import mediapipe as mp
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'.local/wan_motion'
video=ROOT/'03_SCRIPTS/62_hazard_motion_reference_wan3/wan3_01_walk_clay_seed620102_480p.mp4'
cap=cv2.VideoCapture(str(video));fps=cap.get(cv2.CAP_PROP_FPS)
w,h=[int(cap.get(p)) for p in [cv2.CAP_PROP_FRAME_WIDTH,cv2.CAP_PROP_FRAME_HEIGHT]]
options=mp.tasks.vision.PoseLandmarkerOptions(base_options=mp.tasks.BaseOptions(model_asset_path=str(folder/'pose_landmarker_full.task')),running_mode=mp.tasks.vision.RunningMode.VIDEO,min_pose_detection_confidence=.35,min_tracking_confidence=.4)
frames=[]; tiles=[]
with mp.tasks.vision.PoseLandmarker.create_from_options(options) as landmarker:
    i=0
    while True:
        ok,frame=cap.read()
        if not ok:break
        result=landmarker.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(frame,cv2.COLOR_BGR2RGB)),round(i*1000/fps))
        gray=cv2.cvtColor(frame[:65],cv2.COLOR_BGR2GRAY)
        n,_,stats,centers=cv2.connectedComponentsWithStats((gray<100).astype(np.uint8))
        markers=sorted([c.tolist() for s,c in zip(stats[1:],centers[1:]) if 20<s[4]<500 and 4<s[2]<25 and 4<s[3]<25])
        row={'frame':i,'time':i/fps,'markers':markers}
        if result.pose_landmarks:
            row['points']=[[p.x*w,p.y*h,p.z*w,p.visibility] for p in result.pose_landmarks[0]]
            for p in row['points']:cv2.circle(frame,(round(p[0]),round(p[1])),2,(0,0,255),-1)
            for a,b in [(11,13),(13,15),(12,14),(14,16),(23,25),(25,27),(24,26),(26,28),(11,23),(12,24),(27,31),(28,32)]:
                cv2.line(frame,tuple(np.round(row['points'][a][:2]).astype(int)),tuple(np.round(row['points'][b][:2]).astype(int)),(0,200,0),1)
        frames.append(row)
        if i%15==0:
            cv2.putText(frame,f'{i/fps:.2f}s',(10,h-15),cv2.FONT_HERSHEY_SIMPLEX,.6,(0,0,255),1)
            tiles.append(cv2.resize(frame,(421,237)))
        i+=1
(folder/'observations.json').write_text(json.dumps({'fps':fps,'width':w,'height':h,'frames':frames}))
cv2.imwrite(str(folder/'pose_contact.jpg'),np.vstack([np.hstack(tiles[i:i+4]) for i in range(0,12,4)]))
print('frames',len(frames),'tracked',sum('points'in f for f in frames))
for f in frames[::10]:
    p=np.array(f.get('points',[]))
    print(f['frame'],f['markers'],'hip',p[23:25,:2].mean(axis=0).round(1).tolist() if len(p) else None,'feet',p[27:29,:2].round(1).tolist() if len(p) else None)
