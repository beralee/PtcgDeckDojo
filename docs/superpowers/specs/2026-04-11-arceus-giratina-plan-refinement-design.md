# Arceus Giratina Plan Refinement Design

## Goal

Refine `DeckStrategyArceusGiratina` so its opening plan, midgame transition, and endgame conversion are more faithful to the deck's real game plan while staying matchup-generic. Success is defined first by more coherent code-level behavior and second by any win-rate gain versus Miraidon.

## Context

The current `Arceus Giratina` strategy is now functionally active after the shared name-resolution fix, and it can compete with Miraidon. In a fresh `100`-game sweep on `2026-04-11`, it scored `42%` versus Miraidon with clean endings and no prompt or action-cap pollution.

That result shows two things:

- the strategy is no longer dead-on-arrival
- the remaining gap is now about plan quality, not wiring failure

The current implementation already encodes the broad idea of `Arceus first, Giratina later`, but the plan is still too implicit. Its priorities are spread across isolated scoring functions, which makes the strategy overly static and too willing to split early resources across support pieces or keep feeding Arceus after the first attack lane is already online.

## In Scope

1. Refine `DeckStrategyArceusGiratina.gd` to model the deck as a staged plan:
   - opening setup and launch
   - post-launch transition
   - endgame conversion
2. Add focused tests that verify the intended opening and transition behavior directly.
3. Re-run a fresh `100`-game Miraidon benchmark after the refinement.

## Out Of Scope

1. Matchup-specific overrides that explicitly detect Miraidon.
2. New value-net, encoder, or self-play exporter work for Arceus Giratina.
3. Reworking unrelated decks.
4. Changing the unified strategy architecture.

## Current Problems

### 1. Opening priorities are not explicit enough

The strategy correctly values `Arceus V`, `Arceus VSTAR`, and `Double Turbo Energy`, but it still treats several support-line actions as independently strong instead of subordinate to the first `Trinity Nova` launch.

This leads to a weak distinction between:

- cards required to launch the first attacker
- cards that are merely good follow-up pieces

### 2. Transition logic is too soft

The strategy knows Giratina matters, but it does not clearly recognize the moment when Arceus has already done its job and future resources should swing to Giratina. In practice this means:

- searches can remain too Arceus-centric after launch
- energy assignment can overfeed the first attacker
- Giratina can come online one turn late

### 3. Endgame value is under-modeled

The current attack and board evaluation logic rewards generic damage and board presence, but it does not strongly encode the value of a fully prepared Giratina finish line once Arceus has stabilized the board.

## Design

### 1. Make the deck plan explicit

The strategy should operate around three named internal phases:

- `launch`: establish `Arceus V`, evolve, and enable the first `Trinity Nova`
- `transition`: use the first attacker to build Giratina and hand off the main plan
- `convert`: prioritize Giratina completion and closing lines over extra Arceus investment

This does not need a new public interface. It should live as internal helpers in `DeckStrategyArceusGiratina.gd`.

### 2. Opening discipline favors launch over convenience

Before launch is complete:

- `Arceus V`, `Arceus VSTAR`, and launch-enabling energy should outrank convenience pieces
- `Ultra Ball`, `Nest Ball`, and `Capturing Aroma` should score based on whether they close the launch gap
- `Bibarel`, `Skwovet`, and non-core techs should remain useful but secondary

The deck should still bench support pieces when the board can afford it, but not at the expense of the launch line.

### 3. Transition should be keyed off completed Arceus setup, not just turn count

The strategy's phase helper should stop relying mostly on turn count and rough energy checks. Transition should begin when Arceus is evolved and either:

- can already attack cleanly, or
- is one step from attacking with the necessary line clearly in hand/on board

Once that threshold is crossed:

- generic energy and search priorities should start leaning toward Giratina
- Arceus should stop consuming premium follow-up resources unless it is still the cleanest immediate line

### 4. Endgame conversion should reward Giratina readiness more strongly

Once the deck is past launch:

- Giratina evolution, energy attachment, and assignment targets should be upgraded
- support/trainers that help convert the next prize map should outrank low-impact setup actions
- attack scoring should reflect the difference between generic pressure and true finisher progression

### 5. Preserve matchup-generic behavior

No logic in this pass should branch on a specific opposing deck. The plan should be correct because it is a better model of Arceus Giratina, not because it contains Miraidon-specific counterweights.

## Components

### `scripts/ai/DeckStrategyArceusGiratina.gd`

Primary implementation file.

Responsibilities:

- introduce clearer internal phase helpers
- refine setup, search, attach, ability, assignment, attack, and evaluation logic
- keep all changes inside the existing unified strategy contract

### `tests/test_vstar_engine_strategies.gd`

Primary focused coverage for Arceus Giratina.

Responsibilities:

- verify launch-first behavior
- verify post-launch transition toward Giratina
- verify endgame-oriented search and attachment priorities

## Data Flow

`AIOpponent`
-> unified strategy contract
-> `DeckStrategyArceusGiratina.score_action_absolute()`
-> phase helper decides `launch / transition / convert`
-> scoring functions interpret card and target value through that phase
-> `score_interaction_target()` and `evaluate_board()` reinforce the same plan

## Error Handling

- If the deck lacks the expected core pieces, the strategy should degrade to the best available fallback rather than returning near-zero scores everywhere.
- If Arceus is missing entirely, the strategy can fall back to Giratina and draw-support setup, but that path must remain clearly secondary when Arceus is available.
- The refinement must not introduce prompt loops, action-cap regressions, or strategy-contract regressions.

## Testing

Focused tests must verify at least:

1. launch-first setup when both Arceus and support pieces are available
2. search and attachment preference for launch completion before overdeveloping support
3. post-launch shift of generic energy and search toward Giratina
4. stronger valuation of endgame conversion once Giratina is near ready

Verification after implementation:

- targeted focused suite for VSTAR engine strategies
- fresh `100`-game Miraidon versus Arceus benchmark

## Acceptance Criteria

1. `DeckStrategyArceusGiratina` encodes a visible staged plan instead of a flat set of unrelated priorities.
2. Focused tests demonstrate correct opening and transition behavior.
3. A fresh `100`-game Miraidon benchmark completes cleanly.
4. The final report explains both the behavior change and the benchmark result, even if the win rate only improves modestly.
