"""Resize adopted Imagegen albedos and compile deterministic PBR data maps.

No new geometry. Color artwork is only resized; normal maps encode bounded
micro-height gradients, MR maps encode material properties (not lighting).
Run after build_akasaka_textures.py and before build_akasaka_stage.py.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

OUT = Path(__file__).resolve().parents[2] / '04_GAME_ASSETS/3d/stages/akasaka'
SOURCE = OUT / 'source_imagegen'

def save_data(name, array):
    Image.fromarray(np.clip(array, 0, 255).astype('uint8')).save(OUT / name)

for name, size in [('facade_0', (512, 1024)), ('facade_3', (512, 1024)),
                   ('facade_4', (512, 1024)), ('steel', (1024, 256)), ('asphalt', (512, 512))]:
    Image.open(SOURCE / f'{name}.png').convert('RGB').resize(size, Image.Resampling.LANCZOS).save(OUT / f'{name}.png')

# The existing emission maps are clipped to the conservative interiors of the
# same UV window grid. Restrict generated facade windows to avoid glowing sills.
for kind in range(6):
    mask = Image.new('L', (512, 1024)); d = ImageDraw.Draw(mask)
    for y in range(0, 1024, 128):
        for x in range(0, 512, 64 if kind == 3 else 128):
            if kind < 3:
                d.rectangle((x+26,y+42,x+102,y+110), fill=255)
                d.line((x+64,y+40,x+64,y+114),fill=0,width=4)
                d.line((x+24,y+74,x+106,y+74),fill=0,width=3)
            elif kind == 3:d.rectangle((x+5,y+20,x+59,y+121),fill=255)
            elif kind == 4:
                d.rectangle((x+12,y+22,x+116,y+94),fill=255)
                d.line((x+64,y+20,x+64,y+96),fill=0,width=4)
            else:
                d.rectangle((x+12,y+32,x+116,y+98),fill=255)
                for q in range(x,x+128,32):d.rectangle((q,y,q+8,y+127),fill=0)
    # MR uses lower-resolution maps; only smooth panes are reflective, masonry
    # stays matte. Tinted glazing is an opaque metallic-workflow approximation.
    a = np.asarray(mask.resize((256,512),Image.Resampling.BOX),dtype=np.float32)/255
    mr = np.zeros((512,256,3)); mr[:,:,0]=255
    mr[:,:,1] = 228*(1-a)+68*a
    mr[:,:,2] = 5*(1-a)+(110 if kind==3 else 65)*a
    save_data(f'facade_{kind}_mr.png',mr)
    # Keep old emission colors and room choices. Conservative masking changes
    # only shader data, not generated color artwork.
    e=np.asarray(Image.open(OUT/f'facade_{kind}_emit.png').convert('RGB')).copy()
    e=(e.astype(float)*(np.asarray(mask)[:,:,None]/255)).astype('uint8')
    save_data(f'facade_{kind}_emit.png',e)

for name, strength in [('steel',.7),('asphalt',.35)]:
    im=Image.open(OUT/f'{name}.png').convert('RGB')
    rgb=np.asarray(im,dtype=np.float32)/255
    height=np.asarray(im.convert('L').filter(ImageFilter.GaussianBlur(.8)),dtype=np.float32)/255
    dx=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*strength
    dy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*strength
    normal=np.stack([-dx,dy,np.ones_like(dx)],axis=2)
    normal/=np.linalg.norm(normal,axis=2,keepdims=True)
    save_data(f'{name}_normal.png',(normal*.5+.5)*255)
    mr=np.zeros_like(rgb);mr[:,:,0]=1
    if name=='steel':
        # Exposed desaturated scratches are metallic; red painted/rusted areas
        # are dielectric. No blanket shiny "metal" applied to the red paint.
        exposed=np.clip((.12-(rgb[:,:,0]-rgb[:,:,2]))*8,0,1)
        mr[:,:,1]=.78-.42*exposed;mr[:,:,2]=.03+.8*exposed
    else:
        mr[:,:,1]=.9-.12*height;mr[:,:,2]=0
    save_data(f'{name}_mr.png',mr*255)
print('Prepared 5 albedos, 8 MR maps and 2 shallow normal maps')
