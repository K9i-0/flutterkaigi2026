from pathlib import Path
import cv2,numpy as np,json
from PIL import Image,ImageDraw,ImageFont
BASE=Path(__file__).resolve().parent;AUDIT=BASE.parent/'face_audit_20260917'
ns={'__file__':str(BASE/'measurement_utils.py')};exec((BASE/'measurement_utils.py').read_text().split('# Chin and nose anchors')[0].replace('q[:,:,1]*1.5','q[:,:,1]*1.4').replace('q[:,:,0]*1.5','q[:,:,0]*1.3').replace('q[:,:,2]>65','q[:,:,2]>20'),ns)
features=ns['features'];metrics=ns['metrics'];refpath=BASE.parent/'inputs/front.png'
rois={'eyeL':(300,450,500,650),'eyeR':(580,460,775,660),'dot':(492,345,600,455),'mouth':(450,750,640,825),'redUL':(330,300,460,483),'redUR':(615,310,750,490),'redLL':(310,625,450,855),'redLR':(625,635,765,865)}
rf=features(refpath,ns['ROIS_REF']);mf=features(BASE/'front.png',rois)
def oriented_metrics(f,chin,nose):
 out=metrics(f,chin,nose);le,re=np.array(f['eyeL']['center']),np.array(f['eyeR']['center']);axis=(re-le)/np.linalg.norm(re-le);rot=np.array([axis,[-axis[1],axis[0]]]);D=np.linalg.norm(re-le)
 dims={k:np.ptp(np.array(v['contour'])@rot.T,axis=0)+1 for k,v in f.items()}
 out['eye_width']=np.mean([dims[k][0] for k in ['eyeL','eyeR']])/D*100;out['eye_height']=np.mean([dims[k][1] for k in ['eyeL','eyeR']])/D*100
 out['mouth_width']=dims['mouth'][0]/D*100;out['mouth_height']=dims['mouth'][1]/D*100
 return out
rm=oriented_metrics(rf,(410,207),(409,151));mm=oriented_metrics(mf,(525,961),(548,696))
oldfeatures=features(BASE/'before_front.png',ns['ROIS_V3']);oldmetrics=oriented_metrics(oldfeatures,(525,961),(543,696))
old={'v3_features':oldfeatures};rows=[]
for key in ['eye_width','eye_height','mouth_width','mouth_height','mouth_below_eyes','dot_diameter','dot_above_eyes','chin_below_eyes','lower_red_length','lower_red_end_below_eyes']:
 before=round(oldmetrics[key],2)
 rows.append({'metric':key,'reference':round(rm[key],2),'before':before,'after':round(mm[key],2),'difference_percent':round((mm[key]/rm[key]-1)*100,1)})
(BASE/'measurements.json').write_text(json.dumps({'metrics':rows,'features':mf,'manual_chin':[525,961],'method':'Eye-center distance = 100. Width/height measured after roll alignment. Red segmentation includes dark red (R>20), unlike the initial R>65 audit. Reference face approximately 100px wide; 1-2px uncertainty.'},indent=2));print(json.dumps(rows,indent=2))
def align(path,f):
 le,re=np.array(f['eyeL']['center']),np.array(f['eyeR']['center']);mid=(le+re)/2;v=re-le;D=np.linalg.norm(v);a=v/D;rot=np.array([[a[0],a[1]],[-a[1],a[0]]])*240/D;mat=np.c_[rot,np.array([350,320])-rot@mid]
 return cv2.warpAffine(cv2.imread(str(path)),mat,(700,850),borderValue=(245,245,245))
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',24)
panel=Image.new('RGB',(2100,920),'#f5f5f5');d=ImageDraw.Draw(panel)
for off,path,f,label in [(0,refpath,rf,'WAN front / reference'),(700,BASE/'before_front.png',old['v3_features'],'Before / v3'),(1400,BASE/'front.png',mf,'After / face refinement')]:
 im=align(path,f);panel.paste(Image.fromarray(cv2.cvtColor(im,cv2.COLOR_BGR2RGB)),(off,60));d.text((off+20,15),label,font=font,fill='black')
panel.save(BASE/'comparison.png')
