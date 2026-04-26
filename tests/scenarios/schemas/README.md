# Scenario Schema Notes

This directory documents the stable master-side expectations for scenario json files.

## Required top-level keys

- `scenario_id`
- `deck_id`
- `tracked_player_index`
- `state_at_turn_start`
- `expected_end_state`
- `approved_divergent_end_states`

## Master-side guarantees

- `ScenarioCatalog.gd` recursively discovers `*.json` files under a scenario root.
- `ScenarioRunner.gd` returns structured `ERROR` payloads when worker-owned dependencies are absent.
- `ScenarioRunner.gd` only runs the tracked turn in `rules_only` mode unless explicitly overridden by the caller.

## Dependency handoff points

The master runner integrates three worker-owned modules by path:

- `res://scripts/engine/scenario/ScenarioStateRestorer.gd`
- `res://scripts/ai/scenario_comparator/ScenarioEquivalenceRegistry.gd`
- `res://scripts/ai/scenario_comparator/ScenarioEndStateComparator.gd`

Until those files exist, smoke tests assert that dependency failures are surfaced cleanly instead of crashing.
