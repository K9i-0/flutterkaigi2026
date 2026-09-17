from pathlib import Path
import json,cv2,numpy as np
from PIL import Image,ImageDraw,ImageFont
O=Path(__file__).resolve().parent;B=O.parent;S=B/'face_refinement_20260917'
ns={};exec((S/'measurement_utils.py').read_text().replace('BASE=Path(__file__).resolve().parent',f'BASE=Path({str(S)!r})'),ns)
rois={'eyeL':(330,455,510,640),'eyeR':(580,455,760,640),'dot':(490,360,600,465),'mouth':(460,720,625,810)}
f=ns['features'](O/'front.png',rois)
a=json.loads((B/'mask_scale_audit_20260917/measurements.json').read_text());ref=json.loads((S/'reference_landmarks.json').read_text());old=json.loads((S/'measurements.json').read_text())['features']
canvas=Image.new('RGB',(1800,870),'#f6f6f4');draw=ImageDraw.Draw(canvas);font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',24);result={}
for i,(name,path,features,anchor) in enumerate([('WAN front',B/'inputs/front.png',ref,a['anchors_manual_native_pixels']['reference']),('Before',S/'glb_verified_front.png',old,a['anchors_manual_native_pixels']['model']),('After / 90%',O/'front.png',f,a['anchors_manual_native_pixels']['model'])]):
 le,re=np.array(features['eyeL']['center']),np.array(features['eyeR']['center']);v=re-le;v=v/np.linalg.norm(v);rot=np.array([v,[-v[1],v[0]]]);aa={k:rot@p for k,p in anchor.items()};W=aa['right'][0]-aa['left'][0];H=aa['chin'][1]-aa['top'][1];center=np.array([(aa['left'][0]+aa['right'][0])/2,(aa['top'][1]+aa['chin'][1])/2]);fac=560/H;mat=np.c_[rot*fac,[300,415]-center*fac]
 im=cv2.warpAffine(cv2.imread(str(path)),mat,(600,800),borderValue=(246,246,244));canvas.paste(Image.fromarray(cv2.cvtColor(im,cv2.COLOR_BGR2RGB)),(600*i,55));draw.text((600*i+22,15),name,font=font,fill='black')
 pts=np.concatenate([features[k]['contour'] for k in rois])@rot.T;dims=np.ptp(pts,axis=0)+1
 result[name]={'core_width_over_mask_width_pct':100*dims[0]/W,'core_height_over_mask_height_pct':100*dims[1]/H}
 draw.text((600*i+18,825),f"Face / mask: W {100*dims[0]/W:.1f}%  H {100*dims[1]/H:.1f}%",font=font,fill='black')
canvas.save(O/'comparison.png');(O/'measurements.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
