# 完整人物平滑步态管线

> 历史方案，已停用。用户随后确认仍有滑步、重影和松鼠闪切；图像跳变量下降不能证明落脚正确。当前实现见 `grounded_walk_pipeline.md`，以下保留当时记录，不再代表现行规则。

## 问题与范围

用户确认上一版手脚连接和比例正常，但走路抽搐。原运行周期使用单步长度解释双步循环：服务员约每秒 2.27 周期、松鼠约 2.05 周期。八张独立原画还存在高度差，直接硬切放大视觉跳变。旧 GIF 一律每帧 115 ms，没有复现真实游戏速度。

保留完整人物及手杯/手盘一体关系；不修改原 PNG、不拆手脚、不恢复旧肢体网格。原坐下及喝酒保持。业务移动速度、水平世界坐标和存档格式不变。

## 当前实现

1. `TavernPerson.stride_length()` 按两步计一个周期：圆润短腿角色为身高的 0.64，其余为 0.80。真实步频约 0.58–1.14 周期/秒；距离推进，不依赖显示帧率。
2. `TavernWalkArt` 每张原画整身等比注册为角色设定高度，支撑脚仍在原点；保持帧内宽高比例，不单独压缩腿脚。
3. `tools/bake_smooth_walk.gd -- --sources-only` 通过 Godot GPU 绘出注册帧，透明轮廓仍来自原完整人物。
4. `tools/analyze_walk_motion.py` 仅分析注册帧，输出每对相邻帧的双向运动向量，包括第 7 帧到第 0 帧。离线依赖 OpenCV 4.13.0、numpy、Pillow；OpenCV 可只安装至 `tmp/walk_dependencies`，不加入游戏运行依赖。
5. `walk_resample.gdshader` 依据向量反向采样两张原画，再用预乘透明度混合，减轻普通叠画导致的双手双脚。GPU 烘焙为每图 32 帧、2 倍原尺寸；十张图集位于 `assets/tavern/walk_smooth/`。这属于原画重采样，不标称新增手绘原画。
6. 运行时只采样已烘焙图集，不实时计算光流，也不创建每角色特效窗口。停止/拖动回到静态帧，重新移动保留距离相位。点击边界合并相邻原画轮廓，覆盖过渡区域。

## 重建

在工程根目录，使用项目固定的 Godot 4.6.3 控制台程序依次执行：

```text
Godot --path . --position -10000,-10000 --script res://tools/bake_smooth_walk.gd -- --sources-only
python tools/analyze_walk_motion.py
Godot --path . --position -10000,-10000 --script res://tools/bake_smooth_walk.gd
Godot --headless --path . --editor --import --quit
```

运行 `tools/run_tests.ps1 -Render` 后，用 `python tools/encode_smooth_walk_review.py` 编码实际时间 GIF。GIF 用 30/30/40 ms 表示三个 30 FPS 帧，整段时间不变。保留 PNG 帧，避免 GIF 色板成为唯一判断依据。

## 验证边界

验证包括所有九位人物与持盘变体、原尺寸/两倍、浅/深底、左右走动、停步、反向、循环首尾，以及原有坐姿和喝酒回归。离线补间可能在极细轮廓产生轻微柔化，不能把数值平滑视作重绘了全部关节运动；角色原画的美术差异仍由原稿决定。
