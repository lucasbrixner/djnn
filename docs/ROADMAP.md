# `djnn` — Engineering Roadmap

This is a spec-driven engineering plan. Each phase has a goal, concrete tasks,
and acceptance criteria. Tasks and criteria are tracked with checkboxes: mark
`[x]` only when the work is implemented **and** its acceptance criteria are
satisfied. A phase is "done" when every box under it is checked.

This document is scoped to engineering work. Architectural rationale and design
pressure belong in [`ARCHITECTURE.md`](ARCHITECTURE.md); this roadmap records
the implementation order implied by the current direction.

## Status legend

- `[ ]` not started / in progress
- `[x]` implemented and acceptance criteria satisfied
- Effort sizing: **S** (hours), **M** (a few days), **L** (a week or more)

## Architecture direction — 2026-05-18

The v0 plan modelled the portable intersection directly as the only project
schema and deferred the rest. That remains a useful implementation starting
point, but the current architectural direction is to make per-agent surfaces
more explicit before committing too much behavior to the unified model.

The working shape is:

- per-agent surface models, likely under `Djnn.Surface.<Concern>.<Agent>`;
- per-concern unified models, likely under `Djnn.Surface.<Concern>`;
- no global `Djnn.Surface` aggregator for now;
- a separate cross-concern aggregate, with its long-term name deferred;
- an explicit mapping layer between unified views and agent-specific surfaces.

This direction is intended to keep compatibility claims auditable: model what
each agent accepts, derive the portable subset from those models, keep lossy
mappings visible, and avoid universal abstractions where the agents do not
actually converge.

The phases below follow the current sequencing preference:

1. retain the v0 prototype baseline;
2. retain and extend validation;
3. map per-agent surfaces;
4. unify per concern;
5. introduce cross-concern aggregation and mapping;
6. decode authored configuration into the unified view;
7. implement the CLI;
8. add conformance fixtures and a computed compatibility matrix;
9. broaden supported surfaces.

Phases 1–2 remain done for the v0 prototype and validation baseline. Their
modules are retained during migration and superseded only when the newer module
shape fully covers their role.

## Current state

- Haskell package skeleton with library and executable.
- v0 prototype:
  - `Djnn.Schema.MCP`;
  - `Djnn.Schema.Hook`;
  - `Djnn.Schema.Approval`;
  - `Djnn.Schema.Policy`;
  - `Djnn.Canonical`;
  - `Djnn.Codec`.
- Placeholder executable commands:
  - `djnn init`;
  - `djnn generate`;
  - `djnn check`.
- No per-agent `Surface.*` modules yet.
- No authored config decoder yet.
- No generator yet.
- No command performs real filesystem work yet.

## Prior work

These items are independent of the architecture migration and should be handled
before or alongside the early phases.

- [x] `fix/hook-event-intersection` — Add the missing `UserPromptSubmit` hook
      event, update the `HookEvent` rationale to distinguish documented emission
      from schema presence, add regression tests, and update `CHANGELOG.md`.

## Version support policy

`djnn` targets GHC **9.6.7** and more recent GHC releases supported by HLS.

The package description uses Cabal spec **3.8** for compatibility with the HLS
version used during development.

Dependency policy:

- `Surface.*` modules should stay dependency-light, preferably base-only, with
  derived instances where sufficient.
- `Djnn.Codec` should stay base-only while it remains pure validation.
- Parser dependencies belong only in format-specific decoder modules.
- Mapping, aggregation, and generator dependencies should be introduced only
  when those layers need them.

## Phase ordering rationale

The order is dependency-aware:

1. **v0 prototype baseline.** The project needs a small typed baseline before it
   can decode or generate anything.
2. **Validation codec.** Invariants deliberately left unencoded should be
   checked in one pure layer before downstream consumers depend on the model.
3. **Per-agent surface mapping.** Cross-agent compatibility claims are easier to
   audit when the relevant agent surfaces are represented explicitly.
4. **Per-concern unification.** A unified view should be designed with evidence
   from the relevant per-agent surfaces.
5. **Cross-concern aggregation and mapping.** Once the first unified concerns
   exist, introduce the aggregate project-level view and mapping functions.
6. **Authored config decoder.** The decoder should target the unified view, not
   an agent-specific format.
7. **CLI implementation.** The CLI becomes useful once decode, validate, and
   generate paths exist as library functions.
8. **Conformance fixtures and compatibility matrix.** Generated files and
   compatibility claims need fixtures and a regenerable audit surface.
9. **Broader surfaces.** Additional concerns should be added only after their
   agent support and convergence properties are understood.

---

## Phase 1 — v0 prototype baseline

**Goal.** Keep the smallest coherent intersection-oriented model building while
the project evolves toward explicit per-agent surfaces.

**Effort.** S–M

### Baseline

- [x] Package + executable skeleton.
- [x] `Djnn.Schema.MCP`.
- [x] `Djnn.Schema.Hook`.
- [x] `Djnn.Schema.Approval`.
- [x] `Djnn.Schema.Policy` as a documented deferred surface.
- [x] `Djnn.Canonical` aggregator.

### Acceptance criteria

- [x] Library builds with the v0 modules exposed.
- [x] `Djnn.Canonical` aggregates MCP, hooks, and approval.
- [x] Fine-grained policy is documented as deferred rather than half-modelled.

### Migration note

The v0 modules remain valid during migration. They should be removed only when
newer modules fully cover their role and nothing depends on them.

---

## Phase 2 — Validation codec

**Goal.** Validate the invariants deliberately left unencoded, without
introducing parser dependencies.

**Effort.** S

### Baseline

- [x] `Djnn.Codec`.
- [x] `CodecError`.
- [x] Accumulating `Validation`.
- [x] Validators and tests.

### Acceptance criteria

- [x] `cabal test` passes.
- [x] Missing `Stdio` commands are rejected.
- [x] Missing remote URLs are rejected.
- [x] Duplicate MCP environment keys are reported.
- [x] Duplicate MCP server names are reported.
- [x] Independent validation errors accumulate in one result.

### Follow-on

As per-agent surfaces land, validation and test coverage should begin checking
compatibility claims mechanically rather than relying only on prose.

- [ ] For each concern with complete per-agent surface models, add a test or
      validation assertion that the declared portable subset matches, or is a
      subset of, the support computed from those surfaces. **S**

---

## Phase 3 — Per-agent surface mapping

**Goal.** Model needed per-agent surfaces faithfully enough to support
compatibility reasoning and later generation.

**Effort.** L, sub-phased per concern.

### Design decisions to lock first

- [ ] Type-naming convention inside surface modules:
      concern-local names used with qualified imports vs. distinct names such as
      `ClaudeHook`, `CodexHook`, etc.
- [ ] Whether early `Surface.*` modules are exposed modules or internal modules.
- [ ] Initial concern and agent coverage order.
      Recommendation: start with `Hook` for `{Claude, Codex}`, then revisit
      `MCP` and `Approval`.

### Tasks

- [ ] Add initial hook surface modules, likely:
      `Djnn.Surface.Hook.Claude` and `Djnn.Surface.Hook.Codex`.
- [ ] Model hook events and related hook structure from authoritative sources.
- [ ] Add MCP surface modules for the first supported agents.
- [ ] Capture known MCP refinements not present in the v0 model, such as fields
      like `headers`, `cwd`, or `disabled`, where supported by the relevant
      agent.
- [ ] Add approval surface modules for the first supported agents.
- [ ] Record cases that appear unrepresentable in persistent settings rather
      than forcing them into a false common model.
- [ ] Add reference fixtures per `(concern, agent)` where practical.
- [ ] Add tests that lock each surface model against its reference fixture or
      documented source assumptions.

### Acceptance criteria

- [ ] `Surface.<Concern>.<Agent>` modules are leaf-like: no imports from other
      `Djnn.*` modelling modules unless explicitly justified.
- [ ] Each modelled surface is tied to an authoritative source or a documented
      source assumption.
- [ ] Deviations from an agent source are documented in-module.
- [ ] No `(concern, agent)` pair is modelled without a verified need.
- [ ] The Phase 2 follow-on assertion is live for every concern whose per-agent
      surfaces are complete enough to support it.

---

## Phase 4 — Per-concern unification

**Goal.** For each concern with enough per-agent evidence, design the unified
parent model and determine how much genuine convergence exists.

**Effort.** L.

### Design decisions to lock first

- [ ] How portable and full-union views should coexist:
      separate types, one type with a portability marker, explicit extension
      constructors, or another shape.
- [ ] How convergence status is recorded:
      in module docs, type shape, import graph, tests, or some combination.
- [ ] How v0 `Djnn.Schema.<Concern>` modules migrate into the new structure.

### Tasks

- [ ] Add `Djnn.Surface.<Concern>` parent modules as concerns become ready.
- [ ] For convergent concerns, model a unified type that carries real
      abstraction value.
- [ ] For weakly convergent or non-convergent concerns, use explicit
      agent-specific variants rather than flattening incompatible forms.
- [ ] Fold retained v0 `Schema.<Concern>` content into the corresponding
      unified concern when the new model fully covers it.
- [ ] Retire v0 modules only when nothing depends on them.

### Acceptance criteria

- [ ] Each unified concern clearly identifies its portable subset.
- [ ] Each unified concern has a documented strategy for agent-specific
      capabilities.
- [ ] Convergence status is visible from module documentation, type shape, or
      tests.
- [ ] No v0 module is removed while still depended on.
- [ ] `main` remains buildable throughout the migration.

---

## Phase 5 — Cross-concern aggregator and mapping layer

**Goal.** Introduce the project-level aggregate view and the first explicit
mapping functions between unified concerns and agent-specific surfaces.

**Effort.** L.

### Design decisions to lock first

- [ ] Cross-concern aggregate name and module.
      It should be role-named and should not default to `Surface` or `Schema`
      unless that name precisely describes the role.
- [ ] Mapping layer shape:
      one bidirectional module per `(concern, agent)` vs. separate ingest/emit
      modules.
- [ ] Mapping function names:
      `toUnified` / `fromUnified`, `ingest` / `emit`, `lift` / `lower`, or
      another convention.
- [ ] Generated-file representation:
      path + content, metadata, ownership marker, and conflict behavior.
- [ ] Whether ingest is required in the first implementation or can initially be
      limited to test/audit support.

### Tasks

- [ ] Add the cross-concern aggregate over the first unified concerns.
- [ ] Add the first emit mapping from unified concern data to an agent-specific
      surface.
- [ ] Add generated-file representation.
- [ ] Add text rendering for the first generated agent file.
- [ ] Document lossy or partial mappings in the mapping layer.
- [ ] Add tests for mapping behavior.

### Acceptance criteria

- [ ] Generation goes through a typed agent-specific surface or an equivalently
      explicit intermediate representation.
- [ ] Lossy mappings are documented in the mapping layer.
- [ ] The aggregate module has a role-specific name.
- [ ] Generator modules do not parse authored config directly.
- [ ] Mapping tests cover at least one supported concern and agent.

---

## Phase 6 — Authored config decoder

**Goal.** Implement the first authored configuration format, decoding into the
unified aggregate while keeping parser dependencies isolated.

**Effort.** M.

### Design decisions to lock first

- [ ] Choose the first authored config format:
      YAML, TOML, or JSON.
      Current recommendation: YAML for hand-authored ergonomics.
- [ ] Choose the source filename.
- [ ] Decide whether the first decoder reads one file only or also discovers
      adjacent assets.
- [ ] Decide decode-error representation:
      structural errors with spans vs. direct `CodecError` values vs. a wrapper
      type.
- [ ] Decide where aliases and default normalization happen.

### Tasks

- [ ] Add a format-specific decoder module.
- [ ] Add the parser dependency only to the decoder layer.
- [ ] Decode authored MCP configuration into the unified view.
- [ ] Decode authored hook configuration into the unified view.
- [ ] Decode approval defaults into the unified view.
- [ ] Resolve hook event strings, including `UserPromptSubmit`.
- [ ] Produce a clear error for unsupported hook event names.
- [ ] Pipe decoded values through validation.
- [ ] Add valid and invalid authored-config fixtures.

### Acceptance criteria

- [ ] A valid authored config decodes and validates into the unified aggregate.
- [ ] Invalid hook events are rejected.
- [ ] Invalid MCP combinations are rejected.
- [ ] Duplicate names are rejected.
- [ ] Parser dependencies do not leak into `Surface.*` or `Djnn.Codec`.
- [ ] `cabal test` covers successful decode and representative failures.

---

## Phase 7 — CLI implementation

**Goal.** Turn the executable skeleton into a real CLI around decode, validate,
and generate operations.

**Effort.** M.

### Design decisions to lock first

- [ ] CLI option parsing approach.
- [ ] Command names and flags for the first usable version.
- [ ] Whether `generate` writes by default or requires an explicit `--write`.
- [ ] Exit-code behavior for validation and generation errors.
- [ ] Error rendering format.

### Tasks

- [ ] Implement `djnn check`.
- [ ] Implement `djnn generate`.
- [ ] Implement `djnn init`.
- [ ] Add useful rendering for validation and decode errors.
- [ ] Add dry-run or preview behavior for generated files.
- [ ] Add command-line help text.

### Acceptance criteria

- [ ] `djnn check` succeeds on valid authored config.
- [ ] `djnn check` reports accumulated validation errors on invalid config.
- [ ] `djnn generate` produces expected files for the first supported adapter.
- [ ] `djnn init` creates a minimal valid starter config.
- [ ] Exit codes are documented and tested.

---

## Phase 8 — Conformance fixtures and compatibility matrix

**Goal.** Make support claims auditable with fixtures, golden outputs, and a
compatibility matrix derived from implementation data where practical.

**Effort.** M.

### Design decisions to lock first

- [ ] Decide which agents are Tier-1 generation targets.
- [ ] Decide the compatibility-matrix dimensions.
- [ ] Decide whether the matrix is fully generated, partially generated, or
      generated with documented manual annotations.
- [ ] Decide where fixtures live.

### Tasks

- [ ] Add authored-config fixtures for common configurations.
- [ ] Add golden generated-output fixtures per supported adapter.
- [ ] Add negative fixtures for representative validation errors.
- [ ] Add a compatibility matrix under `docs/`.
- [ ] Derive matrix entries from `Surface.*` types where practical.
- [ ] Document lossy mappings using information from the mapping layer.
- [ ] Add tests ensuring generated output remains stable.

### Acceptance criteria

- [ ] Every supported adapter has golden fixtures.
- [ ] The compatibility matrix identifies supported, unsupported, partial, and
      deferred surfaces.
- [ ] Generated or computed parts of the matrix can be regenerated reliably.
- [ ] Invalid fixture cases exercise representative `CodecError` constructors.
- [ ] `cabal test` validates decoder, codec, mapping, and generator behavior.

---

## Phase 9 — Broader surfaces

**Goal.** Expand beyond the first concerns without collapsing incompatible
agent-specific features into an incoherent universal model.

**Effort.** L.

### Candidate concerns

- [ ] Main context files, such as `AGENTS.md`, `CLAUDE.md`, or `GEMINI.md`.
- [ ] Rules and instructions.
- [ ] Skills.
- [ ] Subagents or custom agents.
- [ ] Custom commands or prompts.
- [ ] Workflows or recipes.
- [ ] Ignore files.
- [ ] Agent settings.
- [ ] Plugin or extension manifests.
- [ ] Fine-grained execution policy.

### Design constraints

- [ ] Each new concern identifies which agents support it.
- [ ] Each new concern is checked against authoritative schemas or
      documentation before being modelled.
- [ ] Each new concern declares whether it appears convergent, weakly
      convergent, or agent-specific.
- [ ] Validation rules are designed before generation behavior is marked
      supported.
- [ ] Fixtures exist before a concern/agent pair is considered supported.

### Acceptance criteria

- [ ] No concern is added without documented agent support.
- [ ] Convergence status is recorded for each concern.
- [ ] Agent-specific escape hatches are explicit, not hidden in generic fields.
- [ ] Tests cover both portable and agent-specific behavior where applicable.
