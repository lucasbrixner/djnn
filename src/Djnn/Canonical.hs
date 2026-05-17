{-# LANGUAGE DerivingStrategies #-}

-- | The canonical, runtime-agnostic configuration model for djnn.
--
-- This module is the __aggregator__. The per-surface schemas live as
-- independent leaves under @Djnn.Schema.*@ (the type-level shape
-- definitions); this module composes them into the single value every
-- adapter consumes, 'Canonical'. A leaf is /a/ schema; 'Canonical' is
-- /the/ composed model — naming the aggregator for what it is, not for
-- the leaf namespace.
--
-- There is deliberately __no @Djnn.Schema@ parent module__. The
-- @Djnn.Schema.*@ namespace is a set of independent leaves with no
-- parent, and the sole aggregator is this one — the same shape as
-- @ocelli@, where @Ocelli.Rules.*@ has no @Ocelli.Rules@ parent and the
-- aggregators (@Ocelli.Check@, @Ocelli.Render@) are named for their
-- role.
--
-- Two import styles are intended:
--
--   * an adapter touching one surface: @import Djnn.Schema.MCP@;
--   * the codec and full adapters: @import Djnn.Canonical@ — every
--     surface plus 'Canonical'.
--
-- The whole hierarchy is base-only with derived instances only:
-- __the canonical model is the algebra__. Serialization and invariant
-- checking are deliberately elsewhere (@Djnn.Codec@).
module Djnn.Canonical
  ( -- * Surfaces (re-exported)
    module Djnn.Schema.MCP
  , module Djnn.Schema.Hook
  , module Djnn.Schema.Approval

    -- * Composition
  , Canonical (..)
  ) where

import Djnn.Schema.Approval
import Djnn.Schema.Hook
import Djnn.Schema.MCP

-- | One project's complete canonical configuration: the composition
-- point for all surfaces. Adapters are total functions
-- @Canonical -> FileMap@; this is their sole input.
--
-- This is the current /Tier-1 slice/, not the final shape. Further
-- surfaces (plugin metadata, skills, subagents, instructions, the
-- excluded tool-policy tier) each arrive as their own @Djnn.Schema.*@
-- leaf and gain a field here — the aggregator grows, the leaves do not
-- learn about each other.
data Canonical = Canonical
  { mcpServers :: [MCPServer]
  , hooks      :: [Hook]
  , approval   :: Maybe ApprovalMode
    -- ^ 'Nothing' means "emit no approval setting" — distinct from any
    -- particular mode, so a project can stay silent and let each
    -- runtime keep its own default. Absence is a property of /this
    -- project's config/, not of the approval concept, so it lives in
    -- the composition type rather than the surface enum.
  }
  deriving stock (Eq, Show)
