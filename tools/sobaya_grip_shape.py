"""Volume-aware curved finger field for the approved Sobaya v3 right hand.

Coordinates are in RightHand's rest frame, metres. The original sculpt,
UVs, finger separation, nails and wrist seam are retained. No linear skin
blend across a sharply folded joint is used for the grip target.
"""
import math
from mathutils import Vector, Matrix

REVISION = 'sobaya-grip-v3-20260917'
GRIP_CENTER = (-.018, .100, -.005)
_up=Vector((-.24,.20,1)).normalized()
_handle=Vector((0,-1,0));_handle=(_handle-_up*_handle.dot(_up)).normalized()
_depth=_up.cross(_handle)
MUG_ROTATION=Matrix((_handle,_depth,_up)).transposed()

def smooth(t):
    t = max(0., min(1., t))
    return t*t*(3-2*t)


def deform(p):
    x,y,z = p
    thumb=smooth((-x-.025)/.035)*smooth((z-.005)/.030)*(1-smooth((y-.14)/.012))
    base=.083+.022*smooth((z+.065)/.045)
    t=max(0., y-base)
    radius=.035
    angle=t/radius
    center=.025-.55*(y-.10)-.018*smooth((z+.02)/.07)-.015*smooth((-z-.035)/.030)
    anchor=.025-.55*(base-.10)-.018*smooth((z+.02)/.07)-.015*smooth((-z-.035)/.030)
    offset=x-center
    q=Vector((anchor-radius*(1-math.cos(angle))+offset*math.cos(angle),
              base+radius*math.sin(angle)+offset*math.sin(angle),z)) if t else p.copy()
    q=p.lerp(q,1-thumb)
    q+=Vector((.017,.015,-.008))*(thumb*smooth((y-.030)/.045))
    return q


def jacobian(p):
    eps=1e-5
    columns=[]
    for axis in range(3):
        offset=Vector((0,0,0));offset[axis]=eps
        columns.append((deform(p+offset)-deform(p-offset))/(2*eps))
    return Matrix(columns).transposed()
