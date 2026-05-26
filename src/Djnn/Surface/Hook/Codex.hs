{-# LANGUAGE DerivingStrategies #-}

-- | Codex CLI hook surface, modelled faithfully.
--
-- Authoritative source: Codex CLI configuration JSON Schema,
--   <https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/config.schema.json>
-- Retrieved: 2026-05-25
-- Status: official schema, modelled verbatim. Not hand-edited to fit @djnn@'s
-- unified view; divergences from upstream are documented inline and are
-- upstream's shape, not a normalisation.
--
-- A /leaf/: imports no other @Djnn.*@ module, ever (the per-agent surface
-- invariant). It states only "this is what Codex CLI accepts for hooks" — it
-- does not decide how that maps to the unified surface; that judgment lives in
-- the deferred mapping layer, not here.
--
-- Type names are agent-prefixed by the locked Phase-3 convention, so
-- mapping-layer signatures and error messages stay legible and never collide
-- with the v0 @Djnn.Schema.Hook.HookEvent@ or the future unified
-- @Djnn.Surface.Hook.HookEvent@.
--
-- __Cross-runtime field-modelling convention__ (Phase 3, applied uniformly
-- across @Djnn.Surface.Hook.*@): every nullable scalar schema field is
-- modelled as 'Maybe' a, regardless of whether the schema declares a default.
-- When the schema does declare a default, that default is exposed as a named
-- top-level constant (e.g. 'codexCommandAsyncDefault') rather than baked into
-- the field type. This preserves the absent-vs-explicit-default distinction
-- for lossless round-tripping and keeps defaults discoverable without
-- prose-reading.
module Djnn.Surface.Hook.Codex
  ( -- * Events
    CodexHookEvent (..)
    -- * Handlers and hooks
  , CodexHookHandler (..)
  , CodexHook (..)
    -- * Schema-declared defaults
  , codexCommandAsyncDefault
    -- * Smart constructors
  , codexCommandHandler
  , codexHook
    -- * Enumeration helpers
  , codexHookEvents
  ) where

-- | Codex CLI hook events, exactly the keys of @HooksToml@ in the cited
-- schema (the @state@ key is intentionally excluded — it is per-hook
-- runtime state, not an event).
--
-- Constructor /names/ correspond 1:1 to schema event keys; constructor
-- /order/ is @djnn@'s lifecycle grouping, not the schema's source order. The
-- groupings carry no type-level meaning — they are evidence for the eventual
-- unified @Djnn.Surface.Hook@ layer, where a 'Scope'-like type may
-- legitimately impose this grouping over multiple agents.
data CodexHookEvent
  -- * Agentic Loop
  -- ** Tool Call
  = CodexPreToolUse
  | CodexPostToolUse
  -- ** Tool Call Permission
  | CodexPermissionRequest
  -- ** Subagent
  | CodexSubagentStart
  | CodexSubagentStop

  -- * User-Agent Turn
  -- ** User Prompt (Start)
  | CodexUserPromptSubmit
  -- ** Completion
  | CodexStop

  -- * Session
  -- ** Session Lifecycle
  | CodexSessionStart
  -- ** Context Compaction
  | CodexPreCompact
  | CodexPostCompact
  deriving stock (Eq, Show, Ord, Enum, Bounded)

-- | Codex CLI hook handler shape, modelling all three @HookHandlerConfig@
-- variants the schema declares (@oneOf@: @command@, @prompt@, @agent@).
--
-- The schema's @type@ discriminator is encoded by the constructor itself
-- ('CodexCommandHandler' / 'CodexPromptHandler' / 'CodexAgentHandler'); no
-- redundant @type :: String@ field appears on the constructors.
--
-- The @prompt@ and @agent@ variants are upstream placeholders: their schema
-- entries declare only the discriminator @type@ field and no payload. They
-- are modelled as nullary constructors here to remain faithful to the
-- schema's @oneOf@ — if Codex CLI later attaches fields, those fields will
-- land on these constructors.
data CodexHookHandler
  = CodexCommandHandler
      { codexCommandCommand        :: String
      , codexCommandCommandWindows :: Maybe String
        -- ^ Windows-specific command override, per the schema. Defaults to
        -- @null@ upstream.
      , codexCommandAsync          :: Maybe Bool
        -- ^ Schema-nullable @bool@ with declared default @false@; see
        -- 'codexCommandAsyncDefault'. Modelled as 'Maybe' 'Bool' so the
        -- absent-vs-explicit-@false@ distinction round-trips losslessly.
      , codexCommandStatusMessage  :: Maybe String
      , codexCommandTimeout        :: Maybe Int
        -- ^ Schema declares this as @uint64@ with no documented unit. Codex
        -- CLI's runtime convention is not asserted at this layer; the
        -- mapping layer is the place to normalise units against other
        -- agents.
      }
  | CodexPromptHandler
    -- ^ Schema placeholder: declares only @type: "prompt"@ with no payload.
  | CodexAgentHandler
    -- ^ Schema placeholder: declares only @type: "agent"@ with no payload.
  deriving stock (Eq, Show)

-- | An event\/matcher\/handlers binding as Codex CLI structures it, mirroring
-- @MatcherGroup@: a single optional @matcher@ groups one or more handlers.
-- Keep the matcher pattern verbatim — its language is Codex-specific and is
-- not normalised at this layer.
data CodexHook = CodexHook
  { codexHookEvent    :: CodexHookEvent
  , codexHookMatcher  :: Maybe String
  , codexHookHandlers :: [CodexHookHandler]
  } deriving stock (Eq, Show)

-- | Schema-declared default for 'codexCommandAsync': not asynchronous.
-- Exposed as a named constant so that mapping-layer adapters and
-- presentation code can render an effective value without re-deriving the
-- default from prose.
codexCommandAsyncDefault :: Bool
codexCommandAsyncDefault = False

-- | Minimal 'CodexCommandHandler' — required @command@ positional, all
-- other fields left as their schema-absent values ('Nothing'). Use
-- record-update syntax to set the options you care about.
codexCommandHandler :: String -> CodexHookHandler
codexCommandHandler c = CodexCommandHandler
  { codexCommandCommand        = c
  , codexCommandCommandWindows = Nothing
  , codexCommandAsync          = Nothing
  , codexCommandStatusMessage  = Nothing
  , codexCommandTimeout        = Nothing
  }

-- | Construct a 'CodexHook' from an event and its handlers, with no matcher
-- (i.e. fire on every occurrence of the event). Use record-update syntax to
-- attach a matcher.
codexHook :: CodexHookEvent -> [CodexHookHandler] -> CodexHook
codexHook e hs = CodexHook
  { codexHookEvent    = e
  , codexHookMatcher  = Nothing
  , codexHookHandlers = hs
  }

-- | Total enumeration of Codex CLI hook events, for adapter case analysis and
-- the cross-surface intersection test.
codexHookEvents :: [CodexHookEvent]
codexHookEvents = [minBound .. maxBound]
