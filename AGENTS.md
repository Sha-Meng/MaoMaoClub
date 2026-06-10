---
project: MaoMaoClub
codex_profile: godot-indie-game
---

# MaoMaoClub Project Agent

This repository is a Godot indie game project driven by Codex with a project-local
skill system.

## Pinned Engine Version

- Engine: Godot 4.6.3 stable
- Exact build: 4.6.3.stable.official.7d41c59c4
- Local binary: `/Users/mengsha/Downloads/Godot.app/Contents/MacOS/Godot`
- Version source: `Godot --version`, checked on 2026-06-10

This is a hard project constraint. All game design, architecture, GDScript,
scene construction, export planning, testing, and performance advice must target
Godot 4.6.3 stable unless the user explicitly approves an engine upgrade.

If any vendored skill, upstream documentation, or general model knowledge
mentions a different Godot version, prefer the pinned version above. Before
using APIs or behavior introduced after Godot 4.6.3, stop and verify
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

For Godot-specific work, use `maomao-godot` first. It may route to:

- `godot-master` for architecture and broad implementation decisions
- `godot-project-foundations` for project layout and naming
- `godot-gdscript-mastery` for typed GDScript
- `godot-builder` for CLI, scene, import, and export automation
- `godot-auditor` for Godot-specific reviews
- `godot-testing-patterns` for test structure
- `godot-performance-optimization` for profiling and frame-time work
- `godot-export-builds` for release/export planning

## Collaboration Rules

- Work from the repository root unless a task says otherwise.
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
