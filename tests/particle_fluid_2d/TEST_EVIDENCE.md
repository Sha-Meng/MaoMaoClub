# 2D 粒子流体测试与性能证据

记录日期：2026-08-04

## 验证环境

- 项目锁定引擎：Godot `4.6.3.stable.official.7d41c59c4`
- 便携验证程序：`C:\tmp\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe`
- 官方归档 SHA-256：`E39986A178D585CE7AC198FB8DE6EA436366DC0CC00E594810C2E3E104C04B90`
- 操作系统：Microsoft Windows 11 专业版 64 位，版本 10.0.26200
- CPU：AMD Ryzen 9 9950X，16 核 / 32 逻辑处理器
- 内存：203,625,820,160 字节
- 构建类型：Godot 官方编辑器构建，headless 模式
- 第三方测试插件：无

下载的引擎只解压到临时目录，不修改项目引擎设置或系统安装。项目现有 `project.godot` 差异属于实施前已存在的用户改动，本变更未写入该文件。

## 自动化命令与结果

### 项目解析

```powershell
& 'C:\tmp\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\felixzou\MaoMaoClub' --editor --quit
```

结果：退出码 0；新模块、测试和 demo 脚本均成功注册，没有解析错误。

### 默认单元与集成测试

```powershell
& 'C:\tmp\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\felixzou\MaoMaoClub' --script 'res://tests/particle_fluid_2d/run_particle_fluid_tests.gd'
```

结果：23 通过，0 失败，退出码 0。

覆盖配置校验、实例隔离、快照深拷贝、SPH 核积分、空间哈希与穷举一致性、桶复用、光学往返与守恒、压力动量对称、黏性耗散、确定性、子步上限与警告、静止密度、边界密度补偿、开口杯、运动壁面、容器加速/停止/旋转、液面方向、容器反作用开关、力场生命周期、非法输入隔离、渲染隔离、圆/矩形/凸多边形采样、质心、阿基米德浮力、阻力、恢复扭矩、干区零作用、双向动量和对象注销。

### 测试 runner 失败退出码

```powershell
& 'C:\tmp\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\felixzou\MaoMaoClub' --script 'res://tests/particle_fluid_2d/run_particle_fluid_tests.gd' -- --self-test-failure
```

结果：23 通过，1 个故意失败，Godot 进程退出码 1。证明任一断言失败会使 CI 失败。

### 10,000 子步稳定性

```powershell
& 'C:\tmp\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\felixzou\MaoMaoClub' --script 'res://tests/particle_fluid_2d/run_particle_fluid_tests.gd' -- --long
```

结果：25 通过，0 失败，退出码 0。

| 夹具 | 子步 | 最大动能 | 最终最大速度 | 结果 |
|---|---:|---:|---:|---|
| 静态开放杯 | 10,000 | 14.542818 | 0.015606 m/s | 无非有限值、实体壁泄漏或质量漂移 |
| 平移/旋转开放杯 | 10,000 | 14.386933 | 0.079704 m/s | 无非有限值、实体壁泄漏或质量漂移 |

两个夹具都限定最大速度并检查动能上界，没有观察到无界增长。

### 性能与阶段分析

```powershell
& 'C:\tmp\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe' --headless --profiling --path 'D:\felixzou\MaoMaoClub' --script 'res://tests/particle_fluid_2d/run_particle_fluid_tests.gd' -- --benchmark
```

每档预热 2 步，采样 10 步；峰值内存是进程级 Godot 静态内存峰值。第一版门禁为 1,000 粒子平均 8 ms、P99 16 ms，两项分别判定。

| 粒子数 | 平均耗时 | P99 | 平均邻居 | 峰值内存 | 8 ms 平均 | 16 ms P99 |
|---:|---:|---:|---:|---:|---|---|
| 500 | 10.256 ms | 11.972 ms | 9.91 | 30,876,234 B | 未通过 | 通过 |
| 1,000 | 18.608 ms | 20.828 ms | 9.64 | 30,876,234 B | 未通过 | 未通过 |
| 2,000 | 38.661 ms | 42.645 ms | 9.96 | 30,876,234 B | 观察档 | 观察档 |

1,000 粒子没有达到初始 8/16 ms 门禁；这是已知性能差距，不影响数值正确性结论。2,000 粒子按约定只作为可扩展性观察档。

1,000 粒子阶段均值：

| 阶段 | 耗时 |
|---|---:|
| 空间哈希构建 | 0.544 ms |
| 密度/压力 | 8.159 ms |
| 压力、黏性与颜色力循环 | 7.466 ms |
| 积分/约束 | 0.846 ms |

分析表明瓶颈是两次邻域数值循环，不是哈希构建。根据该证据，实施了两项限定优化：空间桶池复用，以及密度阶段邻居列表在力阶段复用。Godot 4.7.1 诊断基线上，1,000 粒子平均耗时由 15.031 ms 降至 13.977 ms，2,000 粒子由 31.815 ms 降至 28.935 ms；随后重新通过全部正确性和 20,000 子步稳定性测试。

### 交互测试场景体积与粗粒子优化复测

测试场景采用 2D 等效厚度计算粒子体积：

```text
particle_volume = spacing² × effective_depth
```

新默认间距为 0.20 m、等效厚度为 0.10 m，因此每粒子代表 0.004 m³，即约 4 L。默认红、蓝液体各 120 L，总计约 240 L，对应 60 个粒子。连续添加配方时，实际量化体积累加，粒子按顺序自杯底向上排布，液位随总体积上升。

| 方案 | 等效体积 | 粒子数 | 平均子步 | 每帧平均耗时 | 哈希 | 密度/边界 | 力与混色 | 积分/约束 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 原 0.11 m 细粒子 | 约 242 L | 200 | 3.3 | 11.664 ms | 0.387 ms | 3.839 ms | 4.673 ms | 2.450 ms |
| 新 0.20 m 粗粒子（Tait） | 约 240 L | 60 | 3.0 | 4.699 ms | 0.215 ms | 1.571 ms | 1.774 ms | 0.978 ms |
| 新粗粒子压力档（Tait） | 约 544 L | 136 | 3.0 | 11.975 ms | 0.373 ms | 3.909 ms | 5.070 ms | 2.297 ms |

加入 Tait 体积支撑后，同体积默认档平均耗时仍比原细粒子档下降约 59.7%。600 帧静水回归中，240 L 液柱为 1.250 m，360 L 为 1.820 m，增加 0.570 m，接近理论增加值 0.600 m；平均密度分别为 1105.0 kg/m³ 和 1109.4 kg/m³，最大速度分别为 0.070 m/s 和 0.077 m/s，未再塌缩为杯底单层。代价是液面、飞溅和小尺度浮力的空间分辨率下降；这符合当前测试场景优先玩法与观感而非细粒度 CFD 的目标。杯壁密度贡献继续使用空间哈希近邻查询。

## 场景生命周期与回归

独立 demo：

```powershell
& 'C:\tmp\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\felixzou\MaoMaoClub' --quit-after 2 'res://features/particle_fluid_2d/demo/particle_fluid_demo.tscn'
```

结果：退出码 0，无 Autoload 或主业务场景依赖，无资源泄漏提示。

现有主场景：

```powershell
& 'C:\tmp\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\felixzou\MaoMaoClub' --quit-after 2
```

结果：退出码 0，没有发现对现有 feature 的启动回归。

## 人工验收边界

以下视觉行为需要在编辑器中 F6 运行 `particle_fluid_demo.tscn` 后人工观察：

- 两色透明液体的减色混合观感是否符合美术预期；
- 杯子平移冲击、突然耗散和旋转时液面晃动方向；
- 冰块与重物切换后的整体观感；
- 800 粒子 demo 在目标显示帧率下的可接受性。

自动测试已经验证对应的数值方向、守恒关系、连续性和生命周期；人工验收只决定视觉调参，不改变核心物理契约。
