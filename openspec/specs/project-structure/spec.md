# project-structure Specification

## Purpose

Define the accepted directory organization rules for MaoMaoClub.

## Requirements

### Requirement: Feature-Based Runtime Organization

Runtime game code and scenes SHALL be organized primarily by feature rather than
by file type.

#### Scenario: Add player implementation

- WHEN player code, scenes, resources, art, or audio are added
- THEN they are placed under a player feature directory such as
  `features/player/`
- AND they are not split into generic type folders such as `src/scripts/` and
  `assets/sprites/`

### Requirement: Main Scene Stays Thin

The project main scene SHALL remain responsible for bootstrapping and
application flow, not detailed gameplay behavior.

#### Scenario: Add gameplay loop

- WHEN the first playable loop is implemented
- THEN gameplay logic is placed in feature and level directories
- AND the main scene only routes, loads, or hosts the appropriate top-level
  scene

### Requirement: Source Assets Are Ignored By Godot Import

Raw production assets SHALL be kept separate from runtime imported assets.

#### Scenario: Add source art files

- WHEN raw art, audio project files, references, or other source production
  assets are added
- THEN they are placed under `assets/source/`
- AND `assets/source/.gdignore` exists before those files are introduced

### Requirement: Documentation Directories Have Distinct Roles

Design, technical documentation, and production management SHALL remain
separate.

#### Scenario: Add a core-loop document

- WHEN documenting what the game is
- THEN the document is placed under `design/`

#### Scenario: Add a technical architecture decision

- WHEN documenting how the project is implemented
- THEN the document is placed under `docs/`

#### Scenario: Add planning or QA material

- WHEN documenting backlog, QA, release, bugs, milestones, or playtests
- THEN the document is placed under `production/`
