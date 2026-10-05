"""Deterministic local shirt retouch. Requires numpy/Pillow. No generation.
Input is the pre-imagegen canonical sheet from commit a0d774b^.
Usage: python retouch_sobaya_shirt.py input.png output.png
"""
import sys,json
import numpy as np
from PIL import Image
src=np.array(Image.open(sys.argv[1]).convert('RGB'));out=src.copy()
# centers and ellipse radii in original1672x941 pixel coordinates.
regions=[(130,321,14,6),(271,327,16,12),(498,213,10,7),(591,214,10,8),(752,209,7,8),(1277,492,8,6),(1620,498,11,8)]
mask=np.zeros(src.shape[:2],bool)
from scipy.sparse import lil_matrix
from scipy.sparse.linalg import lsqr
for cx,cy,rx,ry in regions:
 x0,x1=cx-rx-3,cx+rx+4;y0,y1=cy-ry-3,cy+ry+4
 patch=src[y0:y1,x0:x1].astype(float);h,w=patch.shape[:2]
 yy,xx=np.mgrid[y0:y1,x0:x1];inside=((xx-cx)/rx)**2+((yy-cy)/ry)**2<1
 coords=np.argwhere(inside);ids=np.full((h,w),-1,int)
 for k,(y,x) in enumerate(coords):ids[y,x]=k
 rows=[];bs=[]
 # Minimize discrete Laplacian energy, including boundary-adjacent rows.
 # Equivalent to a biharmonic smooth fill with fixed surrounding pixels.
 for y in range(1,h-1):
  for x in range(1,w-1):
   stencil=[(y,x,-4),(y-1,x,1),(y+1,x,1),(y,x-1,1),(y,x+1,1)]
   if not any(ids[py,px]>=0 for py,px,c in stencil):continue
   row={};known=np.zeros(3)
   for py,px,c in stencil:
    k=ids[py,px]
    if k>=0:row[k]=c
    else:known+=c*patch[py,px]
   rows.append(row);bs.append(-known)
 A=lil_matrix((len(rows),len(coords)))
 for j,row in enumerate(rows):
  for k,v in row.items():A[j,k]=v
 A=A.tocsr();B=np.array(bs)
 filled=np.stack([lsqr(A,B[:,c],atol=1e-10,btol=1e-10,iter_lim=6000)[0] for c in range(3)],axis=1)
 out[y0:y1,x0:x1][inside]=np.clip(np.rint(filled),0,255).astype('uint8')
 mask[y0:y1,x0:x1]|=inside
assert np.array_equal(src[~mask],out[~mask])
Image.fromarray(out).save(sys.argv[2])
print(json.dumps({'regions':regions,'changed_pixels':int(np.any(src!=out,axis=2).sum()),'outside_masks_exactly_unchanged':True}))
