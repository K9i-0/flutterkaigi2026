"""Keep the original rounded distal phalanges rigid while curling the hand.

The continuous curl field is useful at the roots but can flatten an already
bent fingertip. Fit one rotation per distal finger (no scale/shear), then
blend that preserved sculpt into the proximal curl using surface weights.
"""
import numpy as np
from mathutils import Vector
from sobaya_grip_spacing import DIGITS


def preserve_tips(points,curled,weights):
    source=np.asarray(points,dtype=float);target=np.asarray(curled,dtype=float)
    result=target.copy();records=[]
    for digit,name in enumerate(DIGITS):
        samples=weights[:,digit]>.97
        a=source[samples];b=target[samples]
        ca=a.mean(axis=0);cb=b.mean(axis=0)
        u,s,vt=np.linalg.svd((a-ca).T@(b-cb))
        rotation=u@vt
        if np.linalg.det(rotation)<0:u[:,-1]*=-1;rotation=u@vt
        rigid=(source-ca)@rotation+cb
        blend=np.clip((weights[:,digit]-.55)/.40,0,1)
        blend=blend*blend*(3-2*blend)
        result+=(rigid-target)*blend[:,None]
        records.append({'finger':name,'rigidFitVertices':int(samples.sum()),
                        'maxCorrectionM':float(np.max(np.linalg.norm((rigid-target)*blend[:,None],axis=1)))})
    return [Vector(p) for p in result],{'method':'rigid distal sculpt preservation with surface-weighted root blend','digits':records}
