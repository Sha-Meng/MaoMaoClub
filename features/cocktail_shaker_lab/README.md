# 调酒 Shake 配表测试环境

该功能位于独立的 `features/cocktail_shaker_lab/`，只使用 `particle_fluid_2d` 的公开适配器。调酒业务配表、测试 UI、杯体、封盖、鼠标 Shake 和冰块逻辑均未放入底层流体目录。

## 直接运行

1. 使用 Godot 4.7.1 打开 `features/cocktail_shaker_lab/cocktail_shaker_lab.tscn`。
2. 按 `F6` 运行当前场景。
3. 初始状态只有一个未封盖的空杯，没有液体和冰块。
4. 在下拉框选择液体，点击“增加液体”。每次点击按该液体模拟配表的 `volume_per_add_liters` 加入一批粒子。
5. 点击“增加冰块”逐块加入冰块，直到配置上限。
6. 点击“封盖”。封盖后顶部同时生成流体边界和冰块碰撞壁。
7. 点击“Shake”，然后在窗口中按住鼠标左键，上下左右拖动鼠标。
8. 再次点击“结束 Shake 并复位”，杯体立即回到初始位置和转角。
9. “清空并重置”会删除所有液体和冰块、打开杯盖并复位杯体。

未封盖时不能进入 Shake 模式，避免液体和冰块从开口杯逸出。
封盖后“增加液体”和“增加冰块”按钮会禁用；需要继续加料时先打开杯盖。

新增液体不会直接铺在杯底。每一批粒子在杯口内侧形成窄流束，带向下初速度，并在重力作用下落入杯中。可在液体粒子模拟配置中调整：

- `pour_stream_columns`：流束横向粒子列数。
- `pour_spawn_depth_meters`：相对杯口向下的生成深度。
- `pour_initial_downward_speed_meters_per_second`：初始向下速度。

## 第一层：FluidConfig 业务配表

业务配置与粒子模拟完全分离：

- 枚举与业务结构：`domain/fluid_config.gd`
- 业务目录：`configs/fluid_catalog.tres`
- 水业务配置：`configs/fluids/water.tres`
- 琥珀酒液业务配置：`configs/fluids/amber_spirit.tres`

`FluidConfig.FluidId` 是业务层和模拟层共同使用的稳定 Key。当前值：

- `WATER = 0`
- `AMBER_SPIRIT = 1`

业务字段包括液体名称、说明、酒精度、标签和真实物性。后续新增风味、价格、解锁条件、配方标签等业务字段时，应继续扩展 `FluidConfig`，不要放到粒子求解配置里。

## 第二层：粒子模拟配表

- 模拟结构：`simulation/fluid_particle_simulation_config_2d.gd`
- 模拟表：`configs/particle_simulation_table.tres`
- 水模拟：`configs/simulations/water_particle_simulation.tres`
- 琥珀酒液模拟：`configs/simulations/amber_spirit_particle_simulation.tres`

每一项 `FluidParticleSimulationConfig2D` 使用 `fluid_id` 作为 Key，包含：

- 完整的 `ParticleFluidConfig2D`：单位、粒子质量、平滑半径、压力、黏度、重力、子步、CFL、静稳、混色和边界参数。
- 单次加入体积、颜色、浓度和浑浊度。
- 液体密度/黏度倍率。
- 扩散、互溶组、染色和浑浊倍率。
- 折射和高光参数。

混合多种液体时，第一种加入的液体决定当前共享求解器的完整全局参数；每种液体仍使用自己 ID 对应的材质、密度、黏度、混合和光学参数。空杯时选择另一种液体作为第一杯，场景会自动用该液体的完整求解器配置重建空求解器。

## 新增一种液体

1. 在 `FluidConfig.FluidId` 枚举中追加一个稳定值，已有值禁止改号。
2. 复制一个 `configs/fluids/*.tres`，设置相同的新 `fluid_id` 和业务字段。
3. 把业务 Resource 加入 `configs/fluid_catalog.tres` 的 `fluids` 数组。
4. 复制一个 `configs/simulations/*.tres`，设置相同的新 `fluid_id`，并配置完整 `particle_config` 和材质参数。
5. 把模拟 Resource 加入 `configs/particle_simulation_table.tres` 的 `entries` 数组。
6. 运行测试。目录会拒绝重复 ID、业务配置缺少模拟配置或模拟配置缺少业务配置。

## 鼠标 Shake 参数

在 `default_shaker_test.tres > Motion` 中调整：

- `mouse_sensitivity`：鼠标移动到杯体位移的倍率。
- `maximum_offset_pixels`：水平和垂直最大幅度。
- `maximum_rotation_radians`：水平拖动映射出的最大转角。
- `follow_speed_per_second`：杯体追随鼠标目标的速度。
- `release_return_speed_per_second`：松开左键后目标回中的速度。
- `reset_speed_per_second`：预留的复位调节参数；按钮复位当前采用立即回原点，确保测试可重复。
- `require_left_mouse_button`：是否必须按住左键才接收鼠标移动。

封盖 Shake 使用三层防逸出机制：闭合凸容器半平面硬约束、冰块内框钳制、光学合成杯外像素裁剪。即使单帧鼠标位移远高于最大幅度，也不能把液体或冰块摇出杯外。

## 自动测试

```powershell
& 'D:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script 'res://tests/cocktail_shaker_lab/run_cocktail_shaker_lab_tests.gd'
```

场景冒烟：

```powershell
& 'D:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene 'res://features/cocktail_shaker_lab/cocktail_shaker_lab.tscn' -- --shaker-smoke
```
