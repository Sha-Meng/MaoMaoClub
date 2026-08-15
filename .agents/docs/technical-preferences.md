# Technical Preferences

All Codex and studio workflows should treat this file as the project-local
technical preference source.

## Engine & Language

- Engine: Godot 4.7.1 stable
- Engine exact build: 4.7.1.stable.official.a13da4feb
- Engine version policy: pinned. Do not target another Godot version unless the
  user explicitly approves an upgrade.
- Target OS: Windows only
- Local Godot binary: 'D:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe'
- Language: GDScript 2.0, typed by default
- Rendering: Godot 4.7.1 rendering APIs only; choose Forward+ / Mobile /
  Compatibility after platform decisions
- Physics: Godot 4.7.1 built-in physics, with fixed timestep decisions recorded
  in ADRs

## 文档语言

- 项目自有文档和 OpenSpec 材料默认且必须使用中文。
- 这包括 proposal、tasks、design notes、specifications、production notes 和技术文档。
- 外部上游引用、vendored skill 原文、API 名称、代码标识符和必须保留的英文术语，可以在翻译会降低准确性时保留原文。

## Input & Platform

- Target platforms: to be configured
- Input methods: to be configured
- Primary input: to be configured
- Gamepad support: to be configured
- Touch support: to be configured
- Platform notes: to be configured

## Naming Conventions

- Classes: PascalCase `class_name` where globally useful
- Variables: snake_case, typed
- Signals/events: past-tense snake_case
- Files: snake_case
- Scenes: snake_case filenames, PascalCase root node names
- Constants: UPPER_SNAKE_CASE

## Performance Budgets

- Target framerate: 60 FPS baseline unless a design decision says otherwise
- Frame budget: 16.67 ms baseline
- Draw calls: to be configured per target platform
- Memory ceiling: to be configured per target platform

## Engine Specialists

- Primary: `maomao-godot` -> `godot-master`
- Language/code specialist: `godot-gdscript-mastery`
- Scene/build automation: `godot-builder`
- Audit/review: `godot-auditor`
- Analysis: `godot-analyst`
- Testing: `godot-testing-patterns`
- Performance: `godot-performance-optimization`
- Export/release: `godot-export-builds`

## File Extension Routing

| File Extension / Type | Specialist |
| --- | --- |
| `.gd` | `godot-gdscript-mastery` |
| `.tscn`, `.scn`, `.tres`, `.res` | `godot-builder` and `godot-project-foundations` |
| `.gdshader`, materials | `godot-master` shader references |
| UI scenes | `godot-master` UI references and `team-ui` |
| Export/build files | `godot-export-builds` |

## Forbidden Patterns

- Do not use APIs or workflows that require a Godot version newer than 4.7.1
  unless the user approves an engine upgrade.
- Do not commit `.godot/`, imported cache files, editor-local state, or secrets.
- Do not mix type-based project structure into production code; prefer
  feature-based folders.
