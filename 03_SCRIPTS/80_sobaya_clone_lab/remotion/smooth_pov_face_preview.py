"""Render identical zoom using fractional affine sampling instead of integer crop steps."""
from pathlib import Path
import subprocess
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parent.parent
source=root/'wan3_pov_replacement_seed26092680_480p.mp4'
output=root/'final_remotion_pov_face_smooth.mp4'
width,height=854,480
reader=subprocess.Popen(['ffmpeg','-v','error','-i',str(source),'-map','0:v:0','-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE)
writer=subprocess.Popen(['ffmpeg','-v','error','-y','-f','rawvideo','-pix_fmt','rgb24','-s',f'{width}x{height}','-r','30','-i','-','-i',str(source),'-map','0:v:0','-map','1:a:0','-c:v','libx264','-crf','18','-preset','fast','-pix_fmt','yuv420p','-c:a','copy','-movflags','+faststart',str(output)],stdin=subprocess.PIPE)
transforms=[]
for frame in range(120):
    raw=reader.stdout.read(width*height*3)
    if len(raw)!=width*height*3:raise RuntimeError('Unexpected end of input')
    p=min(max((frame-12)/60,0),1);ease=p*p*(3-2*p)
    z=1.08+(854/352-1.08)*ease
    x=30+205*ease;y=168*ease
    im=Image.frombytes('RGB',(width,height),raw)
    # Keep fractional origin and scale all the way through inverse mapping.
    im=im.transform((width,height),Image.Transform.AFFINE,(1/z,0,x,0,1/z,y),resample=Image.Resampling.BICUBIC)
    writer.stdin.write(im.tobytes());transforms.append((x,y,z))
reader.stdout.close();writer.stdin.close()
assert reader.wait()==0 and writer.wait()==0
np.save(root/'remotion/out/pov-prep/smooth-transforms.npy',transforms)
print(output)
