---
project: MaoMaoClub
codex_profile: godot-indie-game
---

# MaoMaoClub Project Agent

This repository is a Godot indie game project driven by Codex with a project-local
skill system.

## Pinned Engine Version

- Engine: Godot 4.7.1 stable
- Exact build: 4.7.1.stable.official.a13da4feb
- Target OS: Windows only
- Local binary: 'D:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe'
- Version source: `Godot --version`, checked on 2026-08-08

This is a hard project constraint. All game design, architecture, GDScript,
scene construction, export planning, testing, and performance advice must target
Godot 4.7.1 stable unless the user explicitly approves an engine upgrade.

If any vendored skill, upstream documentation, or general model knowledge
mentions a different Godot version, prefer the pinned version above. Before
using APIs or behavior introduced after Godot 4.7.1, stop and verify
compatibility or ask the user.

Engine upgrades require updating all of these files in the same change:

- `AGENTS.md`
- `.godot-version`
- `.agents/docs/godot-version.md`
- `.agents/docs/technical-preferences.md`
- `.agents/skills/maomao-godot/SKILL.md`
- `.agents/skills/godot-master/SKILL.md`

## Primary Skill Stack

- Production workflow: Codex Game Studios, via `.agents/skills/*` and canonical
  workflow sources under `.claude/`.
- Godot expertise: selected `gd-agentic-skills` skills under `.agents/skills/`,
  with `maomao-godot` as the project-specific entry point.
- OpenSpec workflow: repository-local specifications under `openspec/`.

For Godot-specific work, use `maomao-godot` first. It may route to:

- `godot-master` for architecture and broad implementation decisions
- `godot-project-foundations` for project layout and naming
- `godot-gdscript-mastery` for typed GDScript
- `godot-builder` for CLI, scene, import, and export automation
- `godot-auditor` for Godot-specific reviews
- `godot-testing-patterns` for test structure
- `godot-performance-optimization` for profiling and frame-time work
- `godot-export-builds` for release/export planning

## 文档语言

- 项目自有文档和 OpenSpec 材料默认且必须使用中文。
- 这包括 proposal、tasks、design notes、specifications、production notes 和技术文档。
- 外部上游引用、vendored skill 原文、API 名称、代码标识符和必须保留的英文术语，可以在翻译会降低准确性时保留原文。

## Collaboration Rules

- Work from the repository root unless a task says otherwise.
- Follow the OpenSpec workflow in `docs/open-spec-workflow.md` for non-trivial
  design, gameplay, architecture, UI, content, save, build, testing, and tooling
  changes.
- Before implementation, read `openspec/project.md` and relevant files under
  `openspec/specs/`.
- For non-trivial changes, create or update an entry under
  `openspec/changes/<change_id>/` with `proposal.md`, `tasks.md`, and spec deltas
  before touching runtime code.
- Keep accepted behavior in `openspec/specs/`; keep proposed behavior in
  `openspec/changes/` until it is implemented and archived.
- Keep changes scoped to the requested workflow or feature.
- Prefer feature-based Godot organization over type-based folders.
- Use typed GDScript and explicit return types for production code.
- Do not commit `.godot/`, imported cache files, local editor state, or export
  secrets.
- Do not create a Git commit or push to GitHub unless the user asks.

## GitHub Status

This project is prepared for GitHub, but this machine currently does not have
the `gh` CLI available. Create the remote as private by default unless the user
explicitly requests a public repository.
