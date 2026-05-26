{-# LANGUAGE DerivingStrategies #-}

-- | Cursor Agent CLI hook surface, modelled faithfully.
--
-- Authoritative source: Cursor hooks documentation,
--   <https://cursor.com/docs/hooks>
--   <https://cursor.com/docs/reference/third-party-hooks>
-- Retrieved: 2026-05-25
-- Status: official documentation, modelled verbatim. Not hand-edited to fit
-- @djnn@'s unified view; divergences from upstream are documented inline and
-- are upstream's shape, not a normalisation.
--
-- Scope: this module models /agent-category/ hooks only — the events that
-- fire during a Cursor Agent session (Cmd+K, Agent Chat, or @cursor-agent@
-- CLI invocations). The /Tab/ category (autonomous inline-completion hooks)
-- and the /App lifecycle/ category (@workspaceOpen@) are documented in the
-- same source but are deliberately out of scope here: Tab hooks fire only
-- in the IDE's inline-completion surface, and @workspaceOpen@ fires for
-- workspace-folder events independent of any agent session. @djnn@ targets
-- CLI coding agents, so these IDE-specific surfaces are not modelled.
--
-- Whether @cursor-agent@ CLI fires every event in the agent category is
-- not directly documented in the cited source. The hook events below are
-- Cursor's documented agent-category surface; events tied to IDE UX
-- (e.g., 'CursorAfterAgentThought', which presumes a UI showing reasoning
-- blocks) may not fire in CLI mode. CLI-specific emission verification is
-- a deferred item.
--
-- A /leaf/: imports no other @Djnn.*@ module, ever (the per-agent surface
-- invariant). It states only "this is what Cursor accepts for agent-category
-- hooks" — it does not decide how that maps to the unified surface; that
-- judgment lives in the deferred mapping layer, not here.
--
-- Type names are agent-prefixed by the locked Phase-3 convention, so
-- mapping-layer signatures and error messages stay legible and never collide
-- with the v0 @Djnn.Schema.Hook.HookEvent@ or the future unified
-- @Djnn.Surface.Hook.HookEvent@.
module Djnn.Surface.Hook.Cursor
  ( -- * Events
    CursorHookEvent (..)
    -- * Handlers, entries, hooks
  , CursorHookHandler (..)
  , CursorLoopLimit (..)
  , CursorHookEntry (..)
  , CursorHook (..)
    -- * Schema-declared defaults
  , cursorEntryFailClosedDefault
    -- * Smart constructors
  , cursorCommandHandler
  , cursorPromptHandler
  , cursorHookEntry
  , cursorHook
    -- * Enumeration helpers
  , cursorHookEvents
  ) where

-- | Cursor Agent hook events, exactly the agent-category keys of the
-- @hooks@ object in the cited documentation. Constructor /names/
-- correspond 1:1 to documented event keys (PascalCase representations of
-- Cursor's camelCase event strings, e.g., @preToolUse@ becomes
-- 'CursorPreToolUse'); constructor /order/ is @djnn@'s lifecycle grouping,
-- not the docs' source order. The groupings carry no type-level meaning —
-- they are evidence for the eventual unified @Djnn.Surface.Hook@ layer,
-- where a 'Scope'-like type may legitimately impose this grouping over
-- multiple agents.
data CursorHookEvent
  -- * Agentic Loop
  -- ** Tool Call
  = CursorPreToolUse
  | CursorPostToolUse
  | CursorPostToolUseFailure
  -- ** Shell Execution
  | CursorBeforeShellExecution
  | CursorAfterShellExecution
  -- ** MCP Tool Call Execution
  | CursorBeforeMcpExecution
  | CursorAfterMcpExecution
  -- ** Subagent
  | CursorSubagentStart
  | CursorSubagentStop

  -- * User-Agent Turn
  -- ** User Prompt (Start)
  | CursorBeforeSubmitPrompt
  -- ** Generation
  | CursorAfterAgentThought
  | CursorAfterAgentResponse
  -- ** Completion
  | CursorStop

  -- * Session
  -- ** Session Lifecycle
  | CursorSessionStart
  | CursorSessionEnd
  -- ** Context Compaction\/Compression
  | CursorPreCompact
  -- ** Environment Monitoring
  | CursorBeforeReadFile
  | CursorAfterFileEdit
  deriving stock (Eq, Show, Ord, Enum, Bounded)

-- | The three-valued shape of Cursor's @loop_limit@ field, which the docs
-- declare as @number | null@ with a contextual default.
--
-- The docs distinguish three states the JSON can be in:
--
--   * /Absent/: use the per-script default. The default depends on the
--     source: @5@ for native Cursor hooks loaded from @hooks.json@,
--     /no limit/ for Claude Code hooks loaded via the third-party-hooks
--     bridge.
--   * /Explicit @null@/: no limit, regardless of source.
--   * /Explicit number/: that exact limit.
--
-- A naive @Maybe Int@ would fold the first two into the same 'Nothing' and
-- lose the distinction the docs explicitly make.
--
-- Only meaningful on entries for 'CursorStop' and 'CursorSubagentStop';
-- the docs do not assign semantics to @loop_limit@ on other events. This
-- type makes no attempt to enforce that — the constraint is documented at
-- the relevant constructors, and an adapter is free to reject misplaced
-- limits at decode time.
data CursorLoopLimit
  = CursorLoopLimitDefault
    -- ^ Field absent in the JSON; the per-script default applies at
    -- runtime (@5@ for Cursor-native hooks, /no limit/ for hooks loaded
    -- via the Claude-Code third-party bridge).
  | CursorLoopLimitUnbounded
    -- ^ Explicit @null@ in the JSON; the loop is uncapped.
  | CursorLoopLimitExactly Int
    -- ^ Explicit integer in the JSON; that exact cap applies.
  deriving stock (Eq, Show, Ord)

-- | Cursor Agent hook handler shape — the @type@-discriminated portion of
-- an entry, holding only the fields that vary between @command@ and
-- @prompt@. Per-script options that are identical across both variants
-- (@matcher@, @timeout@, @failClosed@, @loop_limit@) live on
-- 'CursorHookEntry' instead, mirroring the flat JSON layout where they sit
-- as peers of @type@ rather than inside a type-specific bag.
--
-- Cursor is the first agent in @Djnn.Surface.Hook.*@ where the @prompt@
-- handler is modelled as a peer of @command@. Claude Code's schema declares
-- four additional handler variants (@agent@, @http@, @mcp_tool@, plus
-- @prompt@), all of which @Djnn.Surface.Hook.Claude@ models faithfully.
-- Codex CLI's @prompt@ and @agent@ variants are upstream-placeholders.
-- Gemini CLI's schema declares only @command@. The decision to model
-- Cursor's @prompt@ alongside @command@ reflects that Cursor's docs treat
-- both as documented, supported, peer execution modes — fidelity to the
-- source rather than consistency with sibling files.
data CursorHookHandler
  = CursorCommandHandler
      { cursorCommandCommand :: String
        -- ^ Script path or command. Project-hook paths are relative to the
        -- project root; user-hook paths are relative to @~\/.cursor\/@.
      }
  | CursorPromptHandler
      { cursorPromptPrompt :: String
        -- ^ Natural-language condition evaluated by an LLM. Returns a
        -- structured @{ ok: boolean, reason?: string }@ response. The docs
        -- note that @$ARGUMENTS@ in the prompt is auto-replaced with the
        -- hook input JSON; if absent, the input is auto-appended.
      , cursorPromptModel :: Maybe String
        -- ^ Optional model override for prompt evaluation. The docs do not
        -- specify a default; Cursor uses "a fast model for quick
        -- evaluation" when omitted.
      }
  deriving stock (Eq, Show)

-- | One element of Cursor's per-event hook array: a single handler with
-- its own matcher and per-script options. Mirrors Cursor's JSON shape,
-- where every entry is a flat object containing the @type@ discriminator,
-- the handler-specific fields (@command@ or @prompt@\/@model@), and the
-- shared per-script options (@matcher@, @timeout@, @failClosed@,
-- @loop_limit@) as peers.
--
-- The matcher pattern is preserved verbatim; its language is
-- Cursor-specific and varies by event, per the configuration docs:
--
--   * regex on tool name for 'CursorPreToolUse', 'CursorPostToolUse', and
--     'CursorPostToolUseFailure' — values include @Shell@, @Read@,
--     @Write@, @Grep@, @Delete@, @Task@, or @MCP:\<tool_name\>@.
--   * regex on the full shell-command string for
--     'CursorBeforeShellExecution' and 'CursorAfterShellExecution'.
--   * subagent-type pattern for 'CursorSubagentStart' and
--     'CursorSubagentStop' — values include @generalPurpose@, @explore@,
--     @shell@.
--   * tool-type filter for 'CursorBeforeReadFile' (e.g. @TabRead@,
--     @Read@) and 'CursorAfterFileEdit' (e.g. @TabWrite@, @Write@).
--   * fixed string @"UserPromptSubmit"@ for 'CursorBeforeSubmitPrompt',
--     @"Stop"@ for 'CursorStop', @"AgentResponse"@ for
--     'CursorAfterAgentResponse', @"AgentThought"@ for
--     'CursorAfterAgentThought'.
--
-- Normalising these heterogeneous matcher languages into a unified surface
-- is the mapping layer's job, not this leaf's.
data CursorHookEntry = CursorHookEntry
  { cursorEntryHandler :: CursorHookHandler
    -- ^ Handler variant ('CursorCommandHandler' or 'CursorPromptHandler')
    -- and its type-specific fields.
  , cursorEntryMatcher :: Maybe String
    -- ^ Cursor's optional @matcher@ field for this entry. 'Nothing' means
    -- "fire for every event of this type"; the docs assign no semantics
    -- to an explicit empty string, so the matcher is kept 'Maybe' 'String'
    -- rather than collapsed.
  , cursorEntryTimeout :: Maybe Double
    -- ^ Execution timeout in seconds. The docs declare this as @number@
    -- with a "platform default" when absent — no concrete default is
    -- nameable at this layer, so this stays 'Maybe'. 'Double' rather than
    -- 'Int' because the docs' "number" admits fractional values.
  , cursorEntryFailClosed :: Maybe Bool
    -- ^ When @true@, hook failures (crash, timeout, invalid JSON) block
    -- the action instead of allowing it through. Docs default 'False'
    -- (see 'cursorEntryFailClosedDefault'). Modelled as 'Maybe' 'Bool' to
    -- preserve the absent-vs-explicit-false distinction; round-trip
    -- through JSON is lossless.
  , cursorEntryLoopLimit :: CursorLoopLimit
    -- ^ Per-script loop limit. Meaningful only on entries for
    -- 'CursorStop' and 'CursorSubagentStop'; see 'CursorLoopLimit' for the
    -- three-state semantics and contextual defaults.
  } deriving stock (Eq, Show)

-- | An event with its list of registered entries, mirroring the @hooks@
-- object in Cursor's @hooks.json@: each event key (e.g. @preToolUse@) maps
-- to an array of entry objects, with no shared matcher and no per-event
-- configuration container.
--
-- /Structural note:/ this aggregation matches Cursor's documented JSON
-- shape verbatim. An earlier shape of this type — a single shared
-- @cursorHookMatcher@ field above a flat list of handlers — was a
-- deliberate divergence chosen for symmetry with
-- 'Djnn.Surface.Hook.Claude.ClaudeHook' and
-- 'Djnn.Surface.Hook.Codex.CodexHook', whose upstream schemas /do/ group
-- handlers under a shared matcher. That symmetry cost real fidelity: two
-- entries under the same event key with /different/ matchers could not be
-- represented in one 'CursorHook' value without fabricating a shared
-- matcher that does not exist in the source. The shape modelled here
-- resolves that — at the price of cross-agent symmetry, which the
-- deferred mapping layer is the right place to recover (by lifting
-- entries with equal matchers into a Claude-shaped group when emitting a
-- unified view, and lowering them back when emitting Cursor JSON).
data CursorHook = CursorHook
  { cursorHookEvent   :: CursorHookEvent
  , cursorHookEntries :: [CursorHookEntry]
  } deriving stock (Eq, Show)

-- | Docs-declared default for 'cursorEntryFailClosed': fail-open. Exposed
-- as a named constant so that mapping-layer adapters and presentation
-- code can render an effective value without re-deriving the default from
-- prose.
cursorEntryFailClosedDefault :: Bool
cursorEntryFailClosedDefault = False

-- | Minimal 'CursorCommandHandler' — required @command@ positional. Per-
-- script options (matcher, timeout, failClosed, loop_limit) are not on
-- the handler; set them on the surrounding 'CursorHookEntry'.
cursorCommandHandler :: String -> CursorHookHandler
cursorCommandHandler c = CursorCommandHandler { cursorCommandCommand = c }

-- | Minimal 'CursorPromptHandler' — required @prompt@ positional, model
-- override left absent.
cursorPromptHandler :: String -> CursorHookHandler
cursorPromptHandler p = CursorPromptHandler
  { cursorPromptPrompt = p
  , cursorPromptModel  = Nothing
  }

-- | Minimal 'CursorHookEntry' — required handler positional, all entry
-- options left as their schema-absent values ('Nothing' for matcher,
-- timeout, failClosed; 'CursorLoopLimitDefault' for loop_limit). Use
-- record-update syntax to set the options you care about.
cursorHookEntry :: CursorHookHandler -> CursorHookEntry
cursorHookEntry h = CursorHookEntry
  { cursorEntryHandler    = h
  , cursorEntryMatcher    = Nothing
  , cursorEntryTimeout    = Nothing
  , cursorEntryFailClosed = Nothing
  , cursorEntryLoopLimit  = CursorLoopLimitDefault
  }

-- | Construct a 'CursorHook' from an event and its entries. Trivial, but
-- exposed for symmetry with the other smart constructors and to keep
-- call sites' record-literal noise out of user code.
cursorHook :: CursorHookEvent -> [CursorHookEntry] -> CursorHook
cursorHook e es = CursorHook
  { cursorHookEvent   = e
  , cursorHookEntries = es
  }

-- | Total enumeration of Cursor Agent hook events, for adapter case analysis
-- and the cross-surface intersection test.
cursorHookEvents :: [CursorHookEvent]
cursorHookEvents = [minBound .. maxBound]
