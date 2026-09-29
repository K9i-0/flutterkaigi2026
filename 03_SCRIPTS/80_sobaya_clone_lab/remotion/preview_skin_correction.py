"""Reproducible, non-destructive 75-frame skin-retouch trial. Requires numpy/opencv.

Run with Python; writes candidates only to remotion/out/skin-preview.
Manual first-frame skin/exclusion masks follow dense optical flow at half scale.
No face reconstruction, geometric changes, or audio processing.
"""
from pathlib import Path
import json
import argparse
import subprocess
import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--beauty', action='store_true', help='Track and heal individual spots in addition to smoothing')
args = parser.parse_args()
OUT = ROOT / ('remotion/out/skin-preview-v2' if args.beauty else 'remotion/out/skin-preview')
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'final_remotion_clone_lab_scanner_camera.mp4'
START, END, FPS = 180, 255, 30
W, H = 1920, 1080


def run(args):
    subprocess.run(args, check=True)


def writer(path, width, height):
    return subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo',
        '-pix_fmt', 'bgr24', '-s', f'{width}x{height}', '-r', str(FPS), '-i', '-',
        '-an', '-c:v', 'libx264', '-crf', '16', '-preset', 'fast',
        '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(path)], stdin=subprocess.PIPE)


mask = np.zeros((H // 2, W // 2), np.float32)
skin = [(1090,178),(1175,175),(1230,202),(1260,270),(1290,338),
        (1296,397),(1355,440),(1390,500),(1360,574),(1325,618),
        (1300,800),(1240,840),(1180,854),(1100,834),(1090,752),
        (1080,666),(1030,610),(1003,540),(996,459),(993,382),
        (1010,296),(1042,228)]
cv2.fillPoly(mask, [np.array(skin, np.int32) // 2], 1)
eyes = ([((1062,362),(77,30)), ((1230,368),(78,29)),
         ((1061,327),(75,19)), ((1229,329),(76,20))] if args.beauty else
        [((1062,358),(86,51)), ((1230,362),(88,53))])
for center, axes in eyes + [((1156,568),(104,48)), ((1150,493),(64,21))]:
    cv2.ellipse(mask, tuple(v // 2 for v in center), tuple(v // 2 for v in axes),
                0, 0, 360, 0, -1)
mask = cv2.GaussianBlur(mask, (0,0), 5)
spots = np.zeros_like(mask)
# First-frame blemishes, selected on the original at 1920x1080; no eye/lip pixels.
spot_centers = [(1025,436,11),(1015,454,10),(1084,416,9),
                (1275,435,11),(1289,435,10),(1270,414,9),(1286,409,10),
                (1273,453,9),(1295,457,9),(1255,454,8),
                (1041,270,9),(1149,656,16),(1182,644,12)]
for x,y,radius in spot_centers:
    cv2.circle(spots,(x//2,y//2),max(3,radius//2),1,-1)

cap = cv2.VideoCapture(str(SOURCE))
assert cap.isOpened()
assert int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)) == W
assert int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)) == H
cap.set(cv2.CAP_PROP_POS_FRAMES, START)
encoded = writer(OUT / 'skin_video_only.mp4', W, H)
compare = writer(OUT / 'comparison_video_only.mp4', W, H)
previous = None
changes = []
grid_x, grid_y = np.meshgrid(np.arange(W//2, dtype=np.float32), np.arange(H//2, dtype=np.float32))
for i in range(END - START):
    ok, original = cap.read()
    assert ok, i
    small = cv2.resize(original, (W//2,H//2), interpolation=cv2.INTER_AREA)
    gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
    if previous is not None:
        backward = cv2.calcOpticalFlowFarneback(gray, previous, None, .5, 4, 31, 5, 7, 1.5, 0)
        mask = cv2.remap(mask, grid_x + backward[:,:,0], grid_y + backward[:,:,1],
                         cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
        spots = cv2.remap(spots, grid_x + backward[:,:,0], grid_y + backward[:,:,1],
                          cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    previous = gray
    # Edge-preserving texture suppression; retain 20% of original skin detail.
    if args.beauty:
        holes = (spots > .30).astype(np.uint8) * 255
        holes = cv2.dilate(holes, np.ones((3,3),np.uint8))
        # Interpolate clean neighbouring skin with normalized convolution in
        # float, then feather the correction to avoid hard inpaint islands.
        hole_float = holes.astype(np.float32) / 255
        known = 1 - hole_float
        weights = cv2.GaussianBlur(known, (0,0), 9)
        surrounding = cv2.GaussianBlur(small.astype(np.float32)*known[:,:,None], (0,0), 9)
        surrounding /= np.maximum(weights[:,:,None], .001)
        feather = cv2.GaussianBlur(hole_float, (0,0), 2)[:,:,None]
        healed = np.clip(small*(1-feather) + surrounding*feather, 0,255).astype(np.uint8)
        smooth = cv2.bilateralFilter(healed, 31, 36, 11).astype(np.float32)
    else:
        smooth = cv2.bilateralFilter(small, 25, 30, 9).astype(np.float32)
    delta = smooth - small.astype(np.float32)
    delta = cv2.resize(delta, (W,H), interpolation=cv2.INTER_LINEAR)
    alpha = cv2.resize(mask, (W,H), interpolation=cv2.INTER_LINEAR)[:,:,None]
    strength = .96 if args.beauty else .80
    corrected = np.clip(original.astype(np.float32) + alpha * (strength * delta +
                        np.array([0.0, 1.3, 2.2], np.float32)), 0, 255).astype(np.uint8)
    encoded.stdin.write(corrected.tobytes())
    # Matching crops make the skin comparison readable at playback size.
    left = original[100:950, 850:1530]
    right = corrected[100:950, 850:1530]
    canvas = np.zeros((H,W,3), np.uint8)
    for x, crop, label in [(0,left,'ORIGINAL'),(960,right,'SKIN CORRECTION')]:
        crop = cv2.resize(crop, (816,1020))
        canvas[60:1080,x+72:x+888] = crop
        cv2.putText(canvas, label, (x+72,40), cv2.FONT_HERSHEY_SIMPLEX, .9, (240,240,240), 2, cv2.LINE_AA)
    compare.stdin.write(canvas.tobytes())
    if i in [0, 30, 37, 60, 74]:
        cv2.imwrite(str(OUT / f'comparison_{i:03}.jpg'), canvas)
        cv2.imwrite(str(OUT / f'mask_{i:03}.jpg'), np.clip(original*.6 + alpha*np.array([0,100,0]),0,255).astype(np.uint8))
        if args.beauty:
            cv2.imwrite(str(OUT / f'spots_{i:03}.jpg'), np.clip(small*.7 + holes[:,:,None]*np.array([0,.3,0]),0,255).astype(np.uint8))
    outside = np.max(np.abs(corrected.astype(np.int16)-original.astype(np.int16))[alpha[:,:,0] < .001])
    changes.append(int(outside))
cap.release()
for process in [encoded,compare]:
    process.stdin.close()
    assert process.wait() == 0
# Preserve the existing reply clip's AAC without another audio encode.
reply = ROOT.parent / '00_REPLY_CLIPS/80_福ちゃん_ギュンギュンどころじゃないわね.mp4'
run(['ffmpeg','-v','error','-y','-i',str(reply),
     '-vn','-c:a','copy',str(OUT/'preview_audio.m4a')])
for stem, video in [('fukuchan_skin_preview','skin_video_only'), ('before_after','comparison_video_only')]:
    run(['ffmpeg','-v','error','-y','-i',str(OUT/f'{video}.mp4'),'-i',str(OUT/'preview_audio.m4a'),
         '-map','0:v:0','-map','1:a:0','-c','copy','-movflags','+faststart',str(OUT/f'{stem}.mp4')])
(OUT/'audit.json').write_text(json.dumps({'source':str(SOURCE),'startFrame':START,
    'endFrameExclusive':END,'frames':END-START,'fps':FPS,
    'maxChannelChangeOutsideMask':max(changes),'status':'trial, not adopted',
    'opencv':cv2.__version__,'numpy':np.__version__,
    'beautySpotCorrection':args.beauty,'initialSpots':spot_centers if args.beauty else []},indent=2)+'\n')
run(['ffmpeg','-v','error','-y','-i',str(SOURCE),'-i',str(OUT/'skin_video_only.mp4'),
     '-filter_complex',
     '[0:v]split=2[a][b];[a]trim=end_frame=180,setpts=PTS-STARTPTS[head];'
     '[b]trim=start_frame=255,setpts=PTS-STARTPTS[tail];'
     '[1:v]setpts=PTS-STARTPTS[patch];[head][patch][tail]concat=n=3:v=1:a=0[v]',
     '-map','[v]','-map','0:a:0','-c:v','libx264','-crf','18','-preset','fast',
     '-pix_fmt','yuv420p','-c:a','copy','-movflags','+faststart',str(OUT/'episode80_skin_preview.mp4')])
print(OUT)
