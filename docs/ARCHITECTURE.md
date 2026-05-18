# `djnn` — Architecture Notes

This document records the current architectural direction for `djnn`: the
layering, vocabulary, working invariants, and design questions that are being
deferred deliberately.

It is a companion to [`docs/ROADMAP.md`](docs/ROADMAP.md). The roadmap tracks
what is planned and when; this document explains the design pressures behind
that plan.

`djnn` is still an early prototype. These notes should therefore be read as a
working architecture, not as a permanent constitution. Some names, boundaries,
and sequencing decisions may change as the project maps more agent surfaces and
learns where the real convergence points are.

The main constraint is the one already stated in the README: `djnn` should model
shared coding-agent surfaces explicitly without pretending that every
agent-specific feature can be flattened into one universal schema. The project
starts with genuinely portable surfaces and records non-goals rather than hiding
incompatibilities behind vague abstractions.

## Vocabulary

The project needs stable-enough words to discuss the configuration matrix, but
the vocabulary is still allowed to evolve as the implementation matures.

### Surface

A **surface** is the configuration contact area for one concern, as exposed by
one agent or as unified by `djnn`.

Examples:

- Claude Code's hook surface;
- Codex's MCP surface;
- the unified hook surface;
- the unified MCP surface.

This term is already used in the project and is a better fit than several
alternatives:

- **Feature** is too vague and collides with the ordinary product-capability
  sense.
- **Interface** is overloaded in Haskell and tooling contexts: module
  interfaces, typeclasses, `.hi` files, and other schema-level uses.
- **Schema** should be avoided for `djnn`'s own modelling layers because the
  repository also carries agents' published JSON Schemas as reference material.

### Concern

A **concern** is one axis of the configuration matrix.

Examples:

- hooks;
- MCP servers;
- approval defaults;
- execution policy;
- instructions;
- skills;
- subagents;
- ignore files;
- settings;
- plugin or extension manifests.

Each agent may expose a surface for a concern. Some concerns are likely to
converge across agents; others may remain mostly agent-specific.

### Agent

An **agent** is a CLI coding agent, such as Claude Code, Codex CLI, Gemini CLI,
Cursor Agent CLI, Copilot CLI, Kiro CLI, or a similar tool.

The term **runtime** is avoided because it suggests an execution abstraction that
`djnn` does not provide. `djnn` centralizes and generates configuration; it does
not run the agents.

There is a small naming tension between **agent** and the later **subagent**
concern. If that starts to cause ambiguity in code or documentation, `target` or
`backend` remain possible alternatives for the second axis of the matrix.

### Schema

Within `djnn`, **schema** should usually refer to an agent's published JSON
Schema or equivalent authoritative reference.

That means `Schema` is not a good long-term namespace for `djnn`'s own canonical
or unified model. The current `Djnn.Schema.*` modules are part of the v0
prototype shape and can remain while they are useful, but future architecture
should avoid making `Schema` the name of the project-owned modelling layer.

## Working thesis

Cross-agent compatibility cannot be asserted only in prose. It has to be derived
from the agents' actual surfaces.

The hook-event correction is the motivating example: a hand-maintained claim
about the portable hook-event set was wrong, and the error became visible only by
comparing the agents' published surfaces against one another.

The working direction is therefore:

> Model each agent's surface for each concern faithfully. Derive a unified view
> of each concern from those per-agent surfaces. Then map the unified view back
> to agent-specific surfaces when generating files.

This gives `djnn` two useful directions:

1. **Per-agent surface → unified view**

   Used to reason about portability, validate assumptions, and potentially
   import existing agent-specific configuration later.

2. **Unified view → per-agent surface**

   Used to generate the files each agent expects.

The early implementation may still begin with intersection-shaped models because
that is the safest MVP. But the architecture should not make
intersection-first modelling impossible to widen later. The goal is to support
both:

- the portable intersection of a concern; and
- the broader union of agent-specific capabilities where that is useful.

## Current sequencing

The current roadmap assumes this order of work:

1. Map the relevant per-agent surfaces for a concern.
2. Use those mappings to design the concern's unified view.
3. Define the mapping functions between per-agent surfaces and the unified view.
4. Build the authored decoder, generators, and CLI behavior on top of that
   unified view.

The reason is dependency direction. The authored configuration format should
target the unified view, so that view needs to exist before the decoder is
designed. Likewise, generators should emit from a known unified model into
agent-specific files, rather than embedding ad hoc compatibility reasoning
directly in the generator layer.

This sequencing is a planning constraint, not a claim that every module boundary
is already known.

## Proposed module layering

The likely end-state has three broad areas:

1. per-agent surface models;
2. per-concern unified models;
3. mapping and generation layers.

The names below are current working names.

## `Djnn.Surface.<Concern>.<Agent>`

A module of this form models one agent's surface for one concern.

Examples:

```haskell
Djnn.Surface.Hook.Claude
Djnn.Surface.Hook.Codex
Djnn.Surface.MCP.Claude
Djnn.Surface.MCP.Codex
```

These modules should be as faithful as practical to the agent's authoritative
source:

- official published JSON Schemas where they exist;
- official documentation where no schema exists;
- generated reference material only when it is known to be reliable for the
  specific surface being modelled.

The intended character of these modules:

- pure data;
- base-only where practical;
- derived instances where sufficient;
- no semantic elaboration;
- no imports from other `Djnn.*` modelling modules unless a concrete need later
  justifies revisiting this rule.

They should be leaf-like modules. Their job is to say, "this is what this agent
accepts for this concern," not to decide how that surface maps to `djnn`'s
unified model.

Per-agent modules should be added only when the project has both:

1. an authoritative source for that `(concern, agent)` pair; and
2. an actual need to model it.

Avoid speculative scaffolding of every agent for every concern. The project is
intentionally conservative and should not create empty abstractions ahead of
evidence.

## `Djnn.Surface.<Concern>`

A module of this form is the unified view for one concern.

Examples:

```haskell
Djnn.Surface.Hook
Djnn.Surface.MCP
Djnn.Surface.Approval
```

This parent module is where `djnn` can model:

- the portable subset of the concern;
- the broader union, if the concern has useful agent-specific capabilities;
- the types and helpers that consumers should normally use.

This parent-over-children shape is different from the v0 `Djnn.Schema.*` layout.
It is acceptable here because the parent module is not a generic bucket. For
example, `Djnn.Surface.Hook` really is the unified hook surface, while
`Djnn.Surface.Hook.Codex` is the Codex-specific hook surface.

The import ergonomics are also useful:

```haskell
import Djnn.Surface.Hook
```

for the unified concern, and:

```haskell
import Djnn.Surface.Hook.Codex
```

for the exact Codex surface.

Path length tracks specificity.

This is a proposed direction, not a requirement that every concern must converge
into a neat abstraction. Some concerns may remain mostly tagged unions over
agent-specific forms.

## Avoiding a global `Djnn.Surface` parent

The current design avoids a global module named:

```haskell
Djnn.Surface
```

as an aggregator for all concerns.

The reason is role clarity. `Surface` names a layer, not the whole project
configuration. A global module that combines hooks, MCP servers, approval
defaults, instructions, skills, subagents, and other concerns would be doing a
different job: cross-concern aggregation.

That role should have its own name once the project knows what shape it needs.

The current v0 module `Djnn.Canonical` plays that kind of aggregating role for
the early canonical model. Whether the long-term name remains `Canonical` or
moves to something else is intentionally deferred.

## Mapping layer

The mapping layer is where semantic judgment lives.

It handles conversions such as:

```text
per-agent surface -> unified view
unified view      -> per-agent surface
```

This layer is deliberately separate from `Surface.*` because mapping is not just
data modelling. It may involve lossy or partial translation.

Examples of mapping questions:

- Can a Codex approval value be represented exactly in the unified model?
- Can a Gemini execution-policy setting be generated from the unified model?
- Does a Claude-specific hook capability have a portable equivalent?
- Should an unsupported target capability fail validation, emit a warning, or be
  ignored explicitly?

Those decisions should not be hidden inside the surface data types.

The exact shape of the mapping layer is still open. Possible designs include:

```haskell
Djnn.Mapping.Hook.Claude
Djnn.Mapping.Hook.Codex
```

or separate directions such as:

```haskell
Djnn.Ingest.Hook.Claude
Djnn.Emit.Hook.Claude
```

or verbs such as `toUnified` / `fromUnified`, `ingest` / `emit`, or
`lift` / `lower`.

The only current preference is that generators should not skip the typed
agent-specific surface. Conceptually, generation should look more like:

```text
Unified -> Surface.<Concern>.<Agent> -> Text
```

than:

```text
Unified -> Text
```

The intermediate agent-specific surface gives the project a place to validate
that generation is producing something the target agent actually understands.

## `Djnn.Codec`

`Djnn.Codec` remains the validation-oriented layer.

Its role is to provide base-only accumulating validation and to check invariants
that are deliberately not encoded directly in the types.

As per-agent surfaces are modelled, `Djnn.Codec` can become more useful. Instead
of relying on docstring claims such as "this canonical event set is portable,"
tests can check that the unified subset is actually supported by the relevant
per-agent surfaces.

The class of bug that omitted `UserPromptSubmit` should become mechanically
easier to catch as more surfaces are represented as typed data.

## Convergence by concern

Whether a concern deserves a strong unified abstraction should be decided per
concern.

Some concerns are likely to be genuinely convergent. For those, the unified type
can carry real abstraction value.

Examples may include:

- MCP servers, where several agents share a broadly similar server shape;
- lifecycle hooks, where event/matcher/command-handler structure may overlap
  across agents.

Other concerns may be non-convergent. For those, forcing a single elegant type
would create a false abstraction.

Examples may include:

- execution policy, where one agent may use rule tables, another may use
  allowlists, and another may expose a different trust model;
- plugin or extension manifests, where manifest structure may differ more than
  the surface names suggest.

For non-convergent concerns, a unified parent may simply be an explicit tagged
union over the agent-specific forms. That is acceptable. A tagged union is better
than pretending incompatible surfaces are the same.

The import graph can help make this visible:

- If `Djnn.Surface.<Concern>` does not need to import agent children, the concern
  may have a genuinely convergent unified model.
- If `Djnn.Surface.<Concern>` imports its agent children and wraps them, the
  concern is probably non-convergent or only weakly convergent.

That import pattern should be treated as evidence, not as a failure.

## Working invariants

These are current design rules. They should guide implementation, but they can
be revised if later evidence shows that a different boundary is simpler or more
accurate.

- `Djnn.Surface.<Concern>.<Agent>` modules should model agent-specific surfaces
  faithfully and avoid project-internal semantic imports.
- `Djnn.Surface.<Concern>` modules should model the unified view for one concern.
- A concern's unified module may import its agent-specific children when the
  concern is non-convergent or when a tagged union is the honest model.
- Agent-specific child modules should not import the unified parent or each
  other.
- Semantic mapping should live outside `Surface.*`.
- The project should avoid a global `Djnn.Surface` aggregator unless a later
  design gives that module a precise role.
- Per-agent modules should be added only for verified, needed
  `(concern, agent)` pairs.
- Official published schemas and authoritative documentation should take
  precedence over generated or inferred references.

## Migration from the v0 shape

The current v0 modules remain valid while the project migrates:

```haskell
Djnn.Schema.MCP
Djnn.Schema.Hook
Djnn.Schema.Approval
Djnn.Schema.Policy
Djnn.Canonical
Djnn.Codec
```

They should be kept building throughout the transition. The migration should not
break `main`.

A reasonable migration path is:

1. Keep the v0 modules as the intersection-oriented seed.
2. Introduce `Surface.<Concern>.<Agent>` modules as authoritative per-agent
   surfaces are mapped.
3. Introduce `Surface.<Concern>` modules when a concern has enough per-agent
   evidence to design the unified view.
4. Move or replace v0 definitions only when the new module shape fully covers
   their role.
5. Remove v0 modules only when nothing depends on them.

This avoids a large rewrite and lets each concern move when it is ready.

## Non-goals

The architecture should continue to reject these failure modes:

- Do not flatten genuinely incompatible agent capabilities into a fake universal
  schema.
- Do not create speculative per-agent modules without an authoritative source
  and a current need.
- Do not put parser dependencies into low-level surface data modules.
- Do not hide lossy compatibility decisions inside data declarations.
- Do not make generated output depend on untyped string assembly when a typed
  agent-specific surface can be used first.

## Open decisions

These should be tracked in `docs/ROADMAP.md` under the relevant phase or design
checkpoint.

### Cross-concern aggregator

The long-term name and shape of the cross-concern aggregate is still open.

Current candidates include keeping or evolving the role currently played by:

```haskell
Djnn.Canonical
```

The name should describe the role of combining concerns into one project
configuration. It should not be `Surface` unless that module's role becomes much
more precise than "everything in the surface layer."

### Mapping layer names

The mapping layer still needs names and direction conventions.

Open questions:

- one bidirectional module per `(concern, agent)`;
- separate ingest and emit modules;
- function names such as `toUnified` / `fromUnified`;
- function names such as `ingest` / `emit`;
- function names such as `lift` / `lower`.

This should be decided after at least one or two concerns have enough per-agent
surface models to expose real mapping pressure.

### Type names inside surface modules

There are two plausible styles.

Module-qualified generic names:

```haskell
Djnn.Surface.Hook.Codex.Hook
Djnn.Surface.Hook.Claude.Hook
```

Distinct names:

```haskell
CodexHook
ClaudeHook
GeminiHook
```

The first style is shorter locally and relies on qualified imports. The second
is clearer in exported APIs and error messages. This decision should be made
when the first real per-agent surface modules are introduced.

### `agent` vs `target` vs `backend`

The working term is `agent`.

If the later subagent concern makes that ambiguous, the second axis of the
matrix may need a different word, such as `target` or `backend`.

### Union representation

The project still needs to decide how to represent a concern's full union.

Possible approaches:

- one unified type with portable and agent-specific constructors;
- a portable core plus explicit extension fields;
- a tagged union over agent-specific surfaces;
- separate portable and full-union types.

The right answer may differ by concern.

## Summary

The architecture should move toward typed per-agent surfaces and typed
per-concern unified views, with mapping kept explicit and testable.

The important principle is not that every module name in this document is final.
The important principle is that `djnn` should make compatibility claims
auditable:

- model what each agent actually accepts;
- derive the portable subset from those models;
- keep lossy mappings visible;
- generate through typed agent-specific surfaces;
- avoid universal abstractions where the agents do not actually converge.
