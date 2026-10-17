"""把真实渲染帧编排为下身逐帧检查页与修订对照，不修改角色像素。"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
FRAMES=ROOT/'tmp/manager_blender/frames'
QA=ROOT/'production/qa/manager_blender'
FONT=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
CLIPS=json.loads((ROOT/'assets/source/manager_blender/animation_manifest.json').read_text(encoding='utf-8'))['clips']


def board(key, indices, destination):
    result=Image.new('RGB',(1380,190*((len(indices)+5)//6)),'#f3efe5')
    draw=ImageDraw.Draw(result)
    for j,i in enumerate(indices):
        tile=Image.open(FRAMES/f'{key}_{i:03d}.png').convert('RGBA').crop((36,112,150,188)).resize((228,152))
        x=(j%6)*230; y=(j//6)*190
        result.paste(tile,(x,y+22),tile)
        draw.text((x+8,y+2),f'{key}  {i:02d}/{CLIPS[key]["count"]}',font=FONT,fill='#45483f')
        draw.line((x+4,y+166,x+226,y+166),fill='#979c90')
    result.save(QA/destination)


def main():
    frame=Image.open(FRAMES/'walk_000.png').convert('RGBA')
    zoom=Image.new('RGBA',frame.size,'#f3efe5')
    zoom.alpha_composite(frame)
    zoom.resize((704,768)).convert('RGB').save(QA/'anatomy_zoom.png')
    board('walk',list(range(30)),'lower_body_all_frames.png')
    board('walk_cup',list(range(30)),'lower_body_cup_all_frames.png')
    board('start',[0,4,8,12,16,20],'start_anatomy.png')
    board('stop',[0,5,10,15,20,26],'stop_anatomy.png')
    before=Image.open(ROOT/'assets/source/manager_blender/rejected_v2/key_poses.png')
    after=Image.open(QA/'key_poses.png')
    comparison=Image.new('RGB',(1200,644),'#f3efe5')
    draw=ImageDraw.Draw(comparison)
    draw.text((16,8),'修订前：宽脚距，不允许双腿前后交叠（错误理解）',font=FONT,fill='#45483f')
    comparison.paste(before.crop((0,0,1200,280)),(0,34))
    draw.text((16,328),'修订后：圆脸短颈、腹内藏根，双腿前后交替、固定近远层',font=FONT,fill='#45483f')
    comparison.paste(after.crop((0,0,1200,280)),(0,362))
    comparison.save(QA/'before_after.png')


if __name__=='__main__': main()
