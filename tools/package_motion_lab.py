"""Build a standalone, locally ad-hoc-signed macOS animation lab."""
from pathlib import Path
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / '22_HUMANOID_MOTION_LAB'


def main():
    subprocess.run(['mise', 'exec', '--', 'flutter', 'build', 'macos', '--release'], cwd=PROJECT, check=True)
    source = PROJECT / 'build/macos/Build/Products/Release/humanoid_motion_lab.app'
    destination = PROJECT / 'dist/そば屋モーションラボ.app'
    destination.parent.mkdir(exist_ok=True)
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(source, destination, symlinks=True)
    info = destination / 'Contents/Info.plist'
    data = plistlib.loads(info.read_bytes())
    data['CFBundleDisplayName'] = 'そば屋モーションラボ'
    info.write_bytes(plistlib.dumps(data))
    subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(destination)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(destination)], check=True)
    print(destination)


if __name__ == '__main__':
    main()
