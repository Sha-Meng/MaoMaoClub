"""将 Godot 真正渲染的检查帧编码为固定调色板 GIF。"""
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
paths=sorted((ROOT/'tmp/manager_blender/review').glob('*.png'))
assert len(paths)==330, f'预览应有 330 帧，实际 {len(paths)}'
samples=Image.new('RGB',(1120,720))
for j,i in enumerate(range(0,330,42)):
    with Image.open(paths[i]) as image:
        samples.paste(image.convert('RGB').resize((280,360)),((j%4)*280,(j//4)*360))
palette=samples.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
frames=[]
for path in paths:
    with Image.open(path) as image:
        frames.append(image.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE))
output=ROOT/'production/qa/manager_blender/manager_demo.gif'
frames[0].save(output,save_all=True,append_images=frames[1:],duration=[30,30,40]*110,loop=0,disposal=1,optimize=False)
print(str(output),output.stat().st_size)
