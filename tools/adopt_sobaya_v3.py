"""Adopt v3 without overwriting either the approved face or old motion inputs."""
import json,hashlib,shutil,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];SRC=ROOT/'04_GAME_ASSETS/3d/characters/sobaya/rig_v3_20260917';BASE=ROOT/'04_GAME_ASSETS/3d/hazard_adopted';OUT=BASE/'v3_20260917';OUT.mkdir(exist_ok=True)
report=json.loads((SRC/'rig_report.json').read_text());old=json.loads((BASE/'manifest.json').read_text());shutil.copy2(SRC/'sobaya_rig.glb',OUT/'sobaya.glb')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old['sobaya'].update(version=3,file=str((OUT/'sobaya.glb').relative_to(ROOT)),source=str((SRC/'sobaya_rig.glb').relative_to(ROOT)),sourceSha256=sha(SRC/'sobaya_rig.glb'),sha256=sha(OUT/'sobaya.glb'),clips=report['clips'],groundSpeedMps=report['groundSpeedMps'],animationSource=report['animationSource'],animationSourceSha256=report['animationSourceSha256'],geometryRevision='wan_v3_upright_90pct_face_red_eye_edge',rig='SobayaV3Rig',boneCount=len(report['bones']),retainedV2ClipCount=report['clipCount'],retargetMethod='world-space rest-aware rotations, anatomical joint offsets, foot contact correction')
old['sobaya']['motionRevision']=report.get('motionRevision','rest-aware-baseline')
old['sobaya']['skinningRevision']=report.get('skinningRevision','anatomical-baseline')
for p in [BASE/'manifest.json',OUT/'manifest.json']:p.write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n')
p=ROOT/'21_SOBAYA_HAZARD_LAB/assets/models/sobaya.glb';assert p.is_symlink();p.unlink();p.symlink_to('../../../'+str((OUT/'sobaya.glb').relative_to(ROOT)))
p=ROOT/'21_SOBAYA_HAZARD_LAB/lib/game/game_motion_blend.dart';s=p.read_text()
for key,role in [('sobayaWalkSpeed','Walk'),('sobayaMugRunSpeed','Run')]:s=re.sub(r'const '+key+r' = [0-9.]+;',f'const {key} = {report["groundSpeedMps"][role]};',s)
p.write_text(s);print('Adopted v3',report['clipCount'],'clips',report['groundSpeedMps'])
