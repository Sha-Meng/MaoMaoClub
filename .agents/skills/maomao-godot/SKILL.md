---
name: maomao-godot
description: "Project-specific Godot entry point for MaoMaoClub. Use for all Godot design, architecture, GDScript, scene, asset pipeline, testing, performance, build, and export work. Enforces the pinned Godot 4.6.3 stable engine version before routing to gd-agentic-skills or Codex Game Studios workflows."
---

# MaoMaoClub Godot Skill

Use this skill for every Godot-specific task in MaoMaoClub.

## Hard Version Pin

- Engine: Godot 4.6.3 stable
- Exact build: 4.6.3.stable.official.7d41c59c4
- Local binary: `/Users/mengsha/Downloads/Godot.app/Contents/MacOS/Godot`
- Version file: `.godot-version`

All Godot choices must target this exact version unless the user explicitly
approves an upgrade.

Before using version-sensitive APIs, editor settings, export behavior, physics
behavior, rendering behavior, or CLI automation, check that the approach is
compatible with Godot 4.6.3 stable. If a vendored skill mentions a different
Godot version, adapt it to 4.6.3 or ask before proceeding.

## Routing

Use the smallest relevant skill or reference:

- Broad Godot architecture: `.agents/skills/godot-master/SKILL.md`
- Project layout and naming: `.agents/skills/godot-project-foundations/SKILL.md`
- Typed GDScript: `.agents/skills/godot-gdscript-mastery/SKILL.md`
- CLI automation and generated scenes: `.agents/skills/godot-builder/SKILL.md`
- Static review and architecture audit: `.agents/skills/godot-auditor/SKILL.md`
- Project analysis: `.agents/skills/godot-analyst/SKILL.md`
- Testing: `.agents/skills/godot-testing-patterns/SKILL.md`
- Performance: `.agents/skills/godot-performance-optimization/SKILL.md`
- Export and release builds: `.agents/skills/godot-export-builds/SKILL.md`

For production planning, GDDs, epics, stories, QA, release checklists, and team
workflow, combine this skill with the Codex Game Studios skills in
`.agents/skills/*` and canonical workflow sources in `.claude/skills/*`.

## Project Defaults

- Organize code by feature, not by file type.
- Use `snake_case` for files and folders.
- Use `PascalCase` for Godot node names.
- Use typed GDScript and explicit return types.
- Prefer signals for cross-system communication.
- Keep presentation, logic, data, and infrastructure separated.
- Use `user://` for runtime saves and persistent player data.
- Avoid synchronous `load()` in hot paths; prefer `preload` or threaded
  `ResourceLoader` workflows where appropriate.

## Upgrade Protocol

If the user asks to upgrade Godot:

1. Confirm the target Godot version.
2. Update `AGENTS.md`, `.godot-version`, `.agents/docs/godot-version.md`,
   `.agents/docs/technical-preferences.md`, this skill, and `godot-master`.
3. Run the local Godot binary with `--version` if available.
4. Summarize compatibility risks before changing gameplay code.
