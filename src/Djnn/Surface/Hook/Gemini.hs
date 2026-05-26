{-# LANGUAGE DerivingStrategies #-}

-- | Gemini CLI hook surface, modelled faithfully.
--
-- Authoritative source: Gemini CLI configuration JSON Schema,
--   <https://raw.githubusercontent.com/google-gemini/gemini-cli/main/schemas/settings.schema.json>
-- Retrieved: 2026-05-25
-- Status: official schema, modelled verbatim. Not hand-edited to fit @djnn@'s
-- unified view; divergences from upstream are documented inline and are
-- upstream's shape, not a normalisation.
--
-- Scope: this module models the per-event @hooks@ object — the eleven
-- documented event keys and the @HookDefinitionArray@ shape they contain.
-- The sibling top-level @hooksConfig@ object (system-level @enabled@ toggle,
-- per-hook block list under @disabled@, run-indicator @notifications@) is a
-- hook-/runtime/ configuration concern rather than a hook-/event/
-- definition: it gates and observes hook execution but does not define
-- handlers. It is deliberately out of scope here, the same way Codex CLI's
-- @HooksToml.state@ (per-hook trust-hash state) is excluded from
-- @Djnn.Surface.Hook.Codex@. If @djnn@ later models hook-runtime control,
-- @hooksConfig@ belongs in that surface, not in this one.
--
-- A /leaf/: imports no other @Djnn.*@ module, ever (the per-agent surface
-- invariant). It states only "this is what Gemini CLI accepts for hooks" — it
-- does not decide how that maps to the unified surface; that judgment lives in
-- the deferred mapping layer, not here.
--
-- Type names are agent-prefixed by the locked Phase-3 convention, so
-- mapping-layer signatures and error messages stay legible and never collide
-- with the v0 @Djnn.Schema.Hook.HookEvent@ or the future unified
-- @Djnn.Surface.Hook.HookEvent@.
module Djnn.Surface.Hook.Gemini
  ( -- * Events
    GeminiHookEvent (..)
    -- * Handlers and hooks
  , GeminiHookHandler (..)
  , GeminiHook (..)
    -- * Smart constructors
  , geminiCommandHandler
  , geminiHook
    -- * Enumeration helpers
  , geminiHookEvents
  ) where

-- | Gemini CLI hook events, exactly the keys of the @hooks@ object in the
-- cited schema.
--
-- Constructor /names/ correspond 1:1 to schema event keys; constructor
-- /order/ is @djnn@'s lifecycle grouping, not the schema's source order. The
-- groupings carry no type-level meaning — they are evidence for the eventual
-- unified @Djnn.Surface.Hook@ layer, where a 'Scope'-like type may
-- legitimately impose this grouping over multiple agents.
data GeminiHookEvent
  -- * Agentic Loop
  -- ** Tool Call
  = GeminiBeforeTool
  | GeminiAfterTool
  -- ** LLM\/RLM Call
  | GeminiBeforeModel
  | GeminiBeforeToolSelection
  | GeminiAfterModel

  -- * User-Agent Turn
  | GeminiBeforeAgent
  | GeminiAfterAgent

  -- * Session
  -- ** Session Lifecycle
  | GeminiSessionStart
  | GeminiSessionEnd
  -- ** Context Compaction\/Compression
  | GeminiPreCompress

  -- * System Notification
  | GeminiNotification
  deriving stock (Eq, Show, Ord, Enum, Bounded)

-- | Gemini CLI hook handler shape, as the schema defines it.
--
-- Unlike Claude Code or Codex CLI, Gemini's schema declares a single hook
-- shape (the @type@ field is documented as "currently only \"command\"
-- supported"), so this is a single-constructor sum. It remains a sum rather
-- than a bare record to leave room for future variants without breaking call
-- sites — the same shape used by @Djnn.Schema.Hook@.
--
-- The schema's @type@ discriminator is encoded by the constructor itself
-- ('GeminiCommandHandler'); no redundant @type :: String@ field appears on
-- the constructor, matching the convention used by sibling
-- @Djnn.Surface.Hook.Claude@ and @Djnn.Surface.Hook.Codex@.
data GeminiHookHandler = GeminiCommandHandler
  { geminiCommandCommand     :: String
    -- ^ Shell command to execute. Receives JSON input via stdin and returns
    -- JSON output via stdout.
  , geminiCommandName        :: Maybe String
    -- ^ Optional unique identifier for the hook.
  , geminiCommandDescription :: Maybe String
    -- ^ Optional description of the hook.
  , geminiCommandTimeoutMs   :: Maybe Int
    -- ^ Timeout in /milliseconds/ for hook execution, per the schema
    -- ("Timeout in milliseconds for hook execution."). The 'Ms' suffix is
    -- deliberate: Claude Code and Codex CLI declare their timeouts in
    -- /seconds/, and this units divergence is one of the things the
    -- deferred mapping layer must normalise.
  } deriving stock (Eq, Show)

-- | An event\/matcher\/handlers binding as Gemini CLI structures it, mirroring
-- @HookDefinitionArray@: a single optional @matcher@ groups one or more
-- handlers. Keep the matcher pattern verbatim — its language is Gemini-specific
-- (exact match, regex (@\/pattern\/@), wildcards) and is not normalised at
-- this layer.
data GeminiHook = GeminiHook
  { geminiHookEvent    :: GeminiHookEvent
  , geminiHookMatcher  :: Maybe String
  , geminiHookHandlers :: [GeminiHookHandler]
  } deriving stock (Eq, Show)

-- | Minimal 'GeminiCommandHandler' — required @command@ positional, all
-- other fields left as their schema-absent values ('Nothing'). Use
-- record-update syntax to set the options you care about.
geminiCommandHandler :: String -> GeminiHookHandler
geminiCommandHandler c = GeminiCommandHandler
  { geminiCommandCommand     = c
  , geminiCommandName        = Nothing
  , geminiCommandDescription = Nothing
  , geminiCommandTimeoutMs   = Nothing
  }

-- | Construct a 'GeminiHook' from an event and its handlers, with no
-- matcher (i.e. fire on every occurrence of the event). Use record-update
-- syntax to attach a matcher.
geminiHook :: GeminiHookEvent -> [GeminiHookHandler] -> GeminiHook
geminiHook e hs = GeminiHook
  { geminiHookEvent    = e
  , geminiHookMatcher  = Nothing
  , geminiHookHandlers = hs
  }

-- | Total enumeration of Gemini CLI hook events, for adapter case analysis and
-- the cross-surface intersection test.
geminiHookEvents :: [GeminiHookEvent]
geminiHookEvents = [minBound .. maxBound]
