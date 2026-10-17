# 采用正式制作的角色动画

状态：2026-10-17 用户选择免费 Blender 制作、透明序列帧导出及 Godot 播放；单店长验证由 `validate-manager-blender-animation` 执行，全员尚未迁移。

## 为什么

用户明确否定当前整图网格关节步态，并给出 Live2D 行走质量参考。数值与业务测试已通过，但未满足视觉需求。问题涉及素材、网格及动作制作，继续微调统一关节公式不足以解决。

## 改什么

- 将完整站姿程序变形改为有可编辑源文件、分层补画和人工校正关键姿态的角色动画。
- 按用户最终选择，使用 Blender 分层骨骼与关键帧制作，导出透明帧供 Godot 4.6.3 原生播放；首个店长交付可编辑 Blender 工程与独立验证场景。
- 用常驻原尺寸连续走停的视觉结果验收样片，之后扩展其他体型；数值测试独立保留。
- Spine 作为后续专业制作工具备选；引入时再确认授权并验证官方 spine-godot GDExtension 与精确引擎构建兼容性。

## 影响

- 当前调研：`design/animation/authored_animation_research.md`。
- 待修改规格：`tavern-character-presentation`。
- 后续运行代码范围：`features/tavern/` 人物表现与动作资源。
- 保留透明桌面、X 轴规则、座位消费、人格行为和现有存档。
