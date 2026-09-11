# CatBar 调酒基础实现测试证据

记录日期：2026-09-04  
引擎：Godot `4.7.1.stable.official.a13da4feb`  
平台：Windows

## 自动化结果

| 门禁 | 结果 |
|---|---:|
| CatBar / 微信 / 存档 / 主装配 | 27 passed，0 failed |
| 既有 Particle Fluid 2D | 31 passed，0 failed |
| 既有 Cocktail Shaker Lab | 5 passed，0 failed |
| 资产与内容聚合校验 | 20 placeholders，1 reference_only，0 errors |
| 主场景 headless 启动 | exit 0 |

测试覆盖内容配置聚合诊断、会话事务、全部首批交互、品质评价、粒子档位隔离、镜头/焦点、Neko 幂等送达、经营奖励、顾客池、微信确定性生成、v1→v2 迁移、未知 ID 过滤和旧 TavernLoop 回退。

## 性能与稳定性

60 FPS 预算为 16.6667 ms。实测平均值：全景 6.7854 ms、调酒近景 6.8987 ms、Shake 6.9093 ms、手机朋友圈 6.9838 ms；采样时场景为 271 个 Node。

30 分钟等价时长模拟结果：顾客实例 2、消息 64、朋友圈 32、朋友圈 UI 条目 64、失败 0。对象池、历史上限、流体实例与信号连接未出现持续增长；重复送达测试保持单次结算。

## 视觉验收

GPU：NVIDIA GeForce RTX 5080，OpenGL Compatibility。截图为 960×540：

- `.work/cat_bar_overview.png`：暖暗全景、吧台、卡座、Neko 与右下角手机入口清晰。
- `.work/cat_bar_mixing.png`：工作台独立屏幕层，不受 Camera2D 缩放；两行内容入口、配方、半透明杯和动作按钮无裁切。
- `.work/cat_bar_phone.png`：手机位于安全区，世界被遮罩，朋友圈长文案换行且页面不穿透。

## 环境说明

所有测试进程均退出 0。沙箱中的 Windows Godot 会报告无法读取系统根证书；主场景 headless 冒烟还会因沙箱禁止写入 AppData 而提示 `user://` 保存失败。这两项均为测试宿主限制，不是项目解析或业务失败。
