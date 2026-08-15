# 2D 粒子流体模块

本目录提供独立的 CPU 版 2D WCSPH 流体。数值核心只使用 `RefCounted`、`Resource` 和纯数据快照，不依赖调酒、角色、UI、存档或全局单例。

## SPH 原理

每个粒子携带位置、速度、质量、密度、压力和光学吸光度。求解器用有限支撑核把邻居离散量平滑到当前位置：

```text
rho_i = sum_j(m_j * W(r_ij, h)) / effective_depth
p_i = bulk_modulus / gamma * max((rho_i / rest_density)^gamma - 1, 0)
F_pressure_i = -sum_j m_i*m_j*(p_i/rho_i^2 + p_j/rho_j^2)*grad_W_ij
```

压力项成对计算并施加等大反向作用，黏性项耗散相对速度。空间哈希只查询当前格及邻格，避免无条件 O(n²) 两两比较。每个物理 tick 根据 CFL、加速度和黏性限制拆成子步，再用半隐式 Euler 积分。

## 单位与调参

- 核心单位：米、秒、千克；水的静止密度使用 `1000 kg/m³`，等价于 `1 kg/L`。
- Godot 场景单位：像素；适配器使用 `pixels_per_meter` 转换。
- 2D 密度通过 `effective_depth_meters` 映射到等效三维体积。
- 先确定粒子间距和 `smoothing_radius_meters`，再校准粒子质量使静水密度接近 `rest_density`。
- `gas_stiffness` 作为体积模量，水预设按 `rest_density * speed_of_sound²` 校准；Tait 指数默认 7。
- 增大 `gas_stiffness` 可降低压缩，但需要更小子步；`dynamic_viscosity` 是粗网格有效数值黏性，不应直接照搬水的分子黏度。
- 出现密度爆炸时，先降低外力/刚度或增加 `max_substeps`，不要直接提高速度上限。

## 光学混色

输入 sRGB 先转换为线性透射率，再保存吸光度：

```text
A = -ln(clamp(T_linear, epsilon, 1))
T_out = exp(-A * optical_path_length)
```

邻居按浓度成对交换吸光度，因此默认表现透明有色饮料的减色混合，而不是直接平均 sRGB。核心输运是 RGB 三波段近似，不是完整光谱模拟。

## 可扩展液体材质

`FluidMaterial2D` 用稳定的 `material_id` 描述一种液体。求解器注册材质时会校验并深复制资源；ID 0 永远作为兼容默认材质。粒子生成批次通过 `material_ids` 指定材质，未指定时继续使用 ID 0。

材质参数分为三组：

- 物理：`density_multiplier`、`viscosity_multiplier`；影响目标静止密度、压力、黏性和稳定子步。
- 混合：`color_diffusion_multiplier`、`mixing_group`、`dye_strength`、`turbidity_multiplier`；影响吸光度、互溶关系和浑浊度。
- 表现：`refractive_strength`、`specular_strength`；只进入渲染快照，不反向修改物理。

只有材质确实改变物理或互溶参数时，求解器才进入多材质邻居循环；默认材质保留专用快速路径。新属性应优先添加到材质资源，并在粒子入场时缓存为状态派生值，避免每个邻居对做字典或 Resource 查询。

## 光学场渲染

`ParticleFluid2D` 默认使用 `OPTICAL_FIELD`：

1. 一个低分辨率 HDR `SubViewport` 接收单次 `MultiMesh` 粒子 splat，累积 RGB 吸光度和有效厚度。
2. 合成 Shader 用 Beer-Lambert 透射率生成透明液体颜色。
3. 厚度梯度近似液面法线，并提供轻量屏幕空间折射、边缘高光和颜色阶梯化，保持 2D 像素风格。

可通过以下属性控制成本或切回旧显示：

```gdscript
fluid.render_mode = ParticleFluid2D.RenderMode.OPTICAL_FIELD
fluid.optical_field_resolution = Vector2i(160, 256)
fluid.optical_surface_fill_scale = 2.20
# 调试/低端回退：
fluid.set_render_mode(ParticleFluid2D.RenderMode.DIRECT_PARTICLES)
```

光学场以重叠 splat 填补粗粒子之间的空隙；`optical_surface_fill_scale` 只扩大离屏覆盖，不增加物理粒子、节点或邻域计算。合成阶段还会在固定纹理采样预算内闭合被液体从两侧包围的小孔，并平滑内部颜色；只有单侧液体支撑的自由表面不会向外无限扩张。直接粒子模式保留离散圆片，供诊断粒子运动。合成同时加入有界的环境散射染色；纯 Beer-Lambert 透射在暗背景上没有足够入射光，会使有色液体近乎不可见。该散射项只提高暗场可读性，仍由累积厚度和浑浊度控制，不参与物理或颜色输运。

该渲染是屏幕空间艺术化近似：它支持透明度、吸收、浑浊、轻量反射高光与折射扰动，但不模拟真实光谱、多次散射或三维焦散。物理快照与渲染完全解耦，关闭或切换渲染模式不会改变求解结果。

验收实验室的普通酒液使用水感粗粒子预设：数值声速 `6.5 m/s`、基础动态黏度
`4.0`、边界恢复系数 `0.0`、壁面摩擦 `0.05`。这些值是针对 0.20 m 粗粒子的交互
近似，不是现实水的直接 SI 参数；糖浆和胶体继续通过材质倍率保持更高黏度。

为消除低黏粗粒子在静置时由压力离散误差产生的持续抖动，配置可选择启用
`quiescent_damping_per_second`。求解器只在无活动力场、容器与固体静止、平均粒子速度
进入阈值并经过 `quiescent_activation_delay_seconds` 后施加指数阻尼；低于
`quiescent_stop_speed` 的残余速度会归零。新外力、粒子增删或调用 `fluid.wake()` 会立即
解除静稳态。实验室使用 `18 s⁻¹` 阻尼、`0.45 s` 延迟和 `0.04 m/s` 归零阈值；这不会
改变默认核心配置，因为该功能默认关闭。

## 容器与外力

`ContainerShape2D` 用有向线段和内侧法线描述实体杯壁，开放杯口不创建边界。边界采样补偿靠壁密度，解析扫掠和投影防止穿墙。运动适配器提交世界变换、速度和加速度；求解器保持世界坐标，因此重力方向不会随杯子错误旋转。

可通过 `set_external_acceleration()` 提交均匀加速度，或用 `FluidForceField2D` 提交有限生命周期的均匀/径向力场。

## 浮力

规则均质对象支持圆、矩形和凸多边形。内部面积样本估算排水体积：

```text
dF_buoyancy = -rho_fluid * displaced_volume * gravity
dF_drag = drag * displaced_volume * (fluid_velocity - body_point_velocity)
```

力矩由样本力相对 `center_of_mass_local_meters` 的力臂产生；相反冲量按 SPH 权重分配给邻近粒子。2D 浮力结果依赖对象和流体使用一致的有效厚度。适配器会把 `RigidBody2D.center_of_mass` 转换为米制快照。

## 最小使用示例

```gdscript
var fluid := ParticleFluid2D.new()
fluid.config = ParticleFluidConfig2D.new()
add_child(fluid)

var red_wine := FluidMaterial2D.new()
red_wine.material_id = 1
red_wine.density_multiplier = 0.99
red_wine.dye_strength = 1.3
red_wine.refractive_strength = 0.7

var syrup := FluidMaterial2D.new()
syrup.material_id = 2
syrup.viscosity_multiplier = 3.0
syrup.turbidity_multiplier = 1.4
var material_table: Array[FluidMaterial2D] = [red_wine, syrup]
fluid.set_materials(material_table)

var batch := ParticleSpawnBatch2D.new()
batch.positions_meters = PackedVector2Array([Vector2(0.0, 0.0)])
batch.colors_srgb = PackedColorArray([Color(0.2, 0.6, 1.0, 0.7)])
batch.material_ids = PackedInt32Array([1])
fluid.add_particles(batch)
```

独立演示场景为 `res://features/particle_fluid_2d/demo/particle_fluid_demo.tscn`。F6 运行后会以 60 粒子交互档自动晃杯，可按 `1`–`6` 切换透明混色、黏度、密度、胶体、冰块和重物用例，并用 `B` 停止自动演示。杯子运动由 `ContainerMotionAdapter2D` 转为纯数据快照。

推荐人工验收使用干净测试场景 `res://features/particle_fluid_2d/demo/particle_fluid_test_lab.tscn`。它不依赖主场景、业务模块、Autoload 或项目 InputMap，支持运行时调整杯子宽高，按升添加、选择、编辑和删除多种自定义粒子液体，并内置六个带操作步骤、通过条件和实时性能指标的测试用例。内置配置统一约 60 个粗粒子，硬上限为 136；杯壁密度采样使用空间哈希近邻查询。

完整按键、预期现象和验收顺序见 `res://features/particle_fluid_2d/demo/TEST_GUIDE.md`。

默认测试入口为：

```powershell
Godot --headless --path . --script res://tests/particle_fluid_2d/run_particle_fluid_tests.gd
```


长稳态与性能模式：

```powershell
Godot --headless --path . --script res://tests/particle_fluid_2d/run_particle_fluid_tests.gd -- --long
Godot --headless --profiling --path . --script res://tests/particle_fluid_2d/run_particle_fluid_tests.gd -- --benchmark
```

完整命令、硬件、性能门禁与结果记录见 `res://tests/particle_fluid_2d/TEST_EVIDENCE.md`。
性能基线主档为 1,000 粒子，2,000 粒子仅作观测。当前版本不包含 GPU Compute、连续液面网格、3D、软体、完整光谱或工程 CFD 精度。
