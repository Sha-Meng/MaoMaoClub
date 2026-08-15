# upgrade-godot-4-7-1

## Why

项目实际已由用户使用 Godot 4.7，且 `project.godot` 已声明 4.7 特征；仓库中的版本锁定、
技能和技术文档仍指向 4.6.3，导致编辑器操作、自动化验证和代理约束不一致。用户已明确
拒绝继续使用 4.6，因此需要将项目正式固定到当前本机可验证的 Godot 4.7.1 构建。

## What Changes

- 将项目固定引擎更新为 Godot `4.7.1.stable.official.a13da4feb`，Windows only。
- 同步根约束、版本文件、技术偏好、项目技能和当前 OpenSpec 项目说明。
- 使用本机 4.7.1 console 构建重新执行项目解析、流体测试、场景冒烟和性能基线。
- 保留历史归档与旧测试证据中的 4.6.3 记录，不回写历史事实。

## Impact

- Specs: `development-workflow`、`particle-fluid-2d`、`fluid-object-interaction`、`desktop-idle-experience`
- Project files: `AGENTS.md`、`.godot-version`、`.agents/docs/*`、`.agents/skills/*`
- Runtime: 不主动采用 4.7.1 独占 API；先验证现有实现兼容性
