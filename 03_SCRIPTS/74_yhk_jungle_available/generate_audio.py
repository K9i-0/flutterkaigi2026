"""Produce canonical Japanese character voices, preserving natural speech duration."""
from pathlib import Path
import json, os, subprocess, hashlib
EP=Path(__file__).resolve().parent
ROOT=EP.parents[1]
rows=json.loads((EP/'remotion/src/dialogue.json').read_text())
tail_edits=json.loads((EP/'audio-tail-edits.json').read_text()) if (EP/'audio-tail-edits.json').exists() else {}
(EP/'voice_candidates').mkdir(exist_ok=True)
log=[]
for row in rows:
    raw=EP/'voice_candidates'/f"{row['id']}_raw.wav"
    out=EP/f"line_{row['id']}_{row['speaker']}.wav"
    who=row['speaker'];refs={'sobaya':('Sobaya_voice.wav',42),'yametaro':('Yametaro_voice.wav',7),'fukuchan':('Fukuchan_voice.wav',100)}
    ref,seed=refs[who]
    caption=row.get('caption') or ('大真面目に、穏やかに答える。短い言葉も明瞭に話す。' if who=='sobaya' else '落ち着いた自然な声で、静かに質問する。誇張しない。')
    if not raw.exists() and not out.exists():
        subprocess.run([str(ROOT/'tools/irodori_speak.sh'),row.get('speechText',row['text']).replace('\n',''),str(raw),str(ROOT/'02_CHARACTERS'/ref),str(seed),caption],cwd=ROOT,env={**os.environ,'HF_HUB_OFFLINE':'1'},check=True)
    if not out.exists():
        if who=='sobaya':subprocess.run([str(ROOT/'tools/sobaya_monsterize.sh'),str(raw),str(out)],check=True)
        else:out.write_bytes(raw.read_bytes())
        if row['id'] in tail_edits:
            edit=tail_edits[row['id']];end=edit['keepThroughSeconds'];fade=edit['fadeOutSeconds'];temp=EP/'voice_candidates'/f"{row['id']}_tail.wav"
            subprocess.run(['ffmpeg','-y','-v','error','-i',str(out),'-af',f"atrim=end={end},afade=t=out:st={end-fade}:d={fade},apad=pad_dur={edit['trailingSilenceSeconds']}",'-c:a','pcm_s16le',str(temp)],check=True)
            os.replace(temp,out)
    duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(out)]))
    log.append({'id':row['id'],'speaker':who,'reference':'02_CHARACTERS/'+ref,'model':'Aratako/Irodori-TTS-v4.1-Small','seed':seed,'caption':caption,'duration':duration,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
    (EP/'audio-generation.json').write_text(json.dumps(log,ensure_ascii=False,indent=2)+'\n')
    print('READY',row['id'],round(duration,2),'seconds',flush=True)
