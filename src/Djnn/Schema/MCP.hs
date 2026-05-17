{-# LANGUAGE DerivingStrategies #-}

-- | The canonical MCP-server surface.
--
-- A /leaf/ module: it imports no other @Djnn.Schema.*@ surface and must
-- never gain one. Cross-surface concerns (e.g. a hook that references a
-- server by name) compose in @Djnn.Canonical@ and validate in
-- @Djnn.Codec@, not here.
--
-- Portability tier: __Tier 1__ — Claude Code (@.mcp.json@), Gemini CLI
-- (@mcpServers@) and Codex (@[mcp_servers]@) converged on the same
-- shape, not merely the same idea.
module Djnn.Schema.MCP
  ( MCPServer (..)
  , Transport (..)
  ) where

-- | How djnn reaches an MCP server.
--
-- All three schema-publishing runtimes distinguish a locally spawned
-- process from a remote endpoint. 'Sse' is the legacy remote transport;
-- 'Http' (streamable HTTP) is its successor. The two are kept distinct
-- rather than merged because Claude still emits a @"type"@ discriminator
-- and the rendered key differs by transport, so the adapter genuinely
-- needs to know which one was meant.
data Transport
  = Stdio
  | Http
  | Sse
  deriving stock (Eq, Show, Ord, Enum, Bounded)

-- | A single MCP server entry, keyed by 'mcpName' in every runtime's
-- server map.
--
-- Field portability:
--
--   * 'mcpName', 'mcpEnv' — universal across all runtimes.
--   * 'mcpCommand', 'mcpArgs' — meaningful for 'Stdio'; ignored for
--     remote transports.
--   * 'mcpUrl' — meaningful for 'Http'\/'Sse'; ignored for 'Stdio'.
--
-- The @(transport, command\/url)@ coupling is a real invariant, left
-- __unencoded__ in the type on purpose. A GADT or refinement making
-- illegal states unrepresentable would not survive a YAML round-trip
-- cleanly, and the authored source is the thing humans edit. The
-- invariant is checked once, in @Djnn.Codec@, on the way in.
data MCPServer = MCPServer
  { mcpName      :: String
  , mcpTransport :: Transport
  , mcpCommand   :: Maybe String
  , mcpArgs      :: [String]
  , mcpUrl       :: Maybe String
  , mcpEnv       :: [(String, String)]
    -- ^ Association list rather than a @Map@ to keep this module
    -- base-only and trivially serializable. Duplicate-key rejection is
    -- a codec concern. A @Map@ swap is an obvious post-v0 refinement.
  }
  deriving stock (Eq, Show)
