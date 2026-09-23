"""Generate separately named candidates; adoption follows ASR screening and is logged."""
from pathlib import Path
import os,subprocess,json
EP=Path(__file__).resolve().parent;ROOT=EP.parents[1]
repairs=[('second','ふたつめ、てぃー。',.70),('arms','うでです。',.45),('left','ひだりうでを通す。',.50),('wear','きられました。',.50),('perfect','かんぺきです。',.30),('today','きょうです。',.40),('buy','こうしきサイトから、購入できます。',.70)]
records=[]
for id,text,scale in repairs:
 version=2 if id=='perfect' else 1
 out=EP/'voice_candidates'/f'{id}_nojobs_repair{version}.wav'
 if not out.exists():subprocess.run([str(ROOT/'tools/irodori_speak.sh'),text,str(out),str(ROOT/'02_CHARACTERS/Yametaro_voice.wav'),'7'],env={**os.environ,'UV_CACHE_DIR':str(ROOT/'.local/keynote-uv-cache'),'HF_HUB_OFFLINE':'1','IRODORI_UNCUT':'1','IRODORI_DURATION_SCALE':str(scale),'IRODORI_CFG_SCALE_TEXT':'7'},check=True)
 records.append({'id':id,'speaker':'yametaro','speechText':text,'durationScale':scale,'textCFG':7.0,'seed':7,'candidate':str(out.relative_to(EP))})
 (EP/'remotion/out/repair-nojobs-candidates.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
 print('REPAIR',id,flush=True)
