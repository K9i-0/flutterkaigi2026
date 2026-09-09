from pathlib import Path
import subprocess,json
r=Path(__file__).resolve().parents[4];p=r/'03_SCRIPTS/66_madogiwa_super_try_invasion';tmp=p/'remotion/out';cap='映画予告編の語り。重々しく抑制した演技。言葉を明瞭に、最後まで大真面目に語る。'
lines=['窓際族物語、最大の謎が、ついに明かされる。','その夜、東京は彼らの狩り場になった。','その男は、地球を支配するために来た。','この男が、やがて窓際族になることを、まだ、誰も知らない。']
rows=[]
for i,t in enumerate(lines,1):
 raw=tmp/f'trailer_narration_{i}_raw.wav';out=p/f'trailer_narration_sobaya_{i}.wav'
 subprocess.run(['bash',str(r/'.claude/skills/seedance/scripts/irodori_speak.sh'),t,str(raw),str(r/'02_CHARACTERS/Sobaya_voice.wav'),'42',cap],check=True)
 subprocess.run(['bash',str(r/'.claude/skills/seedance/scripts/sobaya_monsterize.sh'),str(raw),str(out)],check=True)
 duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(out)]))
 rows.append(dict(text=t,file=out.name,duration=duration,seed=42,caption=cap))
 (p/'trailer_voice_manifest.json').write_text(json.dumps({'model':'Aratako/Irodori-TTS-v4.1-Small','reference':'02_CHARACTERS/Sobaya_voice.wav','postprocess':'sobaya_monsterize.sh','lines':rows},ensure_ascii=False,indent=2))
 print('DONE',i,duration,flush=True)
