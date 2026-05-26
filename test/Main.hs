module Main (main) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.List (intersect, sort)
import Test.Tasty
import Test.Tasty.HUnit

import Djnn.Codec
import Djnn.Canonical
import Djnn.Surface.Hook.Claude (claudeHookEvents)
import Djnn.Surface.Hook.Codex  (codexHookEvents)
import Djnn.Schema.MCP

main :: IO ()
main =
  defaultMain tests

tests :: TestTree
tests =
  testGroup
    "djnn"
    [ codecTests
    , hookTests
    ]

codecTests :: TestTree
codecTests =
  testGroup
    "Djnn.Codec"
    [ testCase "valid stdio server succeeds" $
        validateMCPServer goodStdio
          @?= Success goodStdio

    , testCase "stdio server requires command" $
        validateMCPServer badStdio
          @?= Failure
                (StdioMissingCommand "bad-stdio" :| [])

    , testCase "remote server requires url" $
        validateMCPServer badHttp
          @?= Failure
                (RemoteMissingUrl "bad-http" :| [])

    , testCase "duplicate env keys are accumulated" $
        validateMCPServer duplicateEnv
          @?= Failure
                ( DuplicateEnvKey "dup-env" "PATH"
                :| [ DuplicateEnvKey "dup-env" "TOKEN" ]
                )

    , testCase "transport and env errors accumulate" $
        validateMCPServer veryBad
          @?= Failure
                ( StdioMissingCommand "very-bad"
                :| [ DuplicateEnvKey "very-bad" "TOKEN" ]
                )
    ]

hookTests :: TestTree
hookTests =
  testGroup
    "Djnn.Schema.Hook"
    [ testCase "UserPromptSubmit is a canonical hook event" $
        assertBool
          "UserPromptSubmit must be in canonicalHookEvents"
          (UserPromptSubmit `elem` canonicalHookEvents)
    , testCase "canonical events are exactly the Claude-Codex set" $
        sort canonicalHookEvents
          @?= sort
                [ SessionStart
                , UserPromptSubmit
                , PreToolUse
                , PostToolUse
                , Stop
                , SubagentStart
                , SubagentStop
                , PreCompact
                , PostCompact
                , PermissionRequest
                ]
    , testCase "canonicalHookEvents matches Claude ∩ Codex bare-name intersection" $
        sort (map show canonicalHookEvents)
          @?= sort (claudeBareNames `intersect` codexBareNames)
    ]

baseServer :: MCPServer
baseServer =
  MCPServer
    { mcpName      = "server"
    , mcpTransport = Stdio
    , mcpCommand   = Nothing
    , mcpArgs      = []
    , mcpUrl       = Nothing
    , mcpEnv       = []
    }

goodStdio :: MCPServer
goodStdio =
  baseServer
    { mcpName      = "postgres"
    , mcpTransport = Stdio
    , mcpCommand   = Just "postgres-mcp"
    , mcpEnv       = [("DATABASE_URL", "postgres://example")]
    }

badStdio :: MCPServer
badStdio =
  goodStdio
    { mcpName    = "bad-stdio"
    , mcpCommand = Nothing
    }

badHttp :: MCPServer
badHttp =
  baseServer
    { mcpName      = "bad-http"
    , mcpTransport = Http
    }

duplicateEnv :: MCPServer
duplicateEnv =
  goodStdio
    { mcpName = "dup-env"
    , mcpEnv =
        [ ("TOKEN", "abc")
        , ("TOKEN", "def")
        , ("PATH", "/tmp")
        , ("PATH", "/usr/bin")
        ]
    }

veryBad :: MCPServer
veryBad =
  goodStdio
    { mcpName = "very-bad"
    , mcpCommand = Nothing
    , mcpEnv =
        [ ("TOKEN", "abc")
        , ("TOKEN", "def")
        ]
    }

-- | Bare event names with the agent prefix stripped, for the Claude ∩ Codex
-- assertion against canonicalHookEvents.
claudeBareNames, codexBareNames :: [String]
claudeBareNames = map (drop (length "Claude") . show) claudeHookEvents
codexBareNames  = map (drop (length "Codex")  . show) codexHookEvents
