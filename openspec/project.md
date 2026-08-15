# MaoMaoClub Project Context

## Purpose

MaoMaoClub is a Godot indie game project configured for Codex-assisted
development. The concrete game premise, core loop, target platforms, and input
model are still to be defined in `design/`.

## Hard Constraints

- Engine: Godot 4.7.1 stable.
- Exact build: 4.7.1.stable.official.a13da4feb.
- Target OS: Windows only.
- Local binary: 'D:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe'.
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

- Runtime entry point: `res://scenes/main.tscn`.
- Current main scene is intentionally empty.
- No gameplay feature has been formally specified yet.
- Directory planning is documented in `docs/project-structure-plan.md`.

## Source Of Truth

- Engine version: `AGENTS.md`, `.godot-version`,
  `.agents/docs/godot-version.md`.
- OpenSpec workflow: `docs/open-spec-workflow.md`.
- Current specifications: `openspec/specs/`.
- Proposed changes: `openspec/changes/`.
- Game design: `design/`.
- Technical documentation: `docs/`.
