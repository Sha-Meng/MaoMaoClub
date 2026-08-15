# 多材质流体与光学场渲染设计

## Context

当前求解器使用全局 `rest_density`、`dynamic_viscosity` 和 `color_diffusion`。
`ParticleSpawnBatch2D` 已携带 `material_ids`，`FluidMaterial2D` 也已有密度与黏度倍率，
但求解器没有使用这些字段。当前 `ParticleFluidRenderer2D` 直接将每粒子的显示颜色写入
`MultiMeshInstance2D`，重叠结果依赖普通 alpha 混合，无法按厚度累计吸光度，也没有
连续场法线、反射或折射。

项目已升级并固定 Godot 4.7.1 stable、Windows only。第一阶段不引入 Compute Shader、
GDExtension、第三方测试插件或新的 Autoload。

## Goals / Non-Goals

### Goals

- 让同一求解器中的不同材质具有可观察的密度、黏度、扩散和光学差异。
- 保持成对内力与颜色交换的守恒/对称性质。
- 用低粒子数产生连续、透明、可像素化的液体观感。
- 保持数值核心 headless 可测试，渲染生命周期集中且可整体关闭。
- 让材质数据和渲染快照能够被未来 CPU native 或 GPU 后端复用。

### Non-Goals

- 本变更不实现 GPU Compute、PBF/XPBD、连续液面网格或 3D 光学。
- 不实现完整光谱、真实 Fresnel、焦散、多次散射或工程级胶体模型。
- 不实现任意化学反应、相变、冰块融化或表面永久染色。
- 不承诺本次将 1,000 粒子 GDScript 求解器提升到 60 FPS。

## Decisions

### 1. 材质注册与热路径缓存

`FluidMaterial2D` 使用非负 `material_id`。求解器保存材质的深复制，并在粒子加入时把
会参与每个邻居循环的属性缓存到结构化数组：

- `rest_density_multiplier`
- `viscosity_multiplier`
- `color_diffusion_multiplier`
- `mixing_group`
- `refractive_strength`
- `specular_strength`

染色强度和浑浊倍率在生成粒子时应用到初始吸光度与浑浊度，避免每步重复转换。
材质表更新时，物理/渲染倍率按粒子的 `material_id` 重新同步；已经混合后的吸光度不被
重新乘染色强度，避免破坏颜色守恒。

材质 ID `0` 始终有默认材质。调用方未注册或未提供 ID 时使用默认材质。重复 ID、负 ID
或非有限参数会在材质表生效前被拒绝。

### 2. 不同材质的成对规则

每粒子的目标静止密度为：

```text
rho0_i = config.rest_density * material_i.density_multiplier
```

压力仍使用各自 `rho0_i` 的 Tait 状态方程。黏性粒子对使用两个黏度倍率的算术平均，
并对两个粒子施加等大反向力。颜色扩散只在 `mixing_group` 相同的粒子间发生，扩散倍率
使用两者较小值，从而允许某个材质抑制交换且不会产生单向扩散。

稳定步长中的黏性限制使用当前活动粒子的最大有效黏度和最小目标密度估算；诊断密度
误差相对每粒子的目标静止密度计算。

### 3. 光学场使用一个 HDR SubViewport

新增 `OpticalFluidRenderer2D`，内部持有：

- 一个低分辨率、透明背景、`use_hdr_2d = true` 的 `SubViewport`；
- 一个 `MultiMeshInstance2D`，每粒子一个圆形 splat；
- 一个显示 `ViewportTexture` 的 `Sprite2D` 合成面。

第一阶段把每粒子吸光度编码在实例 custom data RGB 中，把浑浊度编码在 alpha 中；
折射和高光强度由当前粒子快照取均值后作为合成参数。累积 pass 使用加法混合，输出
吸光度积分和有效厚度。合成 pass 通过 Beer-Lambert 近似恢复透射颜色，以厚度梯度
近似表面法线，并在一个液体合成面上读取
屏幕纹理产生小幅折射和边缘高光。

光学场分辨率固定为可配置档位，世界渲染范围来自容器边界；无容器时退化为粒子 AABB。
渲染范围增加一个平滑半径的 padding，防止圆片在边缘被裁切。纹理采用 nearest filter，
低分辨率本身形成可控像素风，不额外追求平滑 CFD 表面。

### 4. 渲染不参与玩法真值

配方体积、成分、酒精度和经营结果继续由业务数据账本持有。渲染器只消费
`ParticleFluidSnapshot2D`，不得反推配方，不得修改粒子状态。关闭、替换或降低渲染
分辨率必须产生相同的物理快照。

### 5. 回退与兼容

`ParticleFluid2D` 提供光学场和直接粒子两种渲染模式。headless 测试默认不要求真实
Viewport 像素输出，只验证快照不可变、节点资源可建立/清空和两种路径不影响求解。
视觉效果通过独立 demo 人工验收。

## Risks / Trade-offs

- HDR SubViewport 与屏幕纹理增加一次离屏绘制和合成成本；通过固定低分辨率、一个
  MultiMesh 和一个合成面限制开销。
- 屏幕空间折射是视觉近似，无法正确处理多个重叠透明液体合成面；第一阶段限定每个
  活跃杯子一个合成面。
- 将不同静止密度引入 WCSPH 可能增加界面压力噪声；第一阶段使用共享压力核和成对力，
  通过窄范围倍率与稳定性回归控制，不实现多相界面张力模型。
- 混合组只决定是否进行颜色扩散，不等同于完整的不互溶两相物理。
- 当前 `project.godot` 有用户本地 4.7 特征标记；本变更不覆盖它，所有验证仍显式调用
  固定 Godot 4.7.1 可执行文件。

## Migration Plan

1. 扩展材质资源、状态快照和求解器材质表，保持默认 ID 0 行为兼容。
2. 添加多材质物理/混色单元与集成测试。
3. 新增光学场渲染器，并在运行时节点暴露渲染模式与分辨率。
4. 更新 demo 与使用说明，执行 Godot 4.7.1 解析、默认测试和性能基线。
5. 用户视觉验收后将规格合并进当前 `particle-fluid-2d` 并归档变更。
