"""Materialize immutable source assets under a Remotion public directory."""
import argparse, hashlib, json, os, shutil
from pathlib import Path

def prepare(project, root):
    public = project / 'public'
    public.mkdir(parents=True, exist_ok=True)
    rows = json.loads((project / 'assets.json').read_text())
    planned = []
    for row in rows:
        src = (root / row['source']).resolve()
        dst = (public / row['target']).resolve()
        if not src.is_relative_to(root.resolve()) or not dst.is_relative_to(public.resolve()):
            raise ValueError('Asset path escapes repository/public')
        if not src.is_file():
            raise FileNotFoundError(src)
        planned.append((row, src, dst))
    result = []
    for row, src, dst in planned:
        dst.parent.mkdir(parents=True, exist_ok=True)
        if dst.exists() and not os.path.samefile(src, dst):
            dst.unlink()
        if not dst.exists():
            try: os.link(src, dst)
            except OSError: shutil.copy2(src, dst)
        result.append({**row, 'sha256': hashlib.sha256(src.read_bytes()).hexdigest()})
    (project / 'asset-lock.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    return result

if __name__ == '__main__':
    p = argparse.ArgumentParser(); p.add_argument('project', type=Path); p.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[4])
    args=p.parse_args(); print(json.dumps(prepare(args.project.resolve(),args.root.resolve()),indent=2))
