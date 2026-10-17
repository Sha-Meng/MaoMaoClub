"""分析引擎注册帧的双向像素运动，仅输出向量数据；不修改或重绘人物图片。

离线工具依赖：numpy、Pillow、opencv-python-headless==4.13.0.92。
可用 pip --target tmp/walk_dependencies --no-deps 安装 OpenCV，不改变全局环境。
输入由 bake_smooth_walk.gd -- --sources-only 生成；输出仅供 GPU 烘焙器使用。
算法 API：https://docs.opencv.org/4.x/dc/d6b/group__video__track.html
"""
from pathlib import Path
import sys
import json
import hashlib

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tmp/walk_dependencies'))
import cv2
import numpy as np
from PIL import Image

FOLDER = ROOT / 'tmp/walk_resample'
report = {'opencv': cv2.__version__, 'cell': [320, 240], 'pairs': {}}
for path in sorted(FOLDER.glob('*.png')):
    rgba = np.array(Image.open(path).convert('RGBA'), dtype=np.float32) / 255
    # Composite for feature detection: transparent hidden RGB must not become motion.
    composite = rgba[..., :3] * rgba[..., 3:] + 0.35 * (1 - rgba[..., 3:])
    gray = cv2.cvtColor(np.uint8(np.clip(composite * 255, 0, 255)), cv2.COLOR_RGB2GRAY)
    frames = np.split(gray, 8, axis=1)
    fields = []
    maximum = 0.0
    for index, a in enumerate(frames):
        b = frames[(index + 1) % 8]
        forward = cv2.calcOpticalFlowFarneback(a, b, None, .5, 5, 25, 7, 7, 1.5, 0)
        backward = cv2.calcOpticalFlowFarneback(b, a, None, .5, 5, 25, 7, 7, 1.5, 0)
        maximum = max(maximum, float(np.max(np.abs(forward))), float(np.max(np.abs(backward))))
        fields.append(np.concatenate((forward / [320, 240], backward / [320, 240]), axis=2))
    np.concatenate(fields, axis=1).astype('<f4').tofile(path.with_suffix('.flow'))
    report['pairs'][path.stem] = {'count': 8, 'max_motion_pixels_at_2x': maximum, 'input_sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
(FOLDER / 'analysis.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))
