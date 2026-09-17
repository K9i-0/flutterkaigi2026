"""Pixel agreement at source resolution; not an identity-recognition score."""
import subprocess,math,json,struct,hashlib
from pathlib import Path
P=Path(__file__).resolve().parent

def gray(name):
    b=subprocess.check_output(['ffmpeg','-v','error','-i',str(P/name),'-vf','scale=180:180:flags=lanczos','-f','rawvideo','-pix_fmt','gray','-frames:v','1','-'])
    return list(b)
ref=gray('reference_face_zoom.png')
regions={'brows_eyes':[52,77,128,101],'nose':[66,101,114,125],'mouth':[60,126,114,143],'central_face':[51,76,130,148]}
res={}
for name in ['baseline_front.png','candidate_front.png']:
    a=gray(name);res[name]={}
    for region,(x0,y0,x1,y1) in regions.items():
        ids=[y*180+x for y in range(y0,y1) for x in range(x0,x1)];u=[ref[i] for i in ids];v=[a[i] for i in ids];mu=sum(u)/len(u);mv=sum(v)/len(v)
        cov=sum((x-mu)*(y-mv) for x,y in zip(u,v));den=math.sqrt(sum((x-mu)**2 for x in u)*sum((y-mv)**2 for y in v))
        res[name][region]={'normalized_luminance_correlation':round(cov/den,4),'mean_absolute_luminance_error_255':round(sum(abs(x-y) for x,y in zip(u,v))/len(u),3)}
(P/'image_agreement.json').write_text(json.dumps({'note':'Fixed camera and lighting. Source-resolution luminance comparison, not an identity or 3D quality score. Region bounds in the 180x180 crop.','regions':regions,'results':res},indent=2)+'\n');print(json.dumps(res,indent=2))
b=(P/'fukuchan_front_faithful.glb').read_bytes();magic,version,size=struct.unpack_from('<4sII',b);length,_=struct.unpack_from('<II',b,12);g=json.loads(b[20:20+length]);assert magic==b'glTF' and size==len(b) and version==2
assert len(g['meshes'])==1 and not g.get('skins') and all('bufferView' in x for x in g['images'])
validation={'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'meshes':1,'material_primitives':sum(len(m['primitives']) for m in g['meshes']),'embedded_images':len(g['images']),'skins':0,'animations':len(g.get('animations',[]))}
(P/'glb_validation.json').write_text(json.dumps(validation,indent=2)+'\n');print(validation)
