# `djnn` — Engineering Roadmap

This is a spec-driven engineering plan. Each phase has a goal, concrete tasks,
and acceptance criteria. Tasks and criteria are tracked with checkboxes: mark
`[x]` only when the work is implemented **and** its acceptance criteria are
satisfied. A phase is "done" when every box under it is checked.

This document is scoped to engineering work.

## Status legend

- `[ ]` not started / in progress
- `[x]` implemented and acceptance criteria satisfied
- Effort sizing: **S** (hours), **M** (a few days), **L** (a week or more)

## Current state

- `djnn` has a Haskell package skeleton with a library and executable.
- The executable exposes placeholder command names: `init`, `generate`, and
  `check`.
- The library contains schema leaves for MCP, hooks, approval, and a deferred
  policy surface.
- `Djnn.Canonical` aggregates the current schema leaves into one canonical
  project-level configuration type.
- `Djnn.Codec` validates canonical values with a base-only accumulating
  applicative validation type.
- The project has tests for codec validation behavior.
- No authored config decoder exists yet.
- No runtime generator exists yet.
- No command performs real filesystem work yet.

## Version support policy

`djnn` targets GHC **9.6.7** and more recent GHC releases supported by HLS.

The package description uses Cabal spec **3.8** for compatibility with the HLS
version used during development.

Dependency policy for the core library:

- schema and canonical modules should stay dependency-light;
- `Djnn.Codec` should stay base-only while it remains pure validation;
- parser dependencies belong in format-specific decoder modules;
- runtime generator dependencies should be introduced only when an adapter needs
  them.

## Phase ordering rationale

The order is dependency-aware:

1. **Canonical schema baseline.** The project needs a small typed model before it
   can decode or generate anything.
2. **Validation codec.** The intentionally unencoded invariants must be checked
   in one pure layer before runtime adapters depend on the model.
3. **Authored decoder.** Once the canonical model and validation are stable,
   choose the first human-authored config format and isolate the parser
   dependency.
4. **Runtime generators.** Adapters should consume validated `Canonical` values,
   not raw authored files.
5. **CLI implementation.** The command-line interface should become real once
   decode, validate, and generate paths exist as library functions.
6. **Conformance fixtures.** Generated runtime files need golden fixtures and a
   compatibility matrix before broadening the supported surface.

---

## Phase 1 — Canonical schema baseline

**Goal.** Define the smallest coherent canonical algebra for Tier-1 coding-agent
surfaces.
**Effort.** S–M

### Baseline

- [x] Create the package skeleton.
- [x] Add the executable skeleton.
- [x] Add `Djnn.Schema.MCP`.
- [x] Add `Djnn.Schema.Hook`.
- [x] Add `Djnn.Schema.Approval`.
- [x] Add `Djnn.Schema.Policy` as a documented deferred surface.
- [x] Add `Djnn.Canonical`.

### Design decisions locked

- [x] Treat MCP, hooks, and approval as Tier-1 surfaces.
- [x] Treat fine-grained execution policy as Tier-2 and defer it.
- [x] Keep schema leaves independent from each other.
- [x] Keep schema leaves free from parser and generator dependencies.
- [x] Represent MCP environment variables as an association list so duplicate
      keys can be detected during validation.
- [x] Leave the MCP transport/command-url invariant unencoded for easier
      authored-config round-tripping.

### Acceptance criteria

- [x] The library builds with the schema modules exposed.
- [x] `Djnn.Canonical` can aggregate MCP servers, hooks, and approval defaults.
- [x] Tier-2 policy is documented as deferred rather than half-modeled.

---

## Phase 2 — Validation codec

**Goal.** Validate the invariants deliberately left unencoded in the canonical
schema, without introducing a parser dependency.
**Effort.** S

### Baseline

- [x] Add `Djnn.Codec`.
- [x] Add `CodecError`.
- [x] Add base-only accumulating `Validation`.
- [x] Add `validateMCPServer`.
- [x] Add `validateCanonical`.
- [x] Add boundary function `validate`.
- [x] Add tests for validation behavior.

### Design decisions locked

- [x] `Djnn.Codec` is validation-only, not a YAML/TOML/JSON decoder.
- [x] Decoding and validation are separate layers.
- [x] Validation accumulates errors applicatively.
- [x] `Validation` intentionally has no `Monad` instance.
- [x] `CodecError` is the unified vocabulary of invalid configuration, including
      errors produced later by decoder modules.
- [x] Hooks need no post-construction validation because the current type already
      makes illegal hook events unrepresentable.
- [x] MCP servers need validation because some invariants were intentionally left
      unencoded.

### Acceptance criteria

- [x] `cabal test` passes.
- [x] Missing `Stdio` commands are rejected.
- [x] Missing remote URLs are rejected.
- [x] Duplicate MCP environment keys are reported.
- [x] Duplicate MCP server names are reported.
- [x] Independent validation errors accumulate in one result.

---

## Phase 3 — Authored config decoder

**Goal.** Choose and implement the first authored configuration format while
keeping parser dependencies isolated from the core schema and validation modules.
**Effort.** M

### Design decisions to lock first

- [ ] Choose the first authored config format:
  - YAML: ergonomic for hand-authored configuration;
  - TOML: close to Codex-style configuration and good for simple tables;
  - JSON: dependency-familiar, but less pleasant for hand-authored files.
- [ ] Decide the source file name, such as `djnn.yaml`, `djnn.toml`, or
      `djnn.json`.
- [ ] Decide whether the first decoder reads only one file or also discovers
      adjacent Markdown assets such as skills/instructions.
- [ ] Decide whether decode-time errors should be represented directly as
      `CodecError` or wrapped in a richer decoder error type with source spans.

### Tasks

- [ ] Add a format-specific decoder module, e.g. `Djnn.Codec.Yaml` or
      `Djnn.Codec.Toml`.
- [ ] Add the chosen parser dependency to the package.
- [ ] Decode authored MCP server entries into `MCPServer` values.
- [ ] Decode authored hook entries into `Hook` values.
- [ ] Decode approval defaults into `ApprovalMode`.
- [ ] Resolve hook event strings into `HookEvent` constructors.
- [ ] Produce `UnknownHookEvent` for unsupported hook event names.
- [ ] Pipe decoded values through `validate` before exposing a final result.
- [ ] Add fixtures for valid and invalid authored config files.

### Acceptance criteria

- [ ] A valid authored config decodes and validates into `Canonical`.
- [ ] Invalid hook event names are rejected with `UnknownHookEvent`.
- [ ] Invalid MCP transport/field combinations are rejected by validation.
- [ ] Duplicate server names are rejected by validation.
- [ ] Parser dependencies do not leak into `Djnn.Schema.*`, `Djnn.Canonical`, or
      `Djnn.Codec`.
- [ ] `cabal test` covers successful decode and representative failures.

---

## Phase 4 — Runtime generators

**Goal.** Generate runtime-specific configuration files from validated canonical
configuration.
**Effort.** L

### Design decisions to lock first

- [ ] Choose the first target runtime adapter.
- [ ] Decide the adapter module layout, e.g. `Djnn.Generate.Claude`,
      `Djnn.Generate.Codex`, `Djnn.Generate.Gemini`.
- [ ] Decide whether generators return an in-memory file tree or write directly
      to disk. Recommended: return an in-memory file tree; the CLI performs
      writes.
- [ ] Decide overwrite behavior and conflict handling.
- [ ] Decide how generated-file ownership is marked, if at all.

### Tasks

- [ ] Define a generated-file representation, such as path plus textual content.
- [ ] Implement one runtime adapter for the smallest useful surface.
- [ ] Generate MCP configuration for the selected runtime.
- [ ] Generate hook configuration for the selected runtime, if supported.
- [ ] Generate approval/default configuration for the selected runtime, if
      supported.
- [ ] Document unsupported fields and lossy mappings.
- [ ] Add golden tests for generated files.

### Acceptance criteria

- [ ] Given a validated `Canonical`, the first adapter produces deterministic
      generated files.
- [ ] Unsupported runtime features are omitted deliberately and documented.
- [ ] Golden tests cover the first adapter.
- [ ] Generator modules do not parse authored config directly.
- [ ] Generator modules consume validated canonical values or a clearly named
      wrapper type representing validated configuration.

---

## Phase 5 — CLI implementation

**Goal.** Turn the executable skeleton into a real CLI around decode, validate,
and generate operations.
**Effort.** M

### Design decisions to lock first

- [ ] Choose CLI option parsing approach.
- [ ] Decide command names and flags for the first usable version.
- [ ] Decide whether `djnn generate` writes by default or requires an explicit
      `--write` flag after previewing.
- [ ] Decide exit-code behavior for validation and generation errors.

### Tasks

- [ ] Implement `djnn check` to read authored config, decode it, validate it, and
      report errors without writing generated files.
- [ ] Implement `djnn generate` to read authored config, validate it, and produce
      runtime files.
- [ ] Implement `djnn init` to create a starter authored config.
- [ ] Add useful error rendering for `CodecError`.
- [ ] Add a dry-run or preview mode for generated files.
- [ ] Add command-line help text.

### Acceptance criteria

- [ ] `djnn check` succeeds on a valid authored config.
- [ ] `djnn check` reports all accumulated validation errors on an invalid config.
- [ ] `djnn generate` produces the expected runtime files for the first adapter.
- [ ] `djnn init` creates a minimal valid starter config.
- [ ] Exit codes are documented and tested.

---

## Phase 6 — Conformance fixtures and compatibility matrix

**Goal.** Make runtime support auditable with fixtures, golden outputs, and a
compatibility matrix.
**Effort.** M–L

### Design decisions to lock first

- [ ] Decide which runtimes are Tier-1 targets for generated output.
- [ ] Decide the compatibility-matrix dimensions:
  - MCP;
  - hooks;
  - approval;
  - instructions;
  - skills;
  - subagents;
  - commands;
  - workflows;
  - ignore files;
  - settings.
- [ ] Decide where fixtures live.

### Tasks

- [ ] Add authored-config fixtures for common configurations.
- [ ] Add golden generated-output fixtures per runtime adapter.
- [ ] Add negative fixtures for invalid configs.
- [ ] Add a compatibility matrix under `docs/`.
- [ ] Document lossy or unsupported mappings per runtime.
- [ ] Add tests ensuring generated output remains stable.

### Acceptance criteria

- [ ] Every supported runtime adapter has golden fixtures.
- [ ] The compatibility matrix identifies supported, unsupported, and deferred
      surfaces.
- [ ] Invalid fixture cases exercise representative `CodecError` constructors.
- [ ] `cabal test` validates decoder, codec, and generator behavior.

---

## Phase 7 — Broader surfaces

**Goal.** Expand beyond Tier-1 surfaces without collapsing incompatible runtime
features into an incoherent universal schema.
**Effort.** L

### Candidate surfaces

- [ ] Main context files, such as `AGENTS.md`, `CLAUDE.md`, or `GEMINI.md`.
- [ ] Rules, policies, and instructions directories.
- [ ] Skills.
- [ ] Subagents/custom agents.
- [ ] Custom commands/prompts.
- [ ] Workflows/recipes.
- [ ] Ignore files.
- [ ] Runtime settings.
- [ ] Fine-grained execution policy.

### Design constraints

- [ ] Each new surface must identify which runtimes truly support it.
- [ ] Each new surface must define whether it is portable, runtime-specific, or a
      tagged union of runtime-specific variants.
- [ ] Each new surface must include validation rules before generation rules.
- [ ] Each new surface must have fixtures before being marked supported.

### Acceptance criteria

- [ ] No new surface is added without documented runtime support.
- [ ] Runtime-specific escape hatches are explicit, not hidden in generic fields.
- [ ] Tests cover both portable and runtime-specific behavior.
