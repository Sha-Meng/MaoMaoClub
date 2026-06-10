# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6.3 stable
- **Engine Exact Build**: 4.6.3.stable.official.7d41c59c4
- **Engine Version Policy**: Pinned. Do not target another Godot version unless the user explicitly approves an upgrade.
- **Local Godot Binary**: `/Users/mengsha/Downloads/Godot.app/Contents/MacOS/Godot`
- **Language**: GDScript 2.0, typed by default
- **Rendering**: Godot 4.6.3 rendering APIs only; select Forward+ / Mobile / Compatibility after platform decisions
- **Physics**: Godot 4.6.3 built-in 2D/3D physics; fixed timestep decisions must be documented in ADRs

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: [TO BE CONFIGURED — e.g., PC, Console, Mobile, Web]
- **Input Methods**: [TO BE CONFIGURED — e.g., Keyboard/Mouse, Gamepad, Touch, Mixed]
- **Primary Input**: [TO BE CONFIGURED — the dominant input for this game]
- **Gamepad Support**: [TO BE CONFIGURED — Full / Partial / None]
- **Touch Support**: [TO BE CONFIGURED — Full / Partial / None]
- **Platform Notes**: [TO BE CONFIGURED — any platform-specific UX constraints]

## Naming Conventions

- **Classes**: PascalCase `class_name` where globally useful
- **Variables**: snake_case, typed
- **Signals/Events**: past-tense snake_case
- **Files**: snake_case
- **Scenes/Prefabs**: snake_case filenames, PascalCase root node names
- **Constants**: UPPER_SNAKE_CASE

## Performance Budgets

- **Target Framerate**: 60 FPS baseline unless a design decision says otherwise
- **Frame Budget**: 16.67 ms baseline
- **Draw Calls**: [TO BE CONFIGURED]
- **Memory Ceiling**: [TO BE CONFIGURED]

## Testing

- **Framework**: [TO BE CONFIGURED]
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: `maomao-godot` -> `godot-master`
- **Language/Code Specialist**: `godot-gdscript-mastery`
- **Shader Specialist**: `godot-master` references, then `godot-shaders-basics` if added later
- **UI Specialist**: `godot-master` references, then `team-ui` for product workflow
- **Additional Specialists**: `godot-builder`, `godot-auditor`, `godot-analyst`, `godot-testing-patterns`, `godot-performance-optimization`, `godot-export-builds`
- **Routing Notes**: Every routed Godot task must honor the pinned Godot 4.6.3 stable version in root `AGENTS.md`.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (primary language) | `godot-gdscript-mastery` |
| Shader / material files | `godot-master` shader references |
| UI / screen files | `godot-master` UI references + `team-ui` |
| Scene / prefab / level files | `godot-builder` + `godot-project-foundations` |
| Native extension / plugin files | `godot-master`; add GDExtension specialist only if needed |
| General architecture review | Primary |
