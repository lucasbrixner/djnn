{-# LANGUAGE DerivingStrategies #-}

-- | The canonical lifecycle-hook surface.
--
-- A /leaf/ module: no @Djnn.Schema.*@ imports, ever. A hook that
-- references an MCP server by name (Claude's @mcp_tool@ handler) is a
-- cross-surface concern and is deliberately excluded from the v1
-- canonical core; when it returns it composes in @Djnn.Canonical@, not
-- by importing the MCP surface here.
--
-- Portability tier: __Tier 1__ — Claude Code and Codex publish almost
-- verbatim-identical event names and a congruent @command@-handler
-- shape.
module Djnn.Schema.Hook
  ( Hook (..)
  , HookEvent (..)
  , HookHandler (..)
  , canonicalHookEvents
  ) where

-- | The canonical hook event set: precisely the events Claude Code and
-- Codex both expose under /identical names/ in their published schemas.
-- This intersection is the safe portable core. Events appearing in only
-- one runtime — e.g. Claude's @PostToolUseFailure@ and
-- @PermissionDenied@ — are intentionally excluded, so a 'Hook' built
-- from this type is guaranteed to render on both. The Gemini adapter
-- maps these onto Gemini's hook system, which shares the same lifecycle
-- concepts under different names.
--
-- Constructor order is lifecycle order, not a semantic ranking; it
-- exists only so 'Enum'\/'Bounded' can enumerate the set.
data HookEvent
  = SessionStart
  | PreToolUse
  | PostToolUse
  | Stop
  | PreCompact
  | PostCompact
  | PermissionRequest
  deriving stock (Eq, Show, Ord, Enum, Bounded)

-- | Every canonical hook event. Used by adapters for total case
-- analysis and by the @check@ command to assert an authored hook
-- targets only the portable intersection.
canonicalHookEvents :: [HookEvent]
canonicalHookEvents = [minBound .. maxBound]

-- | A hook handler.
--
-- Only the @command@ handler has a field shape Claude Code and Codex
-- agree on (@command@, @timeout@, @async@, @statusMessage@). Claude's
-- @prompt@\/@agent@\/@http@\/@mcp_tool@ handlers and Codex's stubbed
-- @prompt@\/@agent@ variants are deliberately outside the v1 canonical
-- core: their fields do not align, so canonicalizing them would mean
-- inventing semantics. Kept a single-constructor sum on purpose — the
-- shape stays open for future variants without breaking call sites.
data HookHandler = CommandHandler
  { handlerCommand       :: String
    -- ^ Shell command to execute. Required in both runtimes.
  , handlerTimeout       :: Maybe Int
    -- ^ Optional timeout in /seconds/ (both runtimes use seconds here).
  , handlerAsync         :: Bool
    -- ^ Run without blocking the agent. Defaults to 'False', the shared
    -- default in both published schemas.
  , handlerStatusMessage :: Maybe String
    -- ^ Optional spinner\/status text shown while the hook runs.
    -- Present in both runtimes under the same name.
  }
  deriving stock (Eq, Show)

-- | A hook binds a handler to an event, optionally filtered by a
-- matcher pattern.
--
-- Both Claude (@hookMatcher@) and Codex (@MatcherGroup@) nest handlers
-- under an optional matcher within each event. djnn flattens that to a
-- single @(event, matcher, handler)@ triple and lets the adapter
-- regroup, because the grouped-by-matcher form is a rendering detail,
-- not a modelling one.
data Hook = Hook
  { hookEvent   :: HookEvent
  , hookMatcher :: Maybe String
    -- ^ Optional event-context filter (e.g. a tool-name or
    -- permission-rule pattern). Semantics are event- and
    -- runtime-specific; djnn passes it through verbatim and does not
    -- normalize the pattern language.
  , hookHandler :: HookHandler
  }
  deriving stock (Eq, Show)
