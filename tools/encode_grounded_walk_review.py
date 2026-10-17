"""编码实际 30 FPS 引擎帧；不重采样、不插帧，也不把图像差异当作落脚指标。"""
import json
import sys
from pathlib import Path
from PIL import Image

folder = Path(__file__).resolve().parents[1] / (sys.argv[1] if len(sys.argv)>1 else 'production/qa/grounded_walk')
for key in json.loads((folder / 'realtime_render.json').read_text())['variants']:
    frames = [Image.open(p).convert('RGB') for p in sorted((folder / 'frames').glob(f'{key}_[0-9][0-9][0-9].png'))]
    if len(frames) != 132:
        raise RuntimeError(f'{key}: 实际时间帧不完整 ({len(frames)}/132)')
    frames[0].save(folder / f'{key}.gif', save_all=True, append_images=frames[1:], duration=[30, 30, 40]*44, loop=0, disposal=2)
    for frame in frames:
        frame.close()
    print(key, flush=True)
