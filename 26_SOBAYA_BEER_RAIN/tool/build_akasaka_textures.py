"""Deterministic texture sources, no downloaded artwork."""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import random
out=Path(__file__).resolve().parents[2]/'04_GAME_ASSETS/3d/stages/akasaka'
out.mkdir(parents=True,exist_ok=True)
r=random.Random(24)
# Facade: broad window rhythm, subtle concrete variation, illuminated rooms.
for k in range(3):
 im=Image.new('RGB',(512,1024));p=im.load();base=[(95,87,89),(82,89,104),(128,112,98)][k]
 for y in range(1024):
  for x in range(512):
   n=r.randrange(-8,9);p[x,y]=tuple(max(0,min(255,c+n)) for c in base)
 d=ImageDraw.Draw(im)
 for y in range(40,1024,128):
  d.rectangle((0,y-12,511,y-8),fill=(45,43,49))
  for x in range(24,512,120):
   color=r.choice([(245,182,98),(206,152,89),(42,52,66),(54,62,80),(94,89,89)])
   d.rectangle((x-4,y-4,x+80,y+78),fill=(34,35,43));d.rectangle((x,y,x+76,y+72),fill=color)
   d.line((x+38,y,x+38,y+72),fill=(51,44,42),width=3)
   d.line((x,y+34,x+76,y+34),fill=(51,44,42),width=2)
 im.save(out/f'facade_{k}.png')
# Rusty steel, with long roll marks, spots and scratches.
im=Image.new('RGB',(1024,256));p=im.load()
for y in range(256):
 for x in range(1024):
  n=r.randrange(-22,23);p[x,y]=(max(0,119+n),max(0,68+n//2),max(0,34+n//3))
d=ImageDraw.Draw(im)
for i in range(700):
 x=r.randrange(1024);y=r.randrange(256);q=r.randrange(2,16)
 d.ellipse((x,y,x+q,y+q/3),fill=r.choice([(77,50,33),(160,97,40),(89,63,44),(170,122,69)]))
for i in range(90):
 x=r.randrange(1024);y=r.randrange(256);d.line((x,y,x+r.randrange(5,80),y),fill=(165,114,64),width=1)
im.save(out/'steel.png')
font='/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc'
for name,word,bg,fg in [('akasaka','赤坂',(156,35,35),(255,220,158)),('izakaya','居酒屋',(240,194,119),(52,28,23)),('yakitori','やきとり',(225,171,103),(64,34,22)),('soba','そば',(30,69,65),(249,225,184))]:
 im=Image.new('RGB',(256,768),bg);d=ImageDraw.Draw(im);d.rectangle((8,8,247,759),outline=fg,width=5)
 f=ImageFont.truetype(font,140 if len(word)<4 else 120)
 for i,c in enumerate(word):d.text((128,384+(i-(len(word)-1)/2)*155),c,font=f,fill=fg,anchor='mm')
 im.save(out/f'sign_{name}.png')
