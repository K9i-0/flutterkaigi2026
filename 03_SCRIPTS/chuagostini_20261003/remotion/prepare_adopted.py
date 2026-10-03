"""Prepare adopted Remotion inputs from episode assets; preserve local candidates."""
from pathlib import Path
import shutil
import subprocess

p = Path(__file__).resolve().parent.parent
public = p / "remotion/public"
public.mkdir(exist_ok=True)
for name in ["scene_08_end.png", "ending_chuagostini_v3.wav", "narration_master_sobaya_no_sokan.wav"]:
    target = public / name
    if not target.exists():
        shutil.copy2(p / name, target)
source = p / "wan3_cm_v2_seed310003_480p_28s.mp4"
target = public / "wan_main_720p.mp4"
if not target.exists():
    if not source.exists():
        raise SystemExit("Restore the local Wan source video before rendering; it is excluded from Git.")
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(source), "-vf", "scale=1280:720:flags=lanczos", "-c:v", "libx264", "-crf", "18", "-c:a", "copy", str(target)], check=True)
print("Adopted composition inputs ready: ChuaSobayaCM")
