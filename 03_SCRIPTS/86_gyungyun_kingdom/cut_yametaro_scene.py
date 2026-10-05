"""Remove Yametaro close-up and dialogue, preserving Fukuchan's voice tail."""
from pathlib import Path
import subprocess,json,hashlib
P=Path(__file__).resolve().parent
src=P/'final_gyungyun_kingdom_720p.mp4';out=P/'final_gyungyun_kingdom_no_yametaro_line_720p.mp4'
# Hospital starts802f. Yametaro shot114–194f -> global916–996f.
# Retain Fukuchan audio through924f; it ends after visual cut to Yametaro.
# Carry those8f over the silent start of Sobaya shot; no dialogue overlaps.
f=';'.join(['[0:v]trim=end_frame=916,setpts=PTS-STARTPTS[v0]','[0:v]trim=start_frame=996:end_frame=1169,setpts=PTS-STARTPTS[v1]','[v0][v1]concat=n=2:v=1:a=0[v]','[0:a]aresample=44100,atrim=end_sample=1358280,asetpts=PTS-STARTPTS[a0]','[0:a]aresample=44100,atrim=start_sample=1475880:end_sample=1718430,asetpts=PTS-STARTPTS[a1]','[a0][a1]concat=n=2:v=0:a=1[a]'])
subprocess.run(['ffmpeg','-v','error','-n','-i',str(src),'-filter_complex',f,'-map','[v]','-map','[a]','-c:v','libx264','-crf','0','-preset','medium','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(out)],check=True)
subprocess.run(['ffmpeg','-v','error','-i',str(out),'-f','null','-'],check=True)
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=codec_type,width,height,nb_frames,r_frame_rate','-of','json',str(out)],text=True))
assert int(next(s for s in probe['streams'] if s['codec_type']=='video')['nb_frames'])==1089
r={'source':src.name,'output':out.name,'fps':30,'removed_video_frames':[916,996],'audio_kept_frames':[[0,924],[1004,1169]],'reason':'Remove entire Yametaro dialogue shot; preserve Fukuchan final8 audio frames over quiet start of Sobaya shot. Sobaya line and corridor unchanged in content and relative sync.','frames':1089,'seconds':36.3,'probe':probe,'full_decode':'passed','sha256':hashlib.sha256(out.read_bytes()).hexdigest()}
(P/'cut_yametaro_scene.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(out)
