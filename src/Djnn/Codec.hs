{-# LANGUAGE DerivingStrategies #-}

-- | The validation algebra.
--
-- This module is, by deliberate split, /only/ validation: a
-- (possibly-illegal) 'Canonical' in, a certified 'Canonical' or a
-- non-empty bag of errors out. __Decoding__ — turning authored text in
-- some concrete format into 'Canonical' values — is a separate, later
-- module (e.g. @Djnn.Codec.Yaml@) so the parser dependency it requires
-- stays isolated and deferred. Keeping this module base-only and
-- effect-free is the same discipline as "the schema is the algebra":
-- here, __the codec is the validation algebra__.
--
-- It is also the only place surfaces are validated /together/: the
-- @Djnn.Schema.*@ leaves never see each other; @Djnn.Canonical@
-- composes them; this module is where cross-surface invariants (e.g.
-- server-name uniqueness across the whole config) are enforced.
--
-- 'CodecError' is the complete vocabulary of "invalid", even for
-- errors that structurally fire at /decode/ time rather than here —
-- see 'UnknownHookEvent'. The error type is the single auditable
-- source of truth for what a valid djnn config is; the layer that
-- /produces/ each error may differ.
module Djnn.Codec
  ( -- * Errors
    CodecError (..)

    -- * Accumulating validation
  , Validation (..)
  , runValidation

    -- * Validators
  , validate
  , validateCanonical
  , validateMCPServer
  ) where

import Data.Foldable (traverse_)
import Data.List (group, sort)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NE
import Data.Maybe (isJust)

import Djnn.Canonical

-- ---------------------------------------------------------------------
-- Error vocabulary
-- ---------------------------------------------------------------------

-- | Every way an authored djnn configuration can be invalid.
--
-- This enumeration /is/ the specification: a config is valid exactly
-- when none of these can be produced for it. Each constructor carries
-- enough context to render an actionable message.
--
-- 'UnknownHookEvent' is included here for completeness even though no
-- validator in this module produces it: the @HookEvent@ type cannot
-- represent a non-canonical event, so that check necessarily lives in
-- the decoder (string → 'HookEvent'), not in post-construction
-- validation. The vocabulary is unified; the firing site is not.
data CodecError
  -- | A 'Stdio' server with no command to spawn (server name).
  = StdioMissingCommand String
  -- | An 'Http'/'Sse' server with no URL to reach (server name).
  | RemoteMissingUrl String
  -- | The same env var set twice on one server (server, key).
  | DuplicateEnvKey String String
  -- | Two MCP servers share a name (the repeated name). Every
  -- runtime keys its server map by name, so this is unrepresentable
  -- downstream.
  | DuplicateServerName String
  -- | The authored source named a hook event outside the canonical
  -- "Claude ∩ Codex" set. Produced by the decoder, never here.
  | UnknownHookEvent String
  deriving stock (Eq, Show)

-- ---------------------------------------------------------------------
-- Accumulating validation
-- ---------------------------------------------------------------------

-- | An accumulating applicative. Unlike 'Either', '<*>' collects
-- errors from /both/ sides instead of short-circuiting, so a single
-- run reports every problem in a config rather than the first.
--
-- There is intentionally __no 'Monad' instance__: '>>=' would
-- necessarily short-circuit, which is exactly the behaviour this type
-- exists to avoid. Validation is applicative by design, not by
-- omission.
data Validation e a
  = Failure e
  | Success a
  deriving stock (Eq, Show)

instance Functor (Validation e) where
  fmap _ (Failure e) = Failure e
  fmap f (Success a) = Success (f a)

instance Semigroup e => Applicative (Validation e) where
  pure = Success

  Failure e1 <*> Failure e2 = Failure (e1 <> e2)
  Failure e1 <*> Success _  = Failure e1
  Success _  <*> Failure e2 = Failure e2
  Success f  <*> Success a  = Success (f a)

-- | Collapse to a plain 'Either' at the boundary, so callers and the
-- effectful decode/IO edge work with an ordinary result.
runValidation :: Validation e a -> Either e a
runValidation (Failure e) = Left e
runValidation (Success a) = Right a

-- | Assert a single invariant.
check :: Bool -> CodecError -> Validation (NonEmpty CodecError) ()
check True  _ = Success ()
check False e = Failure (e :| [])

-- | Elements that occur more than once.
--
-- Total: @group . sort@ yields only non-empty groups, so the
-- @(x : rest)@ generator drops nothing.
duplicates :: Ord a => [a] -> [a]
duplicates xs = [x | (x : rest) <- group (sort xs), not (null rest)]

-- ---------------------------------------------------------------------
-- Validators
-- ---------------------------------------------------------------------

-- | Certify one MCP server.
--
-- This carries the invariant deliberately left /unencoded/ in
-- @Djnn.Schema.MCP@ for YAML-round-trip reasons: the transport decides
-- which of @command@/@url@ must be present. Duplicate env keys are
-- reported one error per offending key, with the accumulating
-- applicative doing real work.
validateMCPServer :: MCPServer -> Validation (NonEmpty CodecError) MCPServer
validateMCPServer s = s <$ (transportOK *> envOK)
  where
    transportOK =
      case mcpTransport s of
        Stdio ->
          check
            (isJust (mcpCommand s))
            (StdioMissingCommand (mcpName s))

        _ ->
          check
            (isJust (mcpUrl s))
            (RemoteMissingUrl (mcpName s))

    envOK =
      case duplicates (map fst (mcpEnv s)) of
        [] ->
          Success ()

        dups ->
          Failure
            (NE.fromList
              [ DuplicateEnvKey (mcpName s) key
              | key <- dups
              ])

-- | Certify a whole configuration: server-name uniqueness across the
-- config, plus every server.
--
-- Hooks and approval are absent here on purpose. There is nothing to
-- check: the @HookEvent@ enum and the well-typed @HookHandler@ already
-- made illegal hooks unrepresentable, and 'Maybe' 'ApprovalMode' has
-- no invalid inhabitant. The codec validates exactly the invariants
-- the types consciously declined to encode — that correspondence is
-- the layering auditing itself.
validateCanonical :: Canonical -> Validation (NonEmpty CodecError) Canonical
validateCanonical c = c <$ (uniqueNames *> eachServer)
  where
    uniqueNames =
      case duplicates (map mcpName (mcpServers c)) of
        [] ->
          Success ()

        dups ->
          Failure
            (NE.fromList
              [ DuplicateServerName name
              | name <- dups
              ])

    eachServer =
      traverse_ validateMCPServer (mcpServers c)

-- | The boundary entry point: validate, as an ordinary 'Either'.
validate :: Canonical -> Either (NonEmpty CodecError) Canonical
validate = runValidation . validateCanonical
