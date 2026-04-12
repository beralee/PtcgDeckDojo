# Shared AI Hardening Design

## Goal

Harden the shared AI stack so newly added deck strategies are not bottlenecked by generic action ordering, shallow feature extraction, weak headless interaction fallbacks, or lossy assignment heuristics. Keep Miraidon safe by preserving a dedicated baseline copy and adding direct Miraidon-vs-Miraidon-baseline regression coverage.

## Problem

Recent `deck-strategy-iteration` loops for `charizard_ex` and `raging_bolt_ogerpon` improved deck-local behavior and passed focused tests, but fresh Miraidon benchmarks remained far below the required `>45%` gate:

- Charizard ex vs Miraidon: `30%`
- Raging Bolt Ogerpon vs Miraidon: `6%`

Those runs were clean. The remaining gap is therefore not benchmark pollution. It sits in the shared AI layers:

1. `AIOpponent` greedy strategy play is still single-step and weak at recognizing multi-step setup combos.
2. `AIHeuristics` still gives only Gardevoir and Miraidon full attach/tool control when fallback scoring runs.
3. `AIActionFeatureEncoder` only models shallow readiness and productivity signals.
4. `AILegalActionBuilder` still falls back to low-quality generic search/selection logic when strategy coverage is incomplete.
5. Counter/distribution headless selection still collapses onto a single target, which undercuts Dusknoir-style shells.

## Scope

### In Scope

1. Back up the current Miraidon strategy implementation into a dedicated baseline file for reference and direct benchmark comparison.
2. Expand shared action features so fallback layers can see:
   - active readiness
   - bench readiness
   - search productivity
   - churn risk
   - deck-out pressure
3. Let any injected deck strategy fully control attach/tool scoring in `AIHeuristics`.
4. Improve generic headless search and assignment fallback behavior in `AILegalActionBuilder`.
5. Improve counter/distribution target selection so multi-target decks are not forced into a single-target dump.
6. Add a light combo-aware greedy planning layer in `AIOpponent` so setup turns can chain enabling actions instead of only picking the single highest immediate score.
7. Add tests that keep Miraidon and Gardevoir stable while shared layers change.
8. Add a benchmark mode or executable path that compares current Miraidon to the backed-up Miraidon baseline.

### Out Of Scope

1. Rewriting MCTS or replacing the current planner with a full tree search redesign.
2. Reworking value nets, encoders, exporters, or training pipelines.
3. Deck-specific matchup hardcoding against Miraidon.
4. Broad UI changes beyond what is required to expose or run the new baseline benchmark.

## Design

### 1. Miraidon Baseline Backup

Create a dedicated baseline copy of the current Miraidon strategy implementation. This file is not the production registry target. It exists so shared-layer refactors always have a frozen tactical reference point and can be benchmarked head-to-head against the evolving live Miraidon strategy.

The live registry should continue to point at `DeckStrategyMiraidon.gd`. The baseline file should be loadable by tests and benchmark helpers, but not silently selected for normal play.

### 2. Shared Heuristic Ownership

`AIHeuristics` should stop special-casing only Gardevoir and Miraidon for attach/tool control. If a strategy has been injected through `AIOpponent.set_deck_strategy()`, shared attach/tool heuristics should treat that strategy as authoritative. Generic attach bonuses should no longer distort decks like Raging Bolt, Arceus, Lugia, or Charizard when the system falls back from absolute scoring into heuristic scoring.

### 3. Richer Shared Features

The shared action feature layer should model more of what setup and churn-heavy decks actually care about:

- whether an action improves active attack readiness
- whether it improves bench attack readiness
- whether a search action finds cards that materially unblock the current plan
- whether a draw or trainer action increases churn risk once a plan is already online
- whether deck size is under pressure and should suppress low-value cycling

This keeps fallback scoring from repeatedly favoring noisy setup or draw actions in already-stable turns.

### 4. Better Headless Fallbacks

`AILegalActionBuilder` should still prefer `score_interaction_target()` when a deck strategy implements it. But its generic fallback quality needs to improve for partially covered steps:

- search steps should prefer plan-enabling cards instead of fixed historical name lists or index-zero defaults
- assignment steps should use richer target quality, not only energy-count or static ordering
- counter distribution should support split assignment heuristics instead of always dumping all counters onto one target

This is especially important for Charizard/Dusknoir and other shells that rely on targeted non-attack damage planning.

### 5. Combo-Aware Greedy Planning

`AIOpponent` does not need a full planner rewrite, but it does need a light setup-combo layer before raw single-step absolute scoring decides the turn. The target behavior is:

- recognize when multiple non-terminal actions collectively unlock a stronger line this turn
- prefer short enabling sequences over isolated local maxima
- still end the turn cleanly when no positive line exists

This should remain bounded and deterministic, not a second full MCTS path.

## Verification Strategy

### Focused Tests

Add or extend tests for:

1. shared attach/tool control applying to any injected strategy
2. richer feature extraction for readiness, productivity, and churn pressure
3. headless search fallback quality
4. counter/distribution fallback quality
5. combo-aware greedy turn selection
6. Miraidon baseline copy availability and non-production registry behavior

### Safety Suites

Run:

- `MiraidonStrategy`
- `GardevoirStrategy`
- `AIStrategyWiring`
- shared-layer suites added in this change

### Benchmarks

Run fresh benchmarks for:

1. Miraidon vs Charizard ex
2. Miraidon vs Raging Bolt Ogerpon
3. live Miraidon vs Miraidon baseline

The Miraidon baseline benchmark exists to catch regressions where shared-layer changes lower current Miraidon quality even if other decks improve.

## Acceptance Criteria

1. Shared AI layers no longer reserve attach/tool authority for only Miraidon and Gardevoir.
2. Shared features include readiness and churn-aware signals that meaningfully affect fallback behavior.
3. Headless generic fallback behavior no longer relies on first-item or legacy Miraidon-only search assumptions.
4. Counter/distribution fallback can represent smarter multi-target choices.
5. Greedy strategy play can prefer short enabling sequences over isolated single-step maxima.
6. A dedicated Miraidon baseline strategy copy exists.
7. A direct Miraidon-vs-Miraidon-baseline benchmark path exists and runs cleanly.
8. Fresh Charizard and Raging Bolt benchmarks improve or, if they do not cross the gate yet, the remaining gap is no longer explainable by the current shared-layer defects.
