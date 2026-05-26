{-# LANGUAGE DerivingStrategies #-}

-- | Claude Code hook surface, modelled faithfully.
--
-- Authoritative source: Claude Code settings JSON Schema,
--   <https://json.schemastore.org/claude-code-settings.json>
--   [local](../../../docs/references/claude/settings.schema.json)
-- Retrieved: 2026-05-25
-- Status: official schema, modelled verbatim. Not hand-edited to fit @djnn@'s
-- unified view; divergences from upstream are documented inline and are
-- upstream's shape, not a normalisation.
--
-- A /leaf/: imports no other @Djnn.*@ module, ever (the per-agent surface
-- invariant). It states only "this is what Claude Code accepts for hooks" — it
-- does not decide how that maps to the unified surface; that judgment lives in
-- the deferred mapping layer, not here.
--
-- Type names are agent-prefixed by the locked Phase-3 convention, so
-- mapping-layer signatures and error messages stay legible and never collide
-- with the v0 @Djnn.Schema.Hook.HookEvent@ or the future unified
-- @Djnn.Surface.Hook.HookEvent@.
module Djnn.Surface.Hook.Claude
  ( -- * Events
    ClaudeHookEvent (..)
    -- * Handlers and hooks
  , ClaudeShell (..)
  , ClaudeHookHandler (..)
  , ClaudeHook (..)
    -- * Smart constructors
  , claudeCommandHandler
  , claudePromptHandler
  , claudeAgentHandler
  , claudeHttpHandler
  , claudeMcpToolHandler
  , claudeHook
    -- * Enumeration helpers
  , claudeHookEvents
  ) where

-- | Claude Code hook events, exactly the keys of the @hooks@ object in the
-- cited schema.
--
-- Constructor /names/ correspond 1:1 to schema event keys; constructor
-- /order/ is @djnn@'s lifecycle grouping, not the schema's source order. The
-- groupings carry no type-level meaning — they are evidence for the eventual
-- unified @Djnn.Surface.Hook@ layer, where a 'Scope'-like type may
-- legitimately impose this grouping over multiple agents.
data ClaudeHookEvent
  -- * Agentic Loop
  -- ** Tool Call
  = ClaudePreToolUse
  | ClaudePostToolUse
  | ClaudePostToolUseFailure
  | ClaudePostToolBatch
  -- ** Tool Call Permission
  | ClaudePermissionRequest
  | ClaudePermissionDenied
  -- ** Tool Call MCP Elicitation
  | ClaudeElicitation
  | ClaudeElicitationResult
  -- ** Subagent
  | ClaudeSubagentStart
  | ClaudeSubagentStop
  -- ** Task
  | ClaudeTaskCreated
  | ClaudeTaskCompleted

  -- * User-Agent Turn
  -- ** User Prompt (Start)
  | ClaudeUserPromptSubmit
  | ClaudeUserPromptExpansion
  -- ** Completion
  | ClaudeStop
  | ClaudeStopFailure
  | ClaudeTeammateIdle

  -- * Session
  -- ** Environment Initialization
  | ClaudeSetup
  -- ** Session Lifecycle
  | ClaudeSessionStart
  | ClaudeSessionEnd
  -- ** Context
  | ClaudeInstructionsLoaded
  -- ** Context Compaction\/Compression
  | ClaudePreCompact
  | ClaudePostCompact
  -- ** Environment Monitoring
  | ClaudeCwdChanged
  | ClaudeFileChanged
  -- ** Configuration
  | ClaudeConfigChange

  -- * Git Worktree
  | ClaudeWorktreeCreate
  | ClaudeWorktreeRemove

  -- * System Notification
  | ClaudeNotification
  deriving stock (Eq, Show, Ord, Enum, Bounded)

-- | Shell interpreter for a command-typed Claude Code hook, per the schema's
-- @shell@ enum (defaults to @bash@ when omitted).
data ClaudeShell
  = ClaudeBash
  | ClaudePowerShell
  deriving stock (Eq, Show, Ord, Enum, Bounded)

-- | Claude Code hook handler shape, modelling all five @hookCommand@
-- variants the schema declares (@anyOf@: @command@, @prompt@, @agent@,
-- @http@, @mcp_tool@). Each constructor mirrors one schema variant exactly.
--
-- The @if@ field, present on every variant, names a permission-rule-syntax
-- filter (e.g. @"Bash(git *)"@); it is evaluated only on tool-related
-- events. Kept as @Maybe String@ so the matcher language stays verbatim —
-- normalisation is the mapping layer's job.
data ClaudeHookHandler
  = ClaudeCommandHandler
      { claudeCommandCommand       :: String
      , claudeCommandTimeout       :: Maybe Double
        -- ^ Seconds, per the schema (@number@, exclusiveMinimum 0).
        -- 'Double' because the schema permits fractional values.
      , claudeCommandAsync         :: Maybe Bool
      , claudeCommandAsyncRewake   :: Maybe Bool
        -- ^ When true the hook runs in the background and wakes the model
        -- when it exits with code 2. Implies @async@.
      , claudeCommandShell         :: Maybe ClaudeShell
      , claudeCommandIf            :: Maybe String
      , claudeCommandStatusMessage :: Maybe String
      , claudeCommandArgs          :: [String]
        -- ^ Argument list for exec form. When present, the command is
        -- spawned directly without shell interpretation. Empty list models
        -- "field absent" since the schema places no semantic meaning on an
        -- empty array.
      }
  | ClaudePromptHandler
      { claudePromptPrompt          :: String
      , claudePromptModel           :: Maybe String
      , claudePromptTimeout         :: Maybe Double
        -- ^ Seconds; schema default 30.
      , claudePromptIf              :: Maybe String
      , claudePromptStatusMessage   :: Maybe String
      , claudePromptContinueOnBlock :: Maybe Bool
        -- ^ Schema default @false@. When the prompt returns @ok: false@,
        -- feed the reason back and continue instead of stopping.
      }
  | ClaudeAgentHandler
      { claudeAgentPrompt        :: String
      , claudeAgentModel         :: Maybe String
      , claudeAgentTimeout       :: Maybe Double
        -- ^ Seconds; schema default 60.
      , claudeAgentIf            :: Maybe String
      , claudeAgentStatusMessage :: Maybe String
      }
  | ClaudeHttpHandler
      { claudeHttpUrl            :: String
      , claudeHttpHeaders        :: [(String, String)]
        -- ^ Schema: object of string values. Empty list models the absent
        -- object.
      , claudeHttpAllowedEnvVars :: [String]
        -- ^ Names of environment variables permitted for @$VAR@ /
        -- @${VAR}@ interpolation in headers. Empty list = no interpolation
        -- allowed, matching the schema's "If not set, no env var
        -- interpolation is allowed."
      , claudeHttpTimeout        :: Maybe Double
        -- ^ Seconds; schema default 30.
      , claudeHttpIf             :: Maybe String
      , claudeHttpStatusMessage  :: Maybe String
      }
  | ClaudeMcpToolHandler
      { claudeMcpServer        :: String
      , claudeMcpTool          :: String
      , claudeMcpInput         :: Maybe String
      , claudeMcpTimeout       :: Maybe Double
        -- ^ Seconds; schema default 60.
      , claudeMcpIf            :: Maybe String
      , claudeMcpStatusMessage :: Maybe String
      }
  deriving stock (Eq, Show)

-- | An event\/matcher\/handlers binding as Claude Code structures it,
-- mirroring @hookMatcher@: a single optional @matcher@ groups one or more
-- handlers. Keep the matcher pattern verbatim — its language is
-- Claude-specific and is not normalised at this layer.
data ClaudeHook = ClaudeHook
  { claudeHookEvent    :: ClaudeHookEvent
  , claudeHookMatcher  :: Maybe String
  , claudeHookHandlers :: [ClaudeHookHandler]
  } deriving stock (Eq, Show)

-- | Minimal 'ClaudeCommandHandler' — required @command@ positional, all
-- other fields left as their schema-absent values. Use record-update syntax
-- to set the options you care about.
claudeCommandHandler :: String -> ClaudeHookHandler
claudeCommandHandler c = ClaudeCommandHandler
  { claudeCommandCommand       = c
  , claudeCommandTimeout       = Nothing
  , claudeCommandAsync         = Nothing
  , claudeCommandAsyncRewake   = Nothing
  , claudeCommandShell         = Nothing
  , claudeCommandIf            = Nothing
  , claudeCommandStatusMessage = Nothing
  , claudeCommandArgs          = []
  }

-- | Minimal 'ClaudePromptHandler' — required @prompt@ positional, all
-- other fields left as their schema-absent values.
claudePromptHandler :: String -> ClaudeHookHandler
claudePromptHandler p = ClaudePromptHandler
  { claudePromptPrompt          = p
  , claudePromptModel           = Nothing
  , claudePromptTimeout         = Nothing
  , claudePromptIf              = Nothing
  , claudePromptStatusMessage   = Nothing
  , claudePromptContinueOnBlock = Nothing
  }

-- | Minimal 'ClaudeAgentHandler' — required @prompt@ positional, all
-- other fields left as their schema-absent values.
claudeAgentHandler :: String -> ClaudeHookHandler
claudeAgentHandler p = ClaudeAgentHandler
  { claudeAgentPrompt        = p
  , claudeAgentModel         = Nothing
  , claudeAgentTimeout       = Nothing
  , claudeAgentIf            = Nothing
  , claudeAgentStatusMessage = Nothing
  }

-- | Minimal 'ClaudeHttpHandler' — required @url@ positional, all other
-- fields left as their schema-absent values (empty headers, no env-var
-- interpolation allowed).
claudeHttpHandler :: String -> ClaudeHookHandler
claudeHttpHandler u = ClaudeHttpHandler
  { claudeHttpUrl            = u
  , claudeHttpHeaders        = []
  , claudeHttpAllowedEnvVars = []
  , claudeHttpTimeout        = Nothing
  , claudeHttpIf             = Nothing
  , claudeHttpStatusMessage  = Nothing
  }

-- | Minimal 'ClaudeMcpToolHandler' — required @server@ and @tool@
-- positionals, all other fields left as their schema-absent values.
claudeMcpToolHandler :: String -> String -> ClaudeHookHandler
claudeMcpToolHandler s t = ClaudeMcpToolHandler
  { claudeMcpServer        = s
  , claudeMcpTool          = t
  , claudeMcpInput         = Nothing
  , claudeMcpTimeout       = Nothing
  , claudeMcpIf            = Nothing
  , claudeMcpStatusMessage = Nothing
  }

-- | Construct a 'ClaudeHook' from an event and its handlers, with no
-- matcher (i.e. fire on every occurrence of the event). Use record-update
-- syntax to attach a matcher.
claudeHook :: ClaudeHookEvent -> [ClaudeHookHandler] -> ClaudeHook
claudeHook e hs = ClaudeHook
  { claudeHookEvent    = e
  , claudeHookMatcher  = Nothing
  , claudeHookHandlers = hs
  }

-- | Total enumeration of Claude Code hook events, for adapter case analysis
-- and the cross-surface intersection test.
claudeHookEvents :: [ClaudeHookEvent]
claudeHookEvents = [minBound .. maxBound]
