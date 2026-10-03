"""Track and soften the incorrect first publisher glyph in the adopted 720p CM.
Run with .local/screen-replacement-venv/bin/python. Audio is stream-copied.
"""
from pathlib import Path
import cv2, numpy as np, subprocess, json
P=Path(__file__).resolve().parent
src=P/'final_remotion_cm_sobaya_no_sokan.mp4'
out=P/'final_remotion_cm_sobaya_blurred.mp4'
work=P/'remotion/out'; work.mkdir(exist_ok=True)
cap=cv2.VideoCapture(str(src))
proc=subprocess.Popen(['ffmpeg','-v','error','-y','-f','rawvideo','-pix_fmt','bgr24','-s','1280x720','-r','30','-i','pipe:0','-i',str(src),'-map','0:v','-map','1:a','-c:v','libx264','-crf','17','-preset','medium','-pix_fmt','yuv420p','-c:a','copy','-movflags','+faststart',str(out)],stdin=subprocess.PIPE)
shots={102:(160,(432.,153.),(18.,15.),(418,136,172,28)),670:(840,(232.,222.),(18.,14.),(215,189,175,43))}
records=[]; thumbs=[]; active=None
for f in range(900):
    ok,im=cap.read()
    if not ok: raise RuntimeError(f'Missing frame {f}')
    gray=cv2.cvtColor(im,cv2.COLOR_BGR2GRAY)
    if f in shots:
        end,center,radii,box=shots[f]; center=np.array(center); radii=np.array(radii)
        x,y,w,h=box; mask=np.zeros_like(gray); mask[y:y+h,x:x+w]=255
        pts=cv2.goodFeaturesToTrack(gray,100,0.005,3,mask=mask)
        active=True; prev=gray
    elif active and f<end:
        nxt,status,_=cv2.calcOpticalFlowPyrLK(prev,gray,pts,None,winSize=(31,31),maxLevel=3)
        good=status.ravel()==1
        mat,inliers=cv2.estimateAffinePartial2D(pts[good],nxt[good],method=cv2.RANSAC,ransacReprojThreshold=2)
        if mat is None: raise RuntimeError(f'Tracking lost {f}')
        center=mat[:,:2]@center+mat[:,2]
        radii*=np.sqrt(np.linalg.det(mat[:,:2]))
        pts=nxt[good].reshape(-1,1,2); prev=gray
    elif active: active=None
    if active:
        cx,cy=center; rx,ry=radii
        x0=max(0,int(cx-rx*2)); x1=min(1280,int(cx+rx*2)+1)
        y0=max(0,int(cy-ry*2)); y1=min(720,int(cy+ry*2)+1)
        roi=im[y0:y1,x0:x1]; yy,xx=np.mgrid[y0:y1,x0:x1]
        distance=np.sqrt(((xx-cx)/rx)**2+((yy-cy)/ry)**2)
        a=np.clip((1.15-distance)/.35,0,1)[...,None]
        blur=cv2.GaussianBlur(roi,(0,0),max(3,float(rx)*.45))
        im[y0:y1,x0:x1]=np.rint(roi*(1-a)+blur*a).astype(np.uint8)
        records.append({'frame':f,'center':center.tolist(),'radii':radii.tolist()})
        if f%10==0 or f in shots or f==end-1:
            crop=im[max(0,int(cy)-35):int(cy)+45,max(0,int(cx)-30):int(cx)+190]
            crop=cv2.resize(crop,(440,160)); cv2.putText(crop,str(f),(5,150),cv2.FONT_HERSHEY_SIMPLEX,.55,(0,180,255),1)
            thumbs.append(crop)
    proc.stdin.write(im.tobytes())
proc.stdin.close(); assert proc.wait()==0
cap.release()
while len(thumbs)%4: thumbs.append(np.zeros_like(thumbs[0]))
cv2.imwrite(str(work/'cover-blur-audit.jpg'),np.vstack([np.hstack(thumbs[i:i+4]) for i in range(0,len(thumbs),4)]))
(P/'cover-blur.json').write_text(json.dumps({'input':src.name,'output':out.name,'fps':30,'audio':'stream-copy','tracking':records},indent=2)+'\n')
print(out)
