# MaoMaoClub 目录规划

## 当前状态

MaoMaoClub 目前的介绍是：一个配置为 Codex 辅助开发的 Godot 独立游戏项目。
核心玩法、玩家目标、目标平台、输入方式和内容支柱还没有形成正式设计文档。

当前真正参与运行的 Godot 文件非常少：

```text
project.godot
scenes/main.tscn
```

仓库已经预留了这些生产支持目录：

```text
assets/
design/
docs/
production/
src/
tests/
tools/
```

因此现阶段的目录规划目标不是一次性铺满所有内容，而是先建立一套适合
Godot 4.6.3 的、可持续扩展的 feature-based 结构。

## 组织原则

- 固定使用 Godot 4.6.3 stable。
- 文件和目录使用 `snake_case`。
- Godot 节点名使用 `PascalCase`。
- 优先按功能组织，不按文件类型组织。
- 主场景只负责启动和挂载流程，不承载具体玩法逻辑。
- 共享系统保持小而明确，避免过大的全局 Manager。
- 功能自己的场景、脚本、资源、音频、美术尽量放在同一个功能目录下。
- 原始美术、音频工程文件、参考资料等应放到带 `.gdignore` 的源文件目录里，
  避免 Godot 自动导入。

## 推荐目标结构

```text
MaoMaoClub/
├── project.godot
├── README.md
├── AGENTS.md
├── .godot-version
├── addons/
├── app/
│   ├── main.tscn
│   ├── main.gd
│   ├── boot/
│   │   ├── boot_screen.tscn
│   │   └── boot_screen.gd
│   └── autoload/
│       ├── scene_router.gd
│       ├── save_service.gd
│       └── settings_service.gd
├── common/
│   ├── events/
│   │   └── game_events.gd
│   ├── resources/
│   │   ├── game_constants.gd
│   │   └── project_metadata.tres
│   ├── themes/
│   │   └── default_theme.tres
│   └── util/
│       └── math_util.gd
├── features/
│   ├── player/
│   │   ├── player.tscn
│   │   ├── player.gd
│   │   ├── player_config.tres
│   │   ├── art/
│   │   └── audio/
│   ├── interaction/
│   │   ├── interactable.gd
│   │   └── interaction_prompt.tscn
│   └── prototype_loop/
│       ├── prototype_loop.tscn
│       ├── prototype_loop.gd
│       └── prototype_loop_config.tres
├── levels/
│   ├── test_room/
│   │   ├── test_room.tscn
│   │   ├── test_room.gd
│   │   └── test_room_data.tres
│   └── shared/
│       ├── level_spawn_point.gd
│       └── level_bounds.gd
├── ui/
│   ├── hud/
│   │   ├── hud.tscn
│   │   └── hud.gd
│   ├── menus/
│   │   ├── main_menu.tscn
│   │   ├── main_menu.gd
│   │   ├── pause_menu.tscn
│   │   └── pause_menu.gd
│   └── widgets/
│       ├── icon_button.tscn
│       └── setting_row.tscn
├── assets/
│   ├── shared/
│   │   ├── fonts/
│   │   ├── materials/
│   │   ├── shaders/
│   │   └── sfx/
│   └── source/
│       ├── .gdignore
│       ├── art/
│       ├── audio/
│       └── references/
├── design/
│   ├── game_overview.md
│   ├── gdd/
│   │   └── core_loop.md
│   ├── ux/
│   │   └── screen_map.md
│   ├── art/
│   │   └── art_bible.md
│   └── audio/
│       └── audio_direction.md
├── docs/
│   ├── godot-version.md
│   ├── project-structure-plan.md
│   ├── architecture/
│   │   └── adr-0001-project-structure.md
│   └── onboarding/
│       └── contributor-guide.md
├── production/
│   ├── backlog/
│   ├── bugs/
│   ├── milestones/
│   ├── playtests/
│   ├── qa/
│   └── release/
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── scenes/
│   └── fixtures/
└── tools/
    ├── sync_codex_adapters.py
    ├── godot/
    └── asset_pipeline/
```

## 目录职责

### `app/`

负责游戏启动、应用生命周期和最上层流程。等第一个真实启动流程出现后，可以把
当前 `scenes/main.tscn` 迁移到 `app/main.tscn`，再把 `project.godot` 的
主场景改到 `res://app/main.tscn`。

`app/autoload/` 只放范围很窄的全局服务，例如场景路由、存档、设置、构建信息。
不要把玩家、敌人、关卡玩法放进这里。

### `common/`

放多个功能都会用到的轻量共享内容，例如全局事件、通用资源、主题、纯工具函数。
这里不是杂物箱。如果某个脚本只服务于一个功能，就应该放回对应的 `features/`
目录。

### `features/`

游戏玩法切片的主要位置。每个功能目录可以同时包含自己的 `.tscn`、`.gd`、
`.tres`、美术和音频。

推荐：

```text
features/player/player.tscn
features/player/player.gd
features/player/player_config.tres
```

避免：

```text
src/scripts/
assets/sprites/
scenes/player/
```

### `levels/`

放可游玩空间、测试房间、关卡片段、地图和场景拼装内容。多个关卡共用的帮助脚本
可以放在 `levels/shared/`。

### `ui/`

放菜单、HUD、弹窗、覆盖层和可复用 UI 组件。只属于某个玩法功能的 UI 可以先跟随
该功能放在 `features/<feature>/`，等变成共享组件后再移到 `ui/`。

### `assets/`

放共享运行时资产和原始生产资产。

- 可复用的已导入资源放 `assets/shared/`。
- 原始工程文件、参考图、未压缩音频等放 `assets/source/`。
- `assets/source/` 应带 `.gdignore`，避免 Godot 导入源文件。
- 只服务于单个功能的资产优先放在 `features/<feature>/art/` 或
  `features/<feature>/audio/`。

### `design/`

游戏设计的源头。现在最需要补的是游戏到底是什么。

建议优先建立：

- `design/game_overview.md`
- `design/gdd/core_loop.md`
- `design/ux/screen_map.md`
- `design/art/art_bible.md`

### `docs/`

技术文档、架构决策、贡献说明和目录规划放这里。这里面记录“项目怎么做”，而
`design/` 记录“游戏是什么”。

### `production/`

放生产管理资料：backlog、里程碑、bug、playtest、QA、发布清单、patch notes。
这里不放运行时游戏资源。

### `tests/`

放自动化测试、测试场景、fixture 和后续 GUT/Godot CLI 测试支持。

### `tools/`

放仓库自动化、Godot 辅助脚本、资产管线和 Codex adapter 维护脚本。

## 从当前状态迁移

### 第一阶段：保持项目稳定

- 继续保留 `scenes/main.tscn` 作为当前主场景。
- 先补设计文档，再大规模创建玩法目录。
- 在原始素材进入仓库前创建 `assets/source/.gdignore`。
- `src/` 暂时保持为空，除非有明确的临时用途。

### 第二阶段：建立第一个可玩切片

- 创建 `app/main.tscn` 和 `app/main.gd`。
- 把 `project.godot` 的主场景切到 `res://app/main.tscn`。
- 在 `features/prototype_loop/` 建立第一个玩法原型。
- 在 `levels/test_room/` 建立第一个测试房间。
- 在 `ui/` 建立基础菜单或 HUD。

### 第三阶段：替换泛型目录

- 把功能相关代码从泛型 `src/` 或 `scenes/` 迁到具体功能目录。
- `scenes/` 只作为过渡目录保留；当没有项目设置引用它时再删除。
- 最终结构稳定后，在 `docs/architecture/adr-0001-project-structure.md`
  记录一次架构决策。

## 立即建议

下一步先写 `design/game_overview.md`。等玩法定位明确后，`features/` 下面的目录
名应该来自真实游戏动词和系统，而不是长期保留 `prototype_loop` 这种占位名。
