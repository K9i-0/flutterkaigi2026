"""Build synchronized left=Blender / right=Wan camera comparison."""
from pathlib import Path
import subprocess
p = Path(__file__).resolve().parent
subprocess.run([
    'ffmpeg', '-y', '-v', 'error',
    '-i', str(p / 'previs_dock/dock_camera_dynamic_v2_8s.mp4'),
    '-i', str(p / 'wan3_result_dock_camera_v3_seed700030_480p.mp4'),
    '-filter_complex', '[0:v]fps=30,scale=854:480,setsar=1,setpts=PTS-STARTPTS[left];[1:v]fps=30,scale=854:480,setsar=1,setpts=PTS-STARTPTS[right];[left][right]hstack=inputs=2[v]',
    '-map', '[v]', '-map', '1:a:0', '-t', '8',
    '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart',
    str(p / 'dock_camera_comparison_v3_side_by_side.mp4'),
], check=True)
