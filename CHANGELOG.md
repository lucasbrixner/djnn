# Revision history for djnn

## Unreleased

### Added

- Added `ARCHITECTURE.md` to record the current Surface-oriented architecture
  direction: explicit per-agent surfaces, per-concern unified views, a deferred
  cross-concern aggregate, and an explicit mapping layer.

### Changed

- Restructured `docs/ROADMAP.md` around the current sequencing preference:
  preserve the v0 prototype and validation baseline, then map per-agent
  surfaces, unify per concern, add aggregation and mapping, decode authored
  config, implement the CLI, and add conformance fixtures.
- Realigned the roadmap phase branch-name examples in `CONTRIBUTING.md` with the
  updated roadmap phases.
- Realigned the `README.md` design-principles section with the current
  Surface-oriented architecture direction.

### Fixed

- Corrected the canonical hook-event set: `UserPromptSubmit` is in the
  Claude∩Codex identical-name intersection but was omitted. Adds the public
  `HookEvent` constructor `UserPromptSubmit`.
- Corrected `Djnn.Schema.Hook`'s rationale to state the schema-presence basis
  and to distinguish events emitted on both runtimes from those only
  schema-present on Codex (`PreCompact`, `PostCompact`, `PermissionRequest`).

## 0.1.0.0 -- 2026-05-17

### Added

- Project skeleton: library + executable, GHC2021, `-Wall` via a shared `common`
  stanza.
- Tier-1 canonical schema surfaces as independent leaves: `Djnn.Schema.MCP`,
  `Djnn.Schema.Hook`, `Djnn.Schema.Approval`.
- `Djnn.Canonical` aggregator and the `Canonical` composition type.
- `Djnn.Schema.Policy`: documented, deliberately unmodeled record of the
  deferred Tier-2 tool/command execution-policy surface.
- `djnn` executable skeleton with the `init` / `generate` / `check` subcommand
  surface (not yet implemented).
