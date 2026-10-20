"""Deterministic texture sources, no downloaded artwork.

One facade tile covers 4 bays x 8 floors (4 x 8 scene units); the stage script
repeats it by face size so windows keep their scale on every building.
"""
from PIL import Image,ImageDraw,ImageFilter,ImageFont
from pathlib import Path
import random
out=Path(__file__).resolve().parents[2]/'04_GAME_ASSETS/3d/stages/akasaka'
out.mkdir(parents=True,exist_ok=True)
r=random.Random(24)
def noise(size,base,amp):
 im=Image.new('RGB',size);p=im.load()
 for y in range(size[1]):
  for x in range(size[0]):
   n=r.randrange(-amp,amp+1);p[x,y]=tuple(max(0,min(255,c+n)) for c in base)
 return im
WARM=[(255,196,112),(244,170,92),(255,214,150),(226,150,84)]
COOL=[(196,222,236),(170,204,226),(222,236,240)]
DARK=[(30,34,44),(38,44,58),(46,50,62)]
def lit(rate,palette):
 return r.choice(palette) if r.random()<rate else r.choice(DARK)
# 0-2: mixed-use buildings, punched windows with frames and random lighting.
for k in range(3):
 base=[(95,87,89),(82,89,104),(128,112,98)][k]
 im=noise((512,1024),base,8);d=ImageDraw.Draw(im)
 for y in range(40,1024,128):
  d.rectangle((0,y-12,511,y-8),fill=(45,43,49))
  for x in range(24,512,128):
   color=lit(.45,WARM)
   d.rectangle((x-4,y-4,x+84,y+78),fill=(34,35,43));d.rectangle((x,y,x+80,y+72),fill=color)
   if color not in DARK and r.random()<.5:d.rectangle((x,y,x+80,y+22),fill=tuple(c*3//4 for c in color))
   d.line((x+40,y,x+40,y+72),fill=(51,44,42),width=3)
   d.line((x,y+34,x+80,y+34),fill=(51,44,42),width=2)
 im.save(out/f'facade_{k}.png')
# 3: office curtain wall, glass floors with a few cool-lit rooms.
im=noise((512,1024),(44,62,78),5);d=ImageDraw.Draw(im)
for y in range(0,1024,128):
 for x in range(0,512,64):
  c=lit(.32,COOL) if r.random()<.8 else (58,82,100)
  d.rectangle((x+3,y+18,x+61,y+124),fill=c)
 d.rectangle((0,y,511,y+16),fill=(70,78,86))
for x in range(0,512,64):d.rectangle((x,0,x+3,1023),fill=(84,92,100))
im.save(out/'facade_3.png')
# 4: apartment, balcony slabs and warm sliding windows.
im=noise((512,1024),(150,140,128),6);d=ImageDraw.Draw(im)
for y in range(0,1024,128):
 for x in range(0,512,128):
  d.rectangle((x+10,y+20,x+118,y+96),fill=lit(.55,WARM))
  d.line((x+64,y+20,x+64,y+96),fill=(60,56,52),width=3)
  d.rectangle((x+128-6,y,x+128,y+128),fill=(118,110,100))
 d.rectangle((0,y+96,511,y+126),fill=(186,178,166));d.rectangle((0,y+100,511,y+104),fill=(120,114,106))
im.save(out/'facade_4.png')
# 5: dark office with vertical fins and strip windows.
im=noise((512,1024),(36,38,46),4);d=ImageDraw.Draw(im)
for y in range(0,1024,128):
 for x in range(0,512,128):
  d.rectangle((x+12,y+30,x+116,y+100),fill=lit(.38,WARM+COOL))
for x in range(0,512,32):d.rectangle((x,0,x+7,1023),fill=(70,72,80))
im.save(out/'facade_5.png')
# Weathered red-oxide primer on rolled steel; one tile is 4 x 1 units.
im=noise((1024,256),(112,44,32),6);d=ImageDraw.Draw(im)
for i in range(420):
 x=r.randrange(1024);y=r.randrange(256);q=r.randrange(3,14)
 d.ellipse((x,y,x+q,y+q*r.uniform(.5,1)),fill=r.choice([(98,40,30),(124,56,36),(104,50,34)]))
im=im.filter(ImageFilter.GaussianBlur(1.2));d=ImageDraw.Draw(im)
for i in range(220):
 x=r.randrange(1024);y=r.randrange(256);q=r.randrange(1,4)
 d.ellipse((x,y,x+q,y+q),fill=r.choice([(146,84,48),(80,34,26)]))
im.save(out/'steel.png')
# Asphalt and sidewalk paving, 4 x 4 units per tile.
im=noise((256,256),(40,41,48),9).filter(ImageFilter.GaussianBlur(.6));im.save(out/'asphalt.png')
im=noise((256,256),(112,108,104),6);d=ImageDraw.Draw(im)
for i in range(0,256,64):d.line((i,0,i,255),fill=(84,80,78),width=2);d.line((0,i,255,i),fill=(84,80,78),width=2)
im.save(out/'paving.png')
# Distant skyline: dark mass with sparse lights, 8 x 8 units per tile.
im=noise((256,256),(38,30,46),3);d=ImageDraw.Draw(im)
for y in range(8,256,16):
 for x in range(6,256,14):
  if r.random()<.22:d.rectangle((x,y,x+6,y+6),fill=r.choice([(200,140,90),(170,150,150)]))
im.save(out/'skyline.png')
font='/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc'
for name,word,bg,fg in [('akasaka','赤坂',(156,35,35),(255,220,158)),('izakaya','居酒屋',(240,194,119),(52,28,23)),('yakitori','やきとり',(225,171,103),(64,34,22)),('soba','そば',(30,69,65),(249,225,184)),('karaoke','カラオケ',(110,40,120),(255,226,250)),('ramen','らーめん',(190,40,30),(255,240,210))]:
 im=Image.new('RGB',(256,768),bg);d=ImageDraw.Draw(im);d.rectangle((8,8,247,759),outline=fg,width=5)
 f=ImageFont.truetype(font,140 if len(word)<4 else 120)
 for i,c in enumerate(word):d.text((128,384+(i-(len(word)-1)/2)*155),c,font=f,fill=fg,anchor='mm')
 im.save(out/f'sign_{name}.png')
# Rooftop billboards with the canonical fictional names (text only).
for name,lines,bg,fg in [('accidenchua',[('ACCIDENCHUA',92)],(236,236,240),(120,20,140)),('tsurai',[('窓際スーパー',84),('つらい',150)],(196,200,208),(206,28,40))]:
 im=Image.new('RGB',(1024,384),bg);d=ImageDraw.Draw(im);d.rectangle((10,10,1013,373),outline=fg,width=10)
 ys=[192] if len(lines)==1 else [110,262]
 for (word,size),y in zip(lines,ys):d.text((512,y),word,font=ImageFont.truetype(font,size),fill=fg,anchor='mm')
 im.save(out/f'ad_{name}.png')
