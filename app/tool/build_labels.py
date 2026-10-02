"""Temporary code-authored brands; canonical Super Try image stays untouched."""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
out=Path(__file__).resolve().parents[2]/'04_GAME_ASSETS/3d/props/beer_rain_cans';out.mkdir(parents=True,exist_ok=True)
font='/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc'
for name,title,band,kind in [('light','窓際ライト','#cc8d27','ビール'),('happoshu','つらめ','#775aa0','発泡酒')]:
 im=Image.new('RGB',(768,1024),'#dedfdc');d=ImageDraw.Draw(im)
 def text(y,t,size,color):
  f=ImageFont.truetype(font,size);d.text((384,y),t,font=f,fill=color,anchor='mt')
 text(60,'休憩' if name=='light' else '労働',75,'#191b1a');text(180,'スーパー',60,'#b92028');text(280,title,112 if name=='happoshu' else 95,'#c82025');text(470,'Madogiwa',78,'#252525');text(600,'生',108,'#191b1a');d.rectangle((0,760,768,950),fill=band);text(787,kind,100,'white');text(970,'仮デザイン',25,'#333333');im.save(out/f'{name}.png')
