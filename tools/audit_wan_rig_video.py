"""Color and fixed-marker diagnostics for the Wan rig-highlight experiment.
Color presence is NOT proof of joint correctness. Inspect saved contact sheets.
"""
from pathlib import Path
import json,hashlib
import cv2
import numpy as np
ROOT=Path(__file__).resolve().parents[1];folder=ROOT/'03_SCRIPTS/62_hazard_motion_reference_wan3';out=folder/'evidence/rig-highlight';out.mkdir(parents=True,exist_ok=True)
video=folder/'wan3_01_walk_clay_rig_seed620102_480p.mp4';cap=cv2.VideoCapture(str(video));fps=cap.get(cv2.CAP_PROP_FPS);w=int(cap.get(3));h=int(cap.get(4));rows=[];tiles=[];armtiles=[]
while True:
 ok,im=cap.read()
 if not ok:break
 i=len(rows);hsv=cv2.cvtColor(im,cv2.COLOR_BGR2HSV)
 masks={'cyan':cv2.inRange(hsv,(75,55,80),(110,255,255)),'magenta':cv2.inRange(hsv,(135,55,80),(178,255,255)),'yellow':cv2.inRange(hsv,(15,55,80),(40,255,255))}
 g=cv2.cvtColor(im[:int(h*.15)],cv2.COLOR_BGR2GRAY);n,_,stats,centers=cv2.connectedComponentsWithStats((g<80).astype(np.uint8));markers=sorted([c.tolist() for s,c in zip(stats[1:],centers[1:]) if 15<s[4]<400 and 4<s[2]<25 and 4<s[3]<25])
 row={'frame':i,'time':i/fps,'colorPixels':{k:int(np.count_nonzero(m)) for k,m in masks.items()},'backgroundMarkers':markers};rows.append(row)
 if i%10==0:
  tile=im.copy();cv2.putText(tile,f'{i/fps:.2f}s',(12,h-12),cv2.FONT_HERSHEY_SIMPLEX,.6,(255,255,255),1);tiles.append(cv2.resize(tile,(421,237)))
  union=masks['cyan']|masks['magenta']|masks['yellow'];ys,xs=np.where(union>0)
  if len(xs):
   x0=max(0,int(np.min(xs))-40);x1=min(w,int(np.max(xs))+40);y0=max(0,int(np.min(ys))-25);y1=min(h,int(np.percentile(ys,60))+20)
   crop=im[y0:y1,x0:x1];canvas=np.full((300,260,3),40,dtype=np.uint8);scale=min(260/crop.shape[1],280/crop.shape[0]);crop=cv2.resize(crop,(round(crop.shape[1]*scale),round(crop.shape[0]*scale)));canvas[:crop.shape[0],:crop.shape[1]]=crop;cv2.putText(canvas,f'{i/fps:.2f}s',(8,294),cv2.FONT_HERSHEY_SIMPLEX,.5,(255,255,255),1);armtiles.append(canvas)
for name,tilelist,cols in [('full',tiles,6),('arms',armtiles,6)]:
 while len(tilelist)%cols:tilelist.append(np.zeros_like(tilelist[0]))
 cv2.imwrite(str(out/f'{name}.jpg'),np.vstack([np.hstack(tilelist[n:n+cols]) for n in range(0,len(tilelist),cols)]))
markers=np.array([r['backgroundMarkers'] for r in rows if len(r['backgroundMarkers'])==3]);report={'taskId':'b70461e5-53e7-49ef-bec3-d15bb2f54637','status':'SUCCEEDED','video':video.name,'sha256':hashlib.sha256(video.read_bytes()).hexdigest(),'resolutionRequested':'480P','width':w,'height':h,'fps':fps,'frames':len(rows),'videoSeconds':len(rows)/fps,'seed':620102,'estimatedCostUsd':.21,'costNote':'Estimate, not billing query','threeMarkersDetectedFrames':len(markers),'maxBackgroundMarkerDisplacementPx':float(np.max(np.linalg.norm(markers-markers[0],axis=2))) if len(markers) else None,'colorPresence':{k:{'minPixels':min(r['colorPixels'][k] for r in rows),'framesWithAtLeast10Pixels':sum(r['colorPixels'][k]>=10 for r in rows)} for k in masks},'limitation':'Color presence does not validate bone count, anatomical registration, left/right identity, bone lengths or 3D pose. See visual review.'}
(out/'frame_measurements.json').write_text(json.dumps(rows,indent=2)+'\n');(folder/'walk_clay_rig_review.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
