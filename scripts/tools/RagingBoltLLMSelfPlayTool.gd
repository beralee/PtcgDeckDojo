class_name RagingBoltLLMSelfPlayTool
extends RefCounted

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const AutoloadResolverScript = preload("res://scripts/engine/AutoloadResolver.gd")

const DEFAULT_DECK_ID := 575718
const DEFAULT_STRATEGY_ID := "raging_bolt_ogerpon_llm"
const DEFAULT_GAMES := 1
const DEFAULT_MAX_STEPS := 160
const DEFAULT_SEED_BASE := 260426
const DEFAULT_LLM_WAIT_SECONDS := 90.0


func run(options: Dictionary, tree: SceneTree) -> Dictionary:
	var result := {
		"games": [],
		"errors": [],
		"log_path": _resolve_log_path(str(options.get("log_path", ""))),
		"llm_audit_paths": [],
	}
	if tree == null:
		result["errors"].append("SceneTree is required")
		return result

	var host_node := Node.new()
	host_node.name = "RagingBoltLLMSelfPlayHost"
	tree.root.add_child(host_node)

	var games: int = max(1, int(options.get("games", DEFAULT_GAMES)))
	var seed_base: int = int(options.get("seed_base", DEFAULT_SEED_BASE))
	var max_steps: int = max(1, int(options.get("max_steps", DEFAULT_MAX_STEPS)))
	_write_jsonl(str(result["log_path"]), {
		"event": "self_play_start",
		"deck_id": DEFAULT_DECK_ID,
		"strategy_id": DEFAULT_STRATEGY_ID,
		"games": games,
		"seed_base": seed_base,
		"max_steps": max_steps,
	})

	for game_index: int in games:
		var game_result: Dictionary = await _run_one_game(game_index, seed_base + game_index, max_steps, options, tree, host_node, str(result["log_path"]))
		result["games"].append(game_result)
		for path: Variant in game_result.get("llm_audit_paths", []):
			var path_str := str(path)
			if path_str != "" and not (result["llm_audit_paths"] as Array).has(path_str):
				(result["llm_audit_paths"] as Array).append(path_str)
		if str(game_result.get("failure_reason", "")) not in ["", "normal_game_end", "deck_out"]:
			result["errors"].append("game %d failed: %s" % [game_index, str(game_result.get("failure_reason", ""))])

	_write_jsonl(str(result["log_path"]), {
		"event": "self_play_finished",
		"games": result["games"],
		"errors": result["errors"],
		"llm_audit_paths": result["llm_audit_paths"],
	})
	host_node.queue_free()
	return result


func _run_one_game(
	game_index: int,
	seed: int,
	max_steps: int,
	options: Dictionary,
	tree: SceneTree,
	host_node: Node,
	log_path: String
) -> Dictionary:
	var card_database = AutoloadResolverScript.get_card_database()
	if card_database == null:
		return {"game_index": game_index, "seed": seed, "failure_reason": "missing_card_database"}
	var deck: DeckData = card_database.get_deck(DEFAULT_DECK_ID)
	if deck == null:
		return {"game_index": game_index, "seed": seed, "failure_reason": "missing_raging_bolt_deck"}

	var gsm := GameStateMachine.new()
	_apply_seed(gsm, seed)
	_set_forced_shuffle_seed(seed)
	gsm.start_game(deck, deck, 0)

	var player_0_ai: AIOpponent = _make_llm_ai(0, host_node)
	var player_1_ai: AIOpponent = _make_llm_ai(1, host_node)
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()

	_write_jsonl(log_path, {
		"event": "game_start",
		"game_index": game_index,
		"seed": seed,
		"player_0_deck": deck.deck_name,
		"player_1_deck": deck.deck_name,
		"state": _compact_state(gsm.game_state),
	})

	var steps := 0
	var result := {}
	while steps < max_steps:
		if gsm.game_state == null:
			result = _make_result(game_index, seed, steps, "invalid_state_transition", gsm, player_0_ai, player_1_ai)
			break
		if gsm.game_state.is_game_over():
			result = _make_result(game_index, seed, steps, _terminal_reason(gsm), gsm, player_0_ai, player_1_ai)
			break
		var before := _compact_step_context(gsm, bridge, steps)
		var progressed: bool = await _run_next_step(gsm, bridge, player_0_ai, player_1_ai, tree, options, log_path)
		var after := _compact_step_context(gsm, bridge, steps)
		_write_jsonl(log_path, {
			"event": "step",
			"game_index": game_index,
			"seed": seed,
			"step": steps,
			"progressed": progressed,
			"before": before,
			"after": after,
			"last_action": _last_action_log_entry(gsm),
			"player_0_llm": _strategy_stats(player_0_ai),
			"player_1_llm": _strategy_stats(player_1_ai),
		})
		if not progressed:
			result = _make_result(game_index, seed, steps + 1, "stalled_no_progress", gsm, player_0_ai, player_1_ai)
			break
		steps += 1
	if result.is_empty():
		result = _make_result(game_index, seed, max_steps, "action_cap_reached", gsm, player_0_ai, player_1_ai)

	_write_jsonl(log_path, {
		"event": "game_end",
		"game_index": game_index,
		"seed": seed,
		"result": result,
		"state": _compact_state(gsm.game_state),
	})
	_clear_forced_shuffle_seed()
	bridge.free()
	return result


func _run_next_step(
	gsm: GameStateMachine,
	bridge: Control,
	player_0_ai: AIOpponent,
	player_1_ai: AIOpponent,
	tree: SceneTree,
	options: Dictionary,
	log_path: String
) -> bool:
	if bridge.has_pending_prompt():
		if bridge.can_resolve_pending_prompt():
			return bridge.resolve_pending_prompt()
		var pending_choice: String = bridge.get_pending_prompt_type()
		if pending_choice not in ["effect_interaction", "heavy_baton_target", "send_out"]:
			return false
		var owner: int = bridge.get_pending_prompt_owner()
		var prompt_ai := _ai_for_player(player_0_ai, player_1_ai, owner)
		if prompt_ai == null:
			return false
		return prompt_ai.run_single_step(bridge, gsm)

	var current_player: int = int(gsm.game_state.current_player_index)
	var current_ai := _ai_for_player(player_0_ai, player_1_ai, current_player)
	if current_ai == null:
		return false
	await _prepare_llm_turn(current_ai, gsm, tree, options, log_path)
	var progressed: bool = current_ai.run_single_step(bridge, gsm)
	if not progressed and gsm.game_state != null and gsm.game_state.phase == GameState.GamePhase.MAIN:
		gsm.end_turn(current_player)
		return true
	return progressed


func _prepare_llm_turn(ai: AIOpponent, gsm: GameStateMachine, tree: SceneTree, options: Dictionary, log_path: String) -> void:
	if ai == null or gsm == null or gsm.game_state == null:
		return
	var strategy: Variant = ai.get("_deck_strategy")
	if strategy == null or not strategy.has_method("ensure_llm_request_fired"):
		return
	var turn: int = int(gsm.game_state.turn_number)
	if strategy.has_method("has_llm_plan_for_turn") and strategy.call("has_llm_plan_for_turn", turn):
		return
	if strategy.has_method("is_llm_disabled_for_turn") and strategy.call("is_llm_disabled_for_turn", turn):
		return
	var legal_actions: Array[Dictionary] = ai.get_legal_actions(gsm)
	strategy.call("ensure_llm_request_fired", gsm.game_state, ai.player_index, legal_actions)
	if not strategy.has_method("is_llm_pending"):
		return
	var wait_limit: float = maxf(0.1, float(options.get("llm_wait_seconds", DEFAULT_LLM_WAIT_SECONDS)))
	var started_msec := Time.get_ticks_msec()
	while bool(strategy.call("is_llm_pending")):
		if strategy.has_method("is_llm_soft_timed_out_for_turn") and bool(strategy.call("is_llm_soft_timed_out_for_turn", turn)):
			if strategy.has_method("force_rules_for_turn"):
				strategy.call("force_rules_for_turn", turn, "self-play soft timeout")
			break
		var elapsed_sec := float(Time.get_ticks_msec() - started_msec) / 1000.0
		if elapsed_sec >= wait_limit:
			if strategy.has_method("force_rules_for_turn"):
				strategy.call("force_rules_for_turn", turn, "self-play wait timeout")
			_write_jsonl(log_path, {
				"event": "llm_wait_timeout",
				"turn": turn,
				"player_index": ai.player_index,
				"wait_seconds": elapsed_sec,
			})
			break
		await tree.process_frame


func _make_llm_ai(player_index: int, host_node: Node) -> AIOpponent:
	var ai: AIOpponent = AIOpponentScript.new()
	ai.configure(player_index, 1)
	var registry := DeckStrategyRegistryScript.new()
	var strategy = registry.create_strategy_by_id(DEFAULT_STRATEGY_ID)
	if strategy != null:
		if strategy.has_method("set_llm_host_node"):
			strategy.call("set_llm_host_node", host_node)
		ai.set_deck_strategy(strategy)
	return ai


func _make_result(
	game_index: int,
	seed: int,
	steps: int,
	failure_reason: String,
	gsm: GameStateMachine,
	player_0_ai: AIOpponent,
	player_1_ai: AIOpponent
) -> Dictionary:
	var winner_index := -1
	var turn_count := -1
	if gsm != null and gsm.game_state != null:
		winner_index = int(gsm.game_state.winner_index)
		turn_count = int(gsm.game_state.turn_number)
	return {
		"game_index": game_index,
		"seed": seed,
		"winner_index": winner_index,
		"turn_count": turn_count,
		"steps": steps,
		"failure_reason": failure_reason,
		"terminated_by_cap": failure_reason == "action_cap_reached",
		"stalled": failure_reason == "stalled_no_progress",
		"player_0_llm": _strategy_stats(player_0_ai),
		"player_1_llm": _strategy_stats(player_1_ai),
		"llm_audit_paths": _llm_audit_paths(player_0_ai, player_1_ai),
	}


func _strategy_stats(ai: AIOpponent) -> Dictionary:
	if ai == null:
		return {}
	var strategy: Variant = ai.get("_deck_strategy")
	if strategy == null:
		return {}
	var stats := {}
	if strategy.has_method("get_strategy_id"):
		stats["strategy_id"] = str(strategy.call("get_strategy_id"))
	if strategy.has_method("get_llm_stats"):
		stats["stats"] = strategy.call("get_llm_stats")
	if strategy.has_method("get_llm_action_queue"):
		stats["queue_size"] = (strategy.call("get_llm_action_queue") as Array).size()
	if strategy.has_method("get_llm_audit_log_path"):
		stats["audit_log_path"] = str(strategy.call("get_llm_audit_log_path"))
	return stats


func _llm_audit_paths(player_0_ai: AIOpponent, player_1_ai: AIOpponent) -> Array[String]:
	var paths: Array[String] = []
	for ai: AIOpponent in [player_0_ai, player_1_ai]:
		var stats := _strategy_stats(ai)
		var path := str(stats.get("audit_log_path", ""))
		if path != "" and not paths.has(path):
			paths.append(path)
	return paths


func _ai_for_player(player_0_ai: AIOpponent, player_1_ai: AIOpponent, player_index: int) -> AIOpponent:
	if player_index == 0:
		return player_0_ai
	if player_index == 1:
		return player_1_ai
	return null


func _compact_step_context(gsm: GameStateMachine, bridge: Control, step: int) -> Dictionary:
	return {
		"step": step,
		"turn": int(gsm.game_state.turn_number) if gsm != null and gsm.game_state != null else -1,
		"current_player": int(gsm.game_state.current_player_index) if gsm != null and gsm.game_state != null else -1,
		"phase": _phase_name(gsm.game_state.phase) if gsm != null and gsm.game_state != null else "",
		"pending_prompt": bridge.get_pending_prompt_type() if bridge != null and bridge.has_pending_prompt() else "",
		"state": _compact_state(gsm.game_state if gsm != null else null),
	}


func _compact_state(game_state: GameState) -> Dictionary:
	if game_state == null:
		return {}
	return {
		"turn": int(game_state.turn_number),
		"current_player": int(game_state.current_player_index),
		"phase": _phase_name(game_state.phase),
		"winner_index": int(game_state.winner_index),
		"players": [
			_compact_player(game_state.players[0]) if game_state.players.size() > 0 else {},
			_compact_player(game_state.players[1]) if game_state.players.size() > 1 else {},
		],
	}


func _compact_player(player: PlayerState) -> Dictionary:
	if player == null:
		return {}
	return {
		"player_index": int(player.player_index),
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size(),
		"discard_count": player.discard_pile.size(),
		"prizes_remaining": player.prizes.size(),
		"active": _compact_slot(player.active_pokemon),
		"bench": _compact_bench(player.bench),
	}


func _compact_bench(bench: Array[PokemonSlot]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in bench.size():
		var row := _compact_slot(bench[i])
		row["position"] = "bench_%d" % i
		result.append(row)
	return result


func _compact_slot(slot: PokemonSlot) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {}
	var cd: CardData = slot.get_card_data()
	return {
		"name": str(slot.get_pokemon_name()),
		"name_en": str(cd.name_en),
		"hp_remaining": int(slot.get_remaining_hp()),
		"damage_counters": int(slot.damage_counters),
		"energy_count": slot.attached_energy.size(),
		"energy": _energy_counts(slot),
		"tool": str(slot.attached_tool.card_data.name_en) if slot.attached_tool != null and slot.attached_tool.card_data != null else "",
	}


func _energy_counts(slot: PokemonSlot) -> Dictionary:
	var counts := {}
	if slot == null:
		return counts
	for card: CardInstance in slot.attached_energy:
		if card == null or card.card_data == null:
			continue
		var key := str(card.card_data.energy_provides)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _last_action_log_entry(gsm: GameStateMachine) -> Variant:
	if gsm == null:
		return {}
	var log: Array = gsm.action_log
	if log.is_empty():
		return {}
	return log[log.size() - 1]


func _terminal_reason(gsm: GameStateMachine) -> String:
	if gsm == null or gsm.game_state == null:
		return "invalid_state_transition"
	if not gsm.game_state.is_game_over():
		return ""
	return "normal_game_end"


func _phase_name(phase: int) -> String:
	match phase:
		GameState.GamePhase.SETUP:
			return "SETUP"
		GameState.GamePhase.DRAW:
			return "DRAW"
		GameState.GamePhase.MAIN:
			return "MAIN"
		GameState.GamePhase.ATTACK:
			return "ATTACK"
		GameState.GamePhase.POKEMON_CHECK:
			return "POKEMON_CHECK"
		GameState.GamePhase.BETWEEN_TURNS:
			return "BETWEEN_TURNS"
		GameState.GamePhase.KNOCKOUT_REPLACE:
			return "KNOCKOUT_REPLACE"
		GameState.GamePhase.GAME_OVER:
			return "GAME_OVER"
	return str(phase)


func _apply_seed(gsm: GameStateMachine, seed: int) -> void:
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


func _resolve_log_path(path: String) -> String:
	if path.strip_edges() != "":
		return path
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace(" ", "_")
	return "user://logs/raging_bolt_llm_self_play_%s.jsonl" % stamp


func _write_jsonl(path: String, payload: Dictionary) -> void:
	_ensure_parent_dir(path)
	var entry := payload.duplicate(true)
	entry["ts_unix"] = Time.get_unix_time_from_system()
	entry["ts"] = Time.get_datetime_string_from_system(false, true)
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(_json_safe(entry)))


func _ensure_parent_dir(path: String) -> void:
	if not path.begins_with("user://"):
		return
	var relative := path.trim_prefix("user://")
	var slash := relative.rfind("/")
	if slash < 0:
		return
	var dir_path := "user://" + relative.substr(0, slash)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))


func _json_safe(value: Variant) -> Variant:
	if value == null or value is String or value is bool or value is int or value is float:
		return value
	if value is Dictionary:
		var result := {}
		for key: Variant in (value as Dictionary).keys():
			result[str(key)] = _json_safe((value as Dictionary).get(key))
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_json_safe(item))
		return result
	if value is CardInstance:
		var card: CardInstance = value
		if card.card_data == null:
			return {}
		return {
			"instance_id": int(card.instance_id),
			"name": str(card.card_data.name),
			"name_en": str(card.card_data.name_en),
		}
	if value is PokemonSlot:
		return _compact_slot(value)
	if value is GameAction:
		var action: GameAction = value
		return {
			"player_index": int(action.player_index),
			"action_type": int(action.action_type),
			"description": str(action.description),
			"data": _json_safe(action.data),
		}
	return str(value)
