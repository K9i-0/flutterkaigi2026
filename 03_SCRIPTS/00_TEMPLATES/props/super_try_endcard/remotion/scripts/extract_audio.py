"""Rebuild the original mixed product call using the frame manifest."""
from pathlib import Path
import json
import subprocess
project = Path(__file__).resolve().parents[1]
repo = next(p for p in project.parents if (p / '.git').exists())
m = json.loads((project / 'src/edit-manifest.json').read_text())
a = m['audioSource']
subprocess.run(['ffmpeg', '-v', 'error', '-ss', str(a['startFrame']/a['fps']), '-i', str(repo/a['path']), '-t', str((a['endFrame']-a['startFrame'])/a['fps']), '-vn', '-ar', '48000', '-c:a', 'pcm_s16le', str(project/'public'/m['audio']), '-y'], check=True)
