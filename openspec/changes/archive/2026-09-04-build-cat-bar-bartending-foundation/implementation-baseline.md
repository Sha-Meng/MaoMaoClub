# CatBar 实施基线

记录日期：2026-09-03

## 环境

- 引擎：Godot `4.7.1.stable.official.a13da4feb`
- 平台：Windows
- 项目入口：`res://app/main.tscn`
- physics tick：60
- 第三方插件：不新增
- 实施前 Git 状态：只有 `openspec/changes/build-cat-bar-bartending-foundation/` 为本变更新增未跟踪目录，无其他已跟踪文件改动。

## 自动化基线

- Godot headless 项目解析：退出码 0。Windows 证书存储提示为已知环境信息，不是项目解析失败。
- 2D 粒子流体默认测试：31 passed，0 failed，退出码 0。
- Cocktail Shaker Lab 测试：5 passed，0 failed，退出码 0。
- Shake 诊断基线：冰块峰值速度 685.72 px/s、29 次接触、10 次冰块间接触；流体平均速度由 3.5045 m/s 收敛至 0.1672 m/s。

## 首轮灰盒锁定值

- 世界画布：960×540。
- physics tick：60；目标显示帧率：60 FPS。
- 内容：2 种虚构酒液、冰块、1 种香料、Shake 杯、量酒杯、长柄勺、1 种目标酒杯、1 个代表性配方。
- 手机策略：在全景可打开；Shake、倒酒和送酒期间拒绝打开；手机打开时调酒输入暂停，卡座氛围以降频逻辑继续。
- 流体策略：业务剂量独立于粒子数；产品交互采用已验证的 60–136 粒子粗粒子档。
- 素材策略：本需求附图仅作 `reference_only` 参考；首轮使用明确标记的原创开发占位内容。

