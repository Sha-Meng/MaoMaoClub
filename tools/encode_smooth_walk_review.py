"""只编码引擎真实时间帧；33.33ms 使用 GIF 的 30/30/40ms 交替近似。"""
from pathlib import Path
from PIL import Image
import json
import numpy as np
import sys

ROOT = Path(__file__).resolve().parents[1]
folder = ROOT / 'production/qa/smooth_walk'
report = {}
selected = {arg.split('=', 1)[1] for arg in sys.argv if arg.startswith('--only=')}
for key in json.loads((folder / 'realtime_render.json').read_text())['variants']:
    if '--metrics-only' not in sys.argv and (not selected or key in selected):
        # Exact three-digit suffix: server_* would also include server_carry_*.
        frames = [Image.open(p).convert('RGB') for p in sorted((folder / 'frames').glob(f'{key}_[0-9][0-9][0-9].png'))]
        if len(frames) != 132:
            raise RuntimeError(f'{key}: 实际时间帧不完整 ({len(frames)}/132)')
        durations = [30, 30, 40] * (len(frames) // 3)
        frames[0].save(folder / f'{key}.gif', save_all=True, append_images=frames[1:], duration=durations, loop=0, disposal=2)
        for frame in frames:
            frame.close()
    # Compare motion-energy spikes, including the cyclic seam. Not a replacement for review.
    baked = np.array(Image.open(ROOT / 'assets/tavern/walk_smooth' / f'{key}.png').convert('RGBA'), dtype=np.float32) / 255
    smooth = np.stack([baked[(i//8)*240:(i//8+1)*240, (i%8)*320:(i%8+1)*320] for i in range(32)])
    # Every fourth baked frame is the exact registered original key pose.
    original = smooth[::4].copy()
    for data in (original, smooth):
        data[..., :3] *= data[..., 3:]
    before = np.mean(np.abs(np.roll(original, -1, axis=0) - original), axis=(1,2,3))
    after = np.mean(np.abs(np.roll(smooth, -1, axis=0) - smooth), axis=(1,2,3))
    report[key] = {'max_original_step': float(before.max()), 'max_resampled_step': float(after.max()), 'cyclic_seam': float(after[-1]), 'peak_ratio': float(after.max()/before.max())}
    if report[key]['peak_ratio'] > .6:
        raise RuntimeError(f'{key}: 帧间跳变回归，检查过渡及循环接缝')
(folder / 'temporal_metrics.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
