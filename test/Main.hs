module Main (main) where

import Data.List.NonEmpty (NonEmpty (..))
import Test.Tasty
import Test.Tasty.HUnit

import Djnn.Codec
import Djnn.Canonical
import Djnn.Schema.MCP

main :: IO ()
main =
  defaultMain tests

tests :: TestTree
tests =
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
