# MaoMaoClub OpenSpec 工作流

## 目标

后续开发采用 OpenSpec 风格的 specification-driven development：先描述要改变的
行为，再实现代码，最后把已实现行为沉淀为当前规格。

这套流程的价值是让项目始终能回答三个问题：

- 现在系统已经承诺了什么？
- 这次改动想改变什么？
- 实现完成后，规格和代码是否一致？

## 目录约定

```text
openspec/
├── project.md
├── specs/
│   ├── development-workflow/
│   │   └── spec.md
│   └── project-structure/
│       └── spec.md
└── changes/
    ├── .gitkeep
    └── archive/
        └── .gitkeep
```

### `openspec/project.md`

项目级背景和硬约束，例如 Godot 版本、代码风格、目录策略、测试策略、设计源头。
每次开始一个较大的任务前都要读它。

### `openspec/specs/`

当前已经生效的规格。这里描述“现在项目承诺怎样工作”，不是未来愿望。

每个能力一个目录：

```text
openspec/specs/<capability>/spec.md
```

### `openspec/changes/`

待实现或正在实现的变更。每个变更一个目录：

```text
openspec/changes/<change_id>/
├── proposal.md
├── tasks.md
├── design.md
└── specs/
    └── <capability>/
        └── spec.md
```

`design.md` 只在需要权衡架构、技术方案或系统边界时创建。

## 什么时候必须写 OpenSpec change

以下改动必须先写 `openspec/changes/<change_id>/`：

- 新玩法、新系统、新关卡结构、新 UI 流程。
- 修改玩家可感知行为。
- 修改存档、设置、输入、场景切换、资源加载、构建发布流程。
- 改动目录结构、架构边界、autoload、全局事件。
- 引入第三方插件、测试框架、资产管线或导出流程。
- 会影响多个功能目录的重构。

以下改动可以不写 change，但仍要遵守当前规格：

- 拼写修正、注释修正、纯文档小修。
- 不改变行为的小范围资源替换。
- 不影响架构边界的局部 bug 修复。

## 标准开发流程

1. 读 `openspec/project.md`。
2. 查找相关 `openspec/specs/<capability>/spec.md`。
3. 为非平凡改动创建 `openspec/changes/<change_id>/`。
4. 写 `proposal.md`：为什么改、改什么、影响范围。
5. 写 `tasks.md`：可勾选的实现和验证步骤。
6. 写 spec delta：用 `ADDED`、`MODIFIED`、`REMOVED` 描述行为变化。
7. 必要时写 `design.md`：记录架构权衡和取舍。
8. 实现 Godot 场景、GDScript、资源或文档。
9. 按 `tasks.md` 验证。
10. 完成后把变更合并进 `openspec/specs/`，再把 change 移到
    `openspec/changes/archive/`。

## `change_id` 命名

使用动词开头、`kebab-case`：

```text
add-main-menu
define-project-structure
implement-save-service
revise-player-movement
```

## `proposal.md` 模板

```md
# <change_id>

## Why

说明为什么需要这个改动。

## What Changes

- 列出玩家、开发者或系统可观察到的变化。

## Impact

- Specs: <affected capability>
- Code: <affected directories/files>
- Tests: <manual or automated validation>
```

## `tasks.md` 模板

```md
# Tasks

- [ ] 更新或新增规格。
- [ ] 实现代码、场景或资源。
- [ ] 运行 Godot/测试/静态检查。
- [ ] 更新文档。
- [ ] 归档 OpenSpec change。
```

## spec delta 写法

```md
## ADDED Requirements

### Requirement: Main Menu Startup

The game SHALL show a main menu before entering gameplay.

#### Scenario: Launch game

- WHEN the project main scene starts
- THEN the player sees the main menu
- AND no gameplay simulation has started yet
```

可用章节：

- `ADDED Requirements`
- `MODIFIED Requirements`
- `REMOVED Requirements`

每条 requirement 至少包含一个 `Scenario`。

## 和 Godot 开发的关系

OpenSpec 决定“要做什么”和“完成标准是什么”；Godot 技能栈决定“怎么正确实现”。

执行 Godot 工作时仍然遵守：

- Godot 4.6.3 stable。
- `maomao-godot` 作为 Godot 任务入口。
- feature-based 目录结构。
- typed GDScript 和显式返回类型。
- 运行时存档使用 `user://`。

## 本项目的最低门禁

每次非平凡实现完成前，至少确认：

- 对应 change 的 `tasks.md` 已完成。
- 当前行为已经合并到 `openspec/specs/`。
- 相关文档和 Godot 项目文件没有互相矛盾。
- 没有把 `.godot/`、导入缓存、本地编辑器状态或密钥纳入提交范围。
