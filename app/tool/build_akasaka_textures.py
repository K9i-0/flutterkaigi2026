"""Deterministic texture sources, no downloaded artwork.

One facade tile covers 4 bays x 8 floors (4 x 8 scene units); the stage script
repeats it by face size so windows keep their scale on every building.
"""
from PIL import Image,ImageDraw,ImageFilter,ImageFont
from pathlib import Path
import random
out=Path(__file__).resolve().parents[2]/'assets/3d/stages/akasaka'
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
GLASS=[(52,66,82),(62,78,96),(44,56,70),(74,90,106)]
# Albedo shows daytime glass; the paired *_emit map holds only the lit rooms,
# so the game can switch window lighting per time of day via emissiveFactor.
class Facade:
 def __init__(s,base,amp):
  s.im=noise((512,1024),base,amp);s.d=ImageDraw.Draw(s.im)
  s.em=Image.new('RGB',(512,1024));s.e=ImageDraw.Draw(s.em)
 def window(s,box,rate,palette,glass=GLASS):
  g=r.choice(glass);x0,y0,x1,y1=box
  s.d.rectangle(box,fill=g);s.d.rectangle((x0,y0,x1,y0+(y1-y0)//4),fill=tuple(min(255,c+22) for c in g))
  if r.random()<rate:
   c=r.choice(palette);s.e.rectangle(box,fill=c)
   s.d.rectangle((x0+2,y1-(y1-y0)//3,x1-2,y1),fill=tuple((a*3+b)//4 for a,b in zip(g,c)))
   if r.random()<.5:s.e.rectangle((x0,y0,x1,y0+(y1-y0)//3),fill=tuple(v*3//4 for v in c))
 def save(s,name):
  s.im.save(out/f'{name}.png');s.em.save(out/f'{name}_emit.png')
# 0-2: mixed-use buildings, punched windows with frames.
for k in range(3):
 f=Facade([(95,87,89),(82,89,104),(128,112,98)][k],8)
 for y in range(40,1024,128):
  f.d.rectangle((0,y-12,511,y-8),fill=(45,43,49))
  for x in range(24,512,128):
   f.d.rectangle((x-4,y-4,x+84,y+78),fill=(34,35,43));f.window((x,y,x+80,y+72),.45,WARM)
   f.d.line((x+40,y,x+40,y+72),fill=(51,44,42),width=3);f.e.line((x+40,y,x+40,y+72),fill=(0,0,0),width=3)
   f.d.line((x,y+34,x+80,y+34),fill=(51,44,42),width=2);f.e.line((x,y+34,x+80,y+34),fill=(0,0,0),width=2)
 f.save(f'facade_{k}')
# 3: office curtain wall, glass floors with a few cool-lit rooms.
f=Facade((44,62,78),5)
for y in range(0,1024,128):
 for x in range(0,512,64):f.window((x+3,y+18,x+61,y+124),.3,COOL,[(70,98,124),(84,112,138),(60,86,110)])
 f.d.rectangle((0,y,511,y+16),fill=(70,78,86))
for x in range(0,512,64):f.d.rectangle((x,0,x+3,1023),fill=(84,92,100));f.e.rectangle((x,0,x+3,1023),fill=(0,0,0))
f.save('facade_3')
# 4: apartment, balcony slabs and warm sliding windows.
f=Facade((150,140,128),6)
for y in range(0,1024,128):
 for x in range(0,512,128):
  f.window((x+10,y+20,x+118,y+96),.55,WARM)
  f.d.line((x+64,y+20,x+64,y+96),fill=(60,56,52),width=3);f.e.line((x+64,y+20,x+64,y+96),fill=(0,0,0),width=3)
  f.d.rectangle((x+128-6,y,x+128,y+128),fill=(118,110,100))
 f.d.rectangle((0,y+96,511,y+126),fill=(186,178,166));f.d.rectangle((0,y+100,511,y+104),fill=(120,114,106))
 f.e.rectangle((0,y+96,511,y+126),fill=(0,0,0))
f.save('facade_4')
# 5: dark office with vertical fins and strip windows.
f=Facade((36,38,46),4)
for y in range(0,1024,128):
 for x in range(0,512,128):f.window((x+12,y+30,x+116,y+100),.38,WARM+COOL)
for x in range(0,512,32):f.d.rectangle((x,0,x+7,1023),fill=(70,72,80));f.e.rectangle((x,0,x+7,1023),fill=(0,0,0))
f.save('facade_5')
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
im=noise((256,256),(60,62,74),3);d=ImageDraw.Draw(im);em=Image.new('RGB',(256,256));e=ImageDraw.Draw(em)
for y in range(8,256,16):
 for x in range(6,256,14):
  d.rectangle((x,y,x+6,y+6),fill=(48,52,64))
  if r.random()<.22:e.rectangle((x,y,x+6,y+6),fill=r.choice([(220,160,100),(190,180,180)]))
im.save(out/'skyline.png');em.save(out/'skyline_emit.png')
# Car atlas cells: dark body, light body, headlight, taillight (+ emission).
im=Image.new('RGB',(64,16));em=Image.new('RGB',(64,16))
for i,(c,g) in enumerate([((34,38,46),(0,0,0)),((176,180,188),(0,0,0)),((250,244,226),(255,244,214)),((200,26,22),(255,36,26))]):
 im.paste(c,(i*16,0,i*16+16,16));em.paste(g,(i*16,0,i*16+16,16))
im.save(out/'car_atlas.png');em.save(out/'car_atlas_emit.png')
font='/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc'
for name,word,bg,fg in [('akasaka','赤坂',(156,35,35),(255,220,158)),('izakaya','居酒屋',(240,194,119),(52,28,23)),('soba','そば',(30,69,65),(249,225,184)),('shika','歯科',(236,240,242),(30,92,150)),('bengoshi','弁護士',(32,44,70),(232,222,190)),('fudosan','不動産',(244,244,240),(40,96,70))]:
 im=Image.new('RGB',(256,768),bg);d=ImageDraw.Draw(im);d.rectangle((8,8,247,759),outline=fg,width=5)
 f=ImageFont.truetype(font,140 if len(word)<4 else 120)
 for i,c in enumerate(word):d.text((128,384+(i-(len(word)-1)/2)*155),c,font=f,fill=fg,anchor='mm')
 im.save(out/f'sign_{name}.png')
# Rooftop billboards for the entrance-ceremony stage: plain corporate tone.
def ad(name,bg,lines,frame=None):
 im=Image.new('RGB',(1024,384),bg);d=ImageDraw.Draw(im)
 if frame:d.rectangle((14,14,1009,369),outline=frame,width=6)
 for word,size,y,fg,x in lines:d.text((x,y),word,font=ImageFont.truetype(font if size>40 else font.replace('W6','W3'),size),fill=fg,anchor='mm')
 return im,d
im,d=ad('exam',(246,245,240),[('採用試験会場',130,160,(28,44,86),512),('受験者の方は係員の指示に従ってください',38,296,(70,76,90),512)],(28,44,86));im.save(out/'ad_exam.png')
# Yumemin billboard from the canonical 2D art (characters/Yumemin.jpg).
im,d=ad('yumemin',(255,255,255),[('ゆめみ',150,170,(32,120,196),650),('YUMEMI',40,292,(90,150,200),650)],(84,170,228))
art=Image.open(out.parents[3]/'characters/Yumemin.jpg').convert('RGB').resize((330,330),Image.LANCZOS)
im.paste(art,(40,27));im.save(out/'ad_yumemin.png')
im,d=ad('accidenchua',(26,40,72),[('ACCIDENCHUA',112,170,(246,246,250),512),('Consulting  ·  Technology  ·  Operations',36,288,(178,190,214),512)]);im.save(out/'ad_accidenchua.png')
im,d=ad('safety',(248,248,246),[('安全第一',150,192,(0,128,72),650)],(0,128,72))
d.rectangle((150,112,250,272),fill=(0,128,72));d.rectangle((120,142,280,242),fill=(0,128,72))
d.rectangle((182,128,218,256),fill=(255,255,255));d.rectangle((136,174,264,210),fill=(255,255,255))
im.save(out/'ad_safety.png')
