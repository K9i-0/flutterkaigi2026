"""Continue an audited speech-free section of Wan audio over the endcard.
Only edits existing generated audio; does not synthesize music or speech.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess
EP=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--music-start-frame',type=int,required=True,help='Audited clean instrumental source start at the 30 fps edit timebase')
args=parser.parse_args()
m=json.loads((EP/'remotion/src/edit-manifest.json').read_text())
fps=m['composition']['fps']; end=m['endcard']['from']/fps; total=m['composition']['durationInFrames']/fps
cross_frames=9; cross=cross_frames/fps
start=args.music_start_frame/fps; needed=total-end+cross
source=EP/json.loads((EP/'wan3_config.json').read_text())['output']
out=EP/'remotion/public/final_audio.wav'
if not source.exists():raise SystemExit('Generate source video first.')
# Preserve source PCM before the final 0.3 seconds; append only existing instrumental.
filtergraph=(f'[0:a]asplit=2[main][music];[main]atrim=0:{end},asetpts=PTS-STARTPTS[a];'
 f'[music]atrim=start={start}:end={start+needed},asetpts=PTS-STARTPTS[b];'
 f'[a][b]acrossfade=d={cross}:c1=tri:c2=tri,atrim=0:{total},'
 f'afade=t=out:st={total-0.1}:d=0.1[out]')
subprocess.run(['ffmpeg','-y','-v','error','-i',str(source),'-filter_complex',filtergraph,'-map','[out]','-ar','48000','-ac','2','-c:a','pcm_s16le',str(out)],check=True)
record={'source':source.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'music_start_frame':args.music_start_frame,'music_duration_frames':round(needed*fps),'crossfade_frames':cross_frames,'output_frames':m['composition']['durationInFrames'],'fps':fps,'output':'remotion/public/final_audio.wav','output_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'method':'reuse generated music; no synthesis; no speech time stretch'}
(EP/'audio-edit.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(record,ensure_ascii=False,indent=2))
