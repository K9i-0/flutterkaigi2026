"""Rebuild the local game v3 with speech and legacy clip aliases."""
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[4]
subprocess.run(['/Applications/Blender.app/Contents/MacOS/Blender','-b','--factory-startup','--python',str(ROOT/'tools/build_fukuchan_v3_speech.py')],check=True)
