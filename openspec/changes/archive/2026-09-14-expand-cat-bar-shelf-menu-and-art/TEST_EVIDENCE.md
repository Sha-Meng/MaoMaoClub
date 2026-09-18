# 吧台二级菜单与调酒素材测试证据

记录日期：2026-09-14  
引擎：Godot `4.7.1.stable.official.a13da4feb`  
平台：Windows / NVIDIA GeForce RTX 5080 / OpenGL Compatibility

## 自动化结果

- CatBar、微信、存档与场景组合：29 passed，0 failed。
- 资产与内容聚合校验：26 placeholders，1 reference_only，0 errors。
- GPU 视觉截图：13 张均以 960×540 成功写出。

## 菜单与美术验收

- `.work/cat_bar_mixing.png`：一级菜单显示基酒、工具、辅料三类图片与名称。
- `.work/cat_bar_menu_base_spirits.png`：五种基酒位于可滚动二级列表，瓶型与色彩可区分。
- `.work/cat_bar_menu_tools.png`：Shake 杯、量酒器和长柄勺图片与名称对齐。
- `.work/cat_bar_menu_support.png`：冰块、猫薄荷香料和特级鱼油完整显示。
- `.work/cat_bar_shake.png`：动态杯体保留粒子运动，同时显示锥形金属轮廓、暖冷高光和猫耳封盖。

## 性能

60 FPS 预算为 16.6667 ms：全景 6.7861 ms、调酒 6.8976 ms、Shake 7.6930 ms、手机朋友圈 7.7347 ms；场景 280 Nodes，全部低于预算。

## 环境提示

Windows 沙箱仍会报告系统根证书读取失败；该提示不影响资源导入、玩法测试、GPU 截图或退出码。
