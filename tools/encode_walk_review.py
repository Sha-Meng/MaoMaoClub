"""只把引擎实际输出的完整检查帧编码成 GIF，不修改游戏素材或图中肢体。"""
from pathlib import Path
from PIL import Image

folder = Path(__file__).resolve().parents[1] / "production/qa/full_character_walk/review"
keys = sorted({path.name.rsplit("_light_", 1)[0] for path in folder.glob("*_light_00.png")})
for key in keys:
    for background in ("light", "dark"):
        frames = [Image.open(folder / f"{key}_{background}_{index:02d}.png").convert("RGB") for index in range(8)]
        frames[0].save(folder / f"{key}_{background}.gif", save_all=True, append_images=frames[1:], duration=115, loop=0, disposal=2)
        for frame in frames:
            frame.close()
print(f"已编码 {len(keys) * 2} 个完整检查动画，源 PNG 保留。")
