module Main (main) where

import System.Environment (getArgs, getProgName)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

-- | Skeleton entry point. The subcommand surface is fixed here
-- (@init@ \/ @generate@ \/ @check@) but the commands are not yet
-- implemented: that work lands with @Djnn.Codec@ and the adapters,
-- at which point this module gains an @optparse-applicative@
-- dependency and dispatches into the library. Kept base-only and
-- @-Wall@-clean until then.
main :: IO ()
main = do
  args <- getArgs
  case args of
    ["init"]     -> notYetImplemented "init"
    ["generate"] -> notYetImplemented "generate"
    ["check"]    -> notYetImplemented "check"
    _            -> usage

notYetImplemented :: String -> IO ()
notYetImplemented cmd =
  putStrLn ("djnn " ++ cmd ++ ": not yet implemented")

usage :: IO ()
usage = do
  name <- getProgName
  hPutStrLn stderr ("usage: " ++ name ++ " (init | generate | check)")
  exitFailure
