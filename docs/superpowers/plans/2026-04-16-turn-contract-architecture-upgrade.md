# Turn Contract Architecture Upgrade

## Problem

Recent deck-strategy iteration stalled across multiple decks for the same reasons:

- benchmark decisions rely on single-seed `100` game sweeps, which are too noisy for small rule changes
- `turn_plan` exists, but most runtime paths still behave like single-step greedy scoring
- decision traces do not always reflect the same scoring path that selected the action
- learned overlays can still mask or undo deck-local rule changes during diagnosis
- focused tests mostly prove wiring or pairwise score order, not turn-level ownership or sequencing

This upgrade treats those issues as one shared architecture problem instead of more per-deck tuning.

## Goals

1. Make benchmark verdicts statistically trustworthy enough to guide architecture and strategy work.
2. Make recorded decision traces match the runtime scoring path that actually chose the action.
3. Upgrade `turn_plan` into a shared turn-contract shape that can carry owner / bridge / pivot / cooldown semantics.
4. Keep current deck strategies working while providing one contract path for future deck-local upgrades.
5. Give deck iteration a controlled `rules_only` vs `rules_plus_learned` runtime mode for diagnosis.

## Non-Goals For This Round

- full teacher-target redesign
- end-to-end learned policy replacement
- full migration of every deck to hard turn-contract consumers
- changing benchmark anchor decks or matchup definitions

Those stay in follow-up phases after the runtime and evaluation signals are stable.

## Design

### 1. Multi-Seed Aggregated Benchmarking

Add support for a list of seed bases to `AITrainingTestRunner` / `AITrainingRunnerScene`.

Behavior:

- new CLI argument: `--seed-bases=13600,13700,13800`
- if omitted, runtime falls back to existing `--seed-base`
- matchup sweep and Miraidon baseline regression both aggregate across all requested seed bases
- reports expose:
  - `seed_bases`
  - `per_seed_results`
  - aggregate mean win rate
  - aggregate win-rate standard deviation
  - aggregate mean turns
  - rolled-up failure counts

Decision policy for future deck iteration:

- do not trust a single `100` game sweep by itself
- use multi-seed mean and spread as the primary acceptance signal

### 2. Unified Runtime Trace Scoring

The current greedy strategy path chooses actions with deck-local absolute scoring plus learned overlay, but decision traces still record heuristic-style scored actions in some cases.

Upgrade:

- centralize action scoring for runtime and trace into one shared helper
- traces must include the same components used by actual action selection:
  - `runtime_mode`
  - `turn_contract`
  - `absolute_score`
  - `learned_action_score`
  - `runtime_score`
  - `effective_score`
- when the greedy strategy path is active, traces must be built from that exact scored-candidate list

This makes replay review usable again.

### 3. Runtime Mode Control

Add explicit runtime scoring modes on `AIOpponent`:

- `rules_plus_learned`
- `rules_only`
- `heuristic_only`

Immediate use:

- benchmark and replay diagnosis can temporarily run `rules_only`
- deck-local rule upgrades can be evaluated without hidden learned drift

Default remains `rules_plus_learned` to preserve current behavior unless explicitly overridden.

### 4. Shared Turn Contract

Keep `build_turn_plan(...)` for backward compatibility, but normalize it into a shared contract shape.

Base contract fields:

- `id`
- `intent`
- `phase`
- `flags`
- `targets`
- `constraints`
- `context`
- `owner`
  - `turn_owner_name`
  - `bridge_target_name`
  - `pivot_target_name`
- `priorities`
  - `search`
  - `attach`
  - `handoff`
- `forbidden_action_kinds`

Compatibility rules:

- strategies may keep implementing `build_turn_plan(...)`
- base layer will normalize old-style plans into the new contract shape
- runtime continues to pass the dictionary through existing `turn_plan` plumbing so current call sites do not break

### 5. Verification

Required checks for this round:

1. Focused unit tests
   - runner arg parsing for multi-seed mode
   - benchmark aggregation math
   - greedy trace uses runtime scores, not heuristic-only scores
   - turn-contract fallback from legacy `build_turn_plan(...)`
2. Existing AI wiring suites still pass.
3. No deck strategy file is required to migrate immediately.

## Implementation Phases

### Phase A

- multi-seed benchmark aggregation
- runtime mode argument plumbing
- shared aggregation helpers

### Phase B

- unified greedy runtime trace scoring
- trace metadata for runtime mode and turn contract

### Phase C

- `build_turn_contract(...)` in `DeckStrategyBase`
- turn-contract normalization helper
- runtime / builder / resolver ask for contract first, then fall back compatibly

### Phase D

- first deck migration: Arceus Giratina
- convert existing `turn_plan` output into explicit owner / bridge / pivot contract semantics
- add turn-level scenario tests before broader rollout

## Follow-Up After This Round

- teacher shaping with main-line completion signals
- shared semantic helper audit: immediate attack windows, effective attack ownership, retreat/handoff semantics
- turn-sequence scenario tests derived from replay seeds
- migration of more decks to explicit turn-contract consumers
