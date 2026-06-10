# MaoMaoClub Project Context

## Purpose

MaoMaoClub is a Godot indie game project configured for Codex-assisted
development. The concrete game premise, core loop, target platforms, and input
model are still to be defined in `design/`.

## Hard Constraints

- Engine: Godot 4.6.3 stable.
- Exact build: 4.6.3.stable.official.7d41c59c4.
- Local binary: `/Users/mengsha/Downloads/Godot.app/Contents/MacOS/Godot`.
- Language: typed GDScript 2.0 by default.
- Production code uses explicit return types.
- Files and folders use `snake_case`.
- Godot node names use `PascalCase`.
- Project organization is feature-based, not type-based.

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
