from pathlib import Path
import cv2, numpy as np, json, csv
from PIL import Image,ImageDraw,ImageFont
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[5]
REF=ROOT/'03_SCRIPTS/sobaya_turnaround_wan_20260916/frames/front.png'
ROIS_REF={'eyeL':(371,112,403,143),'eyeR':(416,112,448,145),'dot':(400,94,420,113),'mouth':(391,159,427,177), 'redUL':(374,86,397,115),'redUR':(422,86,445,115),'redLL':(373,141,394,181),'redLR':(427,141,447,181)}
ROIS_V3={'eyeL':(325,478,490,645),'eyeR':(585,478,757,645),'dot':(480,365,615,495),'mouth':(435,738,650,825),'redUL':(340,315,465,483),'redUR':(610,315,730,490),'redLL':(330,600,450,835),'redLR':(625,610,740,840)}
def features(path,rois,threshold=80):
    im=cv2.imread(str(path));out={}
    for key,(x0,y0,x1,y1) in rois.items():
        q=im[y0:y1,x0:x1].astype(float)
        if key.startswith('red'):mask=((q[:,:,2]>q[:,:,1]*1.5)&(q[:,:,2]>q[:,:,0]*1.5)&(q[:,:,2]>65)).astype('uint8')
        else:mask=(q.max(2)<threshold).astype('uint8')
        cnts,_=cv2.findContours(mask,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
        cnt=max(cnts,key=cv2.contourArea);x,y,w,h=cv2.boundingRect(cnt);mom=cv2.moments(cnt)
        center=[x0+mom['m10']/mom['m00'],y0+mom['m01']/mom['m00']]
        out[key]={'center':center,'bbox':[x0+x,y0+y,w,h],'contour':(cnt[:,0]+[x0,y0]).tolist()}
    return out
def metrics(f,chin,nose):
    le,re=np.array(f['eyeL']['center']),np.array(f['eyeR']['center']);mid=(le+re)/2;v=re-le;D=np.linalg.norm(v);vertical=np.array([-v[1],v[0]])/D
    dist=lambda p:float((np.array(p)-mid)@vertical/D*100)
    return {'eye_width':np.mean([f[k]['bbox'][2] for k in ['eyeL','eyeR']])/D*100,'eye_height':np.mean([f[k]['bbox'][3] for k in ['eyeL','eyeR']])/D*100,'mouth_width':f['mouth']['bbox'][2]/D*100,'mouth_height':f['mouth']['bbox'][3]/D*100,'mouth_below_eyes':dist(f['mouth']['center']),'dot_diameter':np.mean(f['dot']['bbox'][2:])/D*100,'dot_above_eyes':-dist(f['dot']['center']),'chin_below_eyes':dist(chin),'nose_tip_below_eyes':dist(nose),'lower_red_length':np.mean([f[k]['bbox'][3] for k in ['redLL','redLR']])/D*100,'lower_red_end_below_eyes':np.mean([dist([f[k]['center'][0],f[k]['bbox'][1]+f[k]['bbox'][3]-1]) for k in ['redLL','redLR']]),'D_pixels':float(D)}
