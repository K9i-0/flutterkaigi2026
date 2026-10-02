"""Recreate canonical Sobaya narration. Requires the repository Irodori setup."""
from pathlib import Path
import subprocess,json
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
cache=root/'.local/ippai-trailer';cache.mkdir(parents=True,exist_ok=True)
for row in json.loads((out/'narration.json').read_text()):
 text=row.get('generationText',row['text']);raw=cache/f"{row['id']}_raw.wav"
 subprocess.run([str(root/'tools/irodori_speak.sh'),text,str(raw),str(root/'02_CHARACTERS/Sobaya_voice.wav'),'42'],check=True,cwd=root)
 subprocess.run([str(root/'tools/sobaya_monsterize.sh'),str(raw),str(out/row['audio'])],check=True,cwd=root)
