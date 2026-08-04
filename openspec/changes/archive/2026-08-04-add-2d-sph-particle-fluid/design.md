## Context

MaoMaoClub 当前运行于 Godot 4.6.3 stable、Windows 和 typed GDScript 2.0，项目已有业务 feature，但没有流体系统、统一自动化测试框架或粒子规模性能基线。本变更需要同时解决数值模拟、光学混色、运动容器、刚体浮力、批量渲染和测试，因此必须先确定清晰的模块边界与第一版精度范围。

第一版面向游戏表现而非工程计算：要求行为稳定、方向正确、可调、可重复验证，并在中等粒子规模下维持实时运行。所有数值状态由流体模块拥有；业务层只能通过公开命令提交输入，通过只读快照、查询结果和信号消费输出。

## Goals / Non-Goals

**Goals:**

- 提供可独立实例化、无全局单例、无业务依赖的 2D 粒子流体 feature。
- 用弱可压缩 SPH（WCSPH）实现密度、压力、黏性、重力和自由表面运动。
- 让同一求解器可在运行时节点中自动步进，也可在测试中无 SceneTree、无渲染地手动确定性步进。
- 用空间哈希把邻域搜索从全粒子两两比较降为局部桶查询。
- 让粒子具有可编辑颜色，并用线性光/吸光度模型表现有色透明液体混合。
- 支持静止或运动的开放/封闭容器边界，并正确响应容器平移、旋转和加速度。
- 支持圆形、矩形和凸多边形规则均质物体的浮力、阻力、扭矩及流体反作用。
- 提供数值单元测试、场景集成测试、长时间稳定性测试和可复现性能基线。

**Non-Goals:**

- 不提供工程 CFD 精度、不可压缩压力泊松求解或实验数据认证。
- 不支持 3D 流体、任意凹多边形动态刚体、软体、破碎体或多相界面张力。
- 不实现 GPU Compute 求解；第一版保持 CPU 可读、可调试、可测试。
- 不做 marching squares 自由液面网格；第一版以批量粒子圆片/软粒子材质渲染。
- 不负责具体杯子美术、调酒配方、玩法判定、UI、存档或网络同步。
- 不承诺跨硬件逐位一致；确定性仅保证同一 Godot 版本、同一配置、同一平台与相同步进输入下在容差内复现。

## Decisions

### 1. 采用 feature 内部分层，而不是粒子节点树

建议目录：

```text
features/particle_fluid_2d/
  core/
    particle_fluid_solver_2d.gd
    particle_fluid_state_2d.gd
    spatial_hash_2d.gd
    sph_kernels_2d.gd
    color_transport_2d.gd
    boundary_solver_2d.gd
    buoyancy_solver_2d.gd
  data/
    particle_fluid_config_2d.gd
    fluid_material_2d.gd
    container_shape_2d.gd
    buoyant_body_shape_2d.gd
  adapters/
    particle_fluid_2d.gd
    container_motion_adapter_2d.gd
    buoyant_body_adapter_2d.gd
  rendering/
    particle_fluid_renderer_2d.gd
  demo/
    particle_fluid_demo.tscn
    particle_fluid_demo.gd
tests/particle_fluid_2d/
  unit/
  integration/
  fixtures/
  run_particle_fluid_tests.gd
```

- `core` 使用 `RefCounted` 和 typed PackedArray/Array 保存数据，不引用业务节点、场景路径或 Autoload。
- `data` 使用 `Resource` 暴露可复制的配置与材料；运行时实例必须复制配置，禁止修改共享 `.tres`。
- `adapters` 是 Godot SceneTree 边界：收集容器/刚体输入、调用求解器、应用输出力并发出信号。
- `rendering` 只读取位置与颜色快照，不修改物理状态。
- 每个流体实例由一个 `ParticleFluid2D` 节点集中推进；每个粒子不是 Node、RigidBody2D 或 Area2D。

替代方案是为每粒子创建 Node2D/RigidBody2D。该方案调试直观，但场景树、信号和 Godot 物理体开销会先于 SPH 计算成为瓶颈，也难以实现确定性离线步进，因此不采用。

### 2. 数值核心采用 CPU WCSPH 与固定物理 tick 内子步进

粒子状态至少包含：

```text
id: int
position: Vector2
velocity: Vector2
acceleration: Vector2
mass: float
density: float
pressure: float
optical_density: Vector3
turbidity: float
material_id: int
```

每个子步执行：

1. 依据平滑半径 `h` 重建均匀网格空间哈希，桶边长等于 `h`。
2. 只访问当前桶及周围 8 个桶，构建或遍历邻居。
3. 用 2D 归一化平滑核计算密度：`rho_i = sum_j(m_j * W(r_ij, h))`。
4. 用 Tait 状态方程计算压力：`p_i = bulk_modulus / gamma * max((rho_i / rest_density)^gamma - 1, 0)`；`bulk_modulus = rest_density * speed_of_sound^2`，第一版钳制负压以降低 tensile instability。
5. 用对称压力项计算粒子对作用力，确保同一对粒子的压力作用力等大反向；叠加黏性、重力和调用方提交的力场。
6. 处理颜色扩散、边界/刚体耦合，再以半隐式 Euler 更新速度和位置。
7. 连续碰撞投影防止粒子跨越容器壁，并进行有限反弹、切向摩擦与速度修正。

压力力采用对称形式：

```text
F_pressure_i = -sum_j m_i*m_j*(p_i/rho_i^2 + p_j/rho_j^2)*grad_W_ij
```

黏性力采用速度差、邻居密度和黏性核拉普拉斯项。具体 2D 核常数集中在 `sph_kernels_2d.gd`，通过核积分和对称性单元测试锁定，禁止散落在求解器中。

运行时以 `_physics_process(delta)` 驱动，但求解器只接收显式 `step(delta)`。每个 60 Hz 物理 tick 内根据 CFL、最大加速度与黏性限制选择 1 到 `max_substeps` 个等长子步；测试可锁定子步数与随机种子。若稳定步长仍小于允许下限，求解器必须限制输入并上报诊断，不能以 NaN/Infinity 继续。

替代方案 PBF 通常更容易获得近似不可压缩且大步长稳定的视觉结果，但用户明确要求 SPH，且 WCSPH 的密度/压力/黏性含义更直接，故第一版采用 WCSPH。GPU SPH 性能更高，但 Godot 4.6.3 下会增加 Compute shader、缓冲同步和无渲染测试复杂度，留作性能数据证明 CPU 路径不足后的后续变更。

二维求解中的单粒子等效体积由 `particle_mass / rest_density` 给出；对于按均匀间距校准的测试场景，它等价于：

```text
particle_volume = spacing^2 * effective_depth
```

测试场景以升为添加单位，并向上量化到完整粒子，同时明确显示请求体积、实际体积和粒子数。多次添加的实际体积、质量和粒子数必须累加，确定性重建时按全局粒子序号从杯底向上填充，因此液位随总体积上升。静止水平杯的目标液位由 `liquid_height = volume / (cup_width * effective_depth)` 给出；粗粒子测试使用粒子中心的稳健上下分位数估算液柱高度，并允许一个粒子间距的量化误差。性能预设允许通过增大粒子间距来让单粒子代表更大体积，但必须同步校准质量、平滑半径、状态方程和容量计算，不能通过少生成粒子而静默丢失体积。当前交互测试预设使用 0.20 m 间距、0.10 m 等效厚度，即约 4 L/粒子；这是以液面、飞溅和小尺度浮力分辨率换取 CPU 成本下降的明确取舍。测试场景额外使用较高的有效数值黏性耗散粗网格压力振荡，该值不代表水的分子黏度，静止密度仍保持 `1000 kg/m³`。

### 3. 颜色使用吸光度输运和 Beer-Lambert 近似

公开 API 仍允许调用方给每个粒子或批次传入 `Color`。输入 sRGB 颜色先转换为线性光透射率 `T`，再转换为吸光度：

```text
A = -ln(clamp(T, epsilon, 1))
```

粒子内部保存 `optical_density = A * concentration` 和 `turbidity`，而不是直接对 sRGB 通道求平均。相邻粒子根据 SPH 邻域、颜色扩散系数和浓度交换吸光度；该交换必须成对守恒并限制在稳定范围。渲染时按有效光程 `L` 还原线性透射率：

```text
T_out = exp(-optical_density * L)
```

随后转换回 sRGB，并用浑浊度/粒子覆盖率决定 alpha。该模型能近似有色透明液体的减色混合：吸收谱叠加，而不是把屏幕颜色做简单加法。第一版只用 RGB 三波段近似，不模拟完整光谱、折射、散射或化学反应。

替代方案是在 sRGB 中直接 `lerp`。它计算便宜但不满足能量意义，混合结果会产生明显错误，因此不采用。纯线性 RGB 平均适合发光体的加色混合，不适合常见有色饮料的透射混色，也不作为默认模型。

### 4. 容器使用解析边界与边界采样的混合方案

`ContainerShape2D` 由有向线段集合或凸多边形构成，可表示开放杯口；边界法线必须指向允许流体存在的一侧。求解器每步接收纯数据快照：边界局部几何、世界变换、线速度、角速度、线加速度和角加速度，不持有具体 Node 引用。

边界处理分两层：

- 按粒子间距沿壁面生成边界采样点，使壁面参与邻域密度与压力估算，减少靠壁密度亏损和粘壁空洞。
- 对预测位移执行从旧位置到新位置的线段扫掠；若越过壁面，则投影回允许侧并按移动壁面接触点速度修正法向与切向相对速度，防止高速或大加速度时穿杯。

求解器在世界坐标系中运行，因此容器受力后只需由适配器更新边界运动快照：重力仍保持世界方向，移动壁面自然向粒子传递冲量并产生晃动。调用方也可提交风、摇晃脉冲或局部加速度场。若将来增加局部坐标求解器，才需要显式加入平移、科里奥利、欧拉和离心伪力；第一版不引入第二套参考系公式。

流体对容器壁的粒子冲量会按 tick 汇总为反作用力/扭矩查询结果。默认容器可选择只作为运动学输入；当业务需要动态容器双向耦合时，适配器可将汇总结果施加到 RigidBody2D。

只依赖 Godot 碰撞形状做粒子碰撞的替代方案无法修复 SPH 靠壁密度亏损，且大量 PhysicsServer2D 粒子体开销过高，因此不采用。

### 5. 规则均质物体通过浸没采样计算浮力并双向交换动量

第一版对象形状限定为圆、轴对齐/可旋转矩形和凸多边形，并带有统一厚度、质量、质心与转动惯量。`BuoyantBodyAdapter2D` 在 `_integrate_forces()` 可安全使用刚体状态，但只向数值核心提交 `BuoyantBodySnapshot2D`，再消费核心返回的力和扭矩。

每个对象预生成面积权重均匀的内部采样点。每步对样本执行 SPH 插值，得到局部流体密度、速度和是否浸没。对浸没样本累计：

```text
dV = sample_area * effective_depth
dF_buoyancy = -rho_fluid * dV * gravity
dF_drag = drag_coefficient * dV * (fluid_velocity - body_point_velocity)
dTau = lever_arm cross (dF_buoyancy + dF_drag)
```

总力和总扭矩施加到刚体；相反的冲量按 SPH 权重分配给附近粒子。此方法在完全浸没时满足阿基米德原理，在部分浸没时随排水面积连续变化，并允许偏心浸没产生恢复扭矩。由于第一版是 2D，`effective_depth` 是明确的建模参数，质量和密度比较必须使用同一有效厚度。

浸没判定采用邻域密度与表面覆盖阈值的组合，并在阈值附近使用平滑过渡，避免自由表面抖动。低于流体有效密度的物体必须趋于漂浮，高于流体有效密度的物体必须趋于下沉；接近等密度时允许近似悬浮。

替代方案仅在刚体质心施加 `rho * volume * g`，无法处理部分浸没、姿态和扭矩。对刚体表面直接积分 SPH 压力更物理，但自由表面噪声大且采样成本高；第一版采用体积采样的阿基米德近似，并把压力积分作为未来精度升级方向。

### 6. 渲染与求解解耦，使用批量实例

`ParticleFluidRenderer2D` 读取不可变或复制的渲染快照，使用 `MultiMeshInstance2D` 的实例变换与颜色批量绘制粒子圆片。渲染插值只影响显示位置，不回写模拟。必要时可使用共享 CanvasItem shader 做软边缘、alpha 和覆盖叠加，但每粒子不得拥有独立材质或节点。

默认先保证粒子图形清晰可调；连续液面、折射和屏幕空间融合不进入第一版验收。

### 7. 测试采用无第三方依赖的分层确定性方案

仓库当前没有 GUT/GdUnit4。第一版新增纯 GDScript headless runner，失败时 `SceneTree.quit(1)`，成功时 `quit(0)`；测试只调用公开求解器 API，避免锁死内部实现。后续如项目统一引入 GUT，可保留 fixture 与断言语义后迁移。

测试层次：

- 单元：核函数有限支撑/非负/对称，空间哈希邻居完整性，颜色吸光度转换与成对守恒，边界最近点/扫掠，浮力样本面积。
- 数值：静水密度误差、压力对称性、无外力动量漂移、黏性耗散、相同步进输入的快照容差一致。
- 集成：杯中静水不泄漏、杯子水平加速时液面反向倾斜、停止后逐渐稳定、两色流体混合趋于 Beer-Lambert 预期、冰块漂浮/重物下沉/偏置浸没产生恢复扭矩。
- 稳定性：固定场景连续运行至少 10,000 个子步，无 NaN/Infinity、粒子逃逸、速度爆炸或持续能量增长。
- 性能：记录 500、1,000、2,000 粒子的求解耗时、邻居数量和内存；第一版门禁以 1,000 粒子在开发参考机上平均求解时间不超过 8 ms、99 百分位不超过 16 ms 为初始目标，并输出原始测量环境。若参考硬件改变，保留历史数据而不是静默改阈值。

### 8. 公开接口保持窄且可替换

核心接口建议包含：

```text
configure(config: ParticleFluidConfig2D) -> void
reset(seed: int) -> void
add_particles(batch: ParticleSpawnBatch2D) -> PackedInt32Array
remove_particles(ids: PackedInt32Array) -> void
set_container(snapshot: ContainerSnapshot2D) -> void
set_external_acceleration(value: Vector2) -> void
set_force_fields(fields: Array[FluidForceField2D]) -> void
set_buoyant_bodies(bodies: Array[BuoyantBodySnapshot2D]) -> void
step(delta_seconds: float) -> FluidStepResult2D
get_state_snapshot() -> ParticleFluidSnapshot2D
```

`FluidStepResult2D` 包含粒子只读快照、容器反作用、逐刚体力/扭矩、质量/动量/能量诊断和稳定性警告。业务层不能取得核心数组的可写引用。

## Risks / Trade-offs

- [typed GDScript CPU 路径在高粒子数下不足] → 使用空间哈希、结构化数组、缓存复用和批量渲染；先以 profiler/benchmark 定位，再决定是否另开 GDExtension 或 GPU 求解变更。
- [WCSPH 刚度与时间步长不匹配导致爆炸或体积明显压缩] → 配置验证、CFL 子步、速度/密度诊断、负压钳制和稳定性回归场景共同守门。
- [开放杯口或高速运动时粒子穿墙] → 边界采样补密度，解析扫掠做连续投影，并限制单 tick 最大容器位移/角位移；超过限制时细分或报告警告。
- [吸光度三通道模型与真实颜料仍有偏差] → 明确模型是三波段 Beer-Lambert 近似，提供材料吸光参数和校准 fixture，不宣称光谱级准确。
- [双向刚体耦合产生数值振荡] → 对浮力/阻力做平滑和力上限，使用多个均匀样本、固定耦合顺序与小子步，避免在刚体和粒子之间重复施力。
- [2D 有效厚度造成密度/质量单位混乱] → 所有配置统一声明像素到米比例和 `effective_depth`，测试用已知排水面积验证量纲。
- [自动化测试框架自建能力有限] → runner 只提供轻量断言、容差比较、fixture 和退出码；不复制完整第三方框架，后续可平滑迁移。
- [当前 `project.godot` 有用户未提交修改] → 实施时先检查差异，仅追加必要设置且不覆盖用户内容；本方案阶段不修改该文件。

## Migration Plan

1. 先实现无 SceneTree 的核函数、空间哈希、状态和固定步进测试，建立数值基线。
2. 实现 WCSPH 主循环与静态容器，达到静水稳定和不泄漏门禁。
3. 实现吸光度颜色输运及批量渲染。
4. 接入运动容器快照、外力和容器反作用诊断。
5. 接入规则均质刚体浮力与双向动量交换。
6. 建立独立 demo 场景和 headless 全套测试，不接入现有业务场景。
7. 性能与稳定性门禁通过、用户确认视觉/物理效果后，才由具体业务 feature 通过适配器引用。

回滚时可整体移除 `features/particle_fluid_2d/`、对应 `tests/particle_fluid_2d/` 和独立 demo；由于没有 Autoload、没有业务反向依赖且不改存档格式，回滚不需要迁移玩家数据。

## Open Questions

- 第一版最终目标粒子规模是否以 1,000 为验收主档、2,000 为观测档，还是具体玩法需要更高上限？
- 业务视觉更接近透明饮料、浑浊奶液还是颜料？默认 Beer-Lambert 适合透明有色液体，浑浊液需要更强散射近似参数。
- 动态杯子是否需要流体反作用推动杯子，还是只要求杯子运动影响流体？方案支持输出反作用，但默认可关闭以降低耦合振荡。
- 浮力对象第一版是否只需圆形和矩形？方案也预留凸多边形，但可以在实施时按范围分档。
