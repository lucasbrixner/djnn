# Revision history for djnn

## Unreleased

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
