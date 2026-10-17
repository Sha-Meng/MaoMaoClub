"""仅打包 Blender 渲染结果及计算验证指标；不生成或补画角色像素。"""
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'assets/source/manager_blender'
FRAMES=ROOT/'tmp/manager_blender/frames'
OUT=ROOT/'assets/tavern/manager_authored'
QA=ROOT/'production/qa/manager_blender'


def main():
    OUT.mkdir(parents=True,exist_ok=True); QA.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((SOURCE/'animation_manifest.json').read_text(encoding='utf-8'))
    w,h=manifest['cell']; count=sum(c['count'] for c in manifest['clips'].values())
    columns=8
    atlas=Image.new('RGBA',(w*columns,h*math.ceil(count/columns)))
    index=0; frame_checks=[]
    for key,clip in manifest['clips'].items():
        clip['first_frame']=index
        for i in range(clip['count']):
            image=Image.open(FRAMES/f'{key}_{i:03d}.png').convert('RGBA')
            assert image.size==(w,h),f'{key}/{i}: 尺寸不匹配'
            a=np.asarray(image)[:,:,3]
            ys,xs=np.nonzero(a>128)
            assert len(xs)>0,f'{key}/{i}: 空帧'
            edge=int((a[0]>128).sum()+(a[-1]>128).sum()+(a[:,0]>128).sum()+(a[:,-1]>128).sum())
            assert edge==0,f'{key}/{i}: 裁边'
            frame_checks.append({'clip':key,'frame':i,'bounds':[int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())],'opaque':len(xs)})
            atlas.paste(image,((index%columns)*w,(index//columns)*h))
            index+=1
    atlas.save(OUT/'manager_atlas.png')
    manifest['atlas_columns']=columns
    manifest['atlas']='res://assets/tavern/manager_authored/manager_atlas.png'
    manifest['source']='assets/source/manager_blender/manager_rig.blend'
    (OUT/'manager_animation.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    report={'frames':count,'clips':len(manifest['clips']),'cell':[w,h],'atlas_size':list(atlas.size),'rgba8_mib':atlas.width*atlas.height*4/1024**2,'png_bytes':(OUT/'manager_atlas.png').stat().st_size,'edge_clipping':0,'per_frame':frame_checks,'visual_acceptance':'等待用户确认'}
    (QA/'asset_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    # 关键姿态对照属于渲染证据，不是运行素材。
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
    board=Image.new('RGB',(1200,570),'#ece7dc'); draw=ImageDraw.Draw(board)
    for row,key in enumerate(['walk','walk_cup']):
        for col,i in enumerate([0,4,9,15,19,24]):
            frame=Image.open(FRAMES/f'{key}_{i:03d}.png').convert('RGBA')
            board.paste(frame,(12+col*198,30+row*280),frame)
            draw.text((16+col*198,232+row*280),f'{"持杯" if row else "空手"} · {i/30:.2f}s',font=font,fill='#403b32')
            draw.line((col*198+8,214+row*280,col*198+188,214+row*280),fill='#9b9486')
    board.save(QA/'key_poses.png')
    print(json.dumps({k:v for k,v in report.items() if k!='per_frame'},ensure_ascii=False))


if __name__=='__main__': main()
