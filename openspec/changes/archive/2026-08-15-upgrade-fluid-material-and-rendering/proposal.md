# upgrade-fluid-material-and-rendering

## Why

现有 2D WCSPH 模块已经能验证杯中流体、吸光度混色、运动容器和规则固体浮力，
但液体材质中的密度与黏度倍率尚未进入求解热路径，最终画面仍是直接 alpha 混合的
粒子圆片。它不能充分表达不同酒液的流动差异、染色强度、胶体浑浊感、连续液面、
轻量反射和折射。

本变更在不替换现有 CPU 求解器的前提下，先建立可扩展的多材质物性契约和
低分辨率光学场合成渲染，为后续 GDExtension 或 GPU 求解后端保留稳定边界。

## What Changes

- 建立按稳定整数 ID 注册的液体材质表，并让每个粒子的静止密度、黏度、颜色扩散、
  染色强度、浑浊度、折射和高光参数来自材质。
- 保持压力力与黏性力成对对称；不同材质之间使用明确的成对参数规则，并支持互溶组
  阻止不相容液体发生颜色扩散。
- 新增低分辨率 HDR 光学场渲染器，通过单个 `MultiMeshInstance2D` 累积吸光度和
  有效厚度，再由单个 CanvasItem 合成 Shader 输出透明、像素化边缘、轻量高光与
  屏幕空间折射。
- 保留直接粒子渲染器作为诊断/回退路径；两种渲染路径都只消费只读快照，不修改物理。
- 扩充自动化测试、独立演示和性能记录。

- 将原 800 粒子压力演示改为 60–136 粒子的交互预设，并在验收实验室直接提供透明
  混色、黏度对比、密度分层、胶体浑浊、冰块和重物六个可点击用例，以及明确的
  当前步骤、通过条件和运行指标。
## Impact

- Specs: `particle-fluid-2d`
- Code: `features/particle_fluid_2d/data/`、`core/`、`adapters/`、`rendering/`、`demo/`
- Tests: `tests/particle_fluid_2d/unit/`、`integration/`、`performance/`
- Engine: 按用户批准的独立升级变更固定到 Godot 4.7.1 stable
