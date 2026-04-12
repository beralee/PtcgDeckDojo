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
	var suite_report := SharedSuiteRunnerScript.run_suites(suites, selected_suites, "PTCG Train AI/Training Tests")
	print(suite_report.get("output", ""))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if int(suite_report.get("failed", 0)) > 0 else 0)


func run_matchup_sweep(options: Dictionary) -> Dictionary:
	var anchor_deck_id: int = int(options.get("anchor_deck_id", RunnerBootstrapScript.DEFAULT_ANCHOR_DECK_ID))
	var anchor_strategy_override: String = str(options.get("anchor_strategy_override", ""))
	var games_per_matchup: int = int(options.get("games_per_matchup", RunnerBootstrapScript.DEFAULT_GAMES_PER_MATCHUP))
	var max_steps: int = int(options.get("max_steps", RunnerBootstrapScript.DEFAULT_MAX_STEPS))
	var seed_base: int = int(options.get("seed_base", RunnerBootstrapScript.DEFAULT_SEED_BASE))
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
	lines.append("Decks: %d" % deck_ids.size())
	lines.append("")
	lines.append("Deck ID  Name                    Win  Loss Draw  WinRate  AvgTurns  Failures")

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
		var summary := _run_matchup_for_deck(
			benchmark_runner,
			deck,
			anchor_deck,
			deck_index,
			games_per_matchup,
			max_steps,
			seed_base,
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
		"seed_base": seed_base,
		"deck_ids": deck_ids,
		"results": results,
		"errors": errors,
		"error_count": errors.size(),
		"output": "\n".join(lines),
	}


func run_action_cap_probe(options: Dictionary) -> Dictionary:
	var deck_id: int = int(options.get("deck_id", 0))
	var anchor_deck_id: int = int(options.get("anchor_deck_id", RunnerBootstrapScript.DEFAULT_ANCHOR_DECK_ID))
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
	var result: Dictionary = benchmark_runner.run_headless_duel(
		_make_matchup_ai(0, player_0_deck.id),
		_make_matchup_ai(1, player_1_deck.id),
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


func run_miraidon_baseline_regression(options: Dictionary) -> Dictionary:
	var games_per_matchup: int = int(options.get("games_per_matchup", RunnerBootstrapScript.DEFAULT_GAMES_PER_MATCHUP))
	var max_steps: int = int(options.get("max_steps", RunnerBootstrapScript.DEFAULT_MAX_STEPS))
	var seed_base: int = int(options.get("seed_base", RunnerBootstrapScript.DEFAULT_SEED_BASE))
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

		var live_overrides := _build_artifact_overrides(options, "tracked")
		var baseline_overrides := _build_artifact_overrides(options, "anchor")
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
	var output_lines := [
		"PTCG Train Miraidon Baseline Regression",
		"Live deck: %s (%d)" % [miraidon_deck.deck_name, miraidon_deck.id],
		"Games: %d" % games_per_matchup,
		"Live Miraidon wins: %d" % wins,
		"Baseline Miraidon wins: %d" % losses,
		"Draws: %d" % draws,
		"Live win rate: %.1f%%" % [float(wins) / float(total_games) * 100.0],
	]
	return {
		"mode": RunnerBootstrapScript.RUN_MODE_MIRAIDON_BASELINE_REGRESSION,
		"deck_id": miraidon_deck.id,
		"deck_name": miraidon_deck.deck_name,
		"games": games_per_matchup,
		"wins": wins,
		"losses": losses,
		"draws": draws,
		"win_rate": float(wins) / float(total_games),
		"avg_turns": float(total_turns) / float(total_games),
		"failure_reason_counts": failure_reason_counts,
		"games_detail": per_game,
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


func _make_matchup_ai(player_index: int, deck_id: int, strategy_override_id: String = "", artifact_overrides: Dictionary = {}):
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	if strategy_override_id == "miraidon_baseline":
		ai.set_deck_strategy(DeckStrategyMiraidonBaselineScript.new())
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
	}


func _apply_matchup_artifact_overrides(ai: AIOpponent, strategy, artifact_overrides: Dictionary) -> void:
	if ai == null or artifact_overrides.is_empty():
		return
	var value_net_path := str(artifact_overrides.get("value_net_path", ""))
	var action_scorer_path := str(artifact_overrides.get("action_scorer_path", ""))
	var interaction_scorer_path := str(artifact_overrides.get("interaction_scorer_path", ""))
	if value_net_path != "":
		ai.value_net_path = value_net_path
		ai.use_mcts = true
		if strategy != null and strategy.has_method("get_mcts_config"):
			ai.mcts_config = strategy.call("get_mcts_config")
	if action_scorer_path != "":
		ai.action_scorer_path = action_scorer_path
	if interaction_scorer_path != "":
		ai.interaction_scorer_path = interaction_scorer_path


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
	return "%-7d %-22s %3d  %3d  %3d   %5.1f%%    %5.1f    %s" % [
		int(summary.get("deck_id", -1)),
		RunnerBootstrapScript.truncate_name(str(summary.get("deck_name", "")), 22),
		int(summary.get("wins", 0)),
		int(summary.get("losses", 0)),
		int(summary.get("draws", 0)),
		float(summary.get("win_rate", 0.0)) * 100.0,
		float(summary.get("avg_turns", 0.0)),
		failure_text,
	]


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
