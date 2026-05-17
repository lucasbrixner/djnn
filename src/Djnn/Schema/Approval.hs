{-# LANGUAGE DerivingStrategies #-}

-- | The canonical approval-mode surface — the __coarse global default__
-- only.
--
-- A /leaf/ module: no @Djnn.Schema.*@ imports.
--
-- Portability tier: __Tier 1__ — every runtime exposes a single
-- "how much do you ask before acting by default" setting; the labels
-- differ but the concept is shared and converged.
--
-- __Scope boundary (read this).__ This surface is /only/ the coarse
-- default. It is __not__ the fine-grained, per-command\/per-pattern
-- execution policy — the predicate→@{allow|prompt|deny}@ layer that
-- every runtime keeps as a /separate config key/: Codex execpolicy
-- Starlark @prefix_rule()@, Gemini Policy Engine @policies\/*.toml@,
-- Claude @permissions.{allow,ask,deny}@ rule-strings, Cursor\/Copilot
-- allowlists. That is a distinct, universal __Tier-2__ surface with
-- four mutually incompatible encodings; it is documented and
-- deliberately left unmodeled in @Djnn.Schema.Policy@. 'ApprovalMode'
-- and the policy surface are never merged, because the runtimes
-- themselves never merge them (Codex has @approval_policy@ /and/
-- execpolicy @rules@; Gemini @defaultApprovalMode@ /and/ @policyPaths@;
-- Claude @defaultMode@ /and/ @{allow,ask,deny}@). Collapsing the
-- fine-grained layer into this enum would be the Tier-2
-- over-abstraction this project exists to avoid.
module Djnn.Schema.Approval
  ( ApprovalMode (..)
  ) where

-- | The shared coarse-autonomy concept (default only — see the module
-- scope boundary).
--
-- __Honest correction to the earlier "single ordinal axis" framing:__
-- this is /not/ a totally ordered scale. 'Prompt', 'AcceptEdits' and
-- 'Never' sit on one autonomy axis, but 'Plan' is a read-only
-- /restriction/ orthogonal to it — less capable than 'Prompt', not
-- "between" two autonomy levels. The runtimes themselves conflate the
-- restriction and the axis into one enum, so the canonical type mirrors
-- that single-enum shape; the derived 'Ord'\/'Enum' is declaration
-- order only and carries __no semantic meaning__. Splitting this into
-- @(autonomy, planRestriction)@ is deferred — doing it now would be
-- exactly the Tier-2 over-abstraction this project avoids.
--
-- Per-runtime mapping, and where it leaks:
--
--   * 'Prompt'      — Claude @default@, Gemini @default@, Codex
--     @on-request@. Codex also has @untrusted@ (ask for nearly
--     everything); djnn collapses both onto 'Prompt' and loses that
--     shade.
--   * 'AcceptEdits' — Claude @acceptEdits@, Gemini @auto_edit@. Codex
--     has no exact equivalent; its adapter must approximate via
--     granular approval config and should emit a warning.
--   * 'Plan'        — Claude @plan@, Gemini @plan@, Codex plan mode.
--     The cleanest correspondence of the four: all three carry a
--     first-class read-only planning mode.
--   * 'Never'       — Claude @bypassPermissions@, Codex @never@.
--     Gemini's equivalent (@yolo@) is __CLI-flag only__ and cannot be
--     set in @settings.json@. The Gemini adapter therefore cannot
--     represent 'Never' in generated config; it must surface that as an
--     explicit limitation rather than silently emit something weaker.
data ApprovalMode
  = Prompt
  | AcceptEdits
  | Plan
  | Never
  deriving stock (Eq, Show, Ord, Enum, Bounded)
