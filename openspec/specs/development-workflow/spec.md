# development-workflow Specification

## Purpose

Define how MaoMaoClub uses OpenSpec-style specification-driven development.

## Requirements

### Requirement: Non-Trivial Changes Use OpenSpec

Non-trivial game, architecture, UI, content, build, testing, save, input, or
tooling changes SHALL be described in `openspec/changes/<change_id>/` before
runtime code or Godot scene files are modified.

#### Scenario: Add a new gameplay system

- WHEN a developer starts a new gameplay system
- THEN the developer creates a change under `openspec/changes/<change_id>/`
- AND the change includes `proposal.md`
- AND the change includes `tasks.md`
- AND the change includes spec deltas for affected capabilities

### Requirement: Current Behavior Lives In Specs

Accepted project behavior SHALL be documented under `openspec/specs/`.

#### Scenario: Complete a change

- WHEN a change is implemented and validated
- THEN the accepted behavior is merged into the relevant
  `openspec/specs/<capability>/spec.md`
- AND the completed change can be archived under `openspec/changes/archive/`

### Requirement: Project Context Is Read First

OpenSpec work SHALL begin by reading `openspec/project.md` and relevant
capability specs.

#### Scenario: Start implementation

- WHEN a developer begins a non-trivial task
- THEN the developer checks `openspec/project.md`
- AND the developer checks relevant files under `openspec/specs/`

### Requirement: Specs Stay Compatible With Godot Pin

Specifications SHALL not require Godot behavior, APIs, or tooling newer than
Godot 4.6.3 stable unless the user approves an engine upgrade.

#### Scenario: Propose version-sensitive behavior

- WHEN a change depends on a Godot API or engine behavior
- THEN the change is checked against Godot 4.6.3 stable
- AND incompatible behavior is rejected or explicitly marked as requiring an
  approved engine upgrade
