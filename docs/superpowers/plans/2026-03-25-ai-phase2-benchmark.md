# AI Phase 2 Benchmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a stable headless `AI vs AI` runner and first structured benchmark suite for the pinned Miraidon, Gardevoir, and Charizard ex decks.

**Architecture:** Extract Phase 1's ad-hoc headless bridge into a first-class runner component, then layer a typed benchmark-case contract, deck-identity tracking, and result aggregation on top. Keep using `GameStateMachine`, `AIOpponent`, `AILegalActionBuilder`, and `AIStepResolver`; Phase 2 should strengthen orchestration and evaluation, not invent a second rules system.

**Tech Stack:** Godot 4, GDScript, existing `GameStateMachine` / `EffectProcessor` / `AIOpponent`, custom headless test runner in `tests/TestRunner.gd`

---

## Scope Check

This plan intentionally covers one coherent Phase 2 effort:

1. stable headless runner
2. benchmark-case contract
3. deck identity tracking
4. result aggregation
5. fixed benchmark suite for three pinned decks
6. regression gates

It does **not** cover:

1. stronger heuristics
2. self-play training
3. MCTS
4. deck-matrix generation

## File Map

### Create

- `scripts/ai/HeadlessMatchBridge.gd`
  First-class headless battle bridge responsible for prompt ownership, setup bootstrap, progress detection, and all bridge-owned prompt resolution (`mulligan / setup / take_prize / send_out`).

- `scripts/ai/DeckBenchmarkCase.gd`
  Typed benchmark contract holding pinned deck references, comparison mode, seeds, match count, and agent configs.

- `scripts/ai/DeckIdentityTracker.gd`
  Computes the boolean `identity_hits` contract for Miraidon, Gardevoir, and Charizard ex from a completed match.

- `scripts/ai/BenchmarkEvaluator.gd`
  Aggregates single-match results into pairing summaries, per-event identity breakdowns, JSON-ready dictionaries, and text summaries.

- `tests/test_headless_match_bridge.gd`
  Focused unit tests for start-game bootstrap, prompt ownership, progress detection, and failure classification.

- `tests/test_benchmark_evaluator.gd`
  Focused tests for summary aggregation, per-event identity rates, and text output.

- `tests/test_ai_phase2_benchmark.gd`
  Integration-style tests for benchmark cases, pinned deck resolution, shared-agent mirror runs, and version-regression contract.

### Modify

- `scripts/ai/AIBenchmarkRunner.gd`
  Shrink this file back to orchestration logic that composes the new bridge, case contract, identity tracker, and evaluator.

- `tests/test_ai_benchmark.gd`
  Keep only baseline runner smoke coverage here; move Phase 2-specific assertions into the new dedicated suites.

- `tests/TestRunner.gd`
  Register the new Phase 2 test suites.

### Reuse Without Changing Unless Needed

- `scripts/ai/AIOpponent.gd`
- `scripts/ai/AILegalActionBuilder.gd`
- `scripts/ai/AIStepResolver.gd`
- `scripts/autoload/CardDatabase.gd`
- `scripts/engine/GameStateMachine.gd`
- `data/bundled_user/decks/575720.json`
- `data/bundled_user/decks/578647.json`
- `data/bundled_user/decks/575716.json`

Prefer new Phase 2 components over bloating `AIBenchmarkRunner.gd`.

## Match Result Schema

Every raw Phase 2 match result must carry these mandatory fields before it reaches the evaluator:

1. `deck_a`
2. `deck_b`
3. `seed`
4. `winner_index`
5. `turn_count`
6. `steps`
7. `terminated_by_cap`
8. `stalled`
9. `failure_reason`
10. `event_counters`
11. `identity_hits`

`event_counters` is the single source for per-match quantitative counters. It should at minimum track:

1. `turn_end_count`
2. `attack_count_a`
3. `attack_count_b`
4. `take_prize_count`
5. `send_out_count`

The evaluator may derive summary-only fields from this schema, but should not invent missing raw fields downstream.

`deck_a` and `deck_b` should each be a stable dictionary carrying:

1. `deck_id`
2. `deck_key`
3. `deck_name`
4. `source_path`

`identity_hits` should follow the spec-facing normalized shape as one flat stable event map:

```json
{
  "miraidon_bench_developed": true,
  "electric_generator_resolved": true,
  "miraidon_attack_ready": true,
  "gardevoir_stage2_online": false,
  "psychic_embrace_resolved": false
}
```

If the implementation uses per-seat intermediate fields internally, normalize them into this flat spec-facing schema before exposing the raw match result to the evaluator.

## Global Testing Command

Use the existing full-suite runner for all verification steps:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected success shape:

```text
All tests passed!
```

When a step says “run the test to verify failure”, still use the full suite and expect the named Phase 2 test to fail in output.

## Task 1: Extract A First-Class HeadlessMatchBridge

**Files:**
- Create: `scripts/ai/HeadlessMatchBridge.gd`
- Modify: `scripts/ai/AIBenchmarkRunner.gd`
- Modify: `scripts/ai/AIOpponent.gd`
- Create: `tests/test_headless_match_bridge.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write the failing bridge extraction tests**

Add tests covering:

```gdscript
func test_headless_match_bridge_bootstraps_setup_after_start_game() -> String:
	var bridge_script = load("res://scripts/ai/HeadlessMatchBridge.gd")
	return run_checks([
		assert_not_null(bridge_script, "HeadlessMatchBridge script should exist"),
		assert_true(bridge_script.new().has_method("bootstrap_pending_setup"), "Bridge should expose setup bootstrap"),
	])
```

and:

```gdscript
func test_headless_match_bridge_reports_setup_prompt_owner() -> String:
	var bridge_script = load("res://scripts/ai/HeadlessMatchBridge.gd")
	var bridge = bridge_script.new()
	bridge.set("_pending_choice", "setup_active_1")
	bridge.set("_dialog_data", {"player": 1})
	return run_checks([
		assert_eq(bridge.get_pending_prompt_owner(), 1, "Setup prompt owner should be derived from dialog_data.player"),
	])
```

and one explicit bridge-owned prompt test each for:

1. `mulligan_extra_draw`
2. `setup_active_*`
3. `setup_bench_*`
4. `take_prize`
5. `send_out`

- [ ] **Step 2: Run the full suite to verify failure**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected: FAIL mentioning `test_headless_match_bridge_bootstraps_setup_after_start_game`

- [ ] **Step 3: Write the minimal `HeadlessMatchBridge.gd`**

Create:

```gdscript
class_name HeadlessMatchBridge
extends Control

var _gsm: GameStateMachine = null
var _pending_choice: String = ""
var _dialog_data: Dictionary = {}
var _setup_done: Array[bool] = [false, false]

func bind(next_gsm: GameStateMachine) -> void:
	# move the existing signal wiring here

func bootstrap_pending_setup() -> void:
	# if already in SETUP and no prompt is pending, restart setup flow

func get_pending_prompt_owner() -> int:
	# own setup / mulligan / prize / send_out ownership mapping
	return -1

func resolve_bridge_owned_prompt(ai_player_index: int = -1) -> bool:
	# resolve mulligan / setup_active / setup_bench / take_prize / send_out
	return false
```

Move the existing nested `HeadlessBattleBridge` implementation out of `AIBenchmarkRunner.gd` into this file without changing behavior yet.

The extraction must already enforce the final spec boundary:

1. bridge-owned: `mulligan_extra_draw`, `setup_active_*`, `setup_bench_*`, `take_prize`, `send_out`
2. AI-owned: `DRAW / MAIN` action selection and interaction-step resolution
3. rules-owned: `pokemon check`, KO resolution, normal turn transition

Do not preserve a “temporary” split where setup or mulligan still depend on AI-owned fallback behavior.

In the same task, remove the runner-owned setup and mulligan prompt handling from `AIOpponent.run_single_step()` and replace it with a narrower contract:

```gdscript
if pending_choice == "effect_interaction":
	return _step_resolver.resolve_pending_step(battle_scene, gsm, player_index)
```

Setup and mulligan must no longer be resolved by `AIOpponent` in headless benchmark flows.
`HeadlessMatchBridge.resolve_bridge_owned_prompt()` is the required replacement path for all bridge-owned prompts.

- [ ] **Step 4: Refit `AIBenchmarkRunner.gd` to use the new bridge**

Replace the nested class with:

```gdscript
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
```

and instantiate via:

```gdscript
var bridge := HeadlessMatchBridgeScript.new()
```

- [ ] **Step 5: Run the full suite to verify pass**

Expected: new bridge tests pass; prior benchmark smoke tests remain green.

- [ ] **Step 5a: Register the new suite in `tests/TestRunner.gd`**

Add:

```gdscript
const TestHeadlessMatchBridge = preload("res://tests/test_headless_match_bridge.gd")
```

and inside `_ready()`:

```gdscript
_run_test_suite("HeadlessMatchBridge", TestHeadlessMatchBridge.new())
```

- [ ] **Step 6: Commit**

```powershell
git add scripts/ai/HeadlessMatchBridge.gd scripts/ai/AIBenchmarkRunner.gd tests/test_headless_match_bridge.gd tests/TestRunner.gd
git commit -m "feat: extract headless match bridge"
```

## Task 2: Add Progress Detection And Failure Classification To The Runner

**Files:**
- Modify: `scripts/ai/HeadlessMatchBridge.gd`
- Modify: `scripts/ai/AIBenchmarkRunner.gd`
- Modify: `tests/test_headless_match_bridge.gd`

- [ ] **Step 1: Write failing tests for progress and failure reasons**

Add:

```gdscript
func test_headless_match_bridge_marks_unsupported_prompt_as_no_progress() -> String:
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.set("_pending_choice", "unsupported_prompt")
	return run_checks([
		assert_false(bridge.can_resolve_pending_prompt(), "Unsupported prompts should not be claimed as resolvable"),
	])
```

and:

```gdscript
func test_ai_benchmark_runner_returns_stalled_no_progress_reason() -> String:
	var runner := AIBenchmarkRunnerScript.new()
	var result := runner._make_failed_match_result("stalled_no_progress", 7)
	return run_checks([
		assert_eq(result.get("failure_reason", ""), "stalled_no_progress", "Runner should emit a stable failure reason"),
		assert_eq(result.get("steps", -1), 7, "Runner should preserve step count"),
	])
```

- [ ] **Step 2: Run full suite to verify failure**

Expected: FAIL on the new progress/failure tests.

- [ ] **Step 3: Implement explicit progress and failure-reason contracts**

In `HeadlessMatchBridge.gd`, add focused helpers:

```gdscript
func has_pending_prompt() -> bool:
	return _pending_choice != ""

func can_resolve_pending_prompt() -> bool:
	return (
		_pending_choice == "mulligan_extra_draw"
		or _pending_choice == "take_prize"
		or _pending_choice == "send_out"
		or _pending_choice.begins_with("setup_active_")
		or _pending_choice.begins_with("setup_bench_")
	)
```

In `AIBenchmarkRunner.gd`, centralize failure result creation:

```gdscript
func _make_failed_match_result(reason: String, steps: int) -> Dictionary:
	return {
		"deck_a": {},
		"deck_b": {},
		"seed": -1,
		"winner_index": -1,
		"turn_count": 0,
		"steps": steps,
		"terminated_by_cap": reason == "action_cap_reached",
		"stalled": reason == "stalled_no_progress",
		"failure_reason": reason,
		"event_counters": {},
		"identity_hits": {},
	}
```

Make `run_headless_duel()` choose among:

1. `normal_game_end`
2. `deck_out`
3. `stalled_no_progress`
4. `action_cap_reached`
5. `unsupported_prompt`
6. `unsupported_interaction_step`
7. `invalid_state_transition`

- [ ] **Step 4: Run full suite to verify pass**

Expected: failure reasons now emitted consistently; no regressions in existing AI tests.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ai/HeadlessMatchBridge.gd scripts/ai/AIBenchmarkRunner.gd tests/test_headless_match_bridge.gd
git commit -m "feat: classify headless benchmark failures"
```

## Task 3: Add Typed Benchmark Cases With Pinned Deck And Agent Contracts

**Files:**
- Create: `scripts/ai/DeckBenchmarkCase.gd`
- Modify: `scripts/ai/AIBenchmarkRunner.gd`
- Create: `tests/test_ai_phase2_benchmark.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write failing benchmark-case tests**

Add tests for:

```gdscript
func test_deck_benchmark_case_pins_phase2_default_decks() -> String:
	var case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = case_script.new()
	return run_checks([
		assert_true(benchmark_case.has_method("resolve_decks"), "Benchmark case should resolve pinned decks"),
	])
```

and:

```gdscript
func test_deck_benchmark_case_supports_version_regression_contract() -> String:
	var case_script = load("res://scripts/ai/DeckBenchmarkCase.gd")
	var benchmark_case = case_script.new()
	benchmark_case.comparison_mode = "version_regression"
	benchmark_case.agent_a_config = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
	benchmark_case.agent_b_config = {"agent_id": "shared-heuristic", "version_tag": "candidate-v2"}
	return run_checks([
		assert_true(benchmark_case.validate().is_empty(), "Version regression cases should validate with per-side agent configs"),
	])
```

- [ ] **Step 2: Run full suite to verify failure**

Expected: FAIL because the case contract does not exist yet.

- [ ] **Step 3: Implement `DeckBenchmarkCase.gd`**

Create:

```gdscript
class_name DeckBenchmarkCase
extends RefCounted

var deck_a_id: int = 0
var deck_b_id: int = 0
var deck_a_key: String = ""
var deck_b_key: String = ""
var comparison_mode: String = "shared_agent_mirror"
var agent_a_config: Dictionary = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
var agent_b_config: Dictionary = {"agent_id": "shared-heuristic", "version_tag": "baseline-v1"}
var seed_set: Array[int] = []
var match_count: int = 0
```

Add:

1. `validate()`
2. `resolve_decks()`
3. `get_pairing_name()`
4. `make_phase2_default_cases()`

Inside `resolve_decks()`, define the only allowed Phase 2 mapping:

1. `575720 -> "miraidon"`
2. `578647 -> "gardevoir"`
3. `575716 -> "charizard_ex"`

This mapping is the single source of truth for both the runner and the identity tracker.

Pin the exact deck IDs:

1. `575720`
2. `578647`
3. `575716`

- [ ] **Step 4: Refit `AIBenchmarkRunner.gd` to consume cases instead of loose dictionaries**

Keep backward compatibility only if trivial; otherwise add a clean Phase 2 path:

```gdscript
func run_benchmark_case(benchmark_case: DeckBenchmarkCase) -> Dictionary:
	# load decks, build scheduled pairings, run seeds, return raw match list
```

Inside this task, also add a helper that builds the exact Phase 2 default schedule:

```gdscript
func build_match_schedule(benchmark_case: DeckBenchmarkCase) -> Array[Dictionary]:
	# for each seed, run:
	# - deck_a first, deck_b second
	# - deck_b first, deck_a second
	# with both seats represented
```

- [ ] **Step 5: Run full suite to verify pass**

Expected: benchmark-case validation and pinned-deck tests pass.

- [ ] **Step 5a: Register the new suite in `tests/TestRunner.gd`**

Add:

```gdscript
const TestAIPhase2Benchmark = preload("res://tests/test_ai_phase2_benchmark.gd")
```

and inside `_ready()`:

```gdscript
_run_test_suite("AIPhase2Benchmark", TestAIPhase2Benchmark.new())
```

- [ ] **Step 6: Commit**

```powershell
git add scripts/ai/DeckBenchmarkCase.gd scripts/ai/AIBenchmarkRunner.gd tests/test_ai_phase2_benchmark.gd
git commit -m "feat: add typed benchmark cases"
```

## Task 4: Implement Deck Identity Tracking

**Files:**
- Create: `scripts/ai/DeckIdentityTracker.gd`
- Modify: `scripts/ai/AIBenchmarkRunner.gd`
- Create: `tests/test_deck_identity_tracker.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write failing identity tests**

Add concrete, boolean-event tests such as:

```gdscript
func test_deck_identity_tracker_marks_electric_generator_resolution() -> String:
	var tracker_script = load("res://scripts/ai/DeckIdentityTracker.gd")
	var tracker = tracker_script.new()
	var action := GameAction.new()
	action.action_type = GameAction.ActionType.PLAY_TRAINER
	action.description = "玩家0使用 电气发生器"
	var result := tracker.build_identity_hits("miraidon", [action])
	return run_checks([
		assert_true(bool(result.get("electric_generator_resolved", false)), "Miraidon identity should record Electric Generator resolution"),
	])
```

Also add one test each for:

1. `gardevoir_stage2_online`
2. `psychic_embrace_resolved`
3. `gardevoir_energy_loop_online`
4. `charizard_stage2_online`
5. `charizard_evolution_support_used`
6. `charizard_attack_ready`
7. `miraidon_bench_developed`
8. `miraidon_attack_ready`

The tracker suite should explicitly contain one fail-first test per spec event, for all 9 events:

1. `miraidon_bench_developed`
2. `electric_generator_resolved`
3. `miraidon_attack_ready`
4. `gardevoir_stage2_online`
5. `psychic_embrace_resolved`
6. `gardevoir_energy_loop_online`
7. `charizard_stage2_online`
8. `charizard_evolution_support_used`
9. `charizard_attack_ready`

- [ ] **Step 2: Run full suite to verify failure**

Expected: FAIL because tracker does not exist.

- [ ] **Step 3: Implement `DeckIdentityTracker.gd`**

Create a focused tracker with APIs like:

```gdscript
func build_identity_hits(deck_key: String, action_log: Array[GameAction], state: GameState = null) -> Dictionary:
	match deck_key:
		"miraidon":
			return _build_miraidon_hits(action_log, state)
		"gardevoir":
			return _build_gardevoir_hits(action_log, state)
		"charizard_ex":
			return _build_charizard_hits(action_log, state)
	return {}
```

Phase 2 only needs the exact spec events:

1. `miraidon_bench_developed`
2. `electric_generator_resolved`
3. `miraidon_attack_ready`
4. `gardevoir_stage2_online`
5. `psychic_embrace_resolved`
6. `gardevoir_energy_loop_online`
7. `charizard_stage2_online`
8. `charizard_evolution_support_used`
9. `charizard_attack_ready`

- [ ] **Step 4: Wire identity tracking into per-match results**

In `AIBenchmarkRunner.gd`, after each duel completes:

```gdscript
result["deck_a_id"] = benchmark_case.deck_a_id
result["deck_a"] = {
	"deck_id": benchmark_case.deck_a_id,
	"deck_key": benchmark_case.deck_a_key,
	"deck_name": benchmark_case.deck_a_name,
	"source_path": benchmark_case.deck_a_path,
}
result["deck_b"] = {
	"deck_id": benchmark_case.deck_b_id,
	"deck_key": benchmark_case.deck_b_key,
	"deck_name": benchmark_case.deck_b_name,
	"source_path": benchmark_case.deck_b_path,
}
result["seed"] = current_seed
result["turn_count"] = gsm.game_state.turn_number
result["event_counters"] = _build_event_counters(gsm.action_log)
var identity_hits_a := tracker.build_identity_hits(benchmark_case.deck_a_key, gsm.action_log, gsm.game_state)
var identity_hits_b := tracker.build_identity_hits(benchmark_case.deck_b_key, gsm.action_log, gsm.game_state)
result["identity_hits"] = _merge_identity_hits(identity_hits_a, identity_hits_b)
```

Implement `_build_event_counters()` in this task, not later.
Also implement `_merge_identity_hits()` in this task so the evaluator always consumes the flat spec-facing map.

- [ ] **Step 5: Run full suite to verify pass**

Expected: identity tests pass and raw benchmark match results now carry identity fields.

- [ ] **Step 5a: Register the new suite in `tests/TestRunner.gd`**

Add:

```gdscript
const TestDeckIdentityTracker = preload("res://tests/test_deck_identity_tracker.gd")
```

and inside `_ready()`:

```gdscript
_run_test_suite("DeckIdentityTracker", TestDeckIdentityTracker.new())
```

- [ ] **Step 6: Commit**

```powershell
git add scripts/ai/DeckIdentityTracker.gd scripts/ai/AIBenchmarkRunner.gd tests/test_deck_identity_tracker.gd tests/TestRunner.gd
git commit -m "feat: add deck identity tracking"
```

## Task 5: Add BenchmarkEvaluator For JSON And Text Summaries

**Files:**
- Create: `scripts/ai/BenchmarkEvaluator.gd`
- Create: `tests/test_benchmark_evaluator.gd`
- Modify: `scripts/ai/AIBenchmarkRunner.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write failing evaluator tests**

Add:

```gdscript
func test_benchmark_evaluator_aggregates_identity_event_breakdown() -> String:
	var evaluator_script = load("res://scripts/ai/BenchmarkEvaluator.gd")
	var evaluator = evaluator_script.new()
	var summary := evaluator.summarize_pairing([
		{
			"winner_index": 0,
			"turn_count": 5,
			"failure_reason": "normal_game_end",
			"identity_hits": {"miraidon": {"electric_generator_resolved": true}, "gardevoir": {}},
		},
		{
			"winner_index": 1,
			"turn_count": 6,
			"failure_reason": "normal_game_end",
			"identity_hits": {"miraidon": {"electric_generator_resolved": false}, "gardevoir": {}},
		},
	], "Miraidon vs Gardevoir")
	return run_checks([
		assert_eq(int(summary["identity_event_breakdown"]["electric_generator_resolved"]["hit_matches"]), 1, "Evaluator should count event hits"),
	])
```

Also add text-summary tests asserting:

1. pairing name appears
2. win rate appears
3. stall/cap counts appear

Add one full-schema test too:

```gdscript
func test_benchmark_evaluator_emits_full_pairing_summary_shape() -> String:
	var evaluator_script = load("res://scripts/ai/BenchmarkEvaluator.gd")
	var evaluator = evaluator_script.new()
	var summary := evaluator.summarize_pairing([], "Miraidon vs Gardevoir")
	return run_checks([
		assert_true(summary.has("pairing"), "Summary should include pairing"),
		assert_true(summary.has("wins_a"), "Summary should include wins_a"),
		assert_true(summary.has("wins_b"), "Summary should include wins_b"),
		assert_true(summary.has("win_rate_a"), "Summary should include win_rate_a"),
		assert_true(summary.has("win_rate_b"), "Summary should include win_rate_b"),
		assert_true(summary.has("stall_rate"), "Summary should include stall_rate"),
		assert_true(summary.has("cap_termination_rate"), "Summary should include cap_termination_rate"),
		assert_true(summary.has("identity_check_pass_rate"), "Summary should include identity_check_pass_rate"),
	])
```

- [ ] **Step 2: Run full suite to verify failure**

Expected: FAIL because evaluator does not exist.

- [ ] **Step 3: Implement `BenchmarkEvaluator.gd`**

Create methods:

```gdscript
func summarize_pairing(matches: Array[Dictionary], pairing_name: String) -> Dictionary:
	# wins, rates, avg_turn_count, failure_breakdown, identity_event_breakdown

func build_text_summary(summary: Dictionary) -> String:
	# compact human-readable report
```

Per spec, `identity_event_breakdown` must contain:

1. `applicable_matches`
2. `hit_matches`
3. `hit_rate`

And `identity_check_pass_rate` should be derived from the per-event pass/fail statuses, not replace them.

The summary schema in this task must explicitly include:

1. `pairing`
2. `total_matches`
3. `wins_a`
4. `wins_b`
5. `win_rate_a`
6. `win_rate_b`
7. `avg_turn_count`
8. `stall_rate`
9. `cap_termination_rate`
10. `failure_breakdown`
11. `identity_check_pass_rate`
12. `identity_event_breakdown`

- [ ] **Step 4: Integrate evaluator into `AIBenchmarkRunner.gd`**

Add a Phase 2 entry point:

```gdscript
func run_and_summarize_case(benchmark_case: DeckBenchmarkCase) -> Dictionary:
	var matches = run_benchmark_case(benchmark_case)
	return _evaluator.summarize_pairing(matches, benchmark_case.get_pairing_name())
```

- [ ] **Step 5: Run full suite to verify pass**

Expected: evaluator tests pass; pairing summaries now include JSON-ready aggregation plus text summary.

- [ ] **Step 5a: Register the new suite in `tests/TestRunner.gd`**

Add:

```gdscript
const TestBenchmarkEvaluator = preload("res://tests/test_benchmark_evaluator.gd")
```

and inside `_ready()`:

```gdscript
_run_test_suite("BenchmarkEvaluator", TestBenchmarkEvaluator.new())
```

- [ ] **Step 6: Commit**

```powershell
git add scripts/ai/BenchmarkEvaluator.gd scripts/ai/AIBenchmarkRunner.gd tests/test_benchmark_evaluator.gd tests/TestRunner.gd
git commit -m "feat: add benchmark evaluator"
```

## Task 6: Build The Phase 2 Benchmark Suite And Regression Gates

**Files:**
- Modify: `scripts/ai/AIBenchmarkRunner.gd`
- Modify: `scripts/ai/DeckBenchmarkCase.gd`
- Modify: `tests/test_ai_phase2_benchmark.gd`

- [ ] **Step 1: Write failing suite/regression tests**

Add tests that lock the Phase 2 defaults:

```gdscript
func test_phase2_benchmark_suite_contains_three_pinned_pairings() -> String:
	var cases := DeckBenchmarkCaseScript.make_phase2_default_cases()
	return run_checks([
		assert_eq(cases.size(), 3, "Phase 2 should define exactly three pinned pairings"),
	])
```

Add regression-gate assertions for the summary contract:

```gdscript
func test_phase2_regression_gate_fails_when_identity_rate_is_zero() -> String:
	var evaluator = BenchmarkEvaluatorScript.new()
	var summary := {
		"identity_event_breakdown": {
			"electric_generator_resolved": {"hit_rate": 0.0}
		},
		"failure_breakdown": {},
		"cap_termination_rate": 0.0,
	}
	return run_checks([
		assert_false(AIBenchmarkRunnerScript.passes_phase2_regression_gate(summary), "Zero identity hit rate should fail the Phase 2 regression gate"),
	])
```

- [ ] **Step 2: Run full suite to verify failure**

Expected: FAIL because the default suite or gate helpers do not exist yet.

- [ ] **Step 3: Implement the default suite and gate helpers**

In `DeckBenchmarkCase.gd`, implement:

```gdscript
static func make_phase2_default_cases() -> Array[DeckBenchmarkCase]:
	# Miraidon vs Gardevoir
	# Miraidon vs Charizard ex
	# Gardevoir vs Charizard ex
```

Use the fixed seed set:

```gdscript
[11, 29, 47, 83]
```

For every default case, `build_match_schedule()` must expand the 4 seeds into:

1. `deck_a` first-player / `deck_b` second-player
2. `deck_b` first-player / `deck_a` second-player

That yields 8 total matches per pairing. The tests in this task should assert `schedule.size() == 8`.

In `AIBenchmarkRunner.gd`, implement:

```gdscript
static func passes_phase2_regression_gate(summary: Dictionary) -> bool:
	# fail on stalled_no_progress
	# fail on cap_termination_rate > 0
	# fail when any core identity event hit_rate < 0.30
```

- [ ] **Step 4: Run full suite to verify pass**

Expected: suite-definition and regression-gate tests pass.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ai/AIBenchmarkRunner.gd scripts/ai/DeckBenchmarkCase.gd tests/test_ai_phase2_benchmark.gd
git commit -m "feat: add phase 2 benchmark suite"
```

## Task 7: Final Full-Suite Verification And Manual Benchmark Smoke

**Files:**
- Modify: none unless verification finds an issue

- [ ] **Step 1: Run the full automated suite**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected: `All tests passed!`

- [ ] **Step 2: Run one manual Phase 2 benchmark smoke invocation**

Use a short script or Godot console entry point that runs the default benchmark cases and verifies:

1. JSON summaries are emitted
2. text summaries are emitted
3. no pairing stalls

If a one-off helper is needed, add it in `scripts/ai/` or `tests/` and document the exact command in the implementation PR notes.

Preferred Phase 2 smoke helper:

1. Create `tests/RunPhase2BenchmarkSmoke.gd` only if needed
2. Invoke it with:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\ai\code\ptcgtrain' -s 'res://tests/RunPhase2BenchmarkSmoke.gd'
```

If no helper is needed, the implementation must document the exact alternative command in code comments or PR notes.

- [ ] **Step 3: Verify the pinned deck defaults**

Confirm the benchmark suite still resolves exactly:

1. `data/bundled_user/decks/575720.json`
2. `data/bundled_user/decks/578647.json`
3. `data/bundled_user/decks/575716.json`

- [ ] **Step 4: Commit final verification or follow-up fixes**

If verification required no code changes, skip commit.
If verification required a final fix:

```powershell
git add <fixed-files>
git commit -m "fix: stabilize phase 2 benchmark runner"
```
