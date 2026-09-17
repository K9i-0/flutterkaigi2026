"""Close the four fingers laterally, retaining their individual thickness.

Harmonic weights follow the mesh surface. Each distal finger translates as
one piece; only its root blends into the unchanged palm. No global hand-width
scaling and no thumb reposing are used.
"""
import numpy as np
from mathutils import Vector

DIGITS=('Little','Ring','Middle','Index')
# Rest-hand local Z is the finger-row direction. Move the centers toward one
# another, rather than compressing the actual flesh of each finger.
SHIFTS=(.023,.010,-.007,-.021)

def pack_fingers(points,curled,neighbors):
    count=len(points);weights=np.zeros((count,4));fixed=np.zeros(count,dtype=bool)
    labels=np.full(count,-1,dtype=int)
    for i,p in enumerate(points):
        x,y,z=p
        thumb=x<-.044 and z>.020 and y<.145
        if y<.073 or thumb:
            fixed[i]=True
        else:
            digit=None
            if y>.116 and z<-.058:digit=0
            elif y>.150 and -.058<=z<-.018:digit=1
            elif y>.173 and -.018<=z<.026:digit=2
            elif y>.168 and z>=.026:digit=3
            if digit is not None:
                weights[i,digit]=1.;fixed[i]=True;labels[i]=digit
    # Distance-balanced Laplacian: short subdivided edges must not dominate
    # long edges along the same smooth surface.
    rows=[];cols=[];coeff=[]
    for i,adj in enumerate(neighbors):
        values=[1/max((points[i]-points[j]).length,.001) for j in adj]
        total=sum(values)
        for j,w in zip(adj,values):rows.append(i);cols.append(j);coeff.append(w/total)
    rows=np.array(rows);cols=np.array(cols);coeff=np.array(coeff)
    for iteration in range(650):
        average=np.zeros_like(weights)
        np.add.at(average,rows,weights[cols]*coeff[:,None])
        weights[~fixed]=average[~fixed]
    # Increase full-finger ownership along each branch without introducing
    # hard spatial partitions through a bent fingertip.
    total=weights.sum(axis=1)
    sharpened=weights**2
    denom=np.maximum(sharpened.sum(axis=1),1e-12)
    activation=np.clip(total/.70,0,1);activation=activation*activation*(3-2*activation)
    weights=sharpened/denom[:,None]*activation[:,None]
    shifts=weights@np.array(SHIFTS)
    result=[p+Vector((0,0,float(shift))) for p,shift in zip(curled,shifts)]
    return result,weights,{'method':'surface-harmonic finger adduction; distal fingers translate without width scaling',
                   'digitOrder':DIGITS,'fingerCenterShiftsM':SHIFTS,
                   'seedVertices':{n:int(sum(labels==i)) for i,n in enumerate(DIGITS)},
                   'maxAdductionM':float(max(abs(shifts))),
                   'thumbSeedDisplacementM':float(max((abs(shifts[i]) for i,p in enumerate(points) if p.x<-.044 and p.z>.020 and p.y<.145),default=0))}


def measure_spacing(points,positions,triangles,weights):
    from mathutils.bvhtree import BVHTree
    labels=np.argmax(weights,axis=1);confidence=np.max(weights,axis=1)
    surfaces=[];samples=[]
    for digit in range(4):
        faces=[tri for tri in triangles if all(labels[i]==digit and confidence[i]>.55 for i in tri)]
        surfaces.append(BVHTree.FromPolygons(positions,faces))
        cutoff=[.118,.140,.150,.145][digit]
        samples.append([positions[i] for i,p in enumerate(points) if labels[i]==digit and confidence[i]>.7 and p.y>cutoff])
    result=[]
    for left,right in [(0,1),(1,2),(2,3)]:
        distances=[];depths=[]
        for a,b in [(left,right),(right,left)]:
            for p in samples[a]:
                co,n,face,d=surfaces[b].find_nearest(p)
                if co is None:continue
                distances.append(d)
                # Restrict the signed proximity diagnostic to near surfaces;
                # these open finger patches are not closed solid volumes.
                if d<.006 and (p-co).dot(n)<-.0001:depths.append(-(p-co).dot(n))
        result.append({'pair':[DIGITS[left],DIGITS[right]],'minimumSurfaceGapM':min(distances),
                       'closestDecileGapM':float(np.quantile(distances,.1)),
                       'nearNegativeNormalSamples':len(depths),'maximumNegativeNormalDistanceM':max(depths,default=0)})
    return result
