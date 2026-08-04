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
- 增大 `gas_stiffness` 可降低压缩，但需要更小子步；测试场景的高 `dynamic_viscosity` 是粗网格有效数值黏性，不代表水的分子黏度。
- 出现密度爆炸时，先降低外力/刚度或增加 `max_substeps`，不要直接提高速度上限。

## 光学混色

输入 sRGB 先转换为线性透射率，再保存吸光度：

```text
A = -ln(clamp(T_linear, epsilon, 1))
T_out = exp(-A * optical_path_length)
```

邻居按浓度成对交换吸光度，因此默认表现透明有色饮料的减色混合，而不是直接平均 sRGB。该模型是 RGB 三波段 Beer-Lambert 近似，不是完整光谱、折射或散射模拟。

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

var batch := ParticleSpawnBatch2D.new()
batch.positions_meters = PackedVector2Array([Vector2(0.0, 0.0)])
batch.colors_srgb = PackedColorArray([Color(0.2, 0.6, 1.0, 0.7)])
fluid.add_particles(batch)
```

独立演示场景为 `res://features/particle_fluid_2d/demo/particle_fluid_demo.tscn`。F6 运行后可向杯子施加左右冲量或角冲量、触发有限生命周期的液体上冲力场，并切换冰块/重物质量。杯子运动由 `ContainerMotionAdapter2D` 转为纯数据快照。

推荐人工验收使用干净测试场景 `res://features/particle_fluid_2d/demo/particle_fluid_test_lab.tscn`。它不依赖主场景、业务模块、Autoload 或项目 InputMap，支持运行时调整杯子宽高，按升添加、选择、编辑和删除多种自定义粒子液体，并内置两色混合、运动容器、短时外力、冰块浮起、重物下沉、暂停和渲染解耦检查。默认性能配置为宽 2 m、高 4 m、红蓝各 120 L；0.20 m 粗粒子按约 4 L/粒子量化，总计约 60 个粒子；杯壁密度采样使用空间哈希近邻查询。

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
性能基线主档为 1,000 粒子，2,000 粒子仅作观测。第一版不包含 GPU Compute、连续液面网格、3D、软体或工程 CFD 精度。
