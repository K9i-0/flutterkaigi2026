"""Deterministic original game sound effects; no borrowed game audio."""
from pathlib import Path
import math,random,wave,struct
out=Path(__file__).resolve().parent.parent/'21_SOBAYA_HAZARD_LAB/assets/audio';out.mkdir(exist_ok=True)
rate=22050;rng=random.Random(49)
def save(name,duration,kind):
 data=[];low=0
 for i in range(int(rate*duration)):
  t=i/rate;n=rng.uniform(-1,1);low=.97*low+.03*n
  if kind=='ambient':v=low*.6+.018*math.sin(t*math.tau*48)+.008*math.sin(t*math.tau*71)
  elif kind in ['shot','shotgun']:v=(n*.7+math.sin(t*math.tau*(90 if kind=='shot' else 55))*.6)*math.exp(-t*(24 if kind=='shot' else 12))
  elif kind in ['pickup','collect','heal','clear']:v=(math.sin(math.tau*(650+350*(t>.12))*t)+.25*math.sin(math.tau*1300*t))*.22*math.sin(math.pi*t/duration)
  elif kind in ['enemy','hurt']:v=(math.sin(math.tau*(75+15*math.sin(t*17))*t)+n*.12)*.25*math.sin(math.pi*t/duration)
  elif kind in ['reload','equip','empty']:v=n*.35*(math.exp(-t*50)+.5*math.exp(-abs(t-.17)*80))
  elif kind in ['gate','break']:v=(low*3+math.sin(t*math.tau*62)*.12)*math.exp(-t*6)
  else:v=low*3*math.exp(-t*35)
  if kind=='ambient':v*=min(1,t/.12,(duration-t)/.12)
  data.append(struct.pack('<h',int(max(-.95,min(.95,v))*32767)))
 with wave.open(str(out/(name+'.wav')),'wb') as f:f.setparams((1,2,rate,0,'NONE','not compressed'));f.writeframes(b''.join(data))
for name in ['shot','shotgun','pickup','collect','heal','clear','enemy','hurt','reload','equip','empty','gate','break','step','defeat']:save(name,.65 if name!='step' else .16,'collect' if name=='defeat' else name)
save('ambient',8,'ambient')
