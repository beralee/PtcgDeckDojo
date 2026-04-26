class_name LLMRagingBoltDuelTool
extends Node

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const BattleRecorderScript = preload("res://scripts/engine/BattleRecorder.gd")
const AutoloadResolverScript = preload("res://scripts/engine/AutoloadResolver.gd")

const MIRAIDON_DECK_ID := 575720
const RAGING_BOLT_DECK_ID := 575718
const MIRAIDON_STRATEGY_ID := "miraidon"
const RAGING_BOLT_LLM_STRATEGY_ID := "raging_bolt_ogerpon_llm"

const DEFAULT_MAX_STEPS := 260
const DEFAULT_LLM_WAIT_POLL_SECONDS := 0.10
const DEFAULT_LLM_WAIT_TIMEOUT_SECONDS := 75.0
const LLM_WAIT_TIMEOUT_BUFFER_SECONDS := 2.0
const DEFAULT_LLM_MAX_FAILURES_PER_STRATEGY := 2

var output_root: String = "user://match_records/ai_duels"

var _registry = DeckStrategyRegistryScript.new()


func run_rule_miraidon_vs_llm_raging_bolt(games: int = 1, options: Dictionary = {}) -> Dictionary:
	var normalized_games: int = maxi(games, 1)
	var results: Array[Dictionary] = []
	var wins := {"miraidon": 0, "raging_bolt_llm": 0, "draw_or_failed": 0}
	for game_index: int in normalized_games:
		var result: Dictionary = await _run_one_logged_duel(game_index, options)
		results.append(result)
		match int(result.get("winner_index", -1)):
			0:
				wins["miraidon"] = int(wins["miraidon"]) + 1
			1:
				wins["raging_bolt_llm"] = int(wins["raging_bolt_llm"]) + 1
			_:
				wins["draw_or_failed"] = int(wins["draw_or_failed"]) + 1
	return {
		"games": normalized_games,
		"wins": wins,
		"llm_health": _aggregate_llm_health(results, false),
		"miraidon_win_rate": float(wins["miraidon"]) / float(normalized_games),
		"raging_bolt_llm_win_rate": float(wins["raging_bolt_llm"]) / float(normalized_games),
		"results": results,
	}


func run_llm_raging_bolt_self_play(games: int = 1, options: Dictionary = {}) -> Dictionary:
	var normalized_games: int = maxi(games, 1)
	var results: Array[Dictionary] = []
	var wins := {"player_0": 0, "player_1": 0, "draw_or_failed": 0}
	for game_index: int in normalized_games:
		var result: Dictionary = await _run_one_logged_self_play(game_index, options)
		results.append(result)
		match int(result.get("winner_index", -1)):
			0:
				wins["player_0"] = int(wins["player_0"]) + 1
			1:
				wins["player_1"] = int(wins["player_1"]) + 1
			_:
				wins["draw_or_failed"] = int(wins["draw_or_failed"]) + 1
	return {
		"games": normalized_games,
		"wins": wins,
		"llm_health": _aggregate_llm_health(results, true),
		"player_0_win_rate": float(wins["player_0"]) / float(normalized_games),
		"player_1_win_rate": float(wins["player_1"]) / float(normalized_games),
		"results": results,
	}


func build_default_options() -> Dictionary:
	return {
		"miraidon_deck_id": MIRAIDON_DECK_ID,
		"raging_bolt_deck_id": RAGING_BOLT_DECK_ID,
		"first_player_index": 0,
		"seed": 20260426,
		"max_steps": DEFAULT_MAX_STEPS,
		"llm_wait_timeout_seconds": DEFAULT_LLM_WAIT_TIMEOUT_SECONDS,
		"llm_wait_poll_seconds": DEFAULT_LLM_WAIT_POLL_SECONDS,
		"llm_max_failures_per_strategy": DEFAULT_LLM_MAX_FAILURES_PER_STRATEGY,
		"record_match": true,
		"output_root": output_root,
	}


func build_self_play_options() -> Dictionary:
	var options := build_default_options()
	options["mode"] = "llm_raging_bolt_self_play"
	options["player_0_deck_id"] = RAGING_BOLT_DECK_ID
	options["player_1_deck_id"] = RAGING_BOLT_DECK_ID
	options["player_0_strategy_id"] = RAGING_BOLT_LLM_STRATEGY_ID
	options["player_1_strategy_id"] = RAGING_BOLT_LLM_STRATEGY_ID
	return options


func _run_one_logged_self_play(game_index: int, options: Dictionary) -> Dictionary:
	var merged_options := build_self_play_options()
	for key: Variant in options.keys():
		merged_options[str(key)] = options.get(key)

	var deck_id: int = int(merged_options.get("raging_bolt_deck_id", RAGING_BOLT_DECK_ID))
	var seed: int = int(merged_options.get("seed", 20260426)) + game_index
	var first_player_index: int = clampi(int(merged_options.get("first_player_index", 0)), 0, 1)
	var max_steps: int = maxi(int(merged_options.get("max_steps", DEFAULT_MAX_STEPS)), 1)

	var card_database = AutoloadResolverScript.get_card_database()
	var deck: DeckData = card_database.get_deck(deck_id) if card_database != null else null
	if deck == null:
		return {
			"winner_index": -1,
			"failure_reason": "missing_deck",
			"raging_bolt_deck_id": deck_id,
		}

	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	_apply_seed(gsm, seed)
	_set_forced_shuffle_seed(seed)

	var recorder: RefCounted = null
	if bool(merged_options.get("record_match", true)):
		recorder = BattleRecorderScript.new()
		var root_path := str(merged_options.get("output_root", output_root))
		recorder.call("set_output_root", root_path)
		recorder.call("start_match", _build_self_play_meta(seed, first_player_index, deck), {})
		gsm.action_logged.connect(func(action: GameAction) -> void:
			_record_action(recorder, gsm, action)
		)

	gsm.start_game(deck, deck, first_player_index)
	if recorder != null:
		recorder.call("update_match_context", _build_self_play_meta(seed, first_player_index, deck), _serialize_state(gsm.game_state))
		recorder.call("record_event", _make_event(gsm, "match_started", -1, {
			"mode": "llm_raging_bolt_self_play",
			"seed": seed,
		}))
		_record_snapshot(recorder, gsm, "match_start")

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()

	var player_0_ai := _make_ai(0, RAGING_BOLT_LLM_STRATEGY_ID, deck)
	var player_1_ai := _make_ai(1, RAGING_BOLT_LLM_STRATEGY_ID, deck)
	var steps := 0
	var failure_reason := ""
	while steps < max_steps:
		if gsm.game_state.is_game_over():
			break
		var progressed := false
		if bridge.has_pending_prompt():
			if bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				var owner: int = bridge.get_pending_prompt_owner()
				var prompt_ai: AIOpponent = player_0_ai if owner == 0 else player_1_ai
				progressed = prompt_ai.run_single_step(bridge, gsm)
				if progressed and recorder != null:
					_record_ai_decision_trace(recorder, gsm, prompt_ai)
		else:
			var current_player: int = int(gsm.game_state.current_player_index)
			var current_ai: AIOpponent = player_0_ai if current_player == 0 else player_1_ai
			await _prepare_llm_plan_if_needed(current_ai, gsm, merged_options)
			progressed = current_ai.run_single_step(bridge, gsm)
			if progressed and recorder != null:
				_record_ai_decision_trace(recorder, gsm, current_ai)
			if not progressed and gsm.game_state.phase == GameState.GamePhase.MAIN:
				gsm.end_turn(current_player)
				progressed = true
		if not progressed:
			failure_reason = "stalled_no_progress"
			break
		steps += 1

	if steps >= max_steps and not gsm.game_state.is_game_over():
		failure_reason = "action_cap_reached"
	if failure_reason != "" and recorder != null:
		recorder.call("record_event", _make_event(gsm, "match_failed", -1, {"failure_reason": failure_reason}))

	var p0_strategy: Variant = player_0_ai.get("_deck_strategy")
	var p1_strategy: Variant = player_1_ai.get("_deck_strategy")
	var result := {
		"winner_index": int(gsm.game_state.winner_index),
		"reason": str(gsm.game_state.win_reason),
		"failure_reason": failure_reason,
		"turn_number": int(gsm.game_state.turn_number),
		"steps": steps,
		"seed": seed,
		"first_player_index": first_player_index,
		"player_0_deck_id": deck_id,
		"player_1_deck_id": deck_id,
		"player_0_strategy_id": RAGING_BOLT_LLM_STRATEGY_ID,
		"player_1_strategy_id": RAGING_BOLT_LLM_STRATEGY_ID,
		"player_0_llm_audit_log_path": str(p0_strategy.call("get_llm_audit_log_path")) if p0_strategy != null and p0_strategy.has_method("get_llm_audit_log_path") else "",
		"player_1_llm_audit_log_path": str(p1_strategy.call("get_llm_audit_log_path")) if p1_strategy != null and p1_strategy.has_method("get_llm_audit_log_path") else "",
		"player_0_llm_stats": p0_strategy.call("get_llm_stats") if p0_strategy != null and p0_strategy.has_method("get_llm_stats") else {},
		"player_1_llm_stats": p1_strategy.call("get_llm_stats") if p1_strategy != null and p1_strategy.has_method("get_llm_stats") else {},
	}
	if recorder != null:
		_record_snapshot(recorder, gsm, "match_end")
		recorder.call("record_event", _make_event(gsm, "match_ended", int(gsm.game_state.winner_index), result))
		recorder.call("finalize_match", result)
		result["match_dir"] = str(recorder.call("get_match_dir"))
	if is_instance_valid(bridge):
		bridge.free()
	_clear_forced_shuffle_seed()
	return result


func _run_one_logged_duel(game_index: int, options: Dictionary) -> Dictionary:
	var merged_options := build_default_options()
	for key: Variant in options.keys():
		merged_options[str(key)] = options.get(key)

	var miraidon_deck_id: int = int(merged_options.get("miraidon_deck_id", MIRAIDON_DECK_ID))
	var raging_bolt_deck_id: int = int(merged_options.get("raging_bolt_deck_id", RAGING_BOLT_DECK_ID))
	var seed: int = int(merged_options.get("seed", 20260426)) + game_index
	var first_player_index: int = clampi(int(merged_options.get("first_player_index", 0)), 0, 1)
	var max_steps: int = maxi(int(merged_options.get("max_steps", DEFAULT_MAX_STEPS)), 1)

	var card_database = AutoloadResolverScript.get_card_database()
	var miraidon_deck: DeckData = card_database.get_deck(miraidon_deck_id) if card_database != null else null
	var raging_bolt_deck: DeckData = card_database.get_deck(raging_bolt_deck_id) if card_database != null else null
	if miraidon_deck == null or raging_bolt_deck == null:
		return {
			"winner_index": -1,
			"failure_reason": "missing_deck",
			"miraidon_deck_id": miraidon_deck_id,
			"raging_bolt_deck_id": raging_bolt_deck_id,
		}

	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	_apply_seed(gsm, seed)
	_set_forced_shuffle_seed(seed)

	var recorder: RefCounted = null
	if bool(merged_options.get("record_match", true)):
		recorder = BattleRecorderScript.new()
		var root_path := str(merged_options.get("output_root", output_root))
		recorder.call("set_output_root", root_path)
		recorder.call("start_match", _build_meta(seed, first_player_index, miraidon_deck, raging_bolt_deck), {})
		gsm.action_logged.connect(func(action: GameAction) -> void:
			_record_action(recorder, gsm, action)
		)

	gsm.start_game(miraidon_deck, raging_bolt_deck, first_player_index)
	if recorder != null:
		recorder.call("update_match_context", _build_meta(seed, first_player_index, miraidon_deck, raging_bolt_deck), _serialize_state(gsm.game_state))
		recorder.call("record_event", _make_event(gsm, "match_started", -1, {
			"mode": "ai_rule_vs_llm",
			"seed": seed,
		}))
		_record_snapshot(recorder, gsm, "match_start")

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.bootstrap_pending_setup()

	var miraidon_ai := _make_ai(0, MIRAIDON_STRATEGY_ID, miraidon_deck)
	var raging_bolt_ai := _make_ai(1, RAGING_BOLT_LLM_STRATEGY_ID, raging_bolt_deck)
	var steps := 0
	var failure_reason := ""
	while steps < max_steps:
		if gsm.game_state.is_game_over():
			break
		var progressed := false
		if bridge.has_pending_prompt():
			if bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				var owner: int = bridge.get_pending_prompt_owner()
				var prompt_ai: AIOpponent = miraidon_ai if owner == 0 else raging_bolt_ai
				progressed = prompt_ai.run_single_step(bridge, gsm)
				if progressed and recorder != null:
					_record_ai_decision_trace(recorder, gsm, prompt_ai)
		else:
			var current_player: int = int(gsm.game_state.current_player_index)
			var current_ai: AIOpponent = miraidon_ai if current_player == 0 else raging_bolt_ai
			await _prepare_llm_plan_if_needed(current_ai, gsm, merged_options)
			progressed = current_ai.run_single_step(bridge, gsm)
			if progressed and recorder != null:
				_record_ai_decision_trace(recorder, gsm, current_ai)
			if not progressed and gsm.game_state.phase == GameState.GamePhase.MAIN:
				gsm.end_turn(current_player)
				progressed = true
		if not progressed:
			failure_reason = "stalled_no_progress"
			break
		steps += 1

	if steps >= max_steps and not gsm.game_state.is_game_over():
		failure_reason = "action_cap_reached"
	if failure_reason != "" and recorder != null:
		recorder.call("record_event", _make_event(gsm, "match_failed", -1, {"failure_reason": failure_reason}))

	var llm_strategy: Variant = raging_bolt_ai.get("_deck_strategy")
	var result := {
		"winner_index": int(gsm.game_state.winner_index),
		"reason": str(gsm.game_state.win_reason),
		"failure_reason": failure_reason,
		"turn_number": int(gsm.game_state.turn_number),
		"steps": steps,
		"seed": seed,
		"first_player_index": first_player_index,
		"miraidon_player_index": 0,
		"raging_bolt_llm_player_index": 1,
		"llm_audit_log_path": str(llm_strategy.call("get_llm_audit_log_path")) if llm_strategy != null and llm_strategy.has_method("get_llm_audit_log_path") else "",
		"llm_stats": llm_strategy.call("get_llm_stats") if llm_strategy != null and llm_strategy.has_method("get_llm_stats") else {},
	}
	if recorder != null:
		_record_snapshot(recorder, gsm, "match_end")
		recorder.call("record_event", _make_event(gsm, "match_ended", int(gsm.game_state.winner_index), result))
		recorder.call("finalize_match", result)
		result["match_dir"] = str(recorder.call("get_match_dir"))
	if is_instance_valid(bridge):
		bridge.free()
	_clear_forced_shuffle_seed()
	return result


func _make_ai(player_index: int, strategy_id: String, deck: DeckData = null) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	var strategy: RefCounted = _registry.call("create_strategy_by_id", strategy_id)
	if strategy != null:
		if deck != null and strategy.has_method("set_deck_strategy_text"):
			strategy.call("set_deck_strategy_text", str(deck.strategy))
		if strategy.has_method("set_llm_host_node"):
			strategy.call("set_llm_host_node", self)
		ai.set_deck_strategy(strategy)
	return ai


func _prepare_llm_plan_if_needed(ai: AIOpponent, gsm: GameStateMachine, options: Dictionary) -> void:
	if ai == null or gsm == null or gsm.game_state == null:
		return
	var strategy: Variant = ai.get("_deck_strategy")
	if strategy == null or not strategy.has_method("ensure_llm_request_fired"):
		return
	if _llm_failure_budget_exhausted(strategy, options):
		return
	var turn: int = int(gsm.game_state.turn_number)
	if strategy.has_method("has_llm_plan_for_turn") and bool(strategy.call("has_llm_plan_for_turn", turn)):
		return
	if strategy.has_method("is_llm_disabled_for_turn") and bool(strategy.call("is_llm_disabled_for_turn", turn)):
		return
	var legal_actions: Array[Dictionary] = ai.get_legal_actions(gsm)
	strategy.call("ensure_llm_request_fired", gsm.game_state, ai.player_index, legal_actions)
	if not strategy.has_method("is_llm_pending") or not bool(strategy.call("is_llm_pending")):
		return
	var timeout_seconds: float = maxf(float(options.get("llm_wait_timeout_seconds", DEFAULT_LLM_WAIT_TIMEOUT_SECONDS)), 0.0)
	if strategy.has_method("get_llm_soft_timeout_seconds"):
		timeout_seconds = maxf(timeout_seconds, float(strategy.call("get_llm_soft_timeout_seconds")) + LLM_WAIT_TIMEOUT_BUFFER_SECONDS)
	var poll_seconds: float = maxf(float(options.get("llm_wait_poll_seconds", DEFAULT_LLM_WAIT_POLL_SECONDS)), 0.01)
	var started := Time.get_ticks_msec()
	while bool(strategy.call("is_llm_pending")):
		var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
		if elapsed >= timeout_seconds:
			if strategy.has_method("force_rules_for_turn"):
				strategy.call("force_rules_for_turn", turn, "duel tool LLM wait timeout")
			break
		await get_tree().create_timer(poll_seconds).timeout


func _llm_failure_budget_exhausted(strategy: Variant, options: Dictionary) -> bool:
	if strategy == null or not strategy.has_method("get_llm_stats"):
		return false
	var max_failures: int = int(options.get("llm_max_failures_per_strategy", DEFAULT_LLM_MAX_FAILURES_PER_STRATEGY))
	if max_failures <= 0:
		return false
	var stats: Dictionary = strategy.call("get_llm_stats")
	return int(stats.get("successes", 0)) <= 0 and int(stats.get("failures", 0)) >= max_failures


func _aggregate_llm_health(results: Array[Dictionary], self_play: bool) -> Dictionary:
	var health := {
		"requests": 0,
		"successes": 0,
		"failures": 0,
		"skipped_by_local_rules": 0,
		"last_errors": [],
		"takeover_rate": 0.0,
		"all_requests_failed": false,
	}
	for result: Dictionary in results:
		if self_play:
			_add_llm_stats_to_health(health, result.get("player_0_llm_stats", {}))
			_add_llm_stats_to_health(health, result.get("player_1_llm_stats", {}))
		else:
			_add_llm_stats_to_health(health, result.get("llm_stats", {}))
	var requests := int(health["requests"])
	if requests > 0:
		health["takeover_rate"] = float(health["successes"]) / float(requests)
	health["all_requests_failed"] = requests > 0 and int(health["successes"]) == 0
	return health


func _add_llm_stats_to_health(health: Dictionary, raw_stats: Variant) -> void:
	if not (raw_stats is Dictionary):
		return
	var stats: Dictionary = raw_stats
	health["requests"] = int(health["requests"]) + int(stats.get("requests", 0))
	health["successes"] = int(health["successes"]) + int(stats.get("successes", 0))
	health["failures"] = int(health["failures"]) + int(stats.get("failures", 0))
	health["skipped_by_local_rules"] = int(health["skipped_by_local_rules"]) + int(stats.get("skipped_by_local_rules", 0))
	var last_error := str(stats.get("last_error", "")).strip_edges()
	if last_error != "":
		var errors: Array = health.get("last_errors", [])
		if not errors.has(last_error):
			errors.append(last_error)
			health["last_errors"] = errors


func _build_meta(seed: int, first_player_index: int, miraidon_deck: DeckData, raging_bolt_deck: DeckData) -> Dictionary:
	return {
		"mode": "ai_rule_vs_llm",
		"player_types": ["rules_ai", "llm_ai"],
		"selected_deck_ids": [miraidon_deck.id, raging_bolt_deck.id],
		"player_labels": ["规则密勒顿", "LLM猛雷鼓"],
		"deck_names": [miraidon_deck.deck_name, raging_bolt_deck.deck_name],
		"strategy_ids": [MIRAIDON_STRATEGY_ID, RAGING_BOLT_LLM_STRATEGY_ID],
		"first_player_index": first_player_index,
		"seed": seed,
	}


func _build_self_play_meta(seed: int, first_player_index: int, raging_bolt_deck: DeckData) -> Dictionary:
	return {
		"mode": "llm_raging_bolt_self_play",
		"player_types": ["llm_ai", "llm_ai"],
		"selected_deck_ids": [raging_bolt_deck.id, raging_bolt_deck.id],
		"player_labels": ["LLM Raging Bolt P0", "LLM Raging Bolt P1"],
		"deck_names": [raging_bolt_deck.deck_name, raging_bolt_deck.deck_name],
		"strategy_ids": [RAGING_BOLT_LLM_STRATEGY_ID, RAGING_BOLT_LLM_STRATEGY_ID],
		"first_player_index": first_player_index,
		"seed": seed,
	}


func _make_event(gsm: GameStateMachine, event_type: String, player_index: int, extra: Dictionary = {}) -> Dictionary:
	var event := {
		"event_type": event_type,
		"player_index": player_index,
		"turn_number": int(gsm.game_state.turn_number) if gsm != null and gsm.game_state != null else 0,
		"phase": str(gsm.game_state.phase) if gsm != null and gsm.game_state != null else "",
	}
	for key: Variant in extra.keys():
		event[str(key)] = _json_safe(extra.get(key))
	return event


func _record_action(recorder: RefCounted, gsm: GameStateMachine, action: GameAction) -> void:
	if recorder == null or action == null:
		return
	recorder.call("record_event", _make_event(gsm, "action_resolved", action.player_index, {
		"action_type": int(action.action_type),
		"description": str(action.description),
		"data": action.data.duplicate(true),
	}))
	_record_snapshot(recorder, gsm, "after_action_resolved", {
		"action_type": int(action.action_type),
		"description": str(action.description),
		"resolved_player_index": int(action.player_index),
	})


func _record_ai_decision_trace(recorder: RefCounted, gsm: GameStateMachine, ai: AIOpponent) -> void:
	if recorder == null or ai == null:
		return
	var trace = ai.get_last_decision_trace()
	if trace == null or not trace.has_method("to_dictionary"):
		return
	recorder.call("record_event", _make_event(gsm, "ai_decision_trace", ai.player_index, {
		"trace": trace.call("to_dictionary"),
	}))


func _record_snapshot(recorder: RefCounted, gsm: GameStateMachine, reason: String, extra: Dictionary = {}) -> void:
	if recorder == null:
		return
	var payload := {
		"snapshot_reason": reason,
		"state": _serialize_state(gsm.game_state if gsm != null else null),
	}
	for key: Variant in extra.keys():
		payload[str(key)] = extra.get(key)
	recorder.call("record_event", _make_event(gsm, "state_snapshot", int(gsm.game_state.current_player_index) if gsm != null and gsm.game_state != null else -1, payload))


func _serialize_state(state: GameState) -> Dictionary:
	if state == null:
		return {}
	return {
		"turn_number": int(state.turn_number),
		"phase": str(state.phase),
		"current_player_index": int(state.current_player_index),
		"first_player_index": int(state.first_player_index),
		"winner_index": int(state.winner_index),
		"win_reason": str(state.win_reason),
		"energy_attached_this_turn": state.energy_attached_this_turn,
		"supporter_used_this_turn": state.supporter_used_this_turn,
		"retreat_used_this_turn": state.retreat_used_this_turn,
		"players": [
			_serialize_player(state.players[0]) if state.players.size() > 0 else {},
			_serialize_player(state.players[1]) if state.players.size() > 1 else {},
		],
	}


func _serialize_player(player: PlayerState) -> Dictionary:
	if player == null:
		return {}
	return {
		"player_index": int(player.player_index),
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size(),
		"discard_count": player.discard_pile.size(),
		"prize_count": player.prizes.size(),
		"hand": _serialize_cards(player.hand),
		"deck": _serialize_cards(player.deck),
		"prizes": _serialize_cards(player.prizes),
		"discard_pile": _serialize_cards(player.discard_pile),
		"lost_zone": _serialize_cards(player.lost_zone),
		"active": _serialize_slot(player.active_pokemon),
		"bench": _serialize_slots(player.bench),
	}


func _serialize_slots(slots: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for slot: Variant in slots:
		rows.append(_serialize_slot(slot as PokemonSlot if slot is PokemonSlot else null))
	return rows


func _serialize_slot(slot: PokemonSlot) -> Dictionary:
	if slot == null:
		return {}
	return {
		"pokemon_name": slot.get_pokemon_name(),
		"damage_counters": int(slot.damage_counters),
		"remaining_hp": int(slot.get_remaining_hp()),
		"max_hp": int(slot.get_max_hp()),
		"attached_energy": _serialize_cards(slot.attached_energy),
		"attached_tool": _serialize_card(slot.attached_tool),
		"pokemon_stack": _serialize_cards(slot.pokemon_stack),
	}


func _serialize_cards(cards: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for card: Variant in cards:
		rows.append(_serialize_card(card as CardInstance if card is CardInstance else null))
	return rows


func _serialize_card(card: CardInstance) -> Dictionary:
	if card == null or card.card_data == null:
		return {}
	var cd: CardData = card.card_data
	return {
		"card_name": str(cd.name),
		"name_en": str(cd.name_en),
		"instance_id": int(card.instance_id),
		"owner_index": int(card.owner_index),
		"card_type": str(cd.card_type),
		"mechanic": str(cd.mechanic),
		"stage": str(cd.stage),
		"hp": int(cd.hp),
		"energy_type": str(cd.energy_type),
		"energy_provides": str(cd.energy_provides),
		"effect_id": str(cd.effect_id),
		"attacks": cd.attacks.duplicate(true),
		"abilities": cd.abilities.duplicate(true),
	}


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
		return _serialize_card(value)
	if value is PokemonSlot:
		return _serialize_slot(value)
	return str(value)


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
