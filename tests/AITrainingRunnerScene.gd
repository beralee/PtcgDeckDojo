extends Control

const RunnerBootstrapScript = preload("res://tests/AITrainingTestRunner.gd")
const TestSuiteCatalogScript = preload("res://tests/TestSuiteCatalog.gd")
const SharedSuiteRunnerScript = preload("res://tests/SharedSuiteRunner.gd")
const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DeckStrategyMiraidonBaselineScript = preload("res://scripts/ai/DeckStrategyMiraidonBaseline.gd")


class TraceCollector extends RefCounted:
	var traces: Array = []

	func record_trace(trace) -> void:
		if trace == null:
			return
		traces.append(trace.clone())


func _ready() -> void:
	var options := RunnerBootstrapScript.parse_runner_args(OS.get_cmdline_user_args())
	if str(options.get("mode", RunnerBootstrapScript.RUN_MODE_SUITE)) == RunnerBootstrapScript.RUN_MODE_MATCHUP_SWEEP:
		var report := run_matchup_sweep(options)
		print(str(report.get("output", "")))
		var json_output := str(options.get("json_output", ""))
		if json_output != "":
			_write_json(json_output, report)
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1 if int(report.get("error_count", 0)) > 0 else 0)
		return
	if str(options.get("mode", RunnerBootstrapScript.RUN_MODE_SUITE)) == RunnerBootstrapScript.RUN_MODE_MIRAIDON_BASELINE_REGRESSION:
		var regression_report := run_miraidon_baseline_regression(options)
		print(str(regression_report.get("output", "")))
		var regression_json_output := str(options.get("json_output", ""))
		if regression_json_output != "":
			_write_json(regression_json_output, regression_report)
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1 if int(regression_report.get("error_count", 0)) > 0 else 0)
		return
	if str(options.get("mode", RunnerBootstrapScript.RUN_MODE_SUITE)) == RunnerBootstrapScript.RUN_MODE_ACTION_CAP_PROBE:
		var probe_report := run_action_cap_probe(options)
		print(str(probe_report.get("output", "")))
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1 if int(probe_report.get("error_count", 0)) > 0 else 0)
		return

	var selected_suites: Dictionary = options.get("selected_suites", {})
	var suites := TestSuiteCatalogScript.get_suites_for_group(TestSuiteCatalogScript.GROUP_AI_TRAINING)
	var suite_report := await SharedSuiteRunnerScript.run_suites(suites, selected_suites, "PTCG Train AI/Training Tests")
	print(suite_report.get("output", ""))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if int(suite_report.get("failed", 0)) > 0 else 0)


func run_matchup_sweep(options: Dictionary) -> Dictionary:
	var anchor_deck_id: int = int(options.get("anchor_deck_id", RunnerBootstrapScript.DEFAULT_ANCHOR_DECK_ID))
	var anchor_strategy_override: String = str(options.get("anchor_strategy_override", ""))
	var games_per_matchup: int = int(options.get("games_per_matchup", RunnerBootstrapScript.DEFAULT_GAMES_PER_MATCHUP))
	var max_steps: int = int(options.get("max_steps", RunnerBootstrapScript.DEFAULT_MAX_STEPS))
	var seed_bases: Array[int] = RunnerBootstrapScript.resolve_seed_bases(options)
	var deck_ids: Array[int] = RunnerBootstrapScript.resolve_matchup_sweep_deck_ids(options)
	var lines: Array[String] = []
	var errors: Array[String] = []
	var results: Array[Dictionary] = []
	var card_database = _get_card_database()
	var anchor_deck: DeckData = null
	if card_database != null:
		anchor_deck = card_database.call("get_deck", anchor_deck_id)

	if anchor_deck == null:
		errors.append("Unable to load anchor deck %d" % anchor_deck_id)
		return {
			"mode": RunnerBootstrapScript.RUN_MODE_MATCHUP_SWEEP,
			"anchor_deck_id": anchor_deck_id,
			"results": results,
			"errors": errors,
			"error_count": errors.size(),
			"output": "AITrainingTestRunner matchup sweep failed: %s" % ", ".join(errors),
		}

	lines.append("PTCG Train AI Matchup Sweep")
	lines.append("Anchor: %s (%d)" % [anchor_deck.deck_name, anchor_deck_id])
	if anchor_strategy_override != "":
		lines.append("Anchor strategy override: %s" % anchor_strategy_override)
	lines.append("Games per matchup: %d" % games_per_matchup)
	lines.append("Seed bases: %s" % ", ".join(_stringify_int_array(seed_bases)))
	lines.append("Decks: %d" % deck_ids.size())
	lines.append("")
	lines.append("Deck ID  Name                    Win  Loss Draw  WinRate  Sigma  AvgTurns  Failures")

	var benchmark_runner := AIBenchmarkRunnerScript.new()
	var tracked_artifact_overrides := _build_artifact_overrides(options, "tracked")
	var anchor_artifact_overrides := _build_artifact_overrides(options, "anchor")
	for deck_index: int in deck_ids.size():
		var deck_id: int = deck_ids[deck_index]
		var deck: DeckData = null
		if card_database != null:
			deck = card_database.call("get_deck", deck_id)
		if deck == null:
			errors.append("Unable to load deck %d" % deck_id)
			continue
		var summary := _run_matchup_for_deck_multi_seed(
			benchmark_runner,
			deck,
			anchor_deck,
			deck_index,
			games_per_matchup,
			max_steps,
			seed_bases,
			"",
			anchor_strategy_override,
			tracked_artifact_overrides,
			anchor_artifact_overrides
		)
		results.append(summary)
		lines.append(_format_matchup_summary_line(summary))

	if not errors.is_empty():
		lines.append("")
		lines.append("Errors:")
		for message: String in errors:
			lines.append("- %s" % message)

	return {
		"mode": RunnerBootstrapScript.RUN_MODE_MATCHUP_SWEEP,
		"anchor_deck_id": anchor_deck_id,
		"anchor_deck_name": anchor_deck.deck_name,
		"anchor_strategy_override": anchor_strategy_override,
		"games_per_matchup": games_per_matchup,
		"max_steps": max_steps,
		"seed_base": seed_bases[0] if not seed_bases.is_empty() else RunnerBootstrapScript.DEFAULT_SEED_BASE,
		"seed_bases": seed_bases,
		"deck_ids": deck_ids,
		"results": results,
		"errors": errors,
		"error_count": errors.size(),
		"output": "\n".join(lines),
	}


func run_action_cap_probe(options: Dictionary) -> Dictionary:
	var deck_id: int = int(options.get("deck_id", 0))
	var anchor_deck_id: int = int(options.get("anchor_deck_id", RunnerBootstrapScript.DEFAULT_ANCHOR_DECK_ID))
	var anchor_strategy_override: String = str(options.get("anchor_strategy_override", ""))
	var seed_value: int = int(options.get("seed", 0))
	var tracked_player_index: int = int(options.get("tracked_player_index", 0))
	var max_steps: int = int(options.get("max_steps", RunnerBootstrapScript.DEFAULT_MAX_STEPS))
	var errors: Array[String] = []
	var card_database = _get_card_database()
	var tracked_deck: DeckData = null
	var anchor_deck: DeckData = null
	if card_database != null:
		tracked_deck = card_database.call("get_deck", deck_id)
		anchor_deck = card_database.call("get_deck", anchor_deck_id)
	if deck_id <= 0:
		errors.append("Missing --deck-id")
	if seed_value <= 0:
		errors.append("Missing --seed")
	if tracked_deck == null:
		errors.append("Unable to load tracked deck %d" % deck_id)
	if anchor_deck == null:
		errors.append("Unable to load anchor deck %d" % anchor_deck_id)
	if not errors.is_empty():
		return {
			"mode": RunnerBootstrapScript.RUN_MODE_ACTION_CAP_PROBE,
			"errors": errors,
			"error_count": errors.size(),
			"output": "AITrainingTestRunner action cap probe failed: %s" % ", ".join(errors),
		}

	var benchmark_runner := AIBenchmarkRunnerScript.new()
	var gsm := GameStateMachine.new()
	benchmark_runner.call("_clear_forced_shuffle_seed")
	benchmark_runner.call("_apply_match_seed", gsm, seed_value)
	benchmark_runner.call("_set_forced_shuffle_seed", seed_value)
	var player_0_deck: DeckData = tracked_deck if tracked_player_index == 0 else anchor_deck
	var player_1_deck: DeckData = anchor_deck if tracked_player_index == 0 else tracked_deck
	gsm.start_game(player_0_deck, player_1_deck, 0)
	var collector := TraceCollector.new()
	var probe_ai_pair := _build_probe_ai_pair(
		tracked_deck,
		anchor_deck,
		tracked_player_index,
		anchor_strategy_override,
		options
	)
	var result: Dictionary = benchmark_runner.run_headless_duel(
		probe_ai_pair.get("player_0_ai", null),
		probe_ai_pair.get("player_1_ai", null),
		gsm,
		max_steps,
		Callable(),
		collector
	)
	benchmark_runner.call("_clear_forced_shuffle_seed")
	var lines := [
		"PTCG Train Action Cap Probe",
		"Tracked deck: %s (%d)" % [tracked_deck.deck_name, tracked_deck.id],
		"Anchor deck: %s (%d)" % [anchor_deck.deck_name, anchor_deck.id],
		"Anchor strategy override: %s" % anchor_strategy_override,
		"Seed: %d" % seed_value,
		"Tracked player index: %d" % tracked_player_index,
		"Result: %s" % JSON.stringify(result),
		"Trace tail: %s" % _trace_tail_summary(collector.traces),
	]
	var trace_jsonl_output := str(options.get("trace_jsonl_output", ""))
	if trace_jsonl_output != "":
		_write_trace_jsonl(trace_jsonl_output, collector.traces)
	return {
		"mode": RunnerBootstrapScript.RUN_MODE_ACTION_CAP_PROBE,
		"deck_id": tracked_deck.id,
		"anchor_deck_id": anchor_deck.id,
		"seed": seed_value,
		"tracked_player_index": tracked_player_index,
		"result": result,
		"trace_tail": _trace_tail_summary(collector.traces),
		"errors": errors,
		"error_count": errors.size(),
		"output": "\n".join(lines),
	}


func _build_probe_ai_pair(
	tracked_deck: DeckData,
	anchor_deck: DeckData,
	tracked_player_index: int,
	anchor_strategy_override: String,
	options: Dictionary
) -> Dictionary:
	var tracked_artifact_overrides := _build_artifact_overrides(options, "tracked")
	var anchor_artifact_overrides := _build_artifact_overrides(options, "anchor")
	var player_0_override := "" if tracked_player_index == 0 else anchor_strategy_override
	var player_1_override := anchor_strategy_override if tracked_player_index == 0 else ""
	var player_0_artifacts := tracked_artifact_overrides if tracked_player_index == 0 else anchor_artifact_overrides
	var player_1_artifacts := anchor_artifact_overrides if tracked_player_index == 0 else tracked_artifact_overrides
	return {
		"player_0_ai": _make_matchup_ai(0, tracked_deck.id if tracked_player_index == 0 else anchor_deck.id, player_0_override, player_0_artifacts),
		"player_1_ai": _make_matchup_ai(1, anchor_deck.id if tracked_player_index == 0 else tracked_deck.id, player_1_override, player_1_artifacts),
	}


func run_miraidon_baseline_regression(options: Dictionary) -> Dictionary:
	var games_per_matchup: int = int(options.get("games_per_matchup", RunnerBootstrapScript.DEFAULT_GAMES_PER_MATCHUP))
	var max_steps: int = int(options.get("max_steps", RunnerBootstrapScript.DEFAULT_MAX_STEPS))
	var seed_bases: Array[int] = RunnerBootstrapScript.resolve_seed_bases(options)
	var errors: Array[String] = []
	var card_database = _get_card_database()
	var miraidon_deck: DeckData = null
	if card_database != null:
		miraidon_deck = card_database.call("get_deck", RunnerBootstrapScript.DEFAULT_ANCHOR_DECK_ID)
	if miraidon_deck == null:
		errors.append("Unable to load Miraidon deck %d" % RunnerBootstrapScript.DEFAULT_ANCHOR_DECK_ID)
		return {
			"mode": RunnerBootstrapScript.RUN_MODE_MIRAIDON_BASELINE_REGRESSION,
			"errors": errors,
			"error_count": errors.size(),
			"output": "AITrainingTestRunner Miraidon baseline regression failed: %s" % ", ".join(errors),
		}

	var benchmark_runner := AIBenchmarkRunnerScript.new()
	var live_overrides := _build_artifact_overrides(options, "tracked")
	var baseline_overrides := _build_artifact_overrides(options, "anchor")
	var per_seed_results: Array[Dictionary] = []
	for seed_base: int in seed_bases:
		per_seed_results.append(_run_miraidon_baseline_regression_seed(
			benchmark_runner,
			miraidon_deck,
			games_per_matchup,
			max_steps,
			seed_base,
			live_overrides,
			baseline_overrides
		))
	var aggregate := _aggregate_seed_summaries(per_seed_results)
	var total_games: int = int(aggregate.get("games", max(1, games_per_matchup * max(1, seed_bases.size()))))
	var output_lines := [
		"PTCG Train Miraidon Baseline Regression",
		"Live deck: %s (%d)" % [miraidon_deck.deck_name, miraidon_deck.id],
		"Games per seed: %d" % games_per_matchup,
		"Seed bases: %s" % ", ".join(_stringify_int_array(seed_bases)),
		"Total games: %d" % total_games,
		"Live Miraidon wins: %d" % int(aggregate.get("wins", 0)),
		"Baseline Miraidon wins: %d" % int(aggregate.get("losses", 0)),
		"Draws: %d" % int(aggregate.get("draws", 0)),
		"Live win rate: %.1f%% (sigma %.1f%%)" % [float(aggregate.get("win_rate_mean", aggregate.get("win_rate", 0.0))) * 100.0, float(aggregate.get("win_rate_stdev", 0.0)) * 100.0],
	]
	return {
		"mode": RunnerBootstrapScript.RUN_MODE_MIRAIDON_BASELINE_REGRESSION,
		"deck_id": miraidon_deck.id,
		"deck_name": miraidon_deck.deck_name,
		"games": total_games,
		"games_per_matchup": games_per_matchup,
		"wins": int(aggregate.get("wins", 0)),
		"losses": int(aggregate.get("losses", 0)),
		"draws": int(aggregate.get("draws", 0)),
		"win_rate": float(aggregate.get("win_rate_mean", aggregate.get("win_rate", 0.0))),
		"win_rate_mean": float(aggregate.get("win_rate_mean", aggregate.get("win_rate", 0.0))),
		"win_rate_stdev": float(aggregate.get("win_rate_stdev", 0.0)),
		"avg_turns": float(aggregate.get("avg_turns_mean", aggregate.get("avg_turns", 0.0))),
		"avg_turns_mean": float(aggregate.get("avg_turns_mean", aggregate.get("avg_turns", 0.0))),
		"failure_reason_counts": aggregate.get("failure_reason_counts", {}),
		"games_detail": aggregate.get("games_detail", []),
		"seed_bases": seed_bases,
		"per_seed_results": per_seed_results,
		"errors": errors,
		"error_count": errors.size(),
		"output": "\n".join(output_lines),
	}


func _run_matchup_for_deck(
	benchmark_runner,
	deck: DeckData,
	anchor_deck: DeckData,
	deck_index: int,
	games_per_matchup: int,
	max_steps: int,
	seed_base: int,
	deck_strategy_override: String = "",
	anchor_strategy_override: String = "",
	deck_artifact_overrides: Dictionary = {},
	anchor_artifact_overrides: Dictionary = {}
) -> Dictionary:
	var wins := 0
	var losses := 0
	var draws := 0
	var total_turns := 0
	var failure_reason_counts := {}
	var per_game: Array[Dictionary] = []
	for game_index: int in games_per_matchup:
		var seed_value: int = seed_base + deck_index * 100 + game_index
		var tracked_player_index: int = game_index % 2
		var gsm := GameStateMachine.new()
		benchmark_runner.call("_clear_forced_shuffle_seed")
		benchmark_runner.call("_apply_match_seed", gsm, seed_value)
		benchmark_runner.call("_set_forced_shuffle_seed", seed_value)
		var player_0_deck: DeckData = deck if tracked_player_index == 0 else anchor_deck
		var player_1_deck: DeckData = anchor_deck if tracked_player_index == 0 else deck
		gsm.start_game(player_0_deck, player_1_deck, 0)

		var player_0_override := deck_strategy_override if tracked_player_index == 0 else anchor_strategy_override
		var player_1_override := anchor_strategy_override if tracked_player_index == 0 else deck_strategy_override
		var player_0_artifacts := deck_artifact_overrides if tracked_player_index == 0 else anchor_artifact_overrides
		var player_1_artifacts := anchor_artifact_overrides if tracked_player_index == 0 else deck_artifact_overrides
		var player_0_ai = _make_matchup_ai(0, player_0_deck.id, player_0_override, player_0_artifacts)
		var player_1_ai = _make_matchup_ai(1, player_1_deck.id, player_1_override, player_1_artifacts)
		var result: Dictionary = benchmark_runner.run_headless_duel(player_0_ai, player_1_ai, gsm, max_steps)
		benchmark_runner.call("_clear_forced_shuffle_seed")

		var winner_index: int = int(result.get("winner_index", -1))
		if winner_index == tracked_player_index:
			wins += 1
		elif winner_index < 0:
			draws += 1
		else:
			losses += 1

		total_turns += int(result.get("turn_count", 0))
		var failure_reason: String = str(result.get("failure_reason", ""))
		if failure_reason != "":
			failure_reason_counts[failure_reason] = int(failure_reason_counts.get(failure_reason, 0)) + 1

		per_game.append({
			"seed": seed_value,
			"tracked_player_index": tracked_player_index,
			"winner_index": winner_index,
			"turn_count": int(result.get("turn_count", 0)),
			"failure_reason": failure_reason,
			"terminated_by_cap": bool(result.get("terminated_by_cap", false)),
			"stalled": bool(result.get("stalled", false)),
		})

	var total_games: int = max(1, games_per_matchup)
	return {
		"deck_id": deck.id,
		"deck_name": deck.deck_name,
		"anchor_deck_id": anchor_deck.id,
		"anchor_deck_name": anchor_deck.deck_name,
		"deck_strategy_override": deck_strategy_override,
		"anchor_strategy_override": anchor_strategy_override,
		"games": games_per_matchup,
		"wins": wins,
		"losses": losses,
		"draws": draws,
		"win_rate": float(wins) / float(total_games),
		"avg_turns": float(total_turns) / float(total_games),
		"failure_reason_counts": failure_reason_counts,
		"games_detail": per_game,
	}


func _run_matchup_for_deck_multi_seed(
	benchmark_runner,
	deck: DeckData,
	anchor_deck: DeckData,
	deck_index: int,
	games_per_matchup: int,
	max_steps: int,
	seed_bases: Array[int],
	deck_strategy_override: String = "",
	anchor_strategy_override: String = "",
	deck_artifact_overrides: Dictionary = {},
	anchor_artifact_overrides: Dictionary = {}
) -> Dictionary:
	var per_seed_results: Array[Dictionary] = []
	for seed_base: int in seed_bases:
		per_seed_results.append(_run_matchup_for_deck(
			benchmark_runner,
			deck,
			anchor_deck,
			deck_index,
			games_per_matchup,
			max_steps,
			seed_base,
			deck_strategy_override,
			anchor_strategy_override,
			deck_artifact_overrides,
			anchor_artifact_overrides
		))
	var aggregate := _aggregate_seed_summaries(per_seed_results)
	aggregate["deck_id"] = deck.id
	aggregate["deck_name"] = deck.deck_name
	aggregate["anchor_deck_id"] = anchor_deck.id
	aggregate["anchor_deck_name"] = anchor_deck.deck_name
	aggregate["deck_strategy_override"] = deck_strategy_override
	aggregate["anchor_strategy_override"] = anchor_strategy_override
	aggregate["games_per_matchup"] = games_per_matchup
	aggregate["seed_bases"] = seed_bases.duplicate()
	aggregate["per_seed_results"] = per_seed_results
	return aggregate


func _make_matchup_ai(player_index: int, deck_id: int, strategy_override_id: String = "", artifact_overrides: Dictionary = {}):
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	if strategy_override_id != "":
		if strategy_override_id == "miraidon_baseline":
			ai.set_deck_strategy(DeckStrategyMiraidonBaselineScript.new())
			_apply_matchup_artifact_overrides(ai, ai._deck_strategy, artifact_overrides)
			return ai
		var override_registry := DeckStrategyRegistryScript.new()
		var override_strategy = override_registry.create_strategy_by_id(strategy_override_id)
		if override_strategy != null:
			ai.set_deck_strategy(override_strategy)
			_apply_matchup_artifact_overrides(ai, ai._deck_strategy, artifact_overrides)
			return ai
	var card_database = _get_card_database()
	var deck: DeckData = null
	if card_database != null:
		deck = card_database.call("get_deck", deck_id)
	var strategy = null
	if deck != null:
		var registry := DeckStrategyRegistryScript.new()
		strategy = registry.apply_strategy_for_deck(ai, deck)
	_apply_matchup_artifact_overrides(ai, strategy, artifact_overrides)
	return ai


func _build_artifact_overrides(options: Dictionary, prefix: String) -> Dictionary:
	return {
		"value_net_path": str(options.get("%s_value_net_path" % prefix, "")),
		"action_scorer_path": str(options.get("%s_action_scorer_path" % prefix, "")),
		"interaction_scorer_path": str(options.get("%s_interaction_scorer_path" % prefix, "")),
		"decision_mode": str(options.get("%s_decision_mode" % prefix, "")),
	}


func _apply_matchup_artifact_overrides(ai: AIOpponent, strategy, artifact_overrides: Dictionary) -> void:
	if ai == null or artifact_overrides.is_empty():
		return
	var value_net_path := str(artifact_overrides.get("value_net_path", ""))
	var action_scorer_path := str(artifact_overrides.get("action_scorer_path", ""))
	var interaction_scorer_path := str(artifact_overrides.get("interaction_scorer_path", ""))
	var decision_mode := str(artifact_overrides.get("decision_mode", ""))
	if value_net_path != "":
		ai.value_net_path = value_net_path
		ai.use_mcts = true
		if strategy != null and strategy.has_method("get_mcts_config"):
			ai.mcts_config = strategy.call("get_mcts_config")
	if action_scorer_path != "":
		ai.action_scorer_path = action_scorer_path
	if interaction_scorer_path != "":
		ai.interaction_scorer_path = interaction_scorer_path
	if decision_mode != "":
		ai.decision_runtime_mode = decision_mode


func _trace_tail_summary(traces: Array, limit: int = 32) -> String:
	var start_index := maxi(0, traces.size() - limit)
	var parts: Array[String] = []
	for idx: int in range(start_index, traces.size()):
		var trace = traces[idx]
		if trace == null:
			continue
		var chosen_action: Dictionary = trace.chosen_action if trace.chosen_action is Dictionary else {}
		var reason_tags: Array = trace.reason_tags if trace.reason_tags is Array else []
		var card_name := str(chosen_action.get("card_name", chosen_action.get("name", "")))
		var source_name := ""
		var source_slot: Variant = chosen_action.get("source_slot", null)
		if source_slot is PokemonSlot:
			source_name = (source_slot as PokemonSlot).get_pokemon_name()
		var target_name := ""
		var target_slot: Variant = chosen_action.get("target_slot", null)
		if target_slot is PokemonSlot:
			target_name = (target_slot as PokemonSlot).get_pokemon_name()
		parts.append("t%d:p%d:%s:%s:%s:%s:a%d:u%d:%s" % [
			int(trace.turn_number),
			int(trace.player_index),
			str(chosen_action.get("kind", "")),
			source_name,
			card_name,
			target_name,
			int(chosen_action.get("attack_index", -1)),
			int(chosen_action.get("ability_index", -1)),
			",".join(reason_tags),
		])
	return " | ".join(parts)


func _format_matchup_summary_line(summary: Dictionary) -> String:
	var failure_counts: Dictionary = summary.get("failure_reason_counts", {})
	var failure_fragments: Array[String] = []
	for reason: Variant in failure_counts.keys():
		failure_fragments.append("%s:%d" % [str(reason), int(failure_counts[reason])])
	failure_fragments.sort()
	var failure_text := ",".join(failure_fragments)
	if failure_text == "":
		failure_text = "-"
	return "%-7d %-22s %3d  %3d  %3d   %5.1f%%  %4.1f%%   %5.1f    %s" % [
		int(summary.get("deck_id", -1)),
		RunnerBootstrapScript.truncate_name(str(summary.get("deck_name", "")), 22),
		int(summary.get("wins", 0)),
		int(summary.get("losses", 0)),
		int(summary.get("draws", 0)),
		float(summary.get("win_rate_mean", summary.get("win_rate", 0.0))) * 100.0,
		float(summary.get("win_rate_stdev", 0.0)) * 100.0,
		float(summary.get("avg_turns_mean", summary.get("avg_turns", 0.0))),
		failure_text,
	]


func _run_miraidon_baseline_regression_seed(
	benchmark_runner,
	miraidon_deck: DeckData,
	games_per_matchup: int,
	max_steps: int,
	seed_base: int,
	live_overrides: Dictionary,
	baseline_overrides: Dictionary
) -> Dictionary:
	var wins := 0
	var losses := 0
	var draws := 0
	var total_turns := 0
	var failure_reason_counts := {}
	var per_game: Array[Dictionary] = []
	for game_index: int in games_per_matchup:
		var seed_value: int = seed_base + game_index
		var live_player_index: int = game_index % 2
		var gsm := GameStateMachine.new()
		benchmark_runner.call("_clear_forced_shuffle_seed")
		benchmark_runner.call("_apply_match_seed", gsm, seed_value)
		benchmark_runner.call("_set_forced_shuffle_seed", seed_value)
		gsm.start_game(miraidon_deck, miraidon_deck, 0)

		var player_0_ai = _make_matchup_ai(
			0,
			miraidon_deck.id,
			"" if live_player_index == 0 else "miraidon_baseline",
			live_overrides if live_player_index == 0 else baseline_overrides
		)
		var player_1_ai = _make_matchup_ai(
			1,
			miraidon_deck.id,
			"miraidon_baseline" if live_player_index == 0 else "",
			baseline_overrides if live_player_index == 0 else live_overrides
		)
		var result: Dictionary = benchmark_runner.run_headless_duel(player_0_ai, player_1_ai, gsm, max_steps)
		benchmark_runner.call("_clear_forced_shuffle_seed")

		var winner_index: int = int(result.get("winner_index", -1))
		if winner_index == live_player_index:
			wins += 1
		elif winner_index < 0:
			draws += 1
		else:
			losses += 1

		total_turns += int(result.get("turn_count", 0))
		var failure_reason: String = str(result.get("failure_reason", ""))
		if failure_reason != "":
			failure_reason_counts[failure_reason] = int(failure_reason_counts.get(failure_reason, 0)) + 1
		per_game.append({
			"seed": seed_value,
			"live_player_index": live_player_index,
			"winner_index": winner_index,
			"turn_count": int(result.get("turn_count", 0)),
			"failure_reason": failure_reason,
			"terminated_by_cap": bool(result.get("terminated_by_cap", false)),
			"stalled": bool(result.get("stalled", false)),
		})
	var total_games: int = max(1, games_per_matchup)
	return {
		"seed_base": seed_base,
		"games": games_per_matchup,
		"wins": wins,
		"losses": losses,
		"draws": draws,
		"win_rate": float(wins) / float(total_games),
		"avg_turns": float(total_turns) / float(total_games),
		"failure_reason_counts": failure_reason_counts,
		"games_detail": per_game,
	}


func _aggregate_seed_summaries(per_seed_results: Array[Dictionary]) -> Dictionary:
	var wins := 0
	var losses := 0
	var draws := 0
	var total_games := 0
	var failure_reason_counts := {}
	var all_games: Array[Dictionary] = []
	var win_rates: Array[float] = []
	var avg_turns_values: Array[float] = []
	for summary: Dictionary in per_seed_results:
		wins += int(summary.get("wins", 0))
		losses += int(summary.get("losses", 0))
		draws += int(summary.get("draws", 0))
		total_games += int(summary.get("games", 0))
		win_rates.append(float(summary.get("win_rate", 0.0)))
		avg_turns_values.append(float(summary.get("avg_turns", 0.0)))
		var failure_counts: Dictionary = summary.get("failure_reason_counts", {})
		for reason: Variant in failure_counts.keys():
			var reason_name := str(reason)
			failure_reason_counts[reason_name] = int(failure_reason_counts.get(reason_name, 0)) + int(failure_counts[reason])
		var games_detail: Variant = summary.get("games_detail", [])
		if games_detail is Array:
			for game_entry: Variant in games_detail:
				if game_entry is Dictionary:
					all_games.append((game_entry as Dictionary).duplicate(true))
	return {
		"games": total_games,
		"wins": wins,
		"losses": losses,
		"draws": draws,
		"win_rate": float(wins) / float(max(1, total_games)),
		"win_rate_mean": _mean_float_array(win_rates),
		"win_rate_stdev": _sample_stdev_float_array(win_rates),
		"avg_turns": _mean_float_array(avg_turns_values),
		"avg_turns_mean": _mean_float_array(avg_turns_values),
		"avg_turns_stdev": _sample_stdev_float_array(avg_turns_values),
		"failure_reason_counts": failure_reason_counts,
		"games_detail": all_games,
	}


func _mean_float_array(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _sample_stdev_float_array(values: Array[float]) -> float:
	if values.size() <= 1:
		return 0.0
	var mean := _mean_float_array(values)
	var sum_sq := 0.0
	for value: float in values:
		var diff := value - mean
		sum_sq += diff * diff
	return sqrt(sum_sq / float(values.size() - 1))


func _stringify_int_array(values: Array[int]) -> Array[String]:
	var rendered: Array[String] = []
	for value: int in values:
		rendered.append(str(value))
	return rendered


func _get_card_database():
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			var tree_database = tree.root.get_node_or_null("CardDatabase")
			if tree_database != null:
				return tree_database
	return CardDatabase


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("AITrainingRunnerScene: failed to open %s for writing" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))


func _write_trace_jsonl(path: String, traces: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("AITrainingRunnerScene: failed to open %s for writing" % path)
		return
	for trace in traces:
		if trace == null:
			continue
		var payload: Dictionary = trace.to_dictionary() if trace.has_method("to_dictionary") else {}
		file.store_line(JSON.stringify(payload))
