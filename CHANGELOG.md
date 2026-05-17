# Revision history for djnn

## 0.1.0.0 -- 2026-05-17

### Added

- Project skeleton: library + executable, GHC2021, `-Wall` via a shared
  `common` stanza.
- Tier-1 canonical schema surfaces as independent leaves:
  `Djnn.Schema.MCP`, `Djnn.Schema.Hook`, `Djnn.Schema.Approval`.
- `Djnn.Canonical` aggregator and the `Canonical` composition type.
- `Djnn.Schema.Policy`: documented, deliberately unmodeled record of
  the deferred Tier-2 tool/command execution-policy surface.
- `djnn` executable skeleton with the `init` / `generate` / `check`
  subcommand surface (not yet implemented).
