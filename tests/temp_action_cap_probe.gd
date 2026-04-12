extends SceneTree

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const CardDatabaseScript = preload("res://scripts/autoload/CardDatabase.gd")


class TraceCollector extends RefCounted:
	var traces: Array = []

	func record_trace(trace) -> void:
		if trace == null:
			return
		traces.append(trace.clone())


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var deck_id: int = int(args.get("deck_id", 0))
	var anchor_deck_id: int = int(args.get("anchor_deck_id", 575720))
	var seed_value: int = int(args.get("seed", 0))
	var tracked_player_index: int = int(args.get("tracked_player_index", 0))
	var max_steps: int = int(args.get("max_steps", 200))
	var card_database = _get_card_database()

	if deck_id <= 0 or seed_value <= 0:
		push_error("usage: --deck-id=<id> --seed=<n> [--anchor-deck-id=575720] [--tracked-player-index=0|1] [--max-steps=200]")
		quit(2)
		return

	var tracked_deck: DeckData = card_database.get_deck(deck_id)
	var anchor_deck: DeckData = card_database.get_deck(anchor_deck_id)
	if tracked_deck == null or anchor_deck == null:
		push_error("failed to load deck(s): tracked=%s anchor=%s" % [str(tracked_deck), str(anchor_deck)])
		quit(3)
		return

	var benchmark_runner := AIBenchmarkRunnerScript.new()
	var gsm := GameStateMachine.new()
	benchmark_runner.call("_clear_forced_shuffle_seed")
	benchmark_runner.call("_apply_match_seed", gsm, seed_value)
	benchmark_runner.call("_set_forced_shuffle_seed", seed_value)
	var player_0_deck: DeckData = tracked_deck if tracked_player_index == 0 else anchor_deck
	var player_1_deck: DeckData = anchor_deck if tracked_player_index == 0 else tracked_deck
	gsm.start_game(player_0_deck, player_1_deck, 0)

	var player_0_ai := _make_ai(0, player_0_deck.id, card_database)
	var player_1_ai := _make_ai(1, player_1_deck.id, card_database)
	var collector := TraceCollector.new()
	var result: Dictionary = _run_verbose_duel(
		benchmark_runner,
		player_0_ai,
		player_1_ai,
		gsm,
		max_steps,
		collector
	)
	benchmark_runner.call("_clear_forced_shuffle_seed")

	print("== Action Cap Probe ==")
	print("tracked_deck_id=%d anchor_deck_id=%d seed=%d tracked_player_index=%d max_steps=%d" % [
		deck_id,
		anchor_deck_id,
		seed_value,
		tracked_player_index,
		max_steps,
	])
	print("result=%s" % JSON.stringify(result))
	print("trace_count=%d" % collector.traces.size())
	print("-- trace tail --")
	var start_index := maxi(0, collector.traces.size() - 40)
	for idx: int in range(start_index, collector.traces.size()):
		var trace = collector.traces[idx]
		var chosen_action: Dictionary = trace.chosen_action if trace.chosen_action is Dictionary else {}
		var reason_tags: Array = trace.reason_tags if trace.reason_tags is Array else []
		var card_name: String = str(chosen_action.get("card_name", chosen_action.get("name", "")))
		var source_name := ""
		var source_slot: Variant = chosen_action.get("source_slot", null)
		if source_slot is PokemonSlot:
			source_name = (source_slot as PokemonSlot).get_pokemon_name()
		var target_name := ""
		var target_slot: Variant = chosen_action.get("target_slot", null)
		if target_slot is PokemonSlot:
			target_name = (target_slot as PokemonSlot).get_pokemon_name()
		print("%03d turn=%d player=%d kind=%s source=%s card=%s target=%s atk=%d ability=%d tags=%s" % [
			idx,
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
	quit(0)


func _run_verbose_duel(
	benchmark_runner,
	player_0_ai: AIOpponent,
	player_1_ai: AIOpponent,
	gsm: GameStateMachine,
	max_steps: int,
	collector: TraceCollector
) -> Dictionary:
	var bridge := preload("res://scripts/ai/HeadlessMatchBridge.gd").new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()
	var result: Dictionary = {}
	var steps: int = 0
	while steps < max_steps:
		var active_0: String = _slot_name(gsm.game_state.players[0].active_pokemon)
		var active_1: String = _slot_name(gsm.game_state.players[1].active_pokemon)
		print("STEP %03d turn=%d current=%d phase=%s pending=%s active0=%s active1=%s" % [
			steps + 1,
			int(gsm.game_state.turn_number),
			int(gsm.game_state.current_player_index),
			str(gsm.game_state.phase),
			str(bridge.get_pending_prompt_type()),
			active_0,
			active_1,
		])
		if gsm.game_state.is_game_over():
			result = benchmark_runner._make_success_match_result(gsm, steps)
			break
		var progressed := false
		if bridge.has_pending_prompt():
			if bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
				print("  prompt_resolved=%s" % str(progressed))
			else:
				var prompt_owner: int = bridge.get_pending_prompt_owner()
				var prompt_ai: AIOpponent = player_0_ai if prompt_owner == 0 else player_1_ai
				progressed = prompt_ai.run_single_step(bridge, gsm)
				benchmark_runner._record_decision_trace_if_available(collector, prompt_ai)
				print("  prompt_ai=%d progressed=%s pending_now=%s" % [prompt_owner, str(progressed), str(bridge.get_pending_prompt_type())])
		else:
			var current_player: int = gsm.game_state.current_player_index
			var current_ai: AIOpponent = player_0_ai if current_player == 0 else player_1_ai
			progressed = current_ai.run_single_step(bridge, gsm)
			benchmark_runner._record_decision_trace_if_available(collector, current_ai)
			var trace = current_ai.get_last_decision_trace()
			var chosen: Dictionary = trace.chosen_action if trace != null and trace.chosen_action is Dictionary else {}
			print("  action=%s atk=%d ability=%d progressed=%s pending_now=%s" % [
				str(chosen.get("kind", "")),
				int(chosen.get("attack_index", -1)),
				int(chosen.get("ability_index", -1)),
				str(progressed),
				str(bridge.get_pending_prompt_type()),
			])
		steps += 1
	if result.is_empty():
		result = benchmark_runner._make_failed_match_result("action_cap_reached", max_steps, gsm)
	bridge.free()
	return result


func _slot_name(slot: PokemonSlot) -> String:
	if slot == null:
		return "<none>"
	return slot.get_pokemon_name()


func _make_ai(player_index: int, deck_id: int, card_database) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	var deck: DeckData = card_database.get_deck(deck_id)
	if deck == null:
		return ai
	var registry := DeckStrategyRegistryScript.new()
	registry.apply_strategy_for_deck(ai, deck)
	return ai


func _get_card_database():
	if root != null:
		var tree_database = root.get_node_or_null("CardDatabase")
		if tree_database != null:
			return tree_database
	var card_database = CardDatabaseScript.new()
	card_database._ensure_directories()
	card_database._seed_bundled_user_data()
	card_database._load_all_decks()
	return card_database


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for raw_arg: String in raw_args:
		if raw_arg.begins_with("--deck-id="):
			parsed["deck_id"] = int(raw_arg.trim_prefix("--deck-id="))
		elif raw_arg.begins_with("--anchor-deck-id="):
			parsed["anchor_deck_id"] = int(raw_arg.trim_prefix("--anchor-deck-id="))
		elif raw_arg.begins_with("--seed="):
			parsed["seed"] = int(raw_arg.trim_prefix("--seed="))
		elif raw_arg.begins_with("--tracked-player-index="):
			parsed["tracked_player_index"] = int(raw_arg.trim_prefix("--tracked-player-index="))
		elif raw_arg.begins_with("--max-steps="):
			parsed["max_steps"] = int(raw_arg.trim_prefix("--max-steps="))
	return parsed
