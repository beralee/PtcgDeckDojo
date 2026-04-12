# Raging Bolt Precision Iteration Design

## Goal

Improve `DeckStrategyRagingBoltOgerpon.gd` by encoding deck-local precision rules that the current strategy is missing:

- discard the right energy for `Bellowing Thunder`
- route `Professor Sada's Vitality` energy by exact color need
- value discarding energy into the discard pile only when it actually enables Sada or future attacks
- compute the minimum energy discard needed for lethal damage instead of over-discarding

## Root Cause

The current strategy still reasons mostly in total energy counts and coarse phase scores. That is not enough for Raging Bolt:

- `Bellowing Thunder` needs exact damage conversion, not just "more energy is better"
- the current strategy does not distinguish essential `L/F` attack requirements from expendable Grass
- discard selection treats all basic energy too similarly
- Sada routing sees energy count gaps, not exact color gaps

This causes wasted energy, bad reload lines, and low conversion even after churn reduction.

## Design

Add a precise energy-planning layer inside `DeckStrategyRagingBoltOgerpon.gd`:

1. Exact attack requirement helpers
   - determine current attached energy by type
   - determine which colors are still required for the active or follow-up Bolt to attack
   - distinguish essential attack-enabling energy from expendable extra energy

2. Bellowing Thunder discard planner
   - estimate opponent KO threshold from projected damage context
   - compute the minimum extra energy discard count needed for lethal or best-available threshold
   - rank discard candidates:
     - expendable Grass on non-primary Pokemon first
     - expendable energy on follow-up Pokemon second
     - essential active Bolt attack colors last

3. Sada routing precision
   - when a Bolt lacks exact `L/F` colors, matching energy should strongly prefer that Bolt
   - when the primary Bolt is already online, Sada should route toward the next Bolt instead of overfeeding Ogerpon

4. Discard-to-discard-pile planning
   - support `Radiant Greninja` / discard-energy actions by preferring discard targets that improve future Sada and Bolt attack readiness
   - avoid discarding critical active attack colors unless no better option exists

## Verification

Add focused tests for:

- Bellowing Thunder discard ordering prefers expendable Grass before critical active attack colors
- Sada routing fills exact missing colors on Bolt
- discard-energy selection prefers enabling discard-pile energy over random basic energy loss
- minimal lethal calculator avoids over-discarding when fewer energy achieves KO

Run:

- `FutureAncientStrategies`
- `MiraidonStrategy,FutureAncientStrategies`
- fresh 100-game Miraidon vs Raging Bolt benchmark

