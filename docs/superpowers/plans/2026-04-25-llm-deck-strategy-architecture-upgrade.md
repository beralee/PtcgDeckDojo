# LLM Deck Strategy Architecture Upgrade

Date: 2026-04-25
Status: decision-tree runtime implemented

## Goal

Upgrade the current LLM deck strategy runtime from "main-action ordering" to "one LLM decision tree per turn plus rules-owned execution".

The first target is Raging Bolt Ogerpon LLM, but the implementation must be reusable by future LLM strategies for Gardevoir, Charizard, Arceus, and other decks.

## Current Runtime Shape

Current flow:

```text
BattleScene._run_ai_step()
-> AIOpponent.run_single_step()
   -> pending effect_interaction: AIStepResolver.resolve_pending_step()
   -> main phase action: AIOpponent._choose_greedy_strategy_action()
      -> DeckStrategyRagingBoltLLM.score_action_absolute()
```

Previous LLM control:

- `DeckStrategyRagingBoltLLM` receives an LLM action queue.
- Main actions matching the queue receive very high scores.
- The engine executes the highest scoring legal action.

Current gap:

- LLM response already includes `discard_choice` and `search_target`.
- Those fields are parsed by `LLMTurnPlanPromptBuilder`.
- They are not consumed by interaction resolution.
- Therefore the LLM can choose "play Earthen Vessel" but cannot reliably choose what to discard or what to search.

Second gap found in UI testing:

- Short-horizon replanning improves accuracy but waits for the LLM multiple times in one turn.
- This is not viable for interactive AI battle flow.
- The runtime must call the LLM once at turn start, then let rules code execute and branch locally.

## Design Principles

1. Keep legality in the engine.

LLM should express intent, not bypass legal action validation.

2. Make interaction control generic.

`AIStepResolver` should pass current effect context. It should not know Raging Bolt card logic.

3. Use one LLM call per turn.

LLM should return a decision tree covering expected turn branches. Search, draw, discard, supporter use, and manual attachment update the state, but the rules runtime should switch branches without another LLM request.

4. Always preserve rules fallback.

If an LLM intent cannot be matched to legal candidates, fall back to the existing deck strategy rules.

5. Test full interaction chains.

Focused tests should assert that an LLM queue item controls the follow-up discard/search/assignment choices, not just that a main action gets a high score.

## Target Architecture

```text
LLM response
  decision_tree:
    branches:
      - when: [{fact: hand_has_card, card: <JSON name/name_en>}]
        actions:
          - type: play_trainer
            card: <JSON name/name_en>
            discard_choice: <JSON name/name_en or energy type>
            search_target: <JSON name/name_en or energy type>
        then:
          branches:
            - when: [{fact: energy_not_attached}]
              actions: [...]
    fallback_actions: [...]

DeckStrategyRagingBoltLLM
  -> cache decision_tree once per turn
  -> LLMDecisionTreeExecutor.select_action_queue(current game_state)
  -> main action scoring from selected branch actions
  -> LLMInteractionIntentBridge.pick_interaction_items()
  -> LLMInteractionIntentBridge.score_interaction_target()

AIStepResolver
  -> passes pending_effect_card/kind/slot into context
  -> asks deck_strategy for explicit interaction picks
  -> falls back to normal strategy scoring if no explicit LLM match
```

## Data Contract

LLM action item fields:

- `type`: action type, such as `play_trainer`, `use_ability`, `attack`.
- `card`: card name for card-originated actions.
- `pokemon`: Pokemon name for ability-originated actions.
- `discard_choice`: comma-separated card names or energy-type names to discard.
- `search_target`: comma-separated card names or energy-type names to search or select as sources.
- `target`: Pokemon target name for assignment or field target choices.
- `position`: optional target slot label, such as `active`, `bench_0`, `bench_1`.
- `bench_target` and `bench_position`: retreat or switch target hints.
- `attack_name`: attack disambiguation.

Runtime context fields added by `AIStepResolver`:

- `pending_effect_kind`
- `pending_effect_card`
- `pending_effect_slot`
- `pending_effect_ability_index`

Decision tree node fields:

- `actions`: ordered action intents to try when the node is active.
- `branches`: ordered candidate branches. The first branch whose `when` list matches is selected.
- `fallback_actions`: conservative actions used when no branch matches.
- `then`: optional child node for additional branching after the branch actions.

Supported condition facts in `LLMDecisionTreeExecutor`:

- `always`
- `can_attack`
- `can_use_supporter`
- `energy_not_attached`
- `energy_attached_this_turn`
- `supporter_not_used`
- `supporter_used_this_turn`
- `retreat_not_used`
- `retreat_used_this_turn`
- `hand_has_card`
- `discard_has_card`
- `hand_has_type`
- `discard_basic_energy_count_at_least`
- `active_has_energy_at_least`
- `active_attack_ready`
- `has_bench_space`

Unknown condition facts intentionally do not match. This keeps legality and branch selection owned by deterministic rules code, not natural-language guesses.

## Phase 1 Implementation Plan

Files:

- Add `scripts/ai/LLMInteractionIntentBridge.gd`
- Add `scripts/ai/LLMDecisionTreeExecutor.gd`
- Modify `scripts/ai/AIStepResolver.gd`
- Modify `scripts/ai/DeckStrategyRagingBoltLLM.gd`
- Modify `scripts/ai/LLMTurnPlanPromptBuilder.gd`
- Modify `tests/test_llm_interaction_bridge.gd`

Implementation steps:

1. Add `LLMInteractionIntentBridge`.
2. Add effect-origin context in `AIStepResolver.resolve_pending_step()`.
3. Delegate Raging Bolt LLM interaction picks and target scores to the bridge.
4. Add `LLMDecisionTreeExecutor` for deterministic branch selection from current state.
5. Change prompt schema from `actions[]` to `decision_tree`.
6. Remove in-turn LLM replanning from `DeckStrategyRagingBoltLLM`.
7. Add tests for branch switching, no replan, discard choice, search target, assignment source, and assignment target.

Acceptance:

- LLM queue can force Earthen Vessel discard choice.
- LLM queue can force Earthen Vessel energy search targets.
- LLM queue can force Sada energy source selection.
- LLM queue can bias Sada assignment target by name/position.
- One LLM decision tree can switch branches after state changes without another LLM request.
- Existing rule fallback still works when no LLM interaction item matches.

## Phase 2 Plan

State summary:

- Add a human-readable `situation_summary`.
- Include active attacker gaps, discard fuel, supporter availability, manual attachment status, and immediate KO windows.

Tree quality:

- Add focused tests from UI traces where the tree must cover draw/search outcomes.
- Add branch coverage telemetry: which branch matched, which conditions failed, and which fallback was used.
- Add guardrails for trees that overuse unsupported condition facts.

## Phase 3 Plan

Deck-agnostic LLM strategy shell:

- Extract shared LLM request/cache/queue code from `DeckStrategyRagingBoltLLM`.
- Let deck-specific classes provide prompt rules and examples.
- Reuse the same interaction bridge for all LLM deck strategies.

## Non-Goals For Phase 1

- No MCTS plus LLM evaluator integration.
- No learned model changes.
- No replacement of existing rule strategies.
- No direct illegal action execution from LLM output.
