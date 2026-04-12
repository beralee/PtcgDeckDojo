# Unified Deck Strategy Refactor Design

## Goal

Unify the deck-specific AI architecture used by Gardevoir and Miraidon so that:

- both decks implement the same strategy contract
- action selection, interaction target selection, MCTS/value-net wiring, and setup planning use one consistent integration path
- headless interaction resolution and UI interaction resolution choose targets the same way
- deck detection and strategy injection are centralized instead of duplicated across `BattleScene`, `AIOpponent`, `AILegalActionBuilder`, and `AIHeuristics`

This refactor is intended to remove the known architectural drift that accumulated while both decks were developed incrementally.

## Current Problems

### 1. Strategy contract drift

`DeckStrategyMiraidon.gd` already implements a more complete interaction-scoring surface, while `DeckStrategyGardevoir.gd` still exposes several specialized helper methods that are consumed directly by other systems:

- `pick_search_item`
- `pick_search_tool`
- `pick_embrace_target`
- `score_assignment_target`

That means the effective strategy contract is implicit and inconsistent.

### 2. Two target-selection pipelines

Interaction targets are currently chosen through two separate paths:

- `AIStepResolver` uses `score_interaction_target()`
- `AILegalActionBuilder` uses deck-specific helper methods and hardcoded fallback rules

As a result, headless execution and UI-driven interaction can make different choices for the same effect.

### 3. Duplicated deck detection

Deck-family detection is currently split across multiple files and does not behave symmetrically:

- `AIOpponent.gd`
- `AIHeuristics.gd`
- `AILegalActionBuilder.gd`
- `BattleScene.gd`

Miraidon also still relies on builder-level hardcoded preferences in places where strategy logic should own the decision.

### 4. MCTS encoder wiring is not stable

`BattleScene` injects deck-specific encoders, but `AIOpponent._choose_mcts_action()` overwrites `state_encoder_class` with the generic encoder before planning. This breaks the intended contract between deck strategy, value net, and MCTS.

### 5. Multiple strategy instances can diverge

Different subsystems may instantiate their own strategy objects independently. That creates unnecessary duplication and risks inconsistent state or configuration between:

- heuristics
- action builder
- step resolver
- MCTS planner

## Chosen Approach

Use a unified strategy-contract refactor rather than a minimal patch.

This keeps the current deck knowledge and heuristics but standardizes the architecture around three new shared components:

1. `DeckStrategyBase.gd`
2. `DeckStrategyRegistry.gd`
3. `AIInteractionPlanner.gd`

This is the smallest refactor that removes the current architectural splits instead of hiding them.

## Architecture

### DeckStrategyBase

Introduce a shared base contract for deck-specific strategy classes. Both Gardevoir and Miraidon strategies will implement or inherit the same external surface:

- `get_strategy_id()`
- `get_signature_names()`
- `get_state_encoder_class()`
- `load_value_net(path)`
- `get_value_net()`
- `get_mcts_config()`
- `plan_opening_setup(player)`
- `score_action_absolute(action, game_state, player_index)`
- `score_action(action, context)`
- `evaluate_board(game_state, player_index)`
- `predict_attacker_damage(slot, extra_context := 0)`
- `get_discard_priority(card)`
- `get_discard_priority_contextual(card, game_state, player_index)`
- `get_search_priority(card)`
- `score_interaction_target(item, step, context := {})`

Deck-specific helper methods may still exist internally, but external systems must stop depending on them directly.

### DeckStrategyRegistry

Introduce a single registry responsible for:

- deck-family detection from visible cards
- strategy instantiation
- exposing known strategies and their signatures

All AI entry points should use this registry instead of maintaining private detection logic.

### AIInteractionPlanner

Introduce a shared interaction-selection component that takes:

- `deck_strategy`
- interaction step data
- optional planning context

It will be used by:

- `AIStepResolver`
- `AILegalActionBuilder` headless target generation

This ensures both code paths sort and choose targets through the same scoring logic.

### AIOpponent as the integration hub

`AIOpponent` becomes the single owner of the active strategy instance for a match-side.

Add a strategy injection path such as `set_deck_strategy(strategy)` that synchronizes:

- `_deck_strategy`
- `_mcts_planner.deck_strategy`
- `_mcts_planner.state_encoder_class`
- `_step_resolver.deck_strategy`
- `_legal_action_builder.deck_strategy`
- `_heuristics.deck_strategy`

This removes ad-hoc strategy wiring from multiple subsystems.

## Data Flow After Refactor

The intended runtime path becomes:

`BattleScene` or `AIOpponent` determines the deck strategy
-> `AIOpponent.set_deck_strategy()`
-> shared strategy instance is propagated to builder, resolver, heuristics, and MCTS
-> action selection uses `score_action_absolute()` / `score_action()`
-> interaction targets use `AIInteractionPlanner` + `score_interaction_target()`
-> board evaluation and value-net inference use `get_state_encoder_class()` and `get_value_net()`

This makes strategy behavior consistent regardless of whether the action is evaluated by heuristics, greedy deck logic, MCTS, or headless effect resolution.

## Gardevoir Changes

Gardevoir will be brought up to the same architectural standard as Miraidon.

Key changes:

- add unified `score_interaction_target()` coverage for search, discard, assignment, and Embrace target selection
- keep existing internal helper logic where useful, but route it through the unified interface
- stop exposing builder-facing special cases as required integration hooks
- migrate value-net and encoder access to the shared contract

Behavioral fixes are allowed where current heuristics are clearly wrong, because this refactor is not intended to preserve flawed behavior for compatibility.

## Miraidon Changes

Miraidon becomes the reference implementation for the contract shape, but builder-level hardcoding will be removed.

Key changes:

- remove Miraidon-specific hardcoded search and assignment logic from `AILegalActionBuilder`
- rely on strategy-provided interaction scoring instead
- migrate value-net and encoder access to the shared contract
- preserve current deck-specific tactical preferences unless a clear heuristic bug is found during test-first refactoring

## Testing Strategy

This refactor will be implemented with test-first changes.

Required coverage:

1. Strategy contract tests
   - both deck strategies expose the unified required methods

2. Registry detection tests
   - Gardevoir and Miraidon decks resolve to the expected strategy id through the shared registry

3. Interaction planner parity tests
   - the same interaction step yields the same chosen target in both resolver-driven and headless-builder-driven paths

4. Gardevoir interaction regression tests
   - search
   - discard
   - assignment
   - Embrace target selection

5. Miraidon de-hardcoding tests
   - search and energy-target decisions still work after builder hardcoding is removed

6. Encoder preservation tests
   - deck-specific encoder wiring survives through MCTS planning and trace generation

## Risks

### Behavior drift

Because both decks contain large handcrafted heuristics, unifying the interface may unintentionally change some action ordering. This is acceptable only when:

- the old behavior depended on architecture drift
- the new behavior is covered by explicit tests

### Broad integration surface

The affected AI systems are tightly connected. To control risk:

- centralize strategy wiring in `AIOpponent`
- refactor target selection behind a dedicated planner
- keep changes inside the AI stack instead of restructuring unrelated gameplay systems

## Non-Goals

- no full data-driven strategy DSL
- no broad decomposition of every strategy file into many policy files
- no unrelated AI balance work outside Gardevoir and Miraidon
- no changes to training pipelines beyond what is needed for the new unified strategy contract
