"""Reuse Wan music, replace unwanted opening with approved episode-76 PCM.
No synthesis, voice processing or time stretching. Timing comes from manifest.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,wave,array
EP=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--music-start-frame',type=int,required=True);parser.add_argument('--manifest',default='remotion/src/edit-manifest.json');args=parser.parse_args()
m=json.loads((EP/args.manifest).read_text());fps=m['composition']['fps'];rate=48000
end=m['endcard']['from']/fps;total=m['composition']['durationInFrames']/fps;cross=m['audio']['crossfade_frames']/fps
source=EP/json.loads((EP/'wan3_config.json').read_text())['output'];out=EP/'remotion/public'/m['audio']['file'];opening=m['audio']['localOpening'];voice=EP/opening['file']
start=args.music_start_frame/fps;needed=total-end+cross
fg=(f'[0:a]aresample=48000,aformat=channel_layouts=stereo,asplit=2[main][music];[main]atrim=0:{end},asetpts=PTS-STARTPTS[a];'
 f'[music]atrim=start={start}:end={start+needed},asetpts=PTS-STARTPTS[b];'
 f'[a][b]acrossfade=d={cross}:c1=tri:c2=tri,atrim=0:{total},afade=t=out:st={total-0.1}:d=0.1[out]')
raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(source),'-filter_complex',fg,'-map','[out]','-ar',str(rate),'-ac','2','-c:a','pcm_s16le','-f','s16le','-'])
a=array.array('h');a.frombytes(raw)
with wave.open(str(voice)) as w:
 assert (w.getframerate(),w.getnchannels(),w.getsampwidth())==(rate,2,2)
 v=w.readframes(w.getnframes())
b=array.array('h');b.frombytes(v)
lo=round(opening['replaceFromFrame']/fps*rate)*2;hi=round(opening['replaceToFrame']/fps*rate)*2;pos=round(opening['fromFrame']/fps*rate)*2
assert lo<=pos and pos+len(b)<=hi
# The unwanted utterance is removed, not mixed under the replacement.
a[lo:hi]=array.array('h',[0])*(hi-lo);a[pos:pos+len(b)]=b
# 10 ms edge fades outside the approved clip prevent a discontinuity in the bed.
fade=480
for i in range(fade):
 for c in range(2):
  a[lo-fade*2+i*2+c]=round(a[lo-fade*2+i*2+c]*(1-i/fade))
  a[hi+i*2+c]=round(a[hi+i*2+c]*(i/fade))
with wave.open(str(out),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(rate);w.writeframes(a.tobytes())
assert a[pos:pos+len(b)].tobytes()==v
assert a[(hi+fade*2):round(29.7*rate)*2].tobytes()==raw[(hi+fade*2)*2:round(29.7*rate)*4]
record={'source':source.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'music_start_frame':args.music_start_frame,'music_duration_frames':round(needed*fps),'crossfade_frames':m['audio']['crossfade_frames'],'output_frames':m['composition']['durationInFrames'],'fps':fps,'output':'remotion/public/'+m['audio']['file'],'output_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'local_opening':opening,'approved_clip_pcm_identical':True,'unchanged_audio_after_seconds':opening['replaceToFrame']/fps+0.01,'unchanged_until_seconds':29.7,'method':'Replace generated opening utterance with unprocessed approved episode-76 clip; extend original Wan music under endcard'}
(EP/'audio-edit.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n');print(json.dumps(record,indent=2))
