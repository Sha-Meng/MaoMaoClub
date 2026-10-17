"""检查实际渲染连接与动作接缝，不将像素指标当作美术自然度结论。"""
import json
from collections import deque
from pathlib import Path
from PIL import Image
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
FRAMES=ROOT/'tmp/manager_blender/frames'
QA=ROOT/'production/qa/manager_blender'


def components(mask):
    mask=mask.copy(); sizes=[]
    h,w=mask.shape
    for y,x in zip(*np.nonzero(mask)):
        if not mask[y,x]: continue
        mask[y,x]=False; queue=deque([(x,y)]); size=0
        while queue:
            px,py=queue.popleft(); size+=1
            for nx,ny in ((px-1,py),(px+1,py),(px,py-1),(px,py+1),(px-1,py-1),(px+1,py+1),(px-1,py+1),(px+1,py-1)):
                if 0<=nx<w and 0<=ny<h and mask[ny,nx]:
                    mask[ny,nx]=False; queue.append((nx,ny))
        sizes.append(size)
    return sorted(sizes,reverse=True)


def main():
    data=json.loads((ROOT/'assets/tavern/manager_authored/manager_animation.json').read_text(encoding='utf-8'))
    failures=[]; max_island=0; worst=None; seams={}
    for key,clip in data['clips'].items():
        for i in range(clip['count']):
            a=np.asarray(Image.open(FRAMES/f'{key}_{i:03d}.png'))
            sizes=components(a[:,:,3]>128)
            second=sizes[1] if len(sizes)>1 else 0
            if second>max_island: max_island=second; worst=[key,i]
            # 允许少量孤立胡须/抗锯齿，不允许分离成四肢大小的岛。
            if second>20: failures.append(f'{key}/{i}: 分离 alpha 区域 {second} px')
    for suffix in ('','_cup'):
        for before,after in [('idle','start'),('start','walk'),('stop','idle')]:
            i=0 if before=='idle' else data['clips'][before+suffix]['count']-1
            a=np.asarray(Image.open(FRAMES/f'{before+suffix}_{i:03d}.png')).astype(float)
            b=np.asarray(Image.open(FRAMES/f'{after+suffix}_000.png')).astype(float)
            # 比较预乘颜色，排除全透明背景 RGB 噪声。
            a[:,:,:3]*=a[:,:,3:4]/255; b[:,:,:3]*=b[:,:,3:4]/255
            error=float(np.abs(a-b).mean())
            seams[before+suffix+' -> '+after+suffix]=error
            if error>.5: failures.append(f'{before}->{after}: 接缝像素差 {error}')
    report={'frames':sum(c['count'] for c in data['clips'].values()),'max_detached_alpha_component_pixels':max_island,'worst_component_frame':worst,'seam_mean_channel_difference_255':seams,'success':not failures,'failures':failures}
    (QA/'pixel_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False))
    if failures: raise SystemExit(1)


if __name__=='__main__': main()
