"""Stage immutable model inputs under public without editing the source GLB."""
import hashlib
import json
import os
import shutil
from pathlib import Path


def prepare():
    project = Path(__file__).resolve().parent
    root = project.parents[2]
    public = project / 'public'
    rows = json.loads((project / 'assets.json').read_text())
    records = []
    for row in rows:
        source = (root / row['source']).resolve()
        destination = public / row['target']
        if not source.is_relative_to(root) or not destination.resolve().is_relative_to(public.resolve()):
            raise ValueError('Asset path escapes repository/public')
        if not source.is_file():
            raise FileNotFoundError(source)
        destination.parent.mkdir(parents=True, exist_ok=True)
        # Re-stage even when a previous hardlink points at an older exported inode.
        if destination.exists() and not os.path.samefile(source, destination):
            destination.unlink()
        if not destination.exists():
            try:
                os.link(source, destination)
                method = 'hardlink'
            except OSError:
                shutil.copy2(source, destination)
                method = 'copy'
        else:
            method = 'existing-hardlink'
        records.append({**row, 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                        'bytes': source.stat().st_size, 'materialization': method})
    (project / 'asset-lock.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(records, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    prepare()
