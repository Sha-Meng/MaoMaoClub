# MaoMaoClub Project Context

## Purpose

MaoMaoClub 是 Windows 桌面挂机经营游戏：猫猫在夜间小酒馆接待动物顾客，自动营业积累收益，后续通过材料、研发和酒单形成经营策略。设计源头见 `design/catcat-club-mvp-brief.md`。

## Hard Constraints

- Engine: Godot 4.6.3 stable.
- Exact build: 4.6.3.stable.official.7d41c59c4.
- Target OS: Windows only.
- Local binary: 'C:\Users\shame\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe'.
- Language: typed GDScript 2.0 by default.
- Production code uses explicit return types.
- Files and folders use `snake_case`.
- Godot node names use `PascalCase`.
- Project organization is feature-based, not type-based.

## 文档语言

- 项目自有文档和 OpenSpec 材料默认且必须使用中文。
- 这包括 proposal、tasks、design notes、specifications、production notes 和技术文档。
- 外部上游引用、vendored skill 原文、API 名称、代码标识符和必须保留的英文术语，可以在翻译会降低准确性时保留原文。

## Development Workflow

- Use OpenSpec-style specification-driven development for non-trivial changes.
- Accepted behavior lives in `openspec/specs/`.
- Proposed behavior lives in `openspec/changes/<change_id>/` until implemented.
- Godot-specific work starts from the project-local `maomao-godot` skill.
- Production planning may use Codex Game Studios workflows under `.agents/` and
  `.claude/`.

## Current Game State

- 运行入口：`res://app/main.tscn`，`app` 只负责启动与退出协调。
- 已实现六位差异化顾客、店长/调酒员/服务员分工、座位消费、调制递送饮用付款收杯、个性动作及有边界的闲聊。
- 当前步行使用九位人物与服务员持盘变体的同一完整站姿，髋膝踝定长关节驱动屈膝、转踝、承重起伏和对摆，约 0.86–0.95 双步周期/秒。周期按实际位移推进，支撑 60%、摆动 40%；行走轴对称，初次起步只在摆动期对齐。固定先远腿后近腿，镜像不换层。用户已明确反馈关节不自然，视觉未验收；技术测试证据见 `production/qa/articulated_walk/`，正式动画制作建议见 `design/animation/authored_animation_research.md`，待实施变更为 `adopt-authored-character-animation`。
- 店长 Blender 骨骼动画独立验证：用户明确要求正常前后交叉步态，已撤销上一版“不交叉走位”的错误解释。按新原型调整圆脸、短颈、厚腹和粗短腿，腿根在腹部内融合，近远层固定，每周期两次经过交叠。8 片段、216 帧、可编辑 `.blend`、常驻与放大播放、双向走停及持杯切换。入口 `tools/run_manager_lab.ps1`，详情 `design/animation/manager_blender_pilot.md`。不接触正式营业存档；全员迁移仍待完成。
- 桌面形态：无边框、原生透明背景、局部半透明地台与面板、固定常驻置顶；提供移动、最小化和保存后关闭。切换普通应用后继续显示，并保留其他应用的输入焦点。
- 运行时逻辑画布 960×280，店铺约 146 高；随屏幕等比缩放，并提供 80%/100%/120% 设置。角色移动与 DIY 均限定同一水平基线、只改变 X，无 Y 轴及纵深；调酒员不可单独拖动，随店铺整体移动。支持家具增删、动态挂点和布局/营业检查点保存。
- 使用 Compatibility 渲染器和 30 FPS 上限，独立启动入口是 `tools/run_desktop.ps1`。编辑器验收必须关闭 Embed Game on Next Play。测试入口是 `tools/run_tests.ps1`。
- 存档支持旧经济迁移、原子替换及备份恢复；禁止多个正式实例并发写入同一进度。单元/集成与验收证据见 `production/qa/personality_tavern/`。
- 原桌面挂机 MVP 的剩余交互验收与整体归档仍由 `validate-desktop-idle-mvp` 跟踪；调酒经营仍处于独立规格阶段。
- 目录规划见 `docs/project-structure-plan.md`。

## Source Of Truth

- Engine version: `AGENTS.md`, `.godot-version`,
  `.agents/docs/godot-version.md`.
- OpenSpec workflow: `docs/open-spec-workflow.md`.
- Current specifications: `openspec/specs/`.
- Proposed changes: `openspec/changes/`.
- Game design: `design/`.
- Technical documentation: `docs/`.
