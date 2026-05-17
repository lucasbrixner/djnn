# `djnn`

`djnn` centralizes a project's coding-agent configuration in one canonical
source and generates the files expected by multiple CLI coding-agents.

Its purpose is to let a project define coding-agent configuration once, in a
canonical source, and then generate the agent-specific files expected by tools
such as Claude Code, Codex CLI, Gemini CLI, Cursor Agent CLI, Copilot CLI, Kiro
CLI, and related coding-agents.

Instead of hand-maintaining several partially-overlapping configuration trees,
`djnn` models the shared surfaces explicitly:

- MCP servers;
- lifecycle hooks;
- coarse approval defaults;
- later: instructions, skills, subagents, custom commands, workflows, and other
  agent-specific surfaces.

The project is intentionally conservative. It does not try to flatten every
coding-agent feature into one large universal schema. It starts from the surfaces
that are genuinely portable, records non-goals explicitly, and validates only the
invariants that were deliberately left unencoded in the types.

## Name

`djnn` comes from the Semitic root ج ن ن ⟨ʤnn⟩, related to concealment, hiding,
adaptation; related to janīn (جَنِين, 'embryo'), and majnūn (مَجْنُون, 'possessed').
Genies/djinn (جِنّ, collective for genie/djinnī جِنِّيّ) are supernatural beings
composed of thin and subtle bodies; they might be invoked for means of sorcery,
incantation, protection, or divination.

A CLI coding-agent is, in a very practical sense, genie-like: autonomous,
tool-using, partially hidden behind an interface, and capable of acting in ways
that are useful only when bounded by clear instructions.
Claude Code, Codex CLI, Gemini CLI, Cursor Agent CLI, Copilot CLI, Kiro CLI, and
similar tools each have their own nature, affordances, rituals, and failure modes.

`djnn` is the binding layer for those entities.

The point is not the pop-fantasy image of a wish-granting genie. The relevant
image is older and more structural: an autonomous agent whose behavior is made
predictable by a binding artifact — a seal, pact, contract, vessel, or written
constraint. In `djnn`, the binding artifact is project configuration.

## Current status

`djnn` is currently an early prototype.

Implemented:

- package skeleton with library and executable;
- Tier-1 canonical schema leaves:
  - `Djnn.Schema.MCP`;
  - `Djnn.Schema.Hook`;
  - `Djnn.Schema.Approval`;
- `Djnn.Canonical`, the aggregator for the current canonical configuration;
- `Djnn.Schema.Policy`, a documented non-goal for the deferred execution-policy
  surface;
- `Djnn.Codec`, the validation-only codec layer;
- accumulating validation for MCP invariants;
- tests for codec validation behavior;
- executable skeleton with the intended command surface:
  - `djnn init`;
  - `djnn generate`;
  - `djnn check`.

Not implemented yet:

- authored config decoding, such as YAML, TOML, or JSON;
- coding-agent-specific generators/adapters;
- actual CLI command behavior;
- filesystem writes;
- conformance fixtures;
- migration or formatting tooling.

The MVP is intentionally small. Its first goal is to establish the canonical
algebra and validation boundaries before choosing parser dependencies or writing
coding-agent adapters.

## Design principles

### The schema is the algebra

The `Djnn.Schema.*` modules define plain Haskell data types for portable
configuration surfaces.

They are intentionally simple:

- no parser dependencies;
- no serialization instances yet;
- no runtime adapter logic;
- no cross-surface imports;
- derived instances only.

Each schema leaf models one surface. Leaves do not know about each other.

### `Djnn.Canonical` is the aggregator

`Djnn.Canonical` composes the independent schema leaves into one project-level
configuration value.

Adapters should consume `Canonical`, not individual authored files.

### The codec is the validation algebra

`Djnn.Codec` is deliberately not a YAML, TOML, or JSON decoder.

It is the validation layer:

```text
possibly-invalid Canonical
        ↓
validated Canonical or NonEmpty CodecError
```

Decoding authored text is a separate concern and will live in a later
format-specific module such as:

```hs
Djnn.Codec.Yaml
Djnn.Codec.Toml
Djnn.Codec.Json
```

This keeps parser dependencies isolated and lets the core schema and validation
logic remain base-only.

### Decode and validate are separate

The project separates two concerns:

```text
Decode:
  authored text → canonical Haskell values

Validate:
  possibly-invalid canonical values → certified canonical values
```

Some invalid states cannot be represented after decoding. For example, an
unknown hook event string cannot inhabit the `HookEvent` type. That error belongs
to the decoder, but its constructor still lives in `CodecError` so the project
has one auditable vocabulary of invalid input.

Other invalid states are deliberately representable because that makes authored
configuration easier to round-trip. For example, an `MCPServer` may have:

- transport `Stdio` but no command;
- transport `Http` or `Sse` but no URL;
- duplicate environment variable keys.

Those are checked by `Djnn.Codec`.

### Do not over-abstract Tier-2 surfaces too early

Some surfaces are universal in concept but incompatible in representation.

The execution-policy surface is the clearest example:

```text
pattern / predicate → allow | prompt | deny
```

Every runtime has some version of this, but the encodings differ sharply:

- Claude uses permission rule strings;
- Codex uses execpolicy/Starlark-like rules;
- Gemini uses TOML policy files;
- Cursor and Copilot expose weaker allowlist-style forms.

`Djnn.Schema.Policy` exists to record that this surface is real but deliberately
unmodeled in the current version.

## Current canonical surfaces

### MCP servers

MCP servers are modeled by `Djnn.Schema.MCP`.

The current canonical shape supports:

- server name;
- transport:
  - `Stdio`;
  - `Http`;
  - `Sse`;
- command;
- arguments;
- URL;
- environment variables.

The transport determines which fields are meaningful:

| Transport | Required field | Meaning                               |
| --------- | -------------- | ------------------------------------- |
| `Stdio`   | `mcpCommand`   | spawn a local MCP server process      |
| `Http`    | `mcpUrl`       | connect to a streamable HTTP endpoint |
| `Sse`     | `mcpUrl`       | connect to a legacy SSE endpoint      |

The type intentionally allows the invalid combinations. `Djnn.Codec` validates
them on the way in.

### Hooks

Hooks are modeled by `Djnn.Schema.Hook`.

The current canonical event set is the portable intersection used by the initial
target runtimes:

```hs
data HookEvent
  = SessionStart
  | PreToolUse
  | PostToolUse
  | Stop
  | PreCompact
  | PostCompact
  | PermissionRequest
```

The current handler model includes the command-handler shape shared by the
initial runtimes:

```hs
data HookHandler = CommandHandler
  { handlerCommand       :: String
  , handlerTimeout       :: Maybe Int
  , handlerAsync         :: Bool
  , handlerStatusMessage :: Maybe String
  }
```

Runtime-specific handler variants are deliberately deferred.

### Approval defaults

Approval defaults are modeled by `Djnn.Schema.Approval`.

The current type represents the coarse global default only:

```hs
data ApprovalMode
  = Prompt
  | AcceptEdits
  | Plan
  | Never
```

This is not the same thing as fine-grained execution policy. Execution policy is
a separate Tier-2 surface and is intentionally not modeled yet.

## Codec validation

`Djnn.Codec` currently validates:

- `Stdio` MCP servers must have a command;
- `Http` and `Sse` MCP servers must have a URL;
- duplicate environment keys on one MCP server are rejected;
- duplicate MCP server names across the whole canonical config are rejected.

Validation is accumulating, not fail-fast. A single validation run should report
all independent problems it can find.

Example shape:

```hs
validate :: Canonical -> Either (NonEmpty CodecError) Canonical
```

The internal `Validation` type is applicative and intentionally has no `Monad`
instance. A monadic validation would naturally short-circuit; `djnn` wants
configuration checks to accumulate errors for better user feedback.

## Toolchain

The current development setup is:

```text
GHC:             9.6.7
cabal-install:   3.14.x
HLS:             2.14.x
Cabal spec:      3.8
```

Recommended setup:

```text
GHCup → installs GHC, cabal-install, and HLS
cabal → builds and manages the project
HLS   → provides editor integration
Stack → not used for this project
```

The `.cabal` file currently uses:

```cabal
cabal-version: 3.8
```

This keeps the package description compatible with the HLS version used during
development.

## Building

From the project root:

```bash
cabal build all
```

## Testing

Run the test suite:

```bash
cabal test
```

The current tests cover codec validation behavior, including accumulation of
multiple independent errors.

## Documentation

Build Haddock documentation:

```bash
cabal haddock
```

This is useful when changing constructor documentation or exported module
comments.

## Running

The executable command surface exists, but the commands are not implemented yet:

```bash
cabal run djnn -- init
cabal run djnn -- generate
cabal run djnn -- check
```

Current output is a placeholder:

```text
djnn init: not yet implemented
```

The intended future behavior is:

```text
djnn init      create an initial authored config
djnn check     decode and validate config without writing generated files
djnn generate  decode, validate, and generate runtime-specific files
```

## Repository structure

Current intended structure:

```text
djnn/
├── app/
│   └── Main.hs
├── docs/
│   └── ROADMAP.md
├── src/
│   └── Djnn/
│       ├── Schema/
│       │   ├── Approval.hs
│       │   ├── Hook.hs
│       │   ├── MCP.hs
│       │   └── Policy.hs
│       ├── Canonical.hs
│       └── Codec.hs
├── test/
│   └── Main.hs
├── .gitignore
├── CHANGELOG.md
├── CONTRIBUTING.md
├── djnn.cabal
├── LICENSE
└── README.md
```

## Roadmap

Check [docs/ROADMAP.md](docs/ROADMAP.md) for the engineering plan.

The high-level order is:

1. canonical schema baseline;
2. validation codec;
3. authored config decoder;
4. runtime generators;
5. implemented CLI;
6. conformance fixtures and compatibility matrix.

## License

[BSD-3-Clause](LICENSE).
