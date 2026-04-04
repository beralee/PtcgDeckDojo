class_name AIBenchmarkRunner
extends RefCounted

const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckIdentityTrackerScript = preload("res://scripts/ai/DeckIdentityTracker.gd")
const BenchmarkEvaluatorScript = preload("res://scripts/ai/BenchmarkEvaluator.gd")
const PHASE2_DEFAULT_SEED_SET: Array[int] = [11, 29, 47, 83]
const PHASE2_IDENTITY_KEYS: Array[String] = [
	"miraidon_bench_developed",
	"electric_generator_resolved",
	"miraidon_attack_ready",
	"gardevoir_stage2_online",
	"psychic_embrace_resolved",
	"gardevoir_energy_loop_online",
	"charizard_stage2_online",
	"charizard_evolution_support_used",
	"charizard_attack_ready",
]
const PHASE2_EVENT_TO_DECK_KEY: Dictionary = {
	"miraidon_bench_developed": "miraidon",
	"electric_generator_resolved": "miraidon",
	"miraidon_attack_ready": "miraidon",
	"gardevoir_stage2_online": "gardevoir",
	"psychic_embrace_resolved": "gardevoir",
	"gardevoir_energy_loop_online": "gardevoir",
	"charizard_stage2_online": "charizard_ex",
	"charizard_evolution_support_used": "charizard_ex",
	"charizard_attack_ready": "charizard_ex",
}


func run_benchmark_case(benchmark_case) -> Dictionary:
	if benchmark_case == null:
		return {
			"benchmark_case": "",
			"comparison_mode": "",
			"matches": [],
			"errors": PackedStringArray(["benchmark_case is null"]),
		}

	var validation_errors: PackedStringArray = benchmark_case.validate()
	if not validation_errors.is_empty():
		return {
			"benchmark_case": benchmark_case.get_pairing_name(),
			"comparison_mode": benchmark_case.comparison_mode,
			"matches": [],
			"errors": validation_errors,
		}

	benchmark_case.resolve_decks()
	var seed_set: Array = _get_effective_seed_set(benchmark_case)
	var deck_a := _load_benchmark_deck(benchmark_case.deck_a_id)
	var deck_b := _load_benchmark_deck(benchmark_case.deck_b_id)
	if deck_a == null or deck_b == null:
		var load_errors := PackedStringArray()
		if deck_a == null:
			load_errors.append("Unable to load deck_a_id %d" % benchmark_case.deck_a_id)
		if deck_b == null:
			load_errors.append("Unable to load deck_b_id %d" % benchmark_case.deck_b_id)
		return {
			"benchmark_case": benchmark_case.get_pairing_name(),
			"comparison_mode": benchmark_case.comparison_mode,
			"matches": [],
			"errors": load_errors,
		}

	var schedule := build_match_schedule(benchmark_case)
	var matches: Array[Dictionary] = []
	for matchup: Dictionary in schedule:
		matches.append(_run_benchmark_match(benchmark_case, matchup, deck_a, deck_b))

	return {
		"benchmark_case": benchmark_case.get_pairing_name(),
		"comparison_mode": benchmark_case.comparison_mode,
		"deck_a": {
			"deck_id": benchmark_case.deck_a_id,
			"deck_key": benchmark_case.deck_a_key,
		},
		"deck_b": {
			"deck_id": benchmark_case.deck_b_id,
			"deck_key": benchmark_case.deck_b_key,
		},
		"seed_set": seed_set,
		"match_count": matches.size(),
		"matches": matches,
	}


func run_and_summarize_case(benchmark_case) -> Dictionary:
	var raw_result: Dictionary = run_benchmark_case(benchmark_case)
	var errors_variant: Variant = raw_result.get("errors", PackedStringArray())
	var errors: PackedStringArray = errors_variant if errors_variant is PackedStringArray else PackedStringArray()
	if not errors.is_empty():
		return {
			"raw_result": raw_result,
			"errors": errors,
			"summary": {},
			"text_summary": "",
			"regression_gate_passed": false,
		}
	var evaluator := BenchmarkEvaluatorScript.new()
	var pairing_name: String = str(raw_result.get("benchmark_case", ""))
	var matches_variant: Variant = raw_result.get("matches", [])
	var matches: Array[Dictionary] = []
	if matches_variant is Array:
		for match_variant: Variant in matches_variant:
			if match_variant is Dictionary:
				matches.append(match_variant)
	var summary: Dictionary = evaluator.summarize_pairing(matches, pairing_name)
	var regression_gate_passed: bool = passes_phase2_regression_gate(summary)
	return {
		"raw_result": raw_result,
		"errors": errors,
		"summary": summary,
		"text_summary": evaluator.build_text_summary(summary),
		"regression_gate_passed": regression_gate_passed,
	}


static func passes_phase2_regression_gate(summary: Dictionary) -> bool:
	if summary.is_empty():
		return false
	if int(summary.get("total_matches", 0)) <= 0:
		return false

	var failure_breakdown_variant: Variant = summary.get("failure_breakdown", {})
	if not failure_breakdown_variant is Dictionary:
		return false
	var failure_breakdown: Dictionary = failure_breakdown_variant
	if int(failure_breakdown.get("stalled_no_progress", 0)) > 0:
		return false

	var cap_termination_rate: float = float(summary.get("cap_termination_rate", 0.0))
	if cap_termination_rate > 0.0:
		return false

	var identity_breakdown_variant: Variant = summary.get("identity_event_breakdown", {})
	if not identity_breakdown_variant is Dictionary:
		return false
	var identity_breakdown: Dictionary = identity_breakdown_variant
	var pairing: String = str(summary.get("pairing", ""))
	var participating_decks := _get_pairing_deck_keys_from_summary(pairing)
	for event_key: String in PHASE2_IDENTITY_KEYS:
		if not identity_breakdown.has(event_key):
			return false
		var event_variant: Variant = identity_breakdown.get(event_key)
		if not event_variant is Dictionary:
			return false
		var event_summary: Dictionary = event_variant
		var event_deck_key: String = str(PHASE2_EVENT_TO_DECK_KEY.get(event_key, ""))
		var applicable_matches: int = int(event_summary.get("applicable_matches", 0))
		if not participating_decks.has(event_deck_key):
			continue
		if applicable_matches <= 0:
			return false
		if float(event_summary.get("hit_rate", 0.0)) < 0.30:
			return false

	return true


func build_match_schedule(benchmark_case) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	if benchmark_case == null:
		return schedule

	benchmark_case.resolve_decks()
	var seed_values: Array = _get_effective_seed_set(benchmark_case)

	for seed_index: int in seed_values.size():
		var seed: int = int(seed_values[seed_index])
		var version_assignment_flipped: bool = seed_index % 2 == 1
		schedule.append(_make_match_schedule_entry(
			seed,
			seed_index,
			version_assignment_flipped,
			benchmark_case.deck_a_id,
			benchmark_case.deck_a_key,
			benchmark_case.deck_b_id,
			benchmark_case.deck_b_key,
			true
		))
		schedule.append(_make_match_schedule_entry(
			seed,
			seed_index,
			version_assignment_flipped,
			benchmark_case.deck_b_id,
			benchmark_case.deck_b_key,
			benchmark_case.deck_a_id,
			benchmark_case.deck_a_key,
			false
		))

	benchmark_case.match_count = schedule.size()
	return schedule


func run_fixed_match_set(agent: AIOpponent, matchups: Array[Dictionary]) -> Dictionary:
	var wins: int = 0
	for matchup: Dictionary in matchups:
		var result: Dictionary = _run_one_match(agent, matchup)
		if int(result.get("winner_index", -1)) == int(matchup.get("tracked_player_index", 1)):
			wins += 1
	return {
		"total_matches": matchups.size(),
		"wins": wins,
		"win_rate": 0.0 if matchups.is_empty() else float(wins) / float(matchups.size()),
	}


func run_smoke_match(
	agent: AIOpponent,
	step_runner: Callable,
	max_steps: int = 200,
	initial_state: Dictionary = {}
) -> Dictionary:
	var state: Dictionary = initial_state.duplicate(true)
	var steps: int = 0
	while steps < max_steps:
		steps += 1
		var raw_result: Variant = step_runner.call(agent, state)
		var result: Dictionary = raw_result if raw_result is Dictionary else {}
		if _is_terminal_smoke_result(result):
			var completed: Dictionary = _make_raw_match_result(null, steps)
			for key: Variant in result.keys():
				completed[key] = result[key]
			completed["identity_hits"] = _normalize_identity_hits(completed.get("identity_hits", {}))
			completed["steps"] = steps
			completed["terminated_by_cap"] = false
			return completed
	var capped: Dictionary = _make_raw_match_result(null, max_steps)
	capped["winner_index"] = -1
	capped["terminated_by_cap"] = true
	capped["failure_reason"] = "action_cap_reached"
	return capped


func _make_raw_match_result(gsm: GameStateMachine, steps: int) -> Dictionary:
	var turn_count: int = 0
	if gsm != null and gsm.game_state != null:
		turn_count = int(gsm.game_state.turn_number)
	return {
		"deck_a": {},
		"deck_b": {},
		"seed": -1,
		"winner_index": -1,
		"turn_count": turn_count,
		"steps": steps,
		"terminated_by_cap": false,
		"stalled": false,
		"failure_reason": "",
		"event_counters": {},
		"identity_hits": _make_empty_identity_hits(),
	}


func _make_success_match_result(gsm: GameStateMachine, steps: int) -> Dictionary:
	var result: Dictionary = _make_raw_match_result(gsm, steps)
	result["winner_index"] = gsm.game_state.winner_index if gsm != null and gsm.game_state != null else -1
	result["failure_reason"] = _get_terminal_failure_reason(gsm)
	result["identity_hits"] = _normalize_identity_hits(result.get("identity_hits", {}))
	return result


func _make_failed_match_result(reason: String, steps: int, gsm: GameStateMachine = null) -> Dictionary:
	var result: Dictionary = _make_raw_match_result(gsm, steps)
	result["terminated_by_cap"] = reason == "action_cap_reached"
	result["stalled"] = reason == "stalled_no_progress"
	result["failure_reason"] = reason
	result["identity_hits"] = _normalize_identity_hits(result.get("identity_hits", {}))
	return result


func _is_terminal_smoke_result(result: Dictionary) -> bool:
	if result.is_empty():
		return false
	if str(result.get("failure_reason", "")) != "":
		return true
	return int(result.get("winner_index", -1)) >= 0


func _get_terminal_failure_reason(gsm: GameStateMachine) -> String:
	if gsm == null or gsm.game_state == null:
		return "invalid_state_transition"
	if _is_deck_out_game_over(gsm):
		return "deck_out"
	return "normal_game_end"


func _is_deck_out_game_over(gsm: GameStateMachine) -> bool:
	if gsm == null or gsm.game_state == null:
		return false
	if not gsm.game_state.is_game_over():
		return false
	var winner_index: int = int(gsm.game_state.winner_index)
	var current_player_index: int = int(gsm.game_state.current_player_index)
	if winner_index < 0 or current_player_index < 0:
		return false
	if winner_index == current_player_index:
		return false
	if current_player_index >= gsm.game_state.players.size():
		return false
	var losing_player: PlayerState = gsm.game_state.players[current_player_index]
	return losing_player != null and losing_player.deck.is_empty()


func run_headless_duel(
	player_0_ai: AIOpponent,
	player_1_ai: AIOpponent,
	gsm: GameStateMachine,
	max_steps: int = 200,
	step_callback: Callable = Callable(),
	decision_exporter = null,
) -> Dictionary:
	if gsm == null or gsm.game_state == null:
		return _make_failed_match_result("invalid_state_transition", 0, gsm)
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()
	var result: Dictionary = {}
	var steps: int = 0
	while steps < max_steps:
		if gsm.game_state.is_game_over():
			result = _make_success_match_result(gsm, steps)
			break
		var progressed: bool = false
		if bridge.has_pending_prompt():
			if bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
				if not progressed:
					result = _make_failed_match_result("invalid_state_transition", steps + 1, gsm)
					break
			else:
				var pending_choice: String = bridge.get_pending_prompt_type()
				if pending_choice == "effect_interaction":
					if not bridge.has_method("supports_effect_interaction_execution") \
							or not bool(bridge.call("supports_effect_interaction_execution")):
						result = _make_failed_match_result("unsupported_interaction_step", steps + 1, gsm)
						break
					var prompt_owner: int = bridge.get_pending_prompt_owner()
					if prompt_owner < 0 or prompt_owner >= 2:
						result = _make_failed_match_result("invalid_state_transition", steps + 1, gsm)
						break
					var prompt_ai: AIOpponent = _get_ai_for_player(player_0_ai, player_1_ai, prompt_owner)
					if prompt_ai == null:
						result = _make_failed_match_result("unsupported_prompt", steps + 1, gsm)
						break
					progressed = prompt_ai.run_single_step(bridge, gsm)
					if not progressed:
						result = _make_failed_match_result("unsupported_interaction_step", steps + 1, gsm)
						break
					_record_decision_trace_if_available(decision_exporter, prompt_ai)
				else:
					result = _make_failed_match_result("unsupported_prompt", steps + 1, gsm)
					break
		else:
			var current_player: int = gsm.game_state.current_player_index
			if current_player < 0 or current_player >= 2:
				result = _make_failed_match_result("invalid_state_transition", steps + 1, gsm)
				break
			var current_ai: AIOpponent = _get_ai_for_player(player_0_ai, player_1_ai, current_player)
			if current_ai == null:
				result = _make_failed_match_result("invalid_state_transition", steps + 1, gsm)
				break
			progressed = current_ai.run_single_step(bridge, gsm)
			if not progressed:
				if _has_interactive_legal_action(current_ai, gsm):
					result = _make_failed_match_result("unsupported_interaction_step", steps + 1, gsm)
					break
				result = _make_failed_match_result("stalled_no_progress", steps + 1, gsm)
				break
			_record_decision_trace_if_available(decision_exporter, current_ai)
		if step_callback.is_valid():
			step_callback.call(gsm)
		steps += 1
	if result.is_empty():
		result = _make_failed_match_result("action_cap_reached", max_steps, gsm)
	result["event_counters"] = _collect_ai_event_counters(player_0_ai, player_1_ai)
	## 释放 bridge（extends Control，非 RefCounted，必须显式释放）
	bridge.free()
	return result


func _record_decision_trace_if_available(decision_exporter, ai: AIOpponent) -> void:
	if decision_exporter == null or ai == null:
		return
	if not decision_exporter.has_method("record_trace"):
		return
	var trace = ai.get_last_decision_trace()
	if trace == null:
		return
	decision_exporter.record_trace(trace)


func _run_benchmark_match(
	benchmark_case,
	matchup: Dictionary,
	deck_a: DeckData,
	deck_b: DeckData
) -> Dictionary:
	var player_0_deck_id: int = int(matchup.get("player_0_deck_id", benchmark_case.deck_a_id))
	var player_1_deck_id: int = int(matchup.get("player_1_deck_id", benchmark_case.deck_b_id))
	var player_0_deck: DeckData = deck_a if player_0_deck_id == benchmark_case.deck_a_id else deck_b
	var player_1_deck: DeckData = deck_b if player_1_deck_id == benchmark_case.deck_b_id else deck_a
	var agent_configs: Dictionary = _get_match_agent_configs(benchmark_case, matchup)
	var player_0_ai := _make_benchmark_agent(0, agent_configs.get("player_0_agent_config", benchmark_case.agent_a_config), benchmark_case.comparison_mode)
	var player_1_ai := _make_benchmark_agent(1, agent_configs.get("player_1_agent_config", benchmark_case.agent_b_config), benchmark_case.comparison_mode)
	var gsm := GameStateMachine.new()
	_clear_forced_shuffle_seed()
	_apply_match_seed(gsm, int(matchup.get("seed", -1)))
	_set_forced_shuffle_seed(int(matchup.get("seed", -1)))
	gsm.start_game(player_0_deck, player_1_deck, 0)

	var result: Dictionary = run_headless_duel(player_0_ai, player_1_ai, gsm, 200)
	_clear_forced_shuffle_seed()
	result["identity_hits"] = _normalize_identity_hits(_build_match_identity_hits(benchmark_case, gsm))
	result["seed"] = int(matchup.get("seed", -1))
	result["seed_index"] = int(matchup.get("seed_index", -1))
	result["comparison_mode"] = benchmark_case.comparison_mode
	result["deck_a"] = {
		"deck_id": benchmark_case.deck_a_id,
		"deck_key": benchmark_case.deck_a_key,
	}
	result["deck_b"] = {
		"deck_id": benchmark_case.deck_b_id,
		"deck_key": benchmark_case.deck_b_key,
	}
	result["agent_a_config"] = benchmark_case.agent_a_config.duplicate(true)
	result["agent_b_config"] = benchmark_case.agent_b_config.duplicate(true)
	result["version_a_agent_config"] = benchmark_case.agent_a_config.duplicate(true)
	result["version_b_agent_config"] = benchmark_case.agent_b_config.duplicate(true)
	result["player_0_agent_config"] = agent_configs.get("player_0_agent_config", benchmark_case.agent_a_config).duplicate(true)
	result["player_1_agent_config"] = agent_configs.get("player_1_agent_config", benchmark_case.agent_b_config).duplicate(true)
	result["version_a_deck_id"] = int(agent_configs.get("version_a_deck_id", benchmark_case.deck_a_id))
	result["version_b_deck_id"] = int(agent_configs.get("version_b_deck_id", benchmark_case.deck_b_id))
	result["version_a_player_index"] = int(agent_configs.get("version_a_player_index", 0))
	result["version_b_player_index"] = int(agent_configs.get("version_b_player_index", 1))
	result["player_0_deck_id"] = player_0_deck_id
	result["player_0_deck_key"] = str(matchup.get("player_0_deck_key", ""))
	result["player_1_deck_id"] = player_1_deck_id
	result["player_1_deck_key"] = str(matchup.get("player_1_deck_key", ""))
	result["version_assignment_flipped"] = bool(matchup.get("version_assignment_flipped", false))
	result["deck_a_first"] = bool(matchup.get("deck_a_first", true))
	result["seat_order"] = str(matchup.get("seat_order", "deck_a_first"))
	return result


func _build_match_identity_hits(benchmark_case, gsm: GameStateMachine) -> Dictionary:
	var identity_hits := _make_empty_identity_hits()
	if benchmark_case == null or gsm == null:
		return identity_hits

	var tracker := DeckIdentityTrackerScript.new()
	_merge_identity_hits(identity_hits, tracker.build_identity_hits(benchmark_case.deck_a_key, gsm.action_log, gsm.game_state))
	_merge_identity_hits(identity_hits, tracker.build_identity_hits(benchmark_case.deck_b_key, gsm.action_log, gsm.game_state))
	return identity_hits


func _make_match_schedule_entry(
	seed: int,
	seed_index: int,
	version_assignment_flipped: bool,
	player_0_deck_id: int,
	player_0_deck_key: String,
	player_1_deck_id: int,
	player_1_deck_key: String,
	deck_a_first: bool
) -> Dictionary:
	return {
		"seed": seed,
		"seed_index": seed_index,
		"version_assignment_flipped": version_assignment_flipped,
		"player_0_deck_id": player_0_deck_id,
		"player_0_deck_key": player_0_deck_key,
		"player_1_deck_id": player_1_deck_id,
		"player_1_deck_key": player_1_deck_key,
		"deck_a_first": deck_a_first,
		"seat_order": "deck_a_first" if deck_a_first else "deck_b_first",
	}


func _make_benchmark_agent(player_index: int, agent_config: Dictionary, comparison_mode: String) -> AIOpponent:
	var agent := AIOpponentScript.new()
	agent.configure(player_index, 1)
	agent.set_meta("agent_id", str(agent_config.get("agent_id", "")))
	agent.set_meta("version_tag", str(agent_config.get("version_tag", "")))
	agent.set_meta("comparison_mode", comparison_mode)
	var config_weights: Variant = agent_config.get("heuristic_weights", {})
	if config_weights is Dictionary and not (config_weights as Dictionary).is_empty():
		agent.heuristic_weights = (config_weights as Dictionary).duplicate(true)
	var config_mcts: Variant = agent_config.get("mcts_config", {})
	if config_mcts is Dictionary and not (config_mcts as Dictionary).is_empty():
		agent.use_mcts = true
		agent.mcts_config = (config_mcts as Dictionary).duplicate(true)
	var value_net_path := str(agent_config.get("value_net_path", ""))
	if value_net_path != "":
		agent.value_net_path = value_net_path
	var action_scorer_path := str(agent_config.get("action_scorer_path", ""))
	if action_scorer_path != "":
		agent.action_scorer_path = action_scorer_path
	return agent


func _apply_match_seed(gsm: GameStateMachine, seed: int) -> void:
	if gsm == null or gsm.coin_flipper == null:
		return
	var rng: Variant = gsm.coin_flipper.get("_rng")
	if rng is RandomNumberGenerator:
		(rng as RandomNumberGenerator).seed = seed


func _set_forced_shuffle_seed(seed: int) -> void:
	var player_state := PlayerState.new()
	if player_state.has_method("set_forced_shuffle_seed"):
		player_state.call("set_forced_shuffle_seed", seed)


func _clear_forced_shuffle_seed() -> void:
	var player_state := PlayerState.new()
	if player_state.has_method("clear_forced_shuffle_seed"):
		player_state.call("clear_forced_shuffle_seed")


func _get_effective_seed_set(benchmark_case) -> Array:
	var seed_values: Array = benchmark_case.seed_set.duplicate()
	if seed_values.is_empty():
		seed_values = PHASE2_DEFAULT_SEED_SET.duplicate()
	return seed_values


func _get_match_agent_configs(benchmark_case, matchup: Dictionary) -> Dictionary:
	var version_assignment_flipped: bool = bool(matchup.get("version_assignment_flipped", false))
	if benchmark_case.comparison_mode == "version_regression":
		if version_assignment_flipped:
			return {
				"player_0_agent_config": benchmark_case.agent_b_config,
				"player_1_agent_config": benchmark_case.agent_a_config,
				"version_a_agent_config": benchmark_case.agent_a_config,
				"version_b_agent_config": benchmark_case.agent_b_config,
				"version_a_deck_id": int(matchup.get("player_1_deck_id", benchmark_case.deck_b_id)),
				"version_b_deck_id": int(matchup.get("player_0_deck_id", benchmark_case.deck_a_id)),
				"version_a_player_index": 1,
				"version_b_player_index": 0,
			}
		return {
			"player_0_agent_config": benchmark_case.agent_a_config,
			"player_1_agent_config": benchmark_case.agent_b_config,
			"version_a_agent_config": benchmark_case.agent_a_config,
			"version_b_agent_config": benchmark_case.agent_b_config,
			"version_a_deck_id": int(matchup.get("player_0_deck_id", benchmark_case.deck_a_id)),
			"version_b_deck_id": int(matchup.get("player_1_deck_id", benchmark_case.deck_b_id)),
			"version_a_player_index": 0,
			"version_b_player_index": 1,
		}
	if bool(matchup.get("deck_a_first", true)):
		return {
			"player_0_agent_config": benchmark_case.agent_a_config,
			"player_1_agent_config": benchmark_case.agent_b_config,
			"version_a_agent_config": benchmark_case.agent_a_config,
			"version_b_agent_config": benchmark_case.agent_b_config,
			"version_a_deck_id": int(matchup.get("player_0_deck_id", benchmark_case.deck_a_id)),
			"version_b_deck_id": int(matchup.get("player_1_deck_id", benchmark_case.deck_b_id)),
			"version_a_player_index": 0,
			"version_b_player_index": 1,
		}
	return {
		"player_0_agent_config": benchmark_case.agent_b_config,
		"player_1_agent_config": benchmark_case.agent_a_config,
		"version_a_agent_config": benchmark_case.agent_a_config,
		"version_b_agent_config": benchmark_case.agent_b_config,
		"version_a_deck_id": int(matchup.get("player_1_deck_id", benchmark_case.deck_a_id)),
		"version_b_deck_id": int(matchup.get("player_0_deck_id", benchmark_case.deck_b_id)),
		"version_a_player_index": 1,
		"version_b_player_index": 0,
	}


func _load_benchmark_deck(deck_id: int) -> DeckData:
	if deck_id <= 0:
		return null
	return CardDatabase.get_deck(deck_id)


func _run_one_match(agent: AIOpponent, matchup: Dictionary) -> Dictionary:
	var step_runner: Variant = matchup.get("step_runner")
	if step_runner is Callable and (step_runner as Callable).is_valid():
		return run_smoke_match(
			agent,
			step_runner as Callable,
			int(matchup.get("max_steps", 200)),
			matchup.get("initial_state", {})
		)
	var runner: Variant = matchup.get("runner")
	if runner is Callable and (runner as Callable).is_valid():
		var called: Variant = (runner as Callable).call(agent, matchup)
		return called if called is Dictionary else {}
	var preset_result: Variant = matchup.get("result", {})
	return preset_result if preset_result is Dictionary else {}


func _get_ai_for_player(player_0_ai: AIOpponent, player_1_ai: AIOpponent, player_index: int) -> AIOpponent:
	if player_0_ai != null and player_0_ai.player_index == player_index:
		return player_0_ai
	if player_1_ai != null and player_1_ai.player_index == player_index:
		return player_1_ai
	return null


func _has_interactive_legal_action(ai: AIOpponent, gsm: GameStateMachine) -> bool:
	if ai == null or gsm == null:
		return false
	var actions: Array[Dictionary] = ai.get_legal_actions(gsm)
	for action: Dictionary in actions:
		if bool(action.get("requires_interaction", false)):
			return true
	return false


func _collect_ai_event_counters(player_0_ai: AIOpponent, player_1_ai: AIOpponent) -> Dictionary:
	var merged := {}
	for ai: AIOpponent in [player_0_ai, player_1_ai]:
		if ai == null or not ai.has_method("get_event_counters"):
			continue
		_merge_event_counters(merged, ai.get_event_counters())
	return merged


func _merge_event_counters(target: Dictionary, source: Dictionary) -> void:
	for key_variant: Variant in source.keys():
		var key: String = str(key_variant)
		var value: Variant = source.get(key, null)
		if value is Dictionary:
			var target_dict: Dictionary = target.get(key, {})
			for subkey_variant: Variant in (value as Dictionary).keys():
				var subkey: String = str(subkey_variant)
				target_dict[subkey] = int(target_dict.get(subkey, 0)) + int((value as Dictionary).get(subkey, 0))
			target[key] = target_dict
		elif value is Array:
			var target_array: Array = target.get(key, [])
			for entry: Variant in value:
				target_array.append(entry)
			target[key] = target_array
		else:
			target[key] = value


func _make_empty_identity_hits() -> Dictionary:
	var identity_hits: Dictionary = {}
	for key: String in PHASE2_IDENTITY_KEYS:
		identity_hits[key] = false
	return identity_hits


func _merge_identity_hits(target: Dictionary, source: Dictionary) -> void:
	if target.is_empty() or source.is_empty():
		return
	for key: Variant in source.keys():
		var normalized_key := str(key)
		if not target.has(normalized_key):
			continue
		target[normalized_key] = bool(target.get(normalized_key, false)) or bool(source.get(key, false))


func _normalize_identity_hits(raw_hits: Variant) -> Dictionary:
	var normalized := _make_empty_identity_hits()
	if not raw_hits is Dictionary:
		return normalized
	_merge_identity_hits(normalized, raw_hits)
	return normalized


static func _get_pairing_deck_keys_from_summary(pairing: String) -> Dictionary:
	var participating: Dictionary = {}
	if pairing == "":
		return participating
	var deck_keys: PackedStringArray = pairing.split("_vs_")
	for deck_key: String in deck_keys:
		if deck_key == "":
			continue
		participating[deck_key] = true
	return participating
