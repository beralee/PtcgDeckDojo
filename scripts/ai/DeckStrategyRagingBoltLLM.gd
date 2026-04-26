extends "res://scripts/ai/DeckStrategyRagingBoltOgerpon.gd"

const ZenMuxClientScript = preload("res://scripts/network/ZenMuxClient.gd")
const LLMTurnPlanPromptBuilderScript = preload("res://scripts/ai/LLMTurnPlanPromptBuilder.gd")
const LLMInteractionIntentBridgeScript = preload("res://scripts/ai/LLMInteractionIntentBridge.gd")
const LLMDecisionTreeExecutorScript = preload("res://scripts/ai/LLMDecisionTreeExecutor.gd")
const LLMDecisionAuditLoggerScript = preload("res://scripts/ai/LLMDecisionAuditLogger.gd")
const LLMRouteCompilerScript = preload("res://scripts/ai/LLMRouteCompiler.gd")
const LLMRouteActionRegistryScript = preload("res://scripts/ai/LLMRouteActionRegistry.gd")
const AutoloadResolverScript = preload("res://scripts/engine/AutoloadResolver.gd")

signal llm_thinking_started(turn_number: int)
signal llm_thinking_finished(turn_number: int, plan: Dictionary, reasoning: String)
signal llm_thinking_failed(turn_number: int, reason: String)

const QUEUE_BASE_SCORE: float = 90000.0
const QUEUE_STEP: float = 1000.0
const LLM_PROMPT_ACTION_LIMIT: int = 32
const LLM_PROMPT_HAND_ACTION_LIMIT: int = 20
const SUPPORTED_TREE_FACTS := {
	"always": true,
	"can_attack": true,
	"can_use_supporter": true,
	"energy_not_attached": true,
	"energy_attached_this_turn": true,
	"supporter_not_used": true,
	"supporter_used_this_turn": true,
	"retreat_not_used": true,
	"retreat_used_this_turn": true,
	"hand_has_card": true,
	"discard_has_card": true,
	"hand_has_type": true,
	"discard_basic_energy_count_at_least": true,
	"active_has_energy_at_least": true,
	"active_attack_ready": true,
	"has_bench_space": true,
}

var _llm_host_node: Node = null
var _cached_turn_number: int = -1
var _llm_pending: bool = false
var _client: RefCounted = ZenMuxClientScript.new()
var _prompt_builder: RefCounted = LLMTurnPlanPromptBuilderScript.new()
var _interaction_bridge: RefCounted = LLMInteractionIntentBridgeScript.new()
var _decision_tree_executor: RefCounted = LLMDecisionTreeExecutorScript.new()
var _audit_logger: RefCounted = LLMDecisionAuditLoggerScript.new()
var _route_compiler: RefCounted = LLMRouteCompilerScript.new()
var _route_action_registry: RefCounted = LLMRouteActionRegistryScript.new()
var _llm_request_count: int = 0
var _llm_success_count: int = 0
var _llm_fail_count: int = 0
var _llm_request_attempt_turn: int = -1
var _llm_request_turn: int = -1
var _llm_request_started_msec: int = 0
var _llm_soft_timeout_seconds: float = 60.0
var _last_llm_reasoning: String = ""
var _last_llm_error: String = ""
var _llm_decision_tree: Dictionary = {}
var _llm_action_queue: Array[Dictionary] = []
var _llm_queue_turn: int = -1
var _llm_action_catalog: Dictionary = {}
var _llm_route_candidates_by_id: Dictionary = {}
var _llm_skip_count: int = 0
var _llm_disabled_turns: Dictionary = {}
var _llm_game_state_instance_id: int = -1
var _llm_last_seen_turn_number: int = -1
var _llm_completed_queue_turns: Dictionary = {}
var _llm_consumed_actions_by_turn: Dictionary = {}
var _llm_replan_counts: Dictionary = {}
var _llm_replan_context_by_turn: Dictionary = {}
var _llm_replan_eligible_after_reject: Dictionary = {}
var _llm_route_compiler_results_by_turn: Dictionary = {}
var _llm_max_replans_per_turn: int = 2
var _fast_choice_pending: bool = false
var _fast_choice_request_key: String = ""
var _fast_choice_cache: Dictionary = {}
var _fast_choice_failed_keys: Dictionary = {}
var _logged_queue_score_matches: Dictionary = {}

func get_strategy_id() -> String:
	return "raging_bolt_ogerpon_llm"


func _get_llm_prompt_builder() -> RefCounted:
	return _prompt_builder


func get_llm_setup_role_hint(cd: CardData) -> String:
	return _raging_bolt_setup_role_hint(cd)


func get_llm_deck_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	return _raging_bolt_strategy_prompt(game_state, player_index)


func build_llm_request_payload_for_test(game_state: GameState, player_index: int) -> Dictionary:
	_configure_prompt_builder(game_state, player_index)
	return _prompt_builder.build_request_payload(game_state, player_index)


func build_action_id_request_payload_for_test(game_state: GameState, player_index: int, legal_actions: Array) -> Dictionary:
	_configure_prompt_builder(game_state, player_index)
	var prompt_actions: Array = _select_llm_prompt_actions(legal_actions, game_state, player_index)
	_llm_action_catalog = _build_action_catalog(prompt_actions, game_state, player_index)
	var payload: Dictionary = _prompt_builder.build_action_id_request_payload(game_state, player_index, prompt_actions)
	_merge_payload_action_refs_into_catalog(payload)
	_register_payload_candidate_routes(payload)
	return payload


func set_llm_host_node(node: Node) -> void:
	_llm_host_node = node


func get_llm_audit_log_path() -> String:
	if _audit_logger == null:
		return ""
	return str(_audit_logger.get("log_path"))


func log_runtime_action_result(
	action: Dictionary,
	success: bool,
	game_state: GameState = null,
	player_index_override: int = -1,
	audit_turn: int = -1
) -> void:
	var turn := audit_turn if audit_turn >= 0 else (int(game_state.turn_number) if game_state != null else _cached_turn_number)
	var action_queue: Array[Dictionary] = []
	if turn == _llm_queue_turn:
		action_queue = _llm_action_queue.duplicate(true)
	if action_queue.is_empty() and game_state != null and player_index_override >= 0:
		action_queue = _select_current_action_queue(game_state, player_index_override)
	var matched_index := _queue_index_for_action(action, action_queue, game_state, player_index_override)
	_audit_log("runtime_action_result", {
		"turn": turn,
		"player_index": player_index_override,
		"game_state_turn_after_execute": int(game_state.turn_number) if game_state != null else -1,
		"success": success,
		"matched_queue_index": matched_index,
		"action": _audit_logger.call("compact_action", action) if _audit_logger != null else action,
		"queue_head": _audit_logger.call("compact_actions", action_queue.slice(0, mini(action_queue.size(), 5))) if _audit_logger != null else action_queue,
	})
	if success:
		_consume_llm_queue_after_action(action, matched_index, turn, game_state, player_index_override)
	elif matched_index >= 0:
		_audit_log("queue_action_failed", {
			"turn": turn,
			"player_index": player_index_override,
			"matched_queue_index": matched_index,
			"action": _audit_logger.call("compact_action", action) if _audit_logger != null else action,
		})


func make_llm_runtime_snapshot(game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	return {
		"turn": int(game_state.turn_number),
		"phase": int(game_state.phase),
		"player_index": player_index,
		"current_player_index": int(game_state.current_player_index),
		"energy_attached_this_turn": bool(game_state.energy_attached_this_turn),
		"supporter_used_this_turn": bool(game_state.supporter_used_this_turn),
		"retreat_used_this_turn": bool(game_state.retreat_used_this_turn),
		"stadium_played_this_turn": bool(game_state.stadium_played_this_turn),
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size(),
		"discard_count": player.discard_pile.size(),
		"hand_ids": _card_instance_id_list(player.hand),
		"hand_names": _card_name_list(player.hand),
		"raging_bolt_burst_ready": _active_raging_bolt_burst_cost_ready(game_state, player_index),
		"raging_bolt_burst_damage": _raging_bolt_burst_damage_estimate(game_state, player_index),
	}


func observe_llm_runtime_state_change(before_snapshot: Dictionary, after_snapshot: Dictionary, context: Dictionary = {}) -> void:
	if not bool(context.get("success", false)):
		return
	if before_snapshot.is_empty() or after_snapshot.is_empty():
		return
	var turn := int(after_snapshot.get("turn", -1))
	if turn < 0 or turn != int(before_snapshot.get("turn", -2)):
		return
	if turn != _llm_queue_turn and _llm_decision_tree.is_empty() and not bool(_llm_replan_eligible_after_reject.get(turn, false)):
		return
	if _llm_pending or is_llm_disabled_for_turn(turn):
		return
	if str(context.get("pending_choice_after", "")) != "":
		return
	if int(after_snapshot.get("phase", -1)) != GameState.GamePhase.MAIN:
		return
	if int(after_snapshot.get("current_player_index", -1)) != int(after_snapshot.get("player_index", -2)):
		return
	if int(_llm_replan_counts.get(turn, 0)) >= _llm_max_replans_per_turn:
		return
	var trigger: Dictionary = _llm_replan_trigger(before_snapshot, after_snapshot, context)
	if not bool(trigger.get("should_replan", false)):
		return
	var remaining_queue_before_replan: Array[Dictionary] = _llm_action_queue.duplicate(true)
	var completed_prefix_before_replan: Array = _llm_consumed_actions_by_turn.get(turn, [])
	var route_goal := _route_goal_for_replan_context(remaining_queue_before_replan, completed_prefix_before_replan)
	if _should_suppress_replan_for_live_conversion(after_snapshot, remaining_queue_before_replan, route_goal):
		_llm_action_queue = _prune_queue_to_live_terminal_conversion(after_snapshot, remaining_queue_before_replan)
		_audit_log("replan_suppressed", {
			"turn": turn,
			"reason": "live_terminal_conversion_queue",
			"trigger": trigger.duplicate(true),
			"remaining_queue": _compact_route_actions_for_context(remaining_queue_before_replan),
			"original_turn_goal": route_goal,
			"after": after_snapshot,
		})
		return
	_llm_replan_counts[turn] = int(_llm_replan_counts.get(turn, 0)) + 1
	_llm_decision_tree.clear()
	_llm_action_queue.clear()
	_llm_action_catalog.clear()
	_llm_route_candidates_by_id.clear()
	_llm_queue_turn = -1
	_llm_completed_queue_turns.erase(turn)
	_llm_replan_eligible_after_reject.erase(turn)
	_llm_route_compiler_results_by_turn.erase(turn)
	_llm_request_attempt_turn = -1
	_logged_queue_score_matches.clear()
	_llm_replan_context_by_turn[turn] = {
		"trigger": trigger.duplicate(true),
		"previous_hand_names": before_snapshot.get("hand_names", []),
		"current_hand_names": after_snapshot.get("hand_names", []),
		"before_turn_flags": _snapshot_turn_flags(before_snapshot),
		"current_turn_flags": _snapshot_turn_flags(after_snapshot),
		"context": context.duplicate(true),
		"completed_route_prefix": _compact_route_actions_for_context(completed_prefix_before_replan),
		"remaining_queue_before_replan": _compact_route_actions_for_context(remaining_queue_before_replan),
		"original_turn_goal": route_goal,
		"must_continue_mainline": _route_goal_requires_continuation(route_goal, remaining_queue_before_replan),
	}
	_audit_log("replan_requested", {
		"turn": turn,
		"reason": str(trigger.get("reason", "")),
		"replan_count": int(_llm_replan_counts.get(turn, 0)),
		"before": before_snapshot,
		"after": after_snapshot,
		"context": context.duplicate(true),
	})


func _route_goal_for_replan_context(remaining_queue: Array, completed_prefix: Array) -> Dictionary:
	var source: Array = []
	if not remaining_queue.is_empty():
		source = remaining_queue
	elif not completed_prefix.is_empty():
		source = completed_prefix
	if _route_compiler != null:
		var goal: Dictionary = _route_compiler.call("compact_route_goal", source)
		if not goal.is_empty():
			return goal
	return {
		"terminal_type": "",
		"action_id": "",
		"attack_name": "",
		"card": "",
		"capability": "",
	}


func _compact_route_actions_for_context(actions: Array) -> Array:
	if _route_compiler != null:
		return _route_compiler.call("compact_actions", actions, 16)
	var result: Array = []
	for raw_action: Variant in actions:
		if raw_action is Dictionary:
			var action: Dictionary = raw_action
			result.append({
				"id": str(action.get("action_id", action.get("id", ""))),
				"type": str(action.get("type", action.get("kind", ""))),
				"card": str(action.get("card", action.get("pokemon", ""))),
				"attack_name": str(action.get("attack_name", "")),
			})
	return result


func _route_goal_requires_continuation(route_goal: Dictionary, remaining_queue: Array) -> bool:
	if remaining_queue.is_empty():
		return false
	var terminal_type := str(route_goal.get("terminal_type", ""))
	if terminal_type == "attack":
		return true
	if terminal_type == "setup":
		return true
	for raw_action: Variant in remaining_queue:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		var action_id := str(action.get("action_id", action.get("id", "")))
		if action_id.begins_with("future:"):
			return true
		var capability := str(action.get("capability", ""))
		if capability in ["energy_search", "supporter_acceleration", "manual_attach", "charge_and_draw"]:
			return true
	return false


func _should_suppress_replan_for_live_conversion(
	after_snapshot: Dictionary,
	remaining_queue: Array[Dictionary],
	route_goal: Dictionary
) -> bool:
	var terminal_type := str(route_goal.get("terminal_type", ""))
	var burst_ready := bool(after_snapshot.get("raging_bolt_burst_ready", false))
	var burst_damage := int(after_snapshot.get("raging_bolt_burst_damage", 0))
	if burst_ready and burst_damage > 0:
		if remaining_queue.is_empty():
			return not _llm_decision_tree.is_empty()
		if terminal_type in ["attack", "end_turn", "setup"]:
			return true
		for action: Dictionary in remaining_queue:
			if _is_end_turn_action_ref(action):
				return true
	if remaining_queue.is_empty():
		return false
	if _queue_contains_attack(remaining_queue):
		return true
	return false


func _prune_queue_to_live_terminal_conversion(
	after_snapshot: Dictionary,
	remaining_queue: Array[Dictionary]
) -> Array[Dictionary]:
	var burst_ready := bool(after_snapshot.get("raging_bolt_burst_ready", false))
	var burst_damage := int(after_snapshot.get("raging_bolt_burst_damage", 0))
	if not burst_ready or burst_damage <= 0:
		return remaining_queue
	for action: Dictionary in remaining_queue:
		if _is_attack_action_ref(action) or _is_end_turn_action_ref(action):
			return [action]
	return [{"type": "end_turn", "id": "end_turn", "action_id": "end_turn", "capability": "end_turn"}]


func is_llm_pending() -> bool:
	return _llm_pending


func is_fast_choice_pending() -> bool:
	return _fast_choice_pending


func has_llm_plan_for_turn(turn: int) -> bool:
	return _llm_queue_turn == turn \
		and not _llm_decision_tree.is_empty() \
		and not bool(_llm_completed_queue_turns.get(turn, false))


func is_llm_disabled_for_turn(turn: int) -> bool:
	return bool(_llm_disabled_turns.get(turn, false))


func is_llm_soft_timed_out_for_turn(turn: int) -> bool:
	if not _llm_pending or _llm_request_turn != turn:
		return false
	if _llm_request_started_msec <= 0:
		return false
	var elapsed_sec := float(Time.get_ticks_msec() - _llm_request_started_msec) / 1000.0
	return elapsed_sec >= _llm_soft_timeout_seconds


func get_llm_soft_timeout_seconds() -> float:
	return _llm_soft_timeout_seconds


func force_rules_for_turn(turn: int, reason: String = "soft timeout") -> void:
	_llm_fail_count += 1
	_disable_llm_for_turn(turn, reason)


func has_fast_choice_for_prompt(prompt_kind: String, game_state: GameState, player_index: int) -> bool:
	return _fast_choice_cache.has(_fast_choice_key(prompt_kind, game_state, player_index))


func ensure_fast_choice_request_fired(prompt_kind: String, game_state: GameState, player_index: int) -> void:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return
	_sync_game_state_context(game_state, player_index, "ensure_fast_choice_request_fired")
	if int(game_state.turn_number) <= 0:
		return
	var key := _fast_choice_key(prompt_kind, game_state, player_index)
	if _fast_choice_cache.has(key) or _fast_choice_failed_keys.has(key) or _fast_choice_pending:
		return
	_fire_fast_choice_request(prompt_kind, game_state, player_index, key)


func consume_fast_opening_setup_choice(player: PlayerState, game_state: GameState, player_index: int) -> Dictionary:
	var key := _fast_choice_key("setup_active", game_state, player_index)
	if not _fast_choice_cache.has(key):
		return {}
	var choice: Dictionary = _fast_choice_cache.get(key, {})
	_fast_choice_cache.erase(key)
	var active_hand_index: int = int(choice.get("selected_index", -1))
	if active_hand_index < 0 or player == null or active_hand_index >= player.hand.size():
		return {}
	var active_card: CardInstance = player.hand[active_hand_index]
	if active_card == null or active_card.card_data == null or not active_card.card_data.is_basic_pokemon():
		return {}
	var bench_indices: Array[int] = []
	var seen: Dictionary = {active_hand_index: true}
	for raw_index: Variant in choice.get("bench_indices", []):
		var hand_index := int(raw_index)
		if seen.has(hand_index):
			continue
		if hand_index < 0 or hand_index >= player.hand.size():
			continue
		var card: CardInstance = player.hand[hand_index]
		if card == null or card.card_data == null or not card.card_data.is_basic_pokemon():
			continue
		seen[hand_index] = true
		bench_indices.append(hand_index)
	return {"active_hand_index": active_hand_index, "bench_hand_indices": bench_indices}


func consume_fast_send_out_choice(bench_slots: Array[PokemonSlot], game_state: GameState, player_index: int) -> PokemonSlot:
	var key := _fast_choice_key("send_out", game_state, player_index)
	if not _fast_choice_cache.has(key):
		return null
	var choice: Dictionary = _fast_choice_cache.get(key, {})
	_fast_choice_cache.erase(key)
	var bench_index: int = int(choice.get("selected_index", -1))
	if bench_index < 0 or bench_index >= bench_slots.size():
		return null
	return bench_slots[bench_index]


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	_sync_game_state_context(game_state, player_index, "build_turn_plan")
	var turn: int = int(game_state.turn_number)
	if turn != _cached_turn_number:
		_cached_turn_number = turn
		_llm_decision_tree.clear()
		_llm_action_queue.clear()
		_llm_action_catalog.clear()
		_llm_route_candidates_by_id.clear()
		_llm_queue_turn = -1
		_llm_request_attempt_turn = -1
		_last_llm_reasoning = ""
		_llm_completed_queue_turns.clear()
		_llm_consumed_actions_by_turn.clear()
		_logged_queue_score_matches.clear()
		_llm_replan_counts.clear()
		_llm_replan_context_by_turn.clear()
		_llm_replan_eligible_after_reject.clear()
		_llm_route_compiler_results_by_turn.clear()
	return super.build_turn_plan(game_state, player_index, context)


func ensure_llm_request_fired(game_state: GameState, player_index: int, legal_actions: Array = []) -> void:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return
	_sync_game_state_context(game_state, player_index, "ensure_llm_request_fired")
	var turn: int = int(game_state.turn_number)
	if turn != _cached_turn_number:
		_cached_turn_number = turn
		_last_llm_reasoning = ""
		_llm_decision_tree.clear()
		_llm_action_queue.clear()
		_llm_action_catalog.clear()
		_llm_route_candidates_by_id.clear()
		_llm_queue_turn = -1
		_llm_request_attempt_turn = -1
		_llm_completed_queue_turns.clear()
		_llm_consumed_actions_by_turn.clear()
		_logged_queue_score_matches.clear()
		_llm_replan_counts.clear()
		_llm_replan_context_by_turn.clear()
		_llm_replan_eligible_after_reject.clear()
		_llm_route_compiler_results_by_turn.clear()
	var retry_after_escape := bool(_llm_replan_eligible_after_reject.get(turn, false))
	if _llm_request_attempt_turn == turn and not retry_after_escape:
		_log_llm_request_skip(turn, player_index, "already_attempted_this_turn", legal_actions)
		return
	if retry_after_escape:
		_llm_replan_eligible_after_reject.erase(turn)
	_llm_request_attempt_turn = turn
	if turn <= 0:
		_llm_skip_count += 1
		_log_llm_request_skip(turn, player_index, "turn_zero_setup_phase", legal_actions)
		return
	if is_llm_disabled_for_turn(turn):
		_log_llm_request_skip(turn, player_index, "turn_disabled", legal_actions)
		return
	if _should_skip_llm_for_local_rules(game_state, player_index, legal_actions):
		_llm_skip_count += 1
		_log_llm_request_skip(turn, player_index, _llm_local_skip_reason(game_state, player_index, legal_actions), legal_actions)
		return
	if not _llm_pending:
		_fire_llm_request(game_state, player_index, legal_actions)


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	_sync_game_state_context(game_state, player_index, "score_action_absolute")
	var active_queue: Array[Dictionary] = _select_current_action_queue(game_state, player_index)
	if not active_queue.is_empty():
		var queue_score: float = _score_from_queue(action, active_queue, game_state, player_index)
		if queue_score > 0.0:
			_log_queue_score_match_once(action, active_queue, queue_score, game_state, player_index)
			return queue_score
	return super.score_action_absolute(action, game_state, player_index)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var game_state: GameState = context.get("game_state")
	_sync_game_state_context(game_state, int(context.get("player_index", -1)), "pick_interaction_items")
	var active_queue: Array[Dictionary] = _select_current_action_queue(game_state, int(context.get("player_index", -1)))
	if not active_queue.is_empty():
		var planned: Dictionary = _interaction_bridge.call(
			"pick_interaction_items",
			items,
			step,
			context,
			active_queue
		)
		if bool(planned.get("has_plan", false)):
			_audit_log("interaction_pick", {
				"turn": int(game_state.turn_number) if game_state != null else _cached_turn_number,
				"player_index": int(context.get("player_index", -1)),
				"step": step.duplicate(true),
				"items": _audit_logger.call("compact_items", items) if _audit_logger != null else items,
				"picked": _audit_logger.call("compact_items", planned.get("items", [])) if _audit_logger != null else planned.get("items", []),
				"queue": _audit_logger.call("compact_actions", active_queue) if _audit_logger != null else active_queue,
			})
			return planned.get("items", [])
	return super.pick_interaction_items(items, step, context)


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state")
	_sync_game_state_context(game_state, int(context.get("player_index", -1)), "score_interaction_target")
	var active_queue: Array[Dictionary] = _select_current_action_queue(game_state, int(context.get("player_index", -1)))
	if not active_queue.is_empty():
		var planned_score: Dictionary = _interaction_bridge.call(
			"score_interaction_target",
			item,
			step,
			context,
			active_queue
		)
		if bool(planned_score.get("has_score", false)):
			_audit_log("interaction_score", {
				"turn": int(game_state.turn_number) if game_state != null else _cached_turn_number,
				"player_index": int(context.get("player_index", -1)),
				"step": step.duplicate(true),
				"item": _audit_logger.call("safe_value", item) if _audit_logger != null else str(item),
				"score": float(planned_score.get("score", 0.0)),
			})
			return float(planned_score.get("score", 0.0))
	return super.score_interaction_target(item, step, context)


func _select_current_action_queue(game_state: GameState, player_index: int) -> Array[Dictionary]:
	_sync_game_state_context(game_state, player_index, "_select_current_action_queue")
	if _llm_decision_tree.is_empty():
		_llm_action_queue.clear()
		return []
	if game_state == null:
		_llm_action_queue.clear()
		return []
	if _llm_queue_turn != int(game_state.turn_number):
		_llm_action_queue.clear()
		return []
	if bool(_llm_completed_queue_turns.get(int(game_state.turn_number), false)):
		_llm_action_queue.clear()
		return []
	if player_index < 0 or player_index >= game_state.players.size():
		_llm_action_queue.clear()
		return []
	if not _llm_action_catalog.is_empty() and not _llm_action_queue.is_empty():
		return _llm_action_queue
	_llm_action_queue = _decision_tree_executor.call("select_action_queue", _llm_decision_tree, game_state, player_index)
	_llm_action_queue = _normalize_selected_action_queue(_llm_action_queue)
	_llm_action_queue = _compile_selected_action_queue(_llm_action_queue, game_state, player_index)
	_audit_log("queue_selected", {
		"turn": int(game_state.turn_number),
		"player_index": player_index,
		"queue_size": _llm_action_queue.size(),
		"queue": _audit_logger.call("compact_actions", _llm_action_queue) if _audit_logger != null else _llm_action_queue,
	})
	return _llm_action_queue


func _compile_selected_action_queue(queue: Array[Dictionary], game_state: GameState, player_index: int) -> Array[Dictionary]:
	if _route_compiler == null or _llm_action_catalog.is_empty():
		return queue
	var result: Dictionary = _route_compiler.call("compile_queue", queue, _llm_action_catalog, game_state, player_index)
	var compiled_queue: Array[Dictionary] = []
	var raw_queue: Variant = result.get("queue", queue)
	if raw_queue is Array:
		for raw_action: Variant in raw_queue:
			if raw_action is Dictionary:
				compiled_queue.append(raw_action as Dictionary)
	if compiled_queue.is_empty() and not queue.is_empty():
		compiled_queue = queue
	var turn := int(game_state.turn_number) if game_state != null else _cached_turn_number
	_llm_route_compiler_results_by_turn[turn] = result.duplicate(true)
	var notes: Array = result.get("notes", [])
	var inserted: Array = result.get("inserted_actions", [])
	var missed: Array = result.get("missed_actions", [])
	var future_goals: Array = result.get("future_goals", [])
	if not notes.is_empty() or not inserted.is_empty() or not missed.is_empty() or bool(result.get("blocked_end_turn", false)):
		_audit_log("route_compiled", {
			"turn": turn,
			"player_index": player_index,
			"notes": notes,
			"blocked_end_turn": bool(result.get("blocked_end_turn", false)),
			"original_queue": _audit_logger.call("compact_actions", result.get("original_queue", [])) if _audit_logger != null else result.get("original_queue", []),
			"compiled_queue": _audit_logger.call("compact_actions", compiled_queue) if _audit_logger != null else compiled_queue,
			"future_goals": _audit_logger.call("compact_actions", future_goals) if _audit_logger != null else future_goals,
			"inserted_actions": _audit_logger.call("compact_actions", inserted) if _audit_logger != null else inserted,
			"missed_actions": _audit_logger.call("compact_actions", missed) if _audit_logger != null else missed,
		})
	return compiled_queue


func _route_compiler_blocks_end_turn(game_state: GameState) -> bool:
	var turn := int(game_state.turn_number) if game_state != null else _cached_turn_number
	var result: Dictionary = _llm_route_compiler_results_by_turn.get(turn, {})
	return bool(result.get("blocked_end_turn", false))


func _score_from_queue(action: Dictionary, action_queue: Array[Dictionary], game_state: GameState, player_index: int) -> float:
	for i: int in action_queue.size():
		if _queue_item_matches(action_queue[i], action, game_state, player_index):
			return QUEUE_BASE_SCORE - (float(i) * QUEUE_STEP)
	return 0.0


func _queue_index_for_action(action: Dictionary, action_queue: Array[Dictionary], game_state: GameState, player_index: int) -> int:
	for i: int in action_queue.size():
		if _queue_item_matches(action_queue[i], action, game_state, player_index):
			return i
	return -1


func _log_queue_score_match_once(action: Dictionary, action_queue: Array[Dictionary], score: float, game_state: GameState, player_index: int) -> void:
	var turn := int(game_state.turn_number) if game_state != null else _cached_turn_number
	var action_id: String = _action_id_for_action(action, game_state, player_index)
	var key := "%d:%d:%s" % [turn, player_index, action_id]
	if bool(_logged_queue_score_matches.get(key, false)):
		return
	_logged_queue_score_matches[key] = true
	_audit_log("queue_score_match", {
		"turn": turn,
		"player_index": player_index,
		"score": score,
		"matched_queue_index": _queue_index_for_action(action, action_queue, game_state, player_index),
		"action_id": action_id,
		"action": _audit_logger.call("compact_action", action) if _audit_logger != null else action,
		"queue": _audit_logger.call("compact_actions", action_queue) if _audit_logger != null else action_queue,
	})


func _queue_item_matches(q: Dictionary, action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var q_action_id: String = str(q.get("action_id", q.get("id", ""))).strip_edges()
	if q_action_id != "":
		var actual_action_id: String = _action_id_for_action(action, game_state, player_index)
		if q_action_id == "end_turn":
			if _is_end_turn_action_ref(action) and (_should_block_llm_end_turn(game_state, player_index) or _route_compiler_blocks_end_turn(game_state)):
				return false
			if _is_current_action_high_pressure_attack_ref(action, game_state, player_index):
				return true
			if _is_current_action_raging_bolt_burst_ref(action, game_state, player_index):
				return true
		if actual_action_id == q_action_id:
			if _is_raging_bolt_first_attack_ref(q, game_state, player_index) \
					and _is_current_action_raging_bolt_burst_available(game_state, player_index):
				return false
			return true
		if _is_raging_bolt_first_attack_ref(q, game_state, player_index) \
				and _is_current_action_raging_bolt_burst_ref(action, game_state, player_index):
			return true
		if not _is_future_action_ref(q):
			return false
	var q_type: String = str(q.get("type", ""))
	var a_kind: String = str(action.get("kind", ""))
	if q_type == "action_ref":
		return false
	if q_type != a_kind:
		if q_type == "attack" and a_kind == "granted_attack":
			return true
		return false
	match q_type:
		"attach_energy":
			return _match_attach_energy(q, action, game_state, player_index)
		"attach_tool":
			return _match_card_and_target(q, action, game_state, player_index)
		"play_basic_to_bench":
			return _match_card_name(q, action)
		"evolve":
			return _match_card_and_target(q, action, game_state, player_index)
		"play_trainer", "play_stadium":
			return _match_card_name(q, action)
		"use_ability":
			return _match_ability(q, action, game_state, player_index)
		"retreat":
			return _match_retreat(q, action, game_state, player_index)
		"attack":
			return _match_attack(q, action, game_state, player_index)
		"end_turn":
			if _is_end_turn_action_ref(action) and (_should_block_llm_end_turn(game_state, player_index) or _route_compiler_blocks_end_turn(game_state)):
				return false
			if _is_current_action_high_pressure_attack_ref(action, game_state, player_index):
				return true
			if _is_current_action_raging_bolt_burst_ref(action, game_state, player_index):
				return true
			return true
	return false


func _normalize_selected_action_queue(raw_queue: Array) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var manual_attach_seen := false
	for raw_index: int in raw_queue.size():
		var raw_value: Variant = raw_queue[raw_index]
		if not (raw_value is Dictionary):
			continue
		var raw: Dictionary = raw_value
		if raw.is_empty():
			continue
		var action_type: String = str(raw.get("type", raw.get("kind", "")))
		var action_id: String = str(raw.get("action_id", raw.get("id", "")))
		if action_type == "end_turn" or action_id == "end_turn":
			if _has_non_end_turn_after(raw_queue, raw_index):
				continue
		if action_type == "attach_energy":
			if manual_attach_seen:
				continue
			manual_attach_seen = true
		queue.append(raw)
	if queue.is_empty():
		return queue
	if not _queue_has_terminal_action(queue):
		queue.append({"type": "end_turn", "id": "end_turn", "action_id": "end_turn"})
	return queue


func _has_non_end_turn_after(queue: Array, current_index: int) -> bool:
	for i: int in range(current_index + 1, queue.size()):
		var raw_action: Variant = queue[i]
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		var action_type: String = str(action.get("type", action.get("kind", "")))
		var action_id: String = str(action.get("action_id", action.get("id", "")))
		if action_type != "end_turn" and action_id != "end_turn":
			return true
	return false


func _queue_contains_attack(queue: Array[Dictionary]) -> bool:
	for action: Dictionary in queue:
		var action_type: String = str(action.get("type", action.get("kind", "")))
		if action_type in ["attack", "granted_attack"]:
			return true
	return false


func _queue_contains_greninja_ability(queue: Array[Dictionary]) -> bool:
	for action: Dictionary in queue:
		if _is_greninja_ability_ref(action):
			return true
	return false


func _append_short_route_followups(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", "Teal Mask Ogerpon ex", "")
	_append_catalog_match(target, seen_ids, "play_basic_to_bench", "Raging Bolt ex", "")
	_append_best_tool_action(target, seen_ids)
	_append_catalog_match(target, seen_ids, "play_trainer", "Earthen Vessel", "", _earthen_vessel_interactions())
	_append_catalog_match(target, seen_ids, "play_trainer", "Energy Retrieval", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "Night Stretcher", "")
	_append_greninja_ability(target, seen_ids, _greninja_interactions())
	_append_fezandipiti_ability(target, seen_ids)
	_append_catalog_match(target, seen_ids, "use_ability", "", "Teal Mask Ogerpon ex", _ogerpon_interactions())
	_append_virtual_ogerpon_ability(target, seen_ids)
	_append_catalog_match(target, seen_ids, "play_trainer", "Trekking Shoes", "")
	_append_catalog_match(target, seen_ids, "play_trainer", "gear", "")


func _queue_has_terminal_action(queue: Array[Dictionary]) -> bool:
	for action: Dictionary in queue:
		var action_type: String = str(action.get("type", action.get("kind", "")))
		if action_type in ["attack", "granted_attack", "end_turn"]:
			return true
		var action_id: String = str(action.get("action_id", action.get("id", "")))
		if action_id == "end_turn":
			return true
	return false


func _consume_llm_queue_after_action(
	action: Dictionary,
	matched_index: int,
	turn: int,
	game_state: GameState,
	player_index: int
) -> void:
	if turn != _llm_queue_turn or _llm_action_queue.is_empty():
		return
	if matched_index < 0:
		_audit_log("queue_escape_action", {
			"turn": turn,
			"player_index": player_index,
			"action": _audit_logger.call("compact_action", action) if _audit_logger != null else action,
			"queue_head": _audit_logger.call("compact_actions", _llm_action_queue.slice(0, mini(_llm_action_queue.size(), 5))) if _audit_logger != null else _llm_action_queue,
		})
		var stale_queue: Array[Dictionary] = _llm_action_queue.duplicate(true)
		_llm_action_queue.clear()
		_llm_decision_tree.clear()
		_llm_queue_turn = -1
		if _is_terminal_runtime_action(action):
			_llm_completed_queue_turns[turn] = true
		elif int(_llm_replan_counts.get(turn, 0)) < _llm_max_replans_per_turn:
			_llm_completed_queue_turns.erase(turn)
			_llm_replan_counts[turn] = int(_llm_replan_counts.get(turn, 0)) + 1
			_llm_replan_eligible_after_reject[turn] = true
			_llm_request_attempt_turn = -1
		else:
			_llm_completed_queue_turns[turn] = true
		_audit_log("queue_cleared_after_escape", {
			"turn": turn,
			"player_index": player_index,
			"cleared_queue": _audit_logger.call("compact_actions", stale_queue.slice(0, mini(stale_queue.size(), 5))) if _audit_logger != null else stale_queue,
		})
		return
	if matched_index > 0:
		var skipped: Array[Dictionary] = _llm_action_queue.slice(0, matched_index)
		_audit_log("queue_skipped_actions", {
			"turn": turn,
			"player_index": player_index,
			"matched_queue_index": matched_index,
			"skipped": _audit_logger.call("compact_actions", skipped) if _audit_logger != null else skipped,
			"executed": _audit_logger.call("compact_action", action) if _audit_logger != null else action,
		})
	var consumed: Array[Dictionary] = _llm_action_queue.slice(0, matched_index + 1)
	var prior_consumed: Array = _llm_consumed_actions_by_turn.get(turn, [])
	prior_consumed.append_array(consumed)
	_llm_consumed_actions_by_turn[turn] = prior_consumed
	_llm_action_queue = _llm_action_queue.slice(matched_index + 1)
	if _is_terminal_runtime_action(action):
		_llm_action_queue.clear()
		_llm_completed_queue_turns[turn] = true
	elif _llm_action_queue.is_empty():
		_llm_completed_queue_turns[turn] = true
	_audit_log("queue_consumed", {
		"turn": turn,
		"player_index": player_index,
		"matched_queue_index": matched_index,
		"consumed": _audit_logger.call("compact_actions", consumed) if _audit_logger != null else consumed,
		"remaining": _audit_logger.call("compact_actions", _llm_action_queue.slice(0, mini(_llm_action_queue.size(), 5))) if _audit_logger != null else _llm_action_queue,
		"game_state_turn_after_execute": int(game_state.turn_number) if game_state != null else -1,
	})


func _is_terminal_runtime_action(action: Dictionary) -> bool:
	var kind: String = str(action.get("kind", ""))
	return kind in ["attack", "granted_attack", "end_turn"]


func _llm_replan_trigger(before_snapshot: Dictionary, after_snapshot: Dictionary, context: Dictionary) -> Dictionary:
	var before_ids: Array[String] = _string_array(before_snapshot.get("hand_ids", []))
	var after_ids: Array[String] = _string_array(after_snapshot.get("hand_ids", []))
	var added_ids: Array[String] = _array_difference(after_ids, before_ids)
	var removed_ids: Array[String] = _array_difference(before_ids, after_ids)
	var hand_delta := int(after_snapshot.get("hand_count", 0)) - int(before_snapshot.get("hand_count", 0))
	var deck_delta := int(after_snapshot.get("deck_count", 0)) - int(before_snapshot.get("deck_count", 0))
	var discard_delta := int(after_snapshot.get("discard_count", 0)) - int(before_snapshot.get("discard_count", 0))
	var action_kind := str(context.get("action_kind", ""))
	var step_kind := str(context.get("step_kind", ""))
	if action_kind in ["play_basic_to_bench", "attach_energy", "attach_tool", "evolve"]:
		return {"should_replan": false}
	if action_kind in ["attack", "granted_attack", "end_turn"]:
		return {"should_replan": false}
	if added_ids.size() >= 2:
		return {
			"should_replan": true,
			"reason": "hand_gained_%d_cards" % added_ids.size(),
			"added_ids": added_ids,
			"removed_ids": removed_ids,
		}
	if hand_delta >= 2:
		return {"should_replan": true, "reason": "hand_count_increased_%d" % hand_delta}
	if step_kind == "effect_interaction" and added_ids.size() >= 1 and removed_ids.size() >= 1:
		return {
			"should_replan": true,
			"reason": "effect_changed_hand_composition",
			"added_ids": added_ids,
			"removed_ids": removed_ids,
		}
	if deck_delta <= -2 and added_ids.size() >= 1:
		return {"should_replan": true, "reason": "deck_to_hand_resource_change"}
	if abs(discard_delta) >= 2 and not added_ids.is_empty():
		return {"should_replan": true, "reason": "discard_and_hand_resource_change"}
	return {"should_replan": false}


func _action_id_for_action(action: Dictionary, game_state: GameState, player_index: int) -> String:
	if _prompt_builder != null and _prompt_builder.has_method("action_id_for_action"):
		return str(_prompt_builder.call("action_id_for_action", action, game_state, player_index))
	return str(action.get("kind", ""))


func _build_action_catalog(
	legal_actions: Array,
	game_state: GameState,
	player_index: int
) -> Dictionary:
	var catalog := {}
	if _prompt_builder == null or not _prompt_builder.has_method("legal_action_reference"):
		return catalog
	for raw_action: Variant in legal_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		var ref: Dictionary = _prompt_builder.call("legal_action_reference", action, game_state, player_index)
		var action_id: String = str(ref.get("id", ""))
		if action_id == "":
			continue
		ref["action_id"] = action_id
		catalog[action_id] = ref
	return catalog


func _merge_payload_action_refs_into_catalog(payload: Dictionary) -> void:
	for raw_ref: Variant in payload.get("legal_actions", []):
		if not (raw_ref is Dictionary):
			continue
		var ref: Dictionary = raw_ref
		var action_id := str(ref.get("id", ref.get("action_id", "")))
		if action_id == "":
			continue
		ref["action_id"] = action_id
		_llm_action_catalog[action_id] = ref


func _register_payload_candidate_routes(payload: Dictionary) -> void:
	var result: Dictionary = _route_action_registry.call("register_payload_candidate_routes", payload, _llm_action_catalog)
	_llm_action_catalog = result.get("catalog", _llm_action_catalog)
	_llm_route_candidates_by_id = result.get("routes_by_id", {})


func _materialize_candidate_route_actions(raw_actions: Variant) -> Array[Dictionary]:
	return _route_action_registry.call("materialize_candidate_route_actions", raw_actions, _llm_action_catalog)


func _expand_candidate_route_ref(route_ref: Dictionary) -> Array[Dictionary]:
	return _route_action_registry.call("expand_candidate_route_ref", route_ref)


func _candidate_route_fallback_tree() -> Dictionary:
	var route_id := str(_route_action_registry.call("best_route_action_id", _llm_route_candidates_by_id))
	if route_id == "" or not _llm_action_catalog.has(route_id):
		return {}
	return {
		"branches": [{
			"when": [{"fact": "always"}],
			"actions": [{"id": route_id}],
		}],
		"fallback_actions": [{"id": "end_turn"}],
	}


func _is_future_action_ref(ref: Dictionary) -> bool:
	var action_id := str(ref.get("action_id", ref.get("id", "")))
	return bool(ref.get("future", false)) or action_id.begins_with("future:") or action_id.begins_with("virtual:")


func _hand_has_named_card(player: PlayerState, card_query: String) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if _name_contains(str(card.card_data.name_en), card_query) or _name_contains(str(card.card_data.name), card_query):
			return true
	return false


func _materialize_action_refs_in_tree(tree: Dictionary) -> Dictionary:
	return _materialize_action_ref_node(tree) if not tree.is_empty() else {}


func _validate_decision_tree_contract(tree: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	_validate_tree_node(tree, "root", errors)
	return {"valid": errors.is_empty(), "errors": errors}


func _sanitize_decision_tree_contract(tree: Dictionary) -> Dictionary:
	var sanitized: Dictionary = tree.duplicate(true)
	var pruned_errors: Array[String] = []
	var repair_notes: Array[String] = []
	var pruned_count := 0
	var repaired_count := 0
	for key: String in ["actions", "fallback_actions", "fallback"]:
		if not sanitized.has(key):
			continue
		var action_errors: Array[String] = []
		_validate_action_array(sanitized.get(key, []), "root.%s" % key, action_errors)
		if action_errors.is_empty():
			continue
		pruned_errors.append_array(action_errors)
		sanitized.erase(key)
		pruned_count += 1
	var branch_key := ""
	if sanitized.has("branches"):
		branch_key = "branches"
	elif sanitized.has("children"):
		branch_key = "children"
	if branch_key != "":
		var raw_branches: Variant = sanitized.get(branch_key, [])
		if raw_branches is Array:
			var kept_branches: Array[Dictionary] = []
			for i: int in (raw_branches as Array).size():
				var raw_branch: Variant = (raw_branches as Array)[i]
				if not (raw_branch is Dictionary):
					pruned_errors.append("root.%s[%d] is not an object" % [branch_key, i])
					pruned_count += 1
					continue
				var branch_to_validate: Dictionary = (raw_branch as Dictionary).duplicate(true)
				var repair: Dictionary = _repair_active_ready_branch_missing_attack(branch_to_validate)
				if bool(repair.get("repaired", false)):
					branch_to_validate = repair.get("branch", branch_to_validate)
					repair_notes.append("root.%s[%d]: %s" % [branch_key, i, str(repair.get("reason", ""))])
					repaired_count += 1
				var branch_errors: Array[String] = []
				_validate_tree_node({"branches": [branch_to_validate]}, "root", branch_errors)
				if branch_errors.is_empty():
					kept_branches.append(branch_to_validate)
					continue
				pruned_errors.append_array(branch_errors)
				pruned_count += 1
			sanitized[branch_key] = kept_branches
		else:
			pruned_errors.append("root.%s must be an array" % branch_key)
			sanitized.erase(branch_key)
			pruned_count += 1
	var final_check: Dictionary = _validate_decision_tree_contract(sanitized)
	var has_primary_plan := _tree_has_primary_plan(sanitized)
	return {
		"tree": sanitized,
		"valid": bool(final_check.get("valid", false)) and has_primary_plan,
		"errors": final_check.get("errors", []),
		"pruned_errors": pruned_errors,
		"pruned_count": pruned_count,
		"repair_notes": repair_notes,
		"repaired_count": repaired_count,
	}


func _repair_active_ready_branch_missing_attack(branch: Dictionary) -> Dictionary:
	var conditions: Variant = branch.get("when", branch.get("conditions", []))
	if not _conditions_include_fact(conditions, "active_attack_ready"):
		return {"repaired": false, "branch": branch}
	if _branch_contains_attack(branch):
		return {"repaired": false, "branch": branch}
	var attack_ref: Dictionary = _catalog_attack_for_active_ready_conditions(conditions)
	if attack_ref.is_empty():
		return {"repaired": false, "branch": branch}
	var repaired: Dictionary = branch.duplicate(true)
	var actions: Array = []
	var raw_actions: Variant = repaired.get("actions", [])
	if raw_actions is Array:
		for raw_action: Variant in raw_actions:
			if _raw_tree_action_type(raw_action) == "end_turn":
				continue
			actions.append(raw_action)
	actions.append({"id": str(attack_ref.get("action_id", attack_ref.get("id", "")))})
	repaired["actions"] = actions
	return {
		"repaired": true,
		"branch": repaired,
		"reason": "appended legal attack '%s' to active_attack_ready branch" % str(attack_ref.get("attack_name", "")),
	}


func _catalog_attack_for_active_ready_conditions(raw_conditions: Variant) -> Dictionary:
	var desired_attack := ""
	if raw_conditions is Dictionary:
		desired_attack = str((raw_conditions as Dictionary).get("attack_name", "")).strip_edges()
	elif raw_conditions is Array:
		for raw_condition: Variant in raw_conditions:
			if raw_condition is Dictionary and str((raw_condition as Dictionary).get("fact", "")).strip_edges() == "active_attack_ready":
				desired_attack = str((raw_condition as Dictionary).get("attack_name", "")).strip_edges()
				break
	var fallback: Dictionary = {}
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {})
		var action_type: String = str(ref.get("type", ""))
		if action_type not in ["attack", "granted_attack"]:
			continue
		var with_id: Dictionary = ref.duplicate(true)
		with_id["id"] = str(raw_key)
		with_id["action_id"] = str(raw_key)
		if fallback.is_empty():
			fallback = with_id
		var attack_name: String = str(ref.get("attack_name", ""))
		if desired_attack != "" and (_name_contains(attack_name, desired_attack) or _name_contains(desired_attack, attack_name)):
			return with_id
	return fallback


func _raw_tree_action_type(raw_action: Variant) -> String:
	var ref: Dictionary = _ref_for_raw_tree_action(raw_action)
	if not ref.is_empty():
		return str(ref.get("type", ""))
	var action_id := ""
	if raw_action is String:
		action_id = str(raw_action).strip_edges()
	elif raw_action is Dictionary:
		action_id = str((raw_action as Dictionary).get("id", (raw_action as Dictionary).get("action_id", ""))).strip_edges()
	if action_id == "end_turn":
		return "end_turn"
	return ""


func _tree_has_primary_plan(tree: Dictionary) -> bool:
	var raw_actions: Variant = tree.get("actions", [])
	if raw_actions is Array and not (raw_actions as Array).is_empty():
		return true
	var raw_branches: Variant = tree.get("branches", tree.get("children", []))
	if not (raw_branches is Array):
		return false
	for raw_branch: Variant in raw_branches:
		if not (raw_branch is Dictionary):
			continue
		var branch: Dictionary = raw_branch
		var branch_actions: Variant = branch.get("actions", [])
		if branch_actions is Array and not (branch_actions as Array).is_empty():
			return true
		var then_node: Variant = branch.get("then", {})
		if then_node is Dictionary and _tree_has_primary_plan(then_node):
			return true
	return false


func _validate_tree_node(node: Dictionary, path: String, errors: Array[String]) -> void:
	if errors.size() >= 8:
		return
	for key: String in ["actions", "fallback_actions", "fallback"]:
		if node.has(key):
			_validate_action_array(node.get(key, []), "%s.%s" % [path, key], errors)
	var raw_branches: Variant = node.get("branches", node.get("children", []))
	if raw_branches is Array:
		for i: int in (raw_branches as Array).size():
			var raw_branch: Variant = (raw_branches as Array)[i]
			if not (raw_branch is Dictionary):
				errors.append("%s.branches[%d] is not an object" % [path, i])
				continue
			var branch: Dictionary = raw_branch
			var conditions: Variant = branch.get("when", branch.get("conditions", []))
			_validate_conditions(conditions, "%s.branches[%d].when" % [path, i], errors)
			if _branch_starts_with_attack(branch) and not _conditions_include_fact(conditions, "active_attack_ready"):
				errors.append("%s.branches[%d] starts with attack but lacks active_attack_ready; can_attack only means the phase allows attacking" % [path, i])
			if _conditions_include_fact(conditions, "active_attack_ready") and not _branch_contains_attack(branch):
				errors.append("%s.branches[%d] has active_attack_ready but does not include an attack action" % [path, i])
			elif _has_any_attack_action() and _branch_is_attack_setup_route(branch) and not _branch_contains_attack(branch):
				errors.append("%s.branches[%d] uses attack setup actions but ends without attack while attack actions are legal" % [path, i])
			if _branch_contains_low_value_terminal_attack(branch) and _catalog_has_reachable_primary_future_attack():
				errors.append("%s.branches[%d] chooses a low-priority redraw/setup attack while a primary damage attack is reachable through visible setup/search" % [path, i])
			if _branch_is_shallow_setup_route(branch) and _catalog_has_reachable_primary_future_attack():
				errors.append("%s.branches[%d] is a shallow one-action setup route while a primary damage route is reachable; add then/follow-up actions or choose the primary route" % [path, i])
			if branch.has("actions"):
				_validate_action_array(branch.get("actions", []), "%s.branches[%d].actions" % [path, i], errors)
			if branch.has("fallback_actions"):
				_validate_action_array(branch.get("fallback_actions", []), "%s.branches[%d].fallback_actions" % [path, i], errors)
			var then_node: Variant = branch.get("then", {})
			if then_node is Dictionary:
				_validate_tree_node(then_node, "%s.branches[%d].then" % [path, i], errors)
			elif branch.has("branches") or branch.has("children"):
				_validate_tree_node(branch, "%s.branches[%d]" % [path, i], errors)


func _validate_conditions(raw_conditions: Variant, path: String, errors: Array[String]) -> void:
	if raw_conditions == null:
		return
	if raw_conditions is Dictionary:
		_validate_condition(raw_conditions, path, errors)
		return
	if not (raw_conditions is Array):
		errors.append("%s must be an array of standard fact objects" % path)
		return
	for i: int in (raw_conditions as Array).size():
		var raw_condition: Variant = (raw_conditions as Array)[i]
		if not (raw_condition is Dictionary):
			errors.append("%s[%d] is not an object" % [path, i])
			continue
		_validate_condition(raw_condition, "%s[%d]" % [path, i], errors)


func _validate_condition(condition: Dictionary, path: String, errors: Array[String]) -> void:
	if condition.has("condition") and not condition.has("fact"):
		errors.append("%s uses unsupported natural-language condition '%s'; use fact only" % [path, str(condition.get("condition", ""))])
		return
	var fact: String = str(condition.get("fact", condition.get("type", ""))).strip_edges()
	if fact == "":
		errors.append("%s is missing required fact" % path)
		return
	if not bool(SUPPORTED_TREE_FACTS.get(fact, false)):
		errors.append("%s uses unsupported fact '%s'" % [path, fact])
		return
	match fact:
		"hand_has_card", "discard_has_card":
			if str(condition.get("card", condition.get("name", ""))).strip_edges() == "":
				errors.append("%s fact '%s' requires card or name" % [path, fact])
		"hand_has_type":
			if str(condition.get("card_type", "")).strip_edges() == "" and str(condition.get("energy_type", "")).strip_edges() == "":
				errors.append("%s fact hand_has_type requires card_type or energy_type" % path)
		"discard_basic_energy_count_at_least":
			if not condition.has("count"):
				errors.append("%s fact discard_basic_energy_count_at_least requires count" % path)
		"active_has_energy_at_least":
			if not condition.has("count"):
				errors.append("%s fact active_has_energy_at_least requires count" % path)
		"active_attack_ready":
			if str(condition.get("attack_name", "")).strip_edges() == "":
				errors.append("%s fact active_attack_ready requires attack_name" % path)


func _conditions_include_fact(raw_conditions: Variant, fact_name: String) -> bool:
	if raw_conditions is Dictionary:
		return str((raw_conditions as Dictionary).get("fact", (raw_conditions as Dictionary).get("type", ""))).strip_edges() == fact_name
	if not (raw_conditions is Array):
		return false
	for raw: Variant in raw_conditions:
		if not (raw is Dictionary):
			continue
		if str((raw as Dictionary).get("fact", (raw as Dictionary).get("type", ""))).strip_edges() == fact_name:
			return true
	return false


func _branch_starts_with_attack(branch: Dictionary) -> bool:
	var raw_actions: Variant = branch.get("actions", [])
	if not (raw_actions is Array):
		return false
	for raw_action: Variant in raw_actions:
		var action_id := ""
		if raw_action is String:
			action_id = str(raw_action).strip_edges()
		elif raw_action is Dictionary:
			action_id = str((raw_action as Dictionary).get("id", (raw_action as Dictionary).get("action_id", ""))).strip_edges()
		if action_id == "":
			continue
		var ref: Dictionary = _llm_action_catalog.get(action_id, {})
		var action_type: String = str(ref.get("type", ""))
		if action_type == "end_turn":
			continue
		if action_type == "route":
			return _route_ref_first_non_end_type(ref) in ["attack", "granted_attack"]
		return action_type in ["attack", "granted_attack"]
	return false


func _branch_contains_attack(branch: Dictionary) -> bool:
	var raw_actions: Variant = branch.get("actions", [])
	if raw_actions is Array and _action_array_contains_type(raw_actions, ["attack", "granted_attack"]):
		return true
	var raw_fallback: Variant = branch.get("fallback_actions", [])
	if raw_fallback is Array and _action_array_contains_type(raw_fallback, ["attack", "granted_attack"]):
		return true
	var then_node: Variant = branch.get("then", {})
	if then_node is Dictionary:
		return _tree_node_contains_attack(then_node)
	return false


func _branch_contains_low_value_terminal_attack(branch: Dictionary) -> bool:
	var raw_actions: Variant = branch.get("actions", [])
	if raw_actions is Array and _action_array_contains_low_value_attack(raw_actions):
		return true
	var raw_fallback: Variant = branch.get("fallback_actions", [])
	if raw_fallback is Array and _action_array_contains_low_value_attack(raw_fallback):
		return true
	var then_node: Variant = branch.get("then", {})
	if then_node is Dictionary:
		return _tree_node_contains_low_value_attack(then_node)
	return false


func _tree_node_contains_attack(node: Dictionary) -> bool:
	if _action_array_contains_type(node.get("actions", []), ["attack", "granted_attack"]):
		return true
	if _action_array_contains_type(node.get("fallback_actions", node.get("fallback", [])), ["attack", "granted_attack"]):
		return true
	var raw_branches: Variant = node.get("branches", node.get("children", []))
	if raw_branches is Array:
		for raw_branch: Variant in raw_branches:
			if raw_branch is Dictionary and _branch_contains_attack(raw_branch):
				return true
	return false


func _tree_node_contains_low_value_attack(node: Dictionary) -> bool:
	if _action_array_contains_low_value_attack(node.get("actions", [])):
		return true
	if _action_array_contains_low_value_attack(node.get("fallback_actions", node.get("fallback", []))):
		return true
	var raw_branches: Variant = node.get("branches", node.get("children", []))
	if raw_branches is Array:
		for raw_branch: Variant in raw_branches:
			if raw_branch is Dictionary and _branch_contains_low_value_terminal_attack(raw_branch):
				return true
	return false


func _action_array_contains_low_value_attack(raw_actions: Variant) -> bool:
	if not (raw_actions is Array):
		return false
	for raw_action: Variant in raw_actions:
		var ref: Dictionary = _ref_for_raw_tree_action(raw_action)
		if ref.is_empty():
			continue
		if str(ref.get("type", "")) == "route":
			if _route_ref_contains_low_value_attack(ref):
				return true
			continue
		if not _is_attack_action_ref(ref):
			continue
		if _is_low_value_attack_ref_by_quality(ref):
			return true
	return false


func _catalog_has_reachable_primary_future_attack() -> bool:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {})
		if not _is_attack_action_ref(ref):
			continue
		if not bool(ref.get("future", false)):
			continue
		if not bool(ref.get("reachable_with_known_resources", true)):
			continue
		var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
		if str(quality.get("role", "")) == "primary_damage" or str(quality.get("terminal_priority", "")) == "high":
			return true
	return false


func _is_low_value_attack_ref_by_quality(ref: Dictionary) -> bool:
	var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
	if str(quality.get("terminal_priority", "")) == "low":
		return true
	return _is_low_value_first_attack_ref(ref)


func _branch_is_shallow_setup_route(branch: Dictionary) -> bool:
	if branch.has("then") or branch.has("branches") or branch.has("children") or branch.has("fallback_actions"):
		return false
	var raw_actions: Variant = branch.get("actions", [])
	if not (raw_actions is Array):
		return false
	if (raw_actions as Array).size() != 1:
		return false
	var ref: Dictionary = _ref_for_raw_tree_action((raw_actions as Array)[0])
	if ref.is_empty():
		return false
	var action_type := str(ref.get("type", ""))
	if action_type in ["attack", "granted_attack", "end_turn"]:
		return false
	return action_type in ["play_basic_to_bench", "play_trainer", "play_stadium", "use_ability", "attach_tool", "attach_energy"]


func _branch_is_attack_setup_route(branch: Dictionary) -> bool:
	var raw_actions: Variant = branch.get("actions", [])
	if not (raw_actions is Array):
		return false
	return _action_array_contains_attack_setup(raw_actions)


func _action_array_contains_attack_setup(raw_actions: Variant) -> bool:
	if not (raw_actions is Array):
		return false
	for raw_action: Variant in raw_actions:
		var ref: Dictionary = _ref_for_raw_tree_action(raw_action)
		if ref.is_empty():
			continue
		if str(ref.get("type", "")) == "route":
			if _route_ref_contains_attack_setup(ref):
				return true
			continue
		var action_type: String = str(ref.get("type", ""))
		var card_name: String = str(ref.get("card", ""))
		var pokemon_name: String = str(ref.get("pokemon", ""))
		var position: String = str(ref.get("position", ""))
		if action_type == "attach_energy" and position == "active":
			return true
		if action_type == "play_trainer" and (_name_contains(card_name, "Professor Sada's Vitality") or _name_contains(card_name, "Earthen Vessel")):
			return true
		if action_type == "use_ability" and _name_contains(pokemon_name, "Teal Mask Ogerpon ex"):
			return true
	return false


func _action_array_contains_type(raw_actions: Variant, action_types: Array[String]) -> bool:
	if not (raw_actions is Array):
		return false
	for raw_action: Variant in raw_actions:
		var ref: Dictionary = _ref_for_raw_tree_action(raw_action)
		if ref.is_empty():
			continue
		if str(ref.get("type", "")) == "route":
			if _route_ref_contains_type(ref, action_types):
				return true
			continue
		if str(ref.get("type", "")) in action_types:
			return true
	return false


func _route_ref_first_non_end_type(route_ref: Dictionary) -> String:
	var raw_actions: Variant = route_ref.get("actions", [])
	if not (raw_actions is Array):
		return ""
	for raw: Variant in raw_actions:
		if not (raw is Dictionary):
			continue
		var action_type := str((raw as Dictionary).get("type", ""))
		if action_type == "end_turn":
			continue
		return action_type
	return ""


func _route_ref_contains_type(route_ref: Dictionary, action_types: Array[String]) -> bool:
	var raw_actions: Variant = route_ref.get("actions", [])
	if not (raw_actions is Array):
		return false
	for raw: Variant in raw_actions:
		if raw is Dictionary and str((raw as Dictionary).get("type", "")) in action_types:
			return true
	return false


func _route_ref_contains_low_value_attack(route_ref: Dictionary) -> bool:
	var raw_actions: Variant = route_ref.get("actions", [])
	if not (raw_actions is Array):
		return false
	for raw: Variant in raw_actions:
		if raw is Dictionary and _is_attack_action_ref(raw as Dictionary) and _is_low_value_attack_ref_by_quality(raw as Dictionary):
			return true
	return false


func _route_ref_contains_attack_setup(route_ref: Dictionary) -> bool:
	var raw_actions: Variant = route_ref.get("actions", [])
	if not (raw_actions is Array):
		return false
	for raw: Variant in raw_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var action_type := str(ref.get("type", ""))
		var card_name := str(ref.get("card", ""))
		var pokemon_name := str(ref.get("pokemon", ""))
		var position := str(ref.get("position", ""))
		if action_type == "attach_energy" and position == "active":
			return true
		if action_type == "play_trainer" and (_name_contains(card_name, "Professor Sada's Vitality") or _name_contains(card_name, "Earthen Vessel")):
			return true
		if action_type == "use_ability" and _name_contains(pokemon_name, "Teal Mask Ogerpon ex"):
			return true
	return false


func _has_any_attack_action() -> bool:
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(raw_key, {})
		if bool(ref.get("future", false)):
			continue
		if str(ref.get("type", "")) in ["attack", "granted_attack"]:
			return true
	return false


func _ref_for_raw_tree_action(raw_action: Variant) -> Dictionary:
	var action_id := ""
	if raw_action is String:
		action_id = str(raw_action).strip_edges()
	elif raw_action is Dictionary:
		action_id = str((raw_action as Dictionary).get("id", (raw_action as Dictionary).get("action_id", ""))).strip_edges()
	if action_id == "":
		return {}
	return _llm_action_catalog.get(action_id, {})


func _validate_action_array(raw_actions: Variant, path: String, errors: Array[String]) -> void:
	if raw_actions == null:
		return
	if not (raw_actions is Array):
		errors.append("%s must be an array" % path)
		return
	var manual_attach_count := 0
	var route_action_ids: Array[String] = []
	for i: int in (raw_actions as Array).size():
		var raw_action: Variant = (raw_actions as Array)[i]
		var action_id := ""
		var interactions: Dictionary = {}
		if raw_action is String:
			action_id = str(raw_action).strip_edges()
		elif raw_action is Dictionary:
			action_id = str((raw_action as Dictionary).get("id", (raw_action as Dictionary).get("action_id", ""))).strip_edges()
			var raw_interactions: Variant = (raw_action as Dictionary).get("interactions", {})
			if raw_interactions is Dictionary:
				interactions = raw_interactions
		else:
			errors.append("%s[%d] is not an action object" % [path, i])
			continue
		if action_id == "":
			errors.append("%s[%d] is missing id copied from legal_actions" % [path, i])
			continue
		if not _llm_action_catalog.has(action_id):
			errors.append("%s[%d] uses unknown action id '%s'" % [path, i, action_id])
			continue
		var ref: Dictionary = _llm_action_catalog.get(action_id, {})
		if str(ref.get("type", "")) == "route":
			for route_action: Dictionary in _expand_candidate_route_ref(ref):
				var inner_id := str(route_action.get("id", route_action.get("action_id", "")))
				if inner_id == "":
					continue
				route_action_ids.append(inner_id)
				if str(route_action.get("type", "")) == "attach_energy":
					manual_attach_count += 1
				var inner_interactions: Dictionary = route_action.get("interactions", {}) if route_action.get("interactions", {}) is Dictionary else {}
				_validate_action_interactions(inner_id, route_action, inner_interactions, "%s[%d].route_action[%s]" % [path, i, inner_id], errors)
			continue
		route_action_ids.append(action_id)
		if str(ref.get("type", "")) == "attach_energy":
			manual_attach_count += 1
		_validate_action_interactions(action_id, ref, interactions, "%s[%d]" % [path, i], errors)
	if manual_attach_count > 1:
		errors.append("%s contains %d manual attach_energy actions; one manual attach per turn route is allowed" % [path, manual_attach_count])
	_validate_route_resource_conflicts(route_action_ids, path, errors)


func _validate_route_resource_conflicts(route_action_ids: Array[String], path: String, errors: Array[String]) -> void:
	if route_action_ids.size() < 2:
		return
	var route_set: Dictionary = {}
	for action_id: String in route_action_ids:
		route_set[action_id] = true
	for action_id: String in route_action_ids:
		var ref: Dictionary = _llm_action_catalog.get(action_id, {})
		var raw_conflicts: Variant = ref.get("resource_conflicts", [])
		if not (raw_conflicts is Array):
			continue
		for raw_conflict: Variant in raw_conflicts:
			var conflict_id := str(raw_conflict)
			if conflict_id != "" and bool(route_set.get(conflict_id, false)):
				errors.append("%s uses resource-conflicting actions '%s' and '%s'; split them into separate branches or add a draw/search branch first" % [path, action_id, conflict_id])
				return


func _validate_action_interactions(action_id: String, ref: Dictionary, interactions: Dictionary, path: String, errors: Array[String]) -> void:
	if interactions.is_empty():
		return
	var card_name: String = str(ref.get("card", ""))
	if _name_contains(card_name, "Professor Sada's Vitality"):
		for bad_key: String in ["search_target", "search_targets", "search_energy", "discard_energy_types", "discard_energy_type"]:
			if interactions.has(bad_key):
				errors.append("%s gives Professor Sada's Vitality invalid interaction '%s'; use sada_assignments instead" % [path, bad_key])
	if _name_contains(card_name, "Earthen Vessel"):
		for key: String in interactions.keys():
			if key not in ["discard_cards", "discard_card", "search_energy", "search_target", "search_targets"]:
				errors.append("%s gives Earthen Vessel unsupported interaction '%s'" % [path, key])
	var pokemon_name: String = str(ref.get("pokemon", ref.get("card", "")))
	if str(ref.get("type", "")) == "use_ability" and _name_contains(pokemon_name, "Teal Mask Ogerpon ex"):
		for bad_key: String in ["search_target", "search_targets", "search_energy", "search_cards"]:
			if interactions.has(bad_key):
				errors.append("%s gives Teal Mask Ogerpon ex invalid interaction '%s'; use basic_energy_from_hand or energy_card_id instead" % [path, bad_key])


func _materialize_action_ref_node(node: Dictionary) -> Dictionary:
	var result: Dictionary = node.duplicate(true)
	for key: String in ["actions", "fallback_actions", "fallback"]:
		if result.has(key):
			result[key] = _materialize_action_ref_array(result.get(key, []))
	for branch_key: String in ["branches", "children"]:
		var raw_branches: Variant = result.get(branch_key, [])
		if not (raw_branches is Array):
			continue
		var materialized_branches: Array[Dictionary] = []
		for raw_branch: Variant in raw_branches:
			if not (raw_branch is Dictionary):
				continue
			var branch: Dictionary = (raw_branch as Dictionary).duplicate(true)
			if branch.has("actions"):
				branch["actions"] = _materialize_action_ref_array(branch.get("actions", []))
			var then_node: Variant = branch.get("then", {})
			if then_node is Dictionary:
				branch["then"] = _materialize_action_ref_node(then_node as Dictionary)
			if branch.has("fallback_actions"):
				branch["fallback_actions"] = _materialize_action_ref_array(branch.get("fallback_actions", []))
			materialized_branches.append(branch)
		result[branch_key] = materialized_branches
	return result


func _materialize_action_ref_array(raw_actions: Variant) -> Array[Dictionary]:
	return _route_action_registry.call("materialize_action_ref_array", raw_actions, _llm_action_catalog)


func _repair_premature_short_routes_in_tree(tree: Dictionary) -> Dictionary:
	if tree.is_empty() or _llm_action_catalog.is_empty():
		return {"tree": tree, "added_count": 0, "added_actions": []}
	var repair: Dictionary = _repair_premature_short_routes_in_node(tree)
	return {
		"tree": repair.get("node", tree),
		"added_count": int(repair.get("added_count", 0)),
		"added_actions": repair.get("added_actions", []),
	}


func _repair_terminal_attack_routes_in_tree(
	tree: Dictionary,
	game_state: GameState = null,
	player_index: int = -1
) -> Dictionary:
	if tree.is_empty() or _llm_action_catalog.is_empty():
		return {"tree": tree, "changed_count": 0, "repair_notes": []}
	var repair: Dictionary = _repair_terminal_attack_routes_in_node(tree, game_state, player_index)
	return {
		"tree": repair.get("node", tree),
		"changed_count": int(repair.get("changed_count", 0)),
		"repair_notes": repair.get("repair_notes", []),
	}


func _repair_terminal_attack_routes_in_node(
	node: Dictionary,
	game_state: GameState = null,
	player_index: int = -1
) -> Dictionary:
	var result: Dictionary = node.duplicate(true)
	var changed_count := 0
	var repair_notes: Array[String] = []
	for key: String in ["actions", "fallback_actions", "fallback"]:
		if not result.has(key):
			continue
		var action_repair: Dictionary = _repair_terminal_attack_action_array(result.get(key, []), game_state, player_index)
		result[key] = action_repair.get("actions", result.get(key, []))
		changed_count += int(action_repair.get("changed_count", 0))
		repair_notes.append_array(action_repair.get("repair_notes", []))
	for branch_key: String in ["branches", "children"]:
		var raw_branches: Variant = result.get(branch_key, [])
		if not (raw_branches is Array):
			continue
		var repaired_branches: Array[Dictionary] = []
		for raw_branch: Variant in raw_branches:
			if not (raw_branch is Dictionary):
				continue
			var branch: Dictionary = (raw_branch as Dictionary).duplicate(true)
			if branch.has("actions"):
				var branch_repair: Dictionary = _repair_terminal_attack_action_array(branch.get("actions", []), game_state, player_index)
				branch["actions"] = branch_repair.get("actions", branch.get("actions", []))
				changed_count += int(branch_repair.get("changed_count", 0))
				repair_notes.append_array(branch_repair.get("repair_notes", []))
			var then_node: Variant = branch.get("then", {})
			if then_node is Dictionary:
				var then_repair: Dictionary = _repair_terminal_attack_routes_in_node(then_node as Dictionary, game_state, player_index)
				branch["then"] = then_repair.get("node", then_node)
				changed_count += int(then_repair.get("changed_count", 0))
				repair_notes.append_array(then_repair.get("repair_notes", []))
			if branch.has("fallback_actions"):
				var fallback_repair: Dictionary = _repair_terminal_attack_action_array(branch.get("fallback_actions", []), game_state, player_index)
				branch["fallback_actions"] = fallback_repair.get("actions", branch.get("fallback_actions", []))
				changed_count += int(fallback_repair.get("changed_count", 0))
				repair_notes.append_array(fallback_repair.get("repair_notes", []))
			repaired_branches.append(branch)
		result[branch_key] = repaired_branches
	return {"node": result, "changed_count": changed_count, "repair_notes": repair_notes}


func _repair_terminal_attack_action_array(
	raw_actions: Variant,
	game_state: GameState = null,
	player_index: int = -1
) -> Dictionary:
	if not (raw_actions is Array):
		return {"actions": [], "changed_count": 0, "repair_notes": []}
	var actions: Array[Dictionary] = []
	for raw_action: Variant in raw_actions:
		if raw_action is Dictionary:
			actions.append(raw_action)
	if actions.is_empty():
		return {"actions": actions, "changed_count": 0, "repair_notes": []}
	var has_attack := false
	for action: Dictionary in actions:
		if _is_attack_action_ref(action):
			has_attack = true
			break
	if not has_attack:
		return {"actions": actions, "changed_count": 0, "repair_notes": []}
	var pre_attack: Array[Dictionary] = []
	var moved_before_attack: Array[Dictionary] = []
	var chosen_attack: Dictionary = {}
	var changed_count := 0
	var repair_notes: Array[String] = []
	var seen_pre_ids: Dictionary = {}
	for action: Dictionary in actions:
		if _is_end_turn_action_ref(action):
			changed_count += 1
			repair_notes.append("removed end_turn from attack route")
			continue
		if _is_attack_action_ref(action):
			var candidate: Dictionary = _preferred_terminal_attack_for(action, game_state, player_index)
			if chosen_attack.is_empty():
				chosen_attack = candidate
				if _action_ref_id(candidate) != _action_ref_id(action):
					changed_count += 1
					repair_notes.append("replaced low-value first attack with stronger legal attack")
			elif _is_better_terminal_attack(candidate, chosen_attack):
				chosen_attack = candidate
				changed_count += 1
				repair_notes.append("kept stronger terminal attack and dropped earlier attack")
			else:
				changed_count += 1
				repair_notes.append("dropped duplicate post-terminal attack")
			continue
		var action_id: String = _action_ref_id(action)
		if chosen_attack.is_empty():
			if action_id != "":
				seen_pre_ids[action_id] = true
			pre_attack.append(action)
		else:
			if action_id != "" and bool(seen_pre_ids.get(action_id, false)):
				changed_count += 1
				repair_notes.append("dropped duplicate action after attack")
				continue
			if action_id != "":
				seen_pre_ids[action_id] = true
			moved_before_attack.append(action)
			changed_count += 1
			repair_notes.append("moved post-attack action before terminal attack")
	if chosen_attack.is_empty():
		return {"actions": actions, "changed_count": changed_count, "repair_notes": repair_notes}
	var repaired: Array[Dictionary] = []
	repaired.append_array(pre_attack)
	repaired.append_array(moved_before_attack)
	repaired.append(chosen_attack)
	return {"actions": repaired, "changed_count": changed_count, "repair_notes": repair_notes}


func _is_attack_action_ref(action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", action.get("kind", "")))
	return action_type in ["attack", "granted_attack"]


func _is_end_turn_action_ref(action: Dictionary) -> bool:
	var action_type: String = str(action.get("type", action.get("kind", "")))
	var action_id: String = _action_ref_id(action)
	return action_type == "end_turn" or action_id == "end_turn"


func _action_ref_id(action: Dictionary) -> String:
	return str(action.get("action_id", action.get("id", "")))


func _preferred_terminal_attack_for(
	action: Dictionary,
	game_state: GameState = null,
	player_index: int = -1
) -> Dictionary:
	if _is_raging_bolt_first_attack_ref(action, game_state, player_index):
		var burst: Dictionary = _raging_bolt_burst_attack_ref(game_state, player_index)
		if not burst.is_empty() and _raging_bolt_burst_is_pressure(burst, game_state, player_index):
			return _copy_attack_ref_with_interactions(burst, action)
	if not _is_low_value_first_attack_ref(action):
		return action
	var stronger: Dictionary = _stronger_ready_attack_ref()
	if stronger.is_empty():
		return action
	return _copy_attack_ref_with_interactions(stronger, action)


func _copy_attack_ref_with_interactions(replacement: Dictionary, original: Dictionary) -> Dictionary:
	var result: Dictionary = replacement.duplicate(true)
	if not result.has("id") and result.has("action_id"):
		result["id"] = str(result.get("action_id", ""))
	if not result.has("action_id") and result.has("id"):
		result["action_id"] = str(result.get("id", ""))
	var interactions: Variant = original.get("interactions", {})
	if interactions is Dictionary and not (interactions as Dictionary).is_empty():
		result["interactions"] = (interactions as Dictionary).duplicate(true)
	return result


func _is_better_terminal_attack(candidate: Dictionary, current: Dictionary) -> bool:
	if _is_low_value_first_attack_ref(current) and not _is_low_value_first_attack_ref(candidate):
		return true
	return int(candidate.get("attack_index", -1)) > int(current.get("attack_index", -1)) and _attack_has_real_damage(candidate)


func _is_low_value_first_attack_ref(action: Dictionary) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if int(action.get("attack_index", -1)) != 0:
		return false
	var attack_rules: Variant = action.get("attack_rules", {})
	if attack_rules is Dictionary:
		var rules: Dictionary = attack_rules
		var damage: String = str(rules.get("damage", "")).strip_edges()
		var tags: Variant = rules.get("tags", [])
		if damage == "":
			return true
		if tags is Array and ((tags as Array).has("draw") or (tags as Array).has("search_deck") or (tags as Array).has("discard")):
			return true
	var attack_name := str(action.get("attack_name", ""))
	return _name_contains(attack_name, "Roar") \
		or _name_contains(attack_name, "妞嬬偞绨犻崪鍡楁懄") \
		or _name_contains(attack_name, "Bursting Roar") \
		or _name_contains(attack_name, "Burst Roar")


func _is_raging_bolt_first_attack_ref(action: Dictionary, game_state: GameState = null, player_index: int = -1) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if int(action.get("attack_index", -1)) != 0:
		return false
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		var active: PokemonSlot = game_state.players[player_index].active_pokemon
		if active == null or active.get_card_data() == null:
			return false
		var cd: CardData = active.get_card_data()
		if not (_name_contains(str(cd.name_en), "Raging Bolt ex") or _name_contains(str(cd.name), "Raging Bolt")):
			return false
	var attack_name := str(action.get("attack_name", ""))
	if attack_name.strip_edges() == "":
		return true
	return _name_contains(attack_name, "妞嬬偞绨犻崪鍡楁懄") \
		or _name_contains(attack_name, "Bursting Roar") \
		or _name_contains(attack_name, "Burst Roar") \
		or _name_contains(attack_name, "Roar")


func _is_current_action_raging_bolt_burst_available(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var active: PokemonSlot = game_state.players[player_index].active_pokemon
	if active == null or active.get_card_data() == null:
		return false
	var cd: CardData = active.get_card_data()
	if not (_name_contains(str(cd.name_en), "Raging Bolt ex") or _name_contains(str(cd.name), "Raging Bolt")):
		return false
	return _raging_bolt_burst_damage_estimate(game_state, player_index) > 0


func _active_raging_bolt_burst_cost_ready(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var active: PokemonSlot = game_state.players[player_index].active_pokemon
	if active == null or active.get_card_data() == null:
		return false
	var cd: CardData = active.get_card_data()
	if not (_name_contains(str(cd.name_en), "Raging Bolt ex") or _name_contains(str(cd.name), "Raging Bolt")):
		return false
	var has_lightning := false
	var has_fighting := false
	for energy: CardInstance in active.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var provides := str(energy.card_data.energy_provides)
		has_lightning = has_lightning or _energy_type_matches("Lightning", provides) or _energy_type_matches("L", provides)
		has_fighting = has_fighting or _energy_type_matches("Fighting", provides) or _energy_type_matches("F", provides)
	return has_lightning and has_fighting


func _should_block_llm_end_turn(game_state: GameState, player_index: int) -> bool:
	if _active_raging_bolt_burst_cost_ready(game_state, player_index):
		return true
	if _current_active_has_high_pressure_ready_attack(game_state, player_index):
		return true
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return false
	var active: PokemonSlot = player.active_pokemon
	if active == null or active.get_card_data() == null:
		return false
	if _is_raging_bolt_card_data(active.get_card_data()):
		return false
	return _bench_has_raging_bolt(player) or _hand_has_recovery_or_pivot_piece(player)


func _is_current_action_high_pressure_attack_ref(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if _is_current_action_raging_bolt_burst_ref(action, game_state, player_index):
		return true
	var damage := _estimated_current_attack_damage(action, game_state, player_index)
	if damage <= 0:
		return false
	var opponent_hp := _opponent_active_remaining_hp(game_state, player_index)
	if opponent_hp > 0 and damage >= opponent_hp:
		return true
	return damage >= 160


func _current_active_has_high_pressure_ready_attack(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null or player.active_pokemon.get_card_data() == null:
		return false
	var cd: CardData = player.active_pokemon.get_card_data()
	for attack_index: int in cd.attacks.size():
		var attack: Dictionary = cd.attacks[attack_index]
		if not _active_attack_cost_ready(player.active_pokemon, str(attack.get("cost", ""))):
			continue
		var ref := {
			"type": "attack",
			"attack_index": attack_index,
			"attack_name": str(attack.get("name", "")),
			"attack_rules": attack,
		}
		if _is_current_action_high_pressure_attack_ref(ref, game_state, player_index):
			return true
	return false


func _active_attack_cost_ready(slot: PokemonSlot, cost: String) -> bool:
	var remaining := {}
	var total_attached := 0
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var symbol := _energy_symbol_for_runtime(str(energy.card_data.energy_provides))
		if symbol == "":
			continue
		remaining[symbol] = int(remaining.get(symbol, 0)) + 1
		total_attached += 1
	var colorless_needed := 0
	for i: int in cost.length():
		var symbol := _energy_symbol_for_runtime(cost.substr(i, 1))
		if symbol == "":
			continue
		if symbol == "C":
			colorless_needed += 1
			continue
		var count := int(remaining.get(symbol, 0))
		if count <= 0:
			return false
		remaining[symbol] = count - 1
		total_attached -= 1
	return colorless_needed <= total_attached


func _estimated_current_attack_damage(action: Dictionary, game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null or player.active_pokemon.get_card_data() == null:
		return 0
	var active: PokemonSlot = player.active_pokemon
	var rules: Dictionary = action.get("attack_rules", {}) if action.get("attack_rules", {}) is Dictionary else {}
	var attack_index := int(action.get("attack_index", -1))
	if rules.is_empty() and attack_index >= 0 and attack_index < active.get_card_data().attacks.size():
		rules = active.get_card_data().attacks[attack_index]
	var damage_text := str(rules.get("damage", "")).strip_edges()
	var base_damage := _first_int_for_runtime(damage_text)
	if base_damage <= 0:
		return 0
	var combined := "%s %s %s" % [damage_text, str(rules.get("text", "")), str(action.get("attack_name", ""))]
	var lower := combined.to_lower()
	var damage := base_damage
	if _runtime_text_looks_like_both_active_energy_bonus(lower):
		damage = base_damage + (_runtime_energy_multiplier_from_text(combined, 30) * (_attached_energy_count(active) + _attached_energy_count(_opponent_active_slot_for_runtime(game_state, player_index))))
	elif lower.contains("x") or lower.contains("×") or lower.contains("脳"):
		if _name_contains(lower, "raging bolt") or _name_contains(lower, "basic energy") or _name_contains(lower, "discard"):
			damage = _raging_bolt_burst_damage_estimate(game_state, player_index)
		else:
			damage = base_damage * maxi(1, _attached_energy_count(active))
	return _apply_runtime_weakness(damage, active.get_card_data(), _opponent_active_slot_for_runtime(game_state, player_index))


func _opponent_active_remaining_hp(game_state: GameState, player_index: int) -> int:
	var opponent_active: PokemonSlot = _opponent_active_slot_for_runtime(game_state, player_index)
	return opponent_active.get_remaining_hp() if opponent_active != null else 0


func _opponent_active_slot_for_runtime(game_state: GameState, player_index: int) -> PokemonSlot:
	if game_state == null:
		return null
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return null
	var opponent: PlayerState = game_state.players[opponent_index]
	return opponent.active_pokemon if opponent != null else null


func _attached_energy_count(slot: PokemonSlot) -> int:
	return slot.attached_energy.size() if slot != null else 0


func _runtime_text_looks_like_both_active_energy_bonus(lower_text: String) -> bool:
	return (lower_text.contains("both active") or lower_text.contains("双方") or lower_text.contains("战斗宝可梦") or lower_text.contains("戰鬥寶可夢")) \
		and (lower_text.contains("attached energy") or lower_text.contains("energy attached") or lower_text.contains("附着") or lower_text.contains("附著")) \
		and (lower_text.contains("x") or lower_text.contains("×") or lower_text.contains("脳") or lower_text.contains("for each") or lower_text.contains("每"))


func _runtime_energy_multiplier_from_text(text: String, fallback: int) -> int:
	var normalized := text.replace("×", "x").replace("脳", "x")
	var x_index := normalized.find("x")
	if x_index <= 0:
		return fallback
	var digits := ""
	var cursor := x_index - 1
	while cursor >= 0:
		var ch := normalized.substr(cursor, 1)
		if ch >= "0" and ch <= "9":
			digits = ch + digits
			cursor -= 1
			continue
		if digits != "":
			break
		cursor -= 1
	return int(digits) if digits.is_valid_int() else fallback


func _first_int_for_runtime(text: String) -> int:
	var digits := ""
	for i: int in text.length():
		var ch := text.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return int(digits) if digits.is_valid_int() else 0


func _apply_runtime_weakness(damage: int, attacker_cd: CardData, defender: PokemonSlot) -> int:
	if damage <= 0 or attacker_cd == null or defender == null or defender.get_card_data() == null:
		return damage
	var attacker_symbol := _energy_symbol_for_runtime(str(attacker_cd.energy_type))
	var weakness_symbol := _energy_symbol_for_runtime(str(defender.get_card_data().weakness_energy))
	if attacker_symbol == "" or weakness_symbol == "" or attacker_symbol != weakness_symbol:
		return damage
	var value := str(defender.get_card_data().weakness_value)
	if value.contains("2"):
		return damage * 2
	return damage


func _energy_symbol_for_runtime(value: String) -> String:
	var normalized := value.strip_edges().to_upper()
	match normalized:
		"LIGHTNING":
			return "L"
		"FIGHTING":
			return "F"
		"GRASS":
			return "G"
		"FIRE":
			return "R"
		"WATER":
			return "W"
		"PSYCHIC":
			return "P"
		"DARKNESS", "DARK":
			return "D"
		"METAL":
			return "M"
		"COLORLESS":
			return "C"
	if normalized in ["L", "F", "G", "R", "W", "P", "D", "M", "C"]:
		return normalized
	return ""


func _is_raging_bolt_card_data(cd: CardData) -> bool:
	if cd == null:
		return false
	return _name_contains(str(cd.name_en), "Raging Bolt ex") or _name_contains(str(cd.name), "Raging Bolt")


func _bench_has_raging_bolt(player: PlayerState) -> bool:
	if player == null:
		return false
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null and bench_slot.get_card_data() != null and _is_raging_bolt_card_data(bench_slot.get_card_data()):
			return true
	return false


func _hand_has_recovery_or_pivot_piece(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var cd: CardData = card.card_data
		if cd.card_type == "Basic Energy":
			return true
		var name_en := str(cd.name_en)
		var name := str(cd.name)
		if _name_contains(name_en, "Raging Bolt ex") \
				or _name_contains(name_en, "Nest Ball") \
				or _name_contains(name_en, "Switch Cart") \
				or _name_contains(name_en, "Prime Catcher") \
				or _name_contains(name_en, "Professor Sada") \
				or _name_contains(name_en, "Earthen Vessel") \
				or _name_contains(name_en, "Night Stretcher") \
				or _name_contains(name_en, "Energy Retrieval") \
				or _name_contains(name_en, "Pal Pad") \
				or _name_contains(name_en, "Trekking Shoes") \
				or _name_contains(name_en, "Pokegear") \
				or _name_contains(name_en, "Pok茅gear") \
				or _name_contains(name, "Raging Bolt"):
			return true
	return false


func _is_current_action_raging_bolt_burst_ref(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if not _is_attack_action_ref(action):
		return false
	if int(action.get("attack_index", -1)) <= 0:
		return false
	if not _is_current_action_raging_bolt_burst_available(game_state, player_index):
		return false
	return _raging_bolt_burst_is_pressure(action, game_state, player_index)


func _raging_bolt_burst_attack_ref(game_state: GameState = null, player_index: int = -1) -> Dictionary:
	var best: Dictionary = {}
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(str(raw_key), {})
		if not _is_attack_action_ref(ref):
			continue
		if int(ref.get("attack_index", -1)) <= 0:
			continue
		if not _attack_has_real_damage(ref):
			continue
		var attack_name := str(ref.get("attack_name", ""))
		if attack_name != "" and not (_name_contains(attack_name, "Bellowing Thunder") or _name_contains(attack_name, "Thunder")):
			continue
		if best.is_empty() or int(ref.get("attack_index", -1)) > int(best.get("attack_index", -1)):
			best = ref.duplicate(true)
			best["id"] = str(raw_key)
			best["action_id"] = str(raw_key)
	return best


func _raging_bolt_burst_is_pressure(action: Dictionary, game_state: GameState = null, player_index: int = -1) -> bool:
	if action.is_empty():
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return true
	var damage := _raging_bolt_burst_damage_estimate(game_state, player_index)
	if damage >= 140:
		return true
	var opponent_index := 1 - player_index
	if opponent_index >= 0 and opponent_index < game_state.players.size():
		var opponent_active: PokemonSlot = game_state.players[opponent_index].active_pokemon
		if opponent_active != null and opponent_active.get_card_data() != null:
			var remaining_hp := int(opponent_active.get_card_data().hp) - int(opponent_active.damage_counters) * 10
			if remaining_hp > 0 and damage >= remaining_hp:
				return true
	return damage > 0


func _raging_bolt_burst_damage_estimate(game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var player: PlayerState = game_state.players[player_index]
	var energy_count := 0
	if player.active_pokemon != null:
		energy_count += _basic_energy_attached_count(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		energy_count += _basic_energy_attached_count(slot)
	return energy_count * 70


func _basic_energy_attached_count(slot: PokemonSlot) -> int:
	if slot == null:
		return 0
	var count := 0
	for card: CardInstance in slot.attached_energy:
		if card == null or card.card_data == null:
			continue
		if str(card.card_data.card_type) == "Basic Energy":
			count += 1
	return count


func _player_deck_count_for_llm(game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return -1
	var player: PlayerState = game_state.players[player_index]
	return player.deck.size() if player != null else -1


func _stronger_ready_attack_ref() -> Dictionary:
	var best: Dictionary = {}
	for raw_key: Variant in _llm_action_catalog.keys():
		var ref: Dictionary = _llm_action_catalog.get(str(raw_key), {})
		if not _is_attack_action_ref(ref):
			continue
		if int(ref.get("attack_index", -1)) <= 0:
			continue
		if not _attack_has_real_damage(ref):
			continue
		if best.is_empty() or int(ref.get("attack_index", -1)) > int(best.get("attack_index", -1)):
			best = ref.duplicate(true)
			best["id"] = str(raw_key)
			best["action_id"] = str(raw_key)
	return best


func _attack_has_real_damage(action: Dictionary) -> bool:
	var attack_rules: Variant = action.get("attack_rules", {})
	if attack_rules is Dictionary:
		return str((attack_rules as Dictionary).get("damage", "")).strip_edges() != ""
	return str(action.get("attack_name", "")).strip_edges() != ""


func _repair_premature_short_routes_in_node(node: Dictionary) -> Dictionary:
	var result: Dictionary = node.duplicate(true)
	var added_count := 0
	var added_actions: Array[Dictionary] = []
	if result.has("actions"):
		var repaired_actions: Dictionary = _repair_premature_short_action_array(result.get("actions", []))
		result["actions"] = repaired_actions.get("actions", result.get("actions", []))
		added_count += int(repaired_actions.get("added_count", 0))
		added_actions.append_array(repaired_actions.get("added_actions", []))
	for branch_key: String in ["branches", "children"]:
		var raw_branches: Variant = result.get(branch_key, [])
		if not (raw_branches is Array):
			continue
		var repaired_branches: Array[Dictionary] = []
		for raw_branch: Variant in raw_branches:
			if not (raw_branch is Dictionary):
				continue
			var branch: Dictionary = (raw_branch as Dictionary).duplicate(true)
			if branch.has("actions"):
				var branch_actions: Dictionary = _repair_premature_short_action_array(branch.get("actions", []))
				branch["actions"] = branch_actions.get("actions", branch.get("actions", []))
				added_count += int(branch_actions.get("added_count", 0))
				added_actions.append_array(branch_actions.get("added_actions", []))
			var then_node: Variant = branch.get("then", {})
			if then_node is Dictionary:
				var then_repair: Dictionary = _repair_premature_short_routes_in_node(then_node as Dictionary)
				branch["then"] = then_repair.get("node", then_node)
				added_count += int(then_repair.get("added_count", 0))
				added_actions.append_array(then_repair.get("added_actions", []))
			repaired_branches.append(branch)
		result[branch_key] = repaired_branches
	return {"node": result, "added_count": added_count, "added_actions": added_actions}


func _repair_premature_short_action_array(raw_actions: Variant) -> Dictionary:
	if not (raw_actions is Array):
		return {"actions": [], "added_count": 0, "added_actions": []}
	var actions: Array[Dictionary] = []
	var non_terminal_count := 0
	var has_end_turn := false
	var has_attack := false
	var seen_ids: Dictionary = {}
	for raw_action: Variant in raw_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		actions.append(action)
		var action_type: String = str(action.get("type", action.get("kind", "")))
		var action_id: String = str(action.get("action_id", action.get("id", "")))
		if action_id != "":
			seen_ids[action_id] = true
		if action_type in ["attack", "granted_attack"]:
			has_attack = true
		if action_type == "end_turn" or action_id == "end_turn":
			has_end_turn = true
		else:
			non_terminal_count += 1
	if actions.is_empty() or not has_end_turn or has_attack or non_terminal_count > 1:
		var greninja_repair: Dictionary = _repair_missing_greninja_draw_before_end(actions, seen_ids, has_end_turn, has_attack)
		return {
			"actions": greninja_repair.get("actions", actions),
			"added_count": int(greninja_repair.get("added_count", 0)),
			"added_actions": greninja_repair.get("added_actions", []),
		}
	var result: Array[Dictionary] = []
	var added_actions: Array[Dictionary] = []
	var inserted := false
	for action: Dictionary in actions:
		var action_type: String = str(action.get("type", action.get("kind", "")))
		var action_id: String = str(action.get("action_id", action.get("id", "")))
		if not inserted and (action_type == "end_turn" or action_id == "end_turn"):
			var greninja_before := result.size()
			_append_greninja_ability(result, seen_ids, _greninja_interactions())
			if result.size() > greninja_before:
				added_actions.append_array(result.slice(greninja_before, result.size()))
			var before_size := result.size()
			_append_short_route_followups(result, seen_ids)
			if result.size() > before_size:
				added_actions.append_array(result.slice(before_size, result.size()))
			inserted = true
		result.append(action)
	return {
		"actions": result,
		"added_count": added_actions.size(),
		"added_actions": added_actions,
	}


func _repair_missing_greninja_draw_before_end(
	actions: Array[Dictionary],
	seen_ids: Dictionary,
	has_end_turn: bool,
	has_attack: bool
) -> Dictionary:
	if actions.is_empty() or not has_end_turn or has_attack:
		return {"actions": actions, "added_count": 0, "added_actions": []}
	if _queue_contains_greninja_ability(actions):
		return {"actions": actions, "added_count": 0, "added_actions": []}
	var result: Array[Dictionary] = []
	var added_actions: Array[Dictionary] = []
	var inserted := false
	for action: Dictionary in actions:
		var action_type: String = str(action.get("type", action.get("kind", "")))
		var action_id: String = str(action.get("action_id", action.get("id", "")))
		if not inserted and (action_type == "end_turn" or action_id == "end_turn"):
			var before_size := result.size()
			_append_greninja_ability(result, seen_ids, _greninja_interactions())
			if result.size() > before_size:
				added_actions.append_array(result.slice(before_size, result.size()))
			inserted = true
		result.append(action)
	return {
		"actions": result,
		"added_count": added_actions.size(),
		"added_actions": added_actions,
	}


func _repair_missing_survival_tools_in_tree(tree: Dictionary) -> Dictionary:
	if tree.is_empty() or _llm_action_catalog.is_empty():
		return {"tree": tree, "added_count": 0, "added_actions": []}
	var repair: Dictionary = _repair_missing_survival_tools_in_node(tree)
	return {
		"tree": repair.get("node", tree),
		"added_count": int(repair.get("added_count", 0)),
		"added_actions": repair.get("added_actions", []),
	}


func _repair_missing_productive_engine_in_tree(
	tree: Dictionary,
	game_state: GameState = null,
	player_index: int = -1
) -> Dictionary:
	if tree.is_empty() or _llm_action_catalog.is_empty():
		return {"tree": tree, "added_count": 0, "added_actions": []}
	var no_deck_draw_lock := _player_deck_count_for_llm(game_state, player_index) == 0
	var repair: Dictionary = _repair_missing_productive_engine_in_node(tree, no_deck_draw_lock)
	return {
		"tree": repair.get("node", tree),
		"added_count": int(repair.get("added_count", 0)),
		"added_actions": repair.get("added_actions", []),
	}


func _repair_missing_productive_engine_in_node(node: Dictionary, no_deck_draw_lock: bool = false) -> Dictionary:
	var result: Dictionary = node.duplicate(true)
	var added_count := 0
	var added_actions: Array[Dictionary] = []
	for key: String in ["actions", "fallback_actions", "fallback"]:
		if not result.has(key):
			continue
		var action_repair: Dictionary = _repair_missing_productive_engine_action_array(result.get(key, []), no_deck_draw_lock)
		result[key] = action_repair.get("actions", result.get(key, []))
		added_count += int(action_repair.get("added_count", 0))
		added_actions.append_array(action_repair.get("added_actions", []))
	for branch_key: String in ["branches", "children"]:
		var raw_branches: Variant = result.get(branch_key, [])
		if not (raw_branches is Array):
			continue
		var repaired_branches: Array[Dictionary] = []
		for raw_branch: Variant in raw_branches:
			if not (raw_branch is Dictionary):
				continue
			var branch: Dictionary = (raw_branch as Dictionary).duplicate(true)
			if branch.has("actions"):
				var branch_repair: Dictionary = _repair_missing_productive_engine_action_array(branch.get("actions", []), no_deck_draw_lock)
				branch["actions"] = branch_repair.get("actions", branch.get("actions", []))
				added_count += int(branch_repair.get("added_count", 0))
				added_actions.append_array(branch_repair.get("added_actions", []))
			var then_node: Variant = branch.get("then", {})
			if then_node is Dictionary:
				var then_repair: Dictionary = _repair_missing_productive_engine_in_node(then_node as Dictionary, no_deck_draw_lock)
				branch["then"] = then_repair.get("node", then_node)
				added_count += int(then_repair.get("added_count", 0))
				added_actions.append_array(then_repair.get("added_actions", []))
			if branch.has("fallback_actions"):
				var fallback_repair: Dictionary = _repair_missing_productive_engine_action_array(branch.get("fallback_actions", []), no_deck_draw_lock)
				branch["fallback_actions"] = fallback_repair.get("actions", branch.get("fallback_actions", []))
				added_count += int(fallback_repair.get("added_count", 0))
				added_actions.append_array(fallback_repair.get("added_actions", []))
			repaired_branches.append(branch)
		result[branch_key] = repaired_branches
	return {"node": result, "added_count": added_count, "added_actions": added_actions}


func _repair_missing_productive_engine_action_array(raw_actions: Variant, no_deck_draw_lock: bool = false) -> Dictionary:
	if not (raw_actions is Array):
		return {"actions": [], "added_count": 0, "added_actions": []}
	var actions: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var has_terminal := false
	var has_attack := false
	for raw_action: Variant in raw_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		actions.append(action)
		var action_id: String = _action_ref_id(action)
		if action_id != "":
			seen_ids[action_id] = true
		if _is_attack_action_ref(action):
			has_attack = true
			has_terminal = true
		elif _is_end_turn_action_ref(action):
			has_terminal = true
	if actions.is_empty() or not has_terminal:
		return {"actions": actions, "added_count": 0, "added_actions": []}
	var candidates: Array[Dictionary] = _productive_engine_candidates_for_route(actions, seen_ids, has_attack, no_deck_draw_lock)
	if candidates.is_empty():
		return {"actions": actions, "added_count": 0, "added_actions": []}
	var result: Array[Dictionary] = []
	var added_actions: Array[Dictionary] = []
	var inserted := false
	for action: Dictionary in actions:
		if not inserted and (_is_attack_action_ref(action) or _is_end_turn_action_ref(action)):
			for candidate: Dictionary in candidates:
				result.append(candidate)
				added_actions.append(candidate)
			inserted = true
		result.append(action)
	return {
		"actions": result,
		"added_count": added_actions.size(),
		"added_actions": added_actions,
	}


func _productive_engine_candidates_for_route(
	actions: Array[Dictionary],
	seen_ids: Dictionary,
	has_attack: bool,
	no_deck_draw_lock: bool = false
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if no_deck_draw_lock:
		return candidates
	var local_seen := seen_ids.duplicate(true)
	_append_catalog_match(candidates, local_seen, "use_ability", "", "Teal Mask Ogerpon ex", _ogerpon_interactions())
	if not has_attack:
		_append_catalog_match(candidates, local_seen, "play_trainer", "Trekking Shoes", "")
	var result: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		var candidate_id: String = _action_ref_id(candidate)
		if candidate_id == "" or bool(seen_ids.get(candidate_id, false)):
			continue
		if _candidate_conflicts_with_route(candidate, actions):
			continue
		result.append(candidate)
	return result


func _candidate_conflicts_with_route(candidate: Dictionary, actions: Array[Dictionary]) -> bool:
	var candidate_id: String = _action_ref_id(candidate)
	var candidate_conflicts: Array[String] = _resource_conflict_ids_for_action_ref(candidate)
	for action: Dictionary in actions:
		var action_id: String = _action_ref_id(action)
		if action_id == "":
			continue
		if candidate_conflicts.has(action_id):
			return true
		var action_conflicts: Array[String] = _resource_conflict_ids_for_action_ref(action)
		if candidate_id != "" and action_conflicts.has(candidate_id):
			return true
	return false


func _repair_missing_survival_tools_in_node(node: Dictionary) -> Dictionary:
	var result: Dictionary = node.duplicate(true)
	var added_count := 0
	var added_actions: Array[Dictionary] = []
	for key: String in ["actions", "fallback_actions", "fallback"]:
		if not result.has(key):
			continue
		var action_repair: Dictionary = _repair_missing_survival_tool_action_array(result.get(key, []))
		result[key] = action_repair.get("actions", result.get(key, []))
		added_count += int(action_repair.get("added_count", 0))
		added_actions.append_array(action_repair.get("added_actions", []))
	for branch_key: String in ["branches", "children"]:
		var raw_branches: Variant = result.get(branch_key, [])
		if not (raw_branches is Array):
			continue
		var repaired_branches: Array[Dictionary] = []
		for raw_branch: Variant in raw_branches:
			if not (raw_branch is Dictionary):
				continue
			var branch: Dictionary = (raw_branch as Dictionary).duplicate(true)
			if branch.has("actions"):
				var branch_repair: Dictionary = _repair_missing_survival_tool_action_array(branch.get("actions", []))
				branch["actions"] = branch_repair.get("actions", branch.get("actions", []))
				added_count += int(branch_repair.get("added_count", 0))
				added_actions.append_array(branch_repair.get("added_actions", []))
			var then_node: Variant = branch.get("then", {})
			if then_node is Dictionary:
				var then_repair: Dictionary = _repair_missing_survival_tools_in_node(then_node as Dictionary)
				branch["then"] = then_repair.get("node", then_node)
				added_count += int(then_repair.get("added_count", 0))
				added_actions.append_array(then_repair.get("added_actions", []))
			if branch.has("fallback_actions"):
				var fallback_repair: Dictionary = _repair_missing_survival_tool_action_array(branch.get("fallback_actions", []))
				branch["fallback_actions"] = fallback_repair.get("actions", branch.get("fallback_actions", []))
				added_count += int(fallback_repair.get("added_count", 0))
				added_actions.append_array(fallback_repair.get("added_actions", []))
			repaired_branches.append(branch)
		result[branch_key] = repaired_branches
	return {"node": result, "added_count": added_count, "added_actions": added_actions}


func _repair_missing_survival_tool_action_array(raw_actions: Variant) -> Dictionary:
	if not (raw_actions is Array):
		return {"actions": [], "added_count": 0, "added_actions": []}
	var actions: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var has_tool := false
	var has_terminal := false
	for raw_action: Variant in raw_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		actions.append(action)
		var action_id: String = _action_ref_id(action)
		if action_id != "":
			seen_ids[action_id] = true
		if str(action.get("type", action.get("kind", ""))) == "attach_tool":
			has_tool = true
		if _is_attack_action_ref(action) or _is_end_turn_action_ref(action):
			has_terminal = true
	if actions.is_empty() or has_tool or not has_terminal:
		return {"actions": actions, "added_count": 0, "added_actions": []}
	var tool_action: Dictionary = _best_survival_tool_action(seen_ids)
	if tool_action.is_empty():
		return {"actions": actions, "added_count": 0, "added_actions": []}
	var result: Array[Dictionary] = []
	var inserted := false
	for action: Dictionary in actions:
		if not inserted and (_is_attack_action_ref(action) or _is_end_turn_action_ref(action)):
			result.append(tool_action)
			inserted = true
		result.append(action)
	return {
		"actions": result,
		"added_count": 1 if inserted else 0,
		"added_actions": [tool_action] if inserted else [],
	}


func _repair_resource_conflicts_in_tree(tree: Dictionary) -> Dictionary:
	if tree.is_empty():
		return {"tree": tree, "removed_count": 0, "removed_actions": []}
	var repair: Dictionary = _repair_resource_conflicts_in_node(tree)
	return {
		"tree": repair.get("node", tree),
		"removed_count": int(repair.get("removed_count", 0)),
		"removed_actions": repair.get("removed_actions", []),
	}


func _repair_resource_conflicts_in_node(node: Dictionary) -> Dictionary:
	var result: Dictionary = node.duplicate(true)
	var removed_count := 0
	var removed_actions: Array[Dictionary] = []
	for key: String in ["actions", "fallback_actions", "fallback"]:
		if not result.has(key):
			continue
		var action_repair: Dictionary = _repair_resource_conflicts_action_array(result.get(key, []))
		result[key] = action_repair.get("actions", result.get(key, []))
		removed_count += int(action_repair.get("removed_count", 0))
		removed_actions.append_array(action_repair.get("removed_actions", []))
	for branch_key: String in ["branches", "children"]:
		var raw_branches: Variant = result.get(branch_key, [])
		if not (raw_branches is Array):
			continue
		var repaired_branches: Array[Dictionary] = []
		for raw_branch: Variant in raw_branches:
			if not (raw_branch is Dictionary):
				continue
			var branch: Dictionary = (raw_branch as Dictionary).duplicate(true)
			if branch.has("actions"):
				var branch_repair: Dictionary = _repair_resource_conflicts_action_array(branch.get("actions", []))
				branch["actions"] = branch_repair.get("actions", branch.get("actions", []))
				removed_count += int(branch_repair.get("removed_count", 0))
				removed_actions.append_array(branch_repair.get("removed_actions", []))
			var then_node: Variant = branch.get("then", {})
			if then_node is Dictionary:
				var then_repair: Dictionary = _repair_resource_conflicts_in_node(then_node as Dictionary)
				branch["then"] = then_repair.get("node", then_node)
				removed_count += int(then_repair.get("removed_count", 0))
				removed_actions.append_array(then_repair.get("removed_actions", []))
			if branch.has("fallback_actions"):
				var fallback_repair: Dictionary = _repair_resource_conflicts_action_array(branch.get("fallback_actions", []))
				branch["fallback_actions"] = fallback_repair.get("actions", branch.get("fallback_actions", []))
				removed_count += int(fallback_repair.get("removed_count", 0))
				removed_actions.append_array(fallback_repair.get("removed_actions", []))
			repaired_branches.append(branch)
		result[branch_key] = repaired_branches
	return {"node": result, "removed_count": removed_count, "removed_actions": removed_actions}


func _repair_resource_conflicts_action_array(raw_actions: Variant) -> Dictionary:
	if not (raw_actions is Array):
		return {"actions": [], "removed_count": 0, "removed_actions": []}
	var kept: Array[Dictionary] = []
	var kept_ids: Dictionary = {}
	var forbidden_later_ids: Dictionary = {}
	var removed: Array[Dictionary] = []
	for raw_action: Variant in raw_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		var action_id: String = _action_ref_id(action)
		var conflicts: Array[String] = _resource_conflict_ids_for_action_ref(action)
		var conflicts_with_kept := false
		if action_id != "" and bool(forbidden_later_ids.get(action_id, false)):
			conflicts_with_kept = true
		if not conflicts_with_kept:
			for conflict_id: String in conflicts:
				if bool(kept_ids.get(conflict_id, false)):
					conflicts_with_kept = true
					break
		if conflicts_with_kept:
			removed.append(action)
			continue
		kept.append(action)
		if action_id != "":
			kept_ids[action_id] = true
		for conflict_id: String in conflicts:
			if conflict_id != "":
				forbidden_later_ids[conflict_id] = true
	return {
		"actions": kept,
		"removed_count": removed.size(),
		"removed_actions": removed,
	}


func _enrich_sparse_tree_for_raging_bolt(tree: Dictionary) -> Dictionary:
	if not _is_sparse_tree(tree):
		return tree
	var attack_actions: Array[Dictionary] = _extract_attack_actions(tree)
	if attack_actions.is_empty():
		return tree
	var routes: Array[Dictionary] = []
	_append_route(routes, [{"fact": "active_attack_ready"}], _route_actions([
		"bench_ogerpon", "nest_ball", "tool", "earthen_vessel", "ogerpon_ability", "fezandipiti_ability", "trekking_shoes", "sada",
	], attack_actions))
	_append_route(routes, [{"fact": "hand_has_card", "card": "Nest Ball"}], _route_actions([
		"nest_ball", "tool", "ogerpon_ability", "earthen_vessel", "fezandipiti_ability",
	], attack_actions))
	_append_route(routes, [{"fact": "hand_has_card", "card": "Earthen Vessel"}], _route_actions([
		"earthen_vessel", "bench_ogerpon", "tool", "ogerpon_ability", "energy_retrieval", "night_stretcher",
	], attack_actions))
	_append_route(routes, [{"fact": "can_use_supporter"}, {"fact": "hand_has_card", "card": "Professor Sada's Vitality"}], _route_actions([
		"sada", "bench_ogerpon", "tool", "ogerpon_ability", "fezandipiti_ability",
	], attack_actions))
	_append_route(routes, [{"fact": "hand_has_card", "card": "Trekking Shoes"}], _route_actions([
		"trekking_shoes", "nest_ball", "tool", "earthen_vessel", "night_stretcher",
	], attack_actions))
	_append_route(routes, [{"fact": "has_bench_space"}], _route_actions([
		"bench_ogerpon", "bench_bolt", "nest_ball", "tool", "fezandipiti_ability",
	], attack_actions))
	_append_route(routes, [{"fact": "always"}], _route_actions([], attack_actions))
	var enriched := tree.duplicate(true)
	enriched["branches"] = routes
	enriched.erase("actions")
	enriched["fallback_actions"] = attack_actions
	return enriched


func _is_sparse_tree(tree: Dictionary) -> bool:
	var branch_count := 0
	var raw_branches: Variant = tree.get("branches", tree.get("children", []))
	if raw_branches is Array:
		branch_count = (raw_branches as Array).size()
	return branch_count < 5 or _count_tree_actions(tree, 0) <= 4


func _count_tree_actions(node: Dictionary, depth: int) -> int:
	if depth > 8:
		return 0
	var count := 0
	var raw_actions: Variant = node.get("actions", [])
	if raw_actions is Array:
		count += (raw_actions as Array).size()
	var raw_fallback: Variant = node.get("fallback_actions", node.get("fallback", []))
	if raw_fallback is Array:
		count += (raw_fallback as Array).size()
	var raw_branches: Variant = node.get("branches", node.get("children", []))
	if raw_branches is Array:
		for raw_branch: Variant in raw_branches:
			if not (raw_branch is Dictionary):
				continue
			var branch: Dictionary = raw_branch
			var branch_actions: Variant = branch.get("actions", [])
			if branch_actions is Array:
				count += (branch_actions as Array).size()
			var then_node: Variant = branch.get("then", {})
			if then_node is Dictionary:
				count += _count_tree_actions(then_node, depth + 1)
	return count


func _extract_attack_actions(tree: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_collect_attack_actions_from_array(tree.get("actions", []), result)
	_collect_attack_actions_from_array(tree.get("fallback_actions", tree.get("fallback", [])), result)
	var raw_branches: Variant = tree.get("branches", tree.get("children", []))
	if raw_branches is Array:
		for raw_branch: Variant in raw_branches:
			if not (raw_branch is Dictionary):
				continue
			var branch: Dictionary = raw_branch
			_collect_attack_actions_from_array(branch.get("actions", []), result)
			var then_node: Variant = branch.get("then", {})
			if then_node is Dictionary:
				result.append_array(_extract_attack_actions(then_node))
	return result


func _collect_attack_actions_from_array(raw_actions: Variant, result: Array[Dictionary]) -> void:
	if not (raw_actions is Array):
		return
	for raw: Variant in raw_actions:
		if not (raw is Dictionary):
			continue
		var action: Dictionary = raw
		if str(action.get("type", "")) in ["attack", "granted_attack"]:
			result.append(action)


func _append_route(routes: Array[Dictionary], when: Array, actions: Array[Dictionary]) -> void:
	if actions.is_empty():
		return
	routes.append({"when": when, "actions": actions})


func _route_actions(route_keys: Array[String], attack_actions: Array[Dictionary]) -> Array[Dictionary]:
	var seen_ids: Dictionary = {}
	var actions: Array[Dictionary] = []
	for route_key: String in route_keys:
		match route_key:
			"bench_ogerpon":
				_append_catalog_match(actions, seen_ids, "play_basic_to_bench", "Teal Mask Ogerpon ex", "")
			"bench_bolt":
				_append_catalog_match(actions, seen_ids, "play_basic_to_bench", "Raging Bolt ex", "")
			"nest_ball":
				_append_catalog_match(actions, seen_ids, "play_trainer", "Nest Ball", "", {
					"search_pokemon": {"prefer": ["Teal Mask Ogerpon ex", "Raging Bolt ex", "Radiant Greninja", "Squawkabilly ex"]},
				})
			"tool":
				_append_best_tool_action(actions, seen_ids)
			"earthen_vessel":
				_append_catalog_match(actions, seen_ids, "play_trainer", "Earthen Vessel", "", _earthen_vessel_interactions())
			"energy_retrieval":
				_append_catalog_match(actions, seen_ids, "play_trainer", "Energy Retrieval", "")
			"night_stretcher":
				_append_catalog_match(actions, seen_ids, "play_trainer", "Night Stretcher", "")
			"fezandipiti_ability":
				_append_fezandipiti_ability(actions, seen_ids)
			"ogerpon_ability":
				_append_catalog_match(actions, seen_ids, "use_ability", "", "Teal Mask Ogerpon ex", _ogerpon_interactions())
				_append_virtual_ogerpon_ability(actions, seen_ids)
			"trekking_shoes":
				_append_catalog_match(actions, seen_ids, "play_trainer", "Trekking Shoes", "")
			"sada":
				_append_catalog_match(actions, seen_ids, "play_trainer", "Professor Sada's Vitality", "")
	for attack: Dictionary in attack_actions:
		var action_id: String = str(attack.get("action_id", attack.get("id", "")))
		if action_id != "" and bool(seen_ids.get(action_id, false)):
			continue
		actions.append(attack)
		if action_id != "":
			seen_ids[action_id] = true
	return actions


func _augment_attack_first_tree_for_raging_bolt(tree: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	if tree.is_empty() or game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return tree
	if _llm_action_catalog.is_empty():
		return tree
	return _augment_attack_first_node(tree)


func _augment_attack_first_node(node: Dictionary) -> Dictionary:
	var result: Dictionary = node.duplicate(true)
	for key: String in ["actions", "fallback_actions", "fallback"]:
		if result.has(key):
			result[key] = _prepend_safe_pre_attack_actions(result.get(key, []))
	for branch_key: String in ["branches", "children"]:
		var raw_branches: Variant = result.get(branch_key, [])
		if not (raw_branches is Array):
			continue
		var branches: Array[Dictionary] = []
		for raw_branch: Variant in raw_branches:
			if not (raw_branch is Dictionary):
				continue
			var branch: Dictionary = (raw_branch as Dictionary).duplicate(true)
			if branch.has("actions"):
				branch["actions"] = _prepend_safe_pre_attack_actions(branch.get("actions", []))
			var then_node: Variant = branch.get("then", {})
			if then_node is Dictionary:
				branch["then"] = _augment_attack_first_node(then_node as Dictionary)
			if branch.has("fallback_actions"):
				branch["fallback_actions"] = _prepend_safe_pre_attack_actions(branch.get("fallback_actions", []))
			branches.append(branch)
		result[branch_key] = branches
	return result


func _prepend_safe_pre_attack_actions(raw_actions: Variant) -> Array[Dictionary]:
	if not (raw_actions is Array):
		return []
	var actions: Array[Dictionary] = []
	for raw: Variant in raw_actions:
		if raw is Dictionary:
			actions.append(raw)
	if not _starts_with_attack(actions):
		return actions
	var pre_actions: Array[Dictionary] = _safe_pre_attack_actions(actions)
	if pre_actions.is_empty():
		return actions
	var merged: Array[Dictionary] = []
	merged.append_array(pre_actions)
	merged.append_array(actions)
	return merged


func _starts_with_attack(actions: Array[Dictionary]) -> bool:
	for action: Dictionary in actions:
		var action_type: String = str(action.get("type", ""))
		if action_type == "end_turn":
			continue
		return action_type in ["attack", "granted_attack"]
	return false


func _safe_pre_attack_actions(existing_actions: Array[Dictionary]) -> Array[Dictionary]:
	var seen_ids: Dictionary = {}
	for action: Dictionary in existing_actions:
		var action_id: String = str(action.get("action_id", action.get("id", "")))
		if action_id != "":
			seen_ids[action_id] = true
	var candidates: Array[Dictionary] = []
	_append_catalog_match(candidates, seen_ids, "play_basic_to_bench", "Teal Mask Ogerpon ex", "")
	_append_catalog_match(candidates, seen_ids, "play_trainer", "Nest Ball", "", {
		"search_pokemon": {"prefer": ["Teal Mask Ogerpon ex", "Raging Bolt ex", "Radiant Greninja", "Squawkabilly ex"]},
	})
	_append_catalog_match(candidates, seen_ids, "play_basic_to_bench", "Raging Bolt ex", "")
	_append_best_tool_action(candidates, seen_ids)
	_append_catalog_match(candidates, seen_ids, "play_trainer", "Earthen Vessel", "", _earthen_vessel_interactions())
	_append_catalog_match(candidates, seen_ids, "use_ability", "", "Teal Mask Ogerpon ex", _ogerpon_interactions())
	_append_virtual_ogerpon_ability(candidates, seen_ids)
	_append_catalog_match(candidates, seen_ids, "play_trainer", "Trekking Shoes", "")
	_append_catalog_match(candidates, seen_ids, "play_trainer", "Professor Sada's Vitality", "")
	return candidates


func _append_catalog_match(
	target: Array[Dictionary],
	seen_ids: Dictionary,
	action_type: String,
	card_query: String,
	pokemon_query: String,
	interactions: Dictionary = {}
) -> void:
	if target.size() >= 8:
		return
	for raw_key: Variant in _llm_action_catalog.keys():
		var action_id: String = str(raw_key)
		if bool(seen_ids.get(action_id, false)):
			continue
		var ref: Dictionary = _llm_action_catalog.get(action_id, {})
		if str(ref.get("type", "")) != action_type:
			continue
		if card_query != "" and not _name_contains(str(ref.get("card", "")), card_query):
			continue
		if pokemon_query != "" and not _name_contains(str(ref.get("pokemon", "")), pokemon_query):
			continue
		var copy: Dictionary = ref.duplicate(true)
		copy["id"] = action_id
		copy["action_id"] = action_id
		if not interactions.is_empty():
			copy["interactions"] = interactions.duplicate(true)
		target.append(copy)
		seen_ids[action_id] = true
		return


func _append_best_tool_action(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	if target.size() >= 8:
		return
	var best_ref: Dictionary = {}
	var best_id := ""
	var best_score := -999999.0
	for raw_key: Variant in _llm_action_catalog.keys():
		var action_id: String = str(raw_key)
		if bool(seen_ids.get(action_id, false)):
			continue
		var ref: Dictionary = _llm_action_catalog.get(action_id, {})
		if str(ref.get("type", "")) != "attach_tool":
			continue
		var score := 0.0
		var card_name := str(ref.get("card", ""))
		var target_name := str(ref.get("target", ""))
		var position := str(ref.get("position", ""))
		if _name_contains(card_name, "Bravery Charm"):
			score += 1000.0
		if position == "active":
			score += 300.0
		if _name_contains(target_name, "Raging Bolt ex"):
			score += 200.0
		if _name_contains(target_name, "Teal Mask Ogerpon ex"):
			score += 100.0
		if score > best_score:
			best_score = score
			best_id = action_id
			best_ref = ref
	if best_id == "":
		return
	var copy: Dictionary = best_ref.duplicate(true)
	copy["id"] = best_id
	copy["action_id"] = best_id
	target.append(copy)
	seen_ids[best_id] = true


func _best_survival_tool_action(seen_ids: Dictionary) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_id := ""
	var best_score := -999999.0
	for raw_key: Variant in _llm_action_catalog.keys():
		var action_id: String = str(raw_key)
		if bool(seen_ids.get(action_id, false)):
			continue
		var ref: Dictionary = _llm_action_catalog.get(action_id, {})
		if str(ref.get("type", "")) != "attach_tool":
			continue
		if not _action_ref_has_tag(ref, "hp_boost"):
			continue
		var score := 0.0
		var position := str(ref.get("position", ""))
		var target_name := str(ref.get("target", ""))
		var card_name := str(ref.get("card", ""))
		if position == "active":
			score += 500.0
		if _name_contains(target_name, "Raging Bolt ex"):
			score += 250.0
		if _name_contains(target_name, "Teal Mask Ogerpon ex"):
			score += 150.0
		if _name_contains(card_name, "Bravery Charm"):
			score += 100.0
		if score > best_score:
			best_score = score
			best_id = action_id
			best_ref = ref
	if best_id == "":
		return {}
	var copy: Dictionary = best_ref.duplicate(true)
	copy["id"] = best_id
	copy["action_id"] = best_id
	return copy


func _action_ref_has_tag(ref: Dictionary, tag: String) -> bool:
	var tags: Array = []
	if ref.has("tags") and ref.get("tags", []) is Array:
		tags.append_array(ref.get("tags", []))
	var rules: Variant = ref.get("card_rules", {})
	if rules is Dictionary:
		var rule_tags: Variant = (rules as Dictionary).get("tags", [])
		if rule_tags is Array:
			tags.append_array(rule_tags)
	for raw_tag: Variant in tags:
		if str(raw_tag) == tag:
			return true
	return false


func _resource_conflict_ids_for_action_ref(action: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var raw_conflicts: Variant = action.get("resource_conflicts", [])
	if raw_conflicts is Array:
		for raw_conflict: Variant in raw_conflicts:
			var conflict_id := str(raw_conflict)
			if conflict_id != "" and not result.has(conflict_id):
				result.append(conflict_id)
	var action_id: String = _action_ref_id(action)
	if action_id != "" and _llm_action_catalog.has(action_id):
		var catalog_ref: Dictionary = _llm_action_catalog.get(action_id, {})
		var catalog_conflicts: Variant = catalog_ref.get("resource_conflicts", [])
		if catalog_conflicts is Array:
			for raw_conflict: Variant in catalog_conflicts:
				var conflict_id := str(raw_conflict)
				if conflict_id != "" and not result.has(conflict_id):
					result.append(conflict_id)
	return result


func _append_greninja_ability(target: Array[Dictionary], seen_ids: Dictionary, interactions: Dictionary = {}) -> void:
	if target.size() >= 8:
		return
	for raw_key: Variant in _llm_action_catalog.keys():
		var action_id: String = str(raw_key)
		if bool(seen_ids.get(action_id, false)):
			continue
		var ref: Dictionary = _llm_action_catalog.get(action_id, {})
		if not _is_greninja_ability_ref(ref):
			continue
		var copy: Dictionary = ref.duplicate(true)
		copy["id"] = action_id
		copy["action_id"] = action_id
		if not interactions.is_empty():
			copy["interactions"] = interactions.duplicate(true)
		target.append(copy)
		seen_ids[action_id] = true
		return


func _is_greninja_ability_ref(ref: Dictionary) -> bool:
	if str(ref.get("type", "")) != "use_ability" and str(ref.get("kind", "")) != "use_ability":
		return false
	if _name_contains(str(ref.get("pokemon", "")), "Radiant Greninja"):
		return true


	var card_rules: Variant = ref.get("card_rules", {})
	if card_rules is Dictionary:
		var rules: Dictionary = card_rules
		if _name_contains(str(rules.get("name", "")), "Radiant Greninja"):
			return true


		var tags: Variant = rules.get("tags", [])
		if tags is Array and (tags as Array).has("draw") and (tags as Array).has("discard"):
			return true
	return false


func _append_fezandipiti_ability(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	if target.size() >= 8:
		return
	for raw_key: Variant in _llm_action_catalog.keys():
		var action_id: String = str(raw_key)
		if bool(seen_ids.get(action_id, false)):
			continue
		var ref: Dictionary = _llm_action_catalog.get(action_id, {})
		if not _is_fezandipiti_ability_ref(ref):
			continue
		var copy: Dictionary = ref.duplicate(true)
		copy["id"] = action_id
		copy["action_id"] = action_id
		target.append(copy)
		seen_ids[action_id] = true
		return


func _is_fezandipiti_ability_ref(ref: Dictionary) -> bool:
	if str(ref.get("type", ref.get("kind", ""))) != "use_ability":
		return false
	if _name_contains(str(ref.get("pokemon", "")), "Fezandipiti"):
		return true
	var card_rules: Variant = ref.get("card_rules", {})
	if card_rules is Dictionary:
		var rules: Dictionary = card_rules
		if _name_contains(str(rules.get("name_en", "")), "Fezandipiti") or _name_contains(str(rules.get("name", "")), "Fezandipiti"):
			return true
		if str(rules.get("effect_id", "")) == "ab6c3357e2b8a8385a68da738f41e0c1":
			return true
	return false


func _earthen_vessel_interactions() -> Dictionary:
	return {
		"discard_cards": {"prefer": ["Basic Grass Energy", "Basic Lightning Energy", "Basic Fighting Energy"]},
		"discard_card": {"prefer": ["Basic Grass Energy", "Basic Lightning Energy", "Basic Fighting Energy"]},
		"search_energy": {"prefer": ["Basic Lightning Energy", "Basic Fighting Energy", "Basic Grass Energy"]},
	}


func _greninja_interactions() -> Dictionary:
	return {
		"discard_card": {"prefer": ["Basic Grass Energy", "Grass Energy", "Basic Lightning Energy", "Lightning Energy", "Basic Fighting Energy", "Fighting Energy"]},
		"discard_cards": {"prefer": ["Basic Grass Energy", "Grass Energy", "Basic Lightning Energy", "Lightning Energy", "Basic Fighting Energy", "Fighting Energy"]},
		"discard_energy": {"prefer": ["Basic Grass Energy", "Grass Energy", "Basic Lightning Energy", "Lightning Energy", "Basic Fighting Energy", "Fighting Energy"]},
	}


func _ogerpon_interactions() -> Dictionary:
	return {
		"basic_energy_from_hand": {"prefer": ["Basic Grass Energy", "Grass Energy"]},
		"energy_card": {"prefer": ["Basic Grass Energy", "Grass Energy"]},
	}


func _append_virtual_ogerpon_ability(target: Array[Dictionary], seen_ids: Dictionary) -> void:
	if target.size() >= 8:
		return
	if bool(seen_ids.get("virtual:teal_mask_ogerpon_ability", false)):
		return
	for action: Dictionary in target:
		if str(action.get("type", "")) == "use_ability" and _name_contains(str(action.get("pokemon", "")), "Teal Mask Ogerpon ex"):
			return
	target.append({
		"type": "use_ability",
		"pokemon": "Teal Mask Ogerpon ex",
		"action_id": "virtual:teal_mask_ogerpon_ability",
	})
	seen_ids["virtual:teal_mask_ogerpon_ability"] = true


func _sync_game_state_context(game_state: GameState, player_index: int = -1, reason: String = "") -> void:
	if game_state == null:
		return
	var current_id := int(game_state.get_instance_id())
	var current_turn := int(game_state.turn_number)
	if _llm_game_state_instance_id == -1:
		_llm_game_state_instance_id = current_id
		_llm_last_seen_turn_number = current_turn
		return
	var should_reset := false
	var reset_reason := reason
	if _llm_game_state_instance_id != current_id:
		should_reset = true
		reset_reason = "%s:game_state_instance_changed" % reason
	elif _llm_last_seen_turn_number >= 0 and current_turn < _llm_last_seen_turn_number:
		should_reset = true
		reset_reason = "%s:turn_number_rollback" % reason
	if not should_reset:
		if current_turn > _llm_last_seen_turn_number:
			_llm_last_seen_turn_number = current_turn
		return
	var previous_id := _llm_game_state_instance_id
	var previous_turn := _llm_last_seen_turn_number
	_reset_llm_match_state()
	_llm_game_state_instance_id = current_id
	_llm_last_seen_turn_number = current_turn
	_audit_log("match_context_reset", {
		"turn": int(game_state.turn_number),
		"player_index": player_index,
		"reason": reset_reason,
		"previous_game_state_instance_id": previous_id,
		"current_game_state_instance_id": current_id,
		"previous_turn_number": previous_turn,
		"current_turn_number": current_turn,
	})


func _reset_llm_match_state() -> void:
	_cached_turn_number = -1
	_llm_pending = false
	_llm_request_attempt_turn = -1
	_llm_request_turn = -1
	_llm_request_started_msec = 0
	_last_llm_reasoning = ""
	_last_llm_error = ""
	_llm_decision_tree.clear()
	_llm_action_queue.clear()
	_llm_queue_turn = -1
	_llm_action_catalog.clear()
	_llm_route_candidates_by_id.clear()
	_llm_disabled_turns.clear()
	_llm_last_seen_turn_number = -1
	_llm_completed_queue_turns.clear()
	_llm_consumed_actions_by_turn.clear()
	_llm_replan_counts.clear()
	_llm_replan_context_by_turn.clear()
	_llm_replan_eligible_after_reject.clear()
	_llm_route_compiler_results_by_turn.clear()
	_fast_choice_pending = false
	_fast_choice_request_key = ""
	_fast_choice_cache.clear()
	_fast_choice_failed_keys.clear()
	_logged_queue_score_matches.clear()


func _should_skip_llm_for_local_rules(
	game_state: GameState,
	player_index: int,
	legal_actions: Array
) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return true
	if legal_actions.is_empty():
		return false
	var productive: Array[Dictionary] = []
	var has_attack := false
	var has_supporter := false
	var has_ability := false
	var has_interactive_trainer := false
	var has_setup_or_resource := false
	for raw_action: Variant in legal_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		var kind: String = str(action.get("kind", ""))
		if kind == "end_turn":
			continue
		productive.append(action)
		if kind in ["attack", "granted_attack"]:
			has_attack = true
		elif kind == "use_ability":
			has_ability = true
		elif kind == "play_trainer":
			if bool(action.get("requires_interaction", false)):
				has_interactive_trainer = true
			var card: Variant = action.get("card")
			if card is CardInstance and (card as CardInstance).card_data != null:
				var cd: CardData = (card as CardInstance).card_data
				if str(cd.card_type) == "Supporter":
					has_supporter = true
				if _name_contains(str(cd.name_en), "Earthen Vessel") \
						or _name_contains(str(cd.name_en), "Nest Ball") \
						or _name_contains(str(cd.name_en), "Trekking Shoes") \
						or _name_contains(str(cd.name_en), "Pokegear") \
						or _name_contains(str(cd.name_en), "Energy Retrieval"):
					has_setup_or_resource = true
		elif kind in ["attach_energy", "attach_tool", "play_basic_to_bench", "retreat"]:
			has_setup_or_resource = true
	if productive.size() <= 1:
		return not (has_attack or has_supporter or has_ability or has_interactive_trainer)
	if has_attack or has_supporter or has_ability or has_interactive_trainer or has_setup_or_resource:
		return false
	return false


func _llm_local_skip_reason(game_state: GameState, player_index: int, legal_actions: Array) -> String:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return "invalid_game_state"
	var productive_count := 0
	var productive_kinds: Array[String] = []
	for raw_action: Variant in legal_actions:
		if not (raw_action is Dictionary):
			continue
		var kind: String = str((raw_action as Dictionary).get("kind", ""))
		if kind == "end_turn":
			continue
		productive_count += 1
		if not productive_kinds.has(kind):
			productive_kinds.append(kind)
	return "local_rules_skip productive_count=%d kinds=%s" % [productive_count, ",".join(productive_kinds)]


func _log_llm_request_skip(turn: int, player_index: int, reason: String, legal_actions: Array = []) -> void:
	_audit_log("request_skipped", {
		"turn": turn,
		"player_index": player_index,
		"reason": reason,
		"legal_action_count": legal_actions.size(),
		"legal_action_summary": _compact_legal_action_summary(legal_actions),
	})


func _compact_legal_action_summary(legal_actions: Array, limit: int = 20) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_action: Variant in legal_actions:
		if result.size() >= limit:
			break
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		var row := {
			"kind": str(action.get("kind", "")),
		}
		var card: Variant = action.get("card")
		if card is CardInstance and (card as CardInstance).card_data != null:
			row["card"] = str((card as CardInstance).card_data.name_en)
		if action.has("attack_index"):
			row["attack_index"] = int(action.get("attack_index", -1))
		if action.has("ability_index"):
			row["ability_index"] = int(action.get("ability_index", -1))
		if action.has("requires_interaction"):
			row["requires_interaction"] = bool(action.get("requires_interaction", false))
		result.append(row)
	return result


func _select_llm_prompt_actions(
	legal_actions: Array,
	game_state: GameState,
	player_index: int
) -> Array:
	var scored: Array[Dictionary] = []
	for raw_action: Variant in legal_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		var kind: String = str(action.get("kind", ""))
		var score: float = 0.0
		if kind == "end_turn":
			score = -1000.0
		else:
			score = super.score_action_absolute(action, game_state, player_index)
			if kind in ["attack", "granted_attack"]:
				score += 300.0
			elif kind in ["play_trainer", "use_ability", "retreat"]:
				score += 120.0
			elif kind in ["attach_energy", "play_basic_to_bench", "attach_tool"]:
				score += 40.0
		scored.append({"action": action, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var result: Array = []
	var seen_action_ids: Dictionary = {}
	var seen_hand_cards: Dictionary = {}
	for entry: Dictionary in scored:
		var action: Dictionary = entry.get("action", {})
		if not _is_hand_visibility_action(action):
			continue
		var hand_key: String = _hand_action_visibility_key(action)
		if hand_key == "" or bool(seen_hand_cards.get(hand_key, false)):
			continue
		if _append_prompt_action(result, seen_action_ids, action, game_state, player_index):
			seen_hand_cards[hand_key] = true
		if result.size() >= LLM_PROMPT_HAND_ACTION_LIMIT:
			break
	for entry: Dictionary in scored:
		var action: Dictionary = entry.get("action", {})
		var kind: String = str(action.get("kind", ""))
		if kind == "end_turn":
			continue
		_append_prompt_action(result, seen_action_ids, action, game_state, player_index)
		if result.size() >= LLM_PROMPT_ACTION_LIMIT:
			break
	for entry: Dictionary in scored:
		var action: Dictionary = entry.get("action", {})
		if str(action.get("kind", "")) == "end_turn":
			result.append(action)
			break
	return result


func _append_prompt_action(
	result: Array,
	seen_action_ids: Dictionary,
	action: Dictionary,
	game_state: GameState,
	player_index: int
) -> bool:
	var action_id: String = _action_id_for_action(action, game_state, player_index)
	if action_id == "" or bool(seen_action_ids.get(action_id, false)):
		return false
	seen_action_ids[action_id] = true
	result.append(action)
	return true


func _is_hand_visibility_action(action: Dictionary) -> bool:
	var kind: String = str(action.get("kind", ""))
	return kind in ["play_trainer", "play_stadium", "play_basic_to_bench", "attach_tool", "evolve"]


func _hand_action_visibility_key(action: Dictionary) -> String:
	var card: Variant = action.get("card")
	if card is CardInstance and (card as CardInstance).card_data != null:
		return "%s:%s" % [str(action.get("kind", "")), str((card as CardInstance).card_data.name_en)]
	return ""


func _disable_llm_for_turn(turn: int, reason: String = "") -> void:
	_llm_disabled_turns[turn] = true
	_llm_pending = false
	_llm_request_turn = -1
	_llm_request_started_msec = 0
	_last_llm_error = reason
	_llm_decision_tree.clear()
	_llm_action_queue.clear()
	_llm_action_catalog.clear()
	_llm_route_candidates_by_id.clear()
	_llm_queue_turn = -1
	_llm_completed_queue_turns.clear()
	_llm_consumed_actions_by_turn.erase(turn)
	_llm_route_compiler_results_by_turn.erase(turn)
	_last_llm_reasoning = reason
	_audit_log("turn_disabled", {
		"turn": turn,
		"reason": reason,
	})


func _clear_rejected_llm_plan_for_turn(turn: int, reason: String = "") -> void:
	_llm_pending = false
	_llm_request_turn = -1
	_llm_request_started_msec = 0
	_last_llm_error = reason
	_llm_decision_tree.clear()
	_llm_action_queue.clear()
	_llm_action_catalog.clear()
	_llm_route_candidates_by_id.clear()
	_llm_queue_turn = -1
	_llm_completed_queue_turns.erase(turn)
	_llm_consumed_actions_by_turn.erase(turn)
	_llm_route_compiler_results_by_turn.erase(turn)
	_last_llm_reasoning = reason
	_llm_replan_eligible_after_reject[turn] = true
	_audit_log("turn_plan_rejected_without_disable", {
		"turn": turn,
		"reason": reason,
	})


func _audit_log(event_type: String, data: Dictionary = {}) -> void:
	if _audit_logger == null:
		return
	var payload := data.duplicate(true)
	payload["strategy_id"] = get_strategy_id()
	_audit_logger.call("log_event", event_type, payload)


func _fire_llm_request(game_state: GameState, player_index: int, legal_actions: Array = []) -> void:
	if _llm_host_node == null or not is_instance_valid(_llm_host_node):
		var turn_no_host := int(game_state.turn_number) if game_state != null else -1
		_log_llm_request_skip(turn_no_host, player_index, "missing_llm_host_node", legal_actions)
		return
	var game_manager: Variant = AutoloadResolverScript.get_game_manager()
	if game_manager == null:
		var turn_no_manager := int(game_state.turn_number) if game_state != null else -1
		_log_llm_request_skip(turn_no_manager, player_index, "missing_game_manager", legal_actions)
		return
	var api_config: Dictionary = game_manager.call("get_battle_review_api_config")
	var endpoint: String = str(api_config.get("endpoint", ""))
	var api_key: String = str(api_config.get("api_key", ""))
	if endpoint == "" or api_key == "":
		var turn_no_config := int(game_state.turn_number) if game_state != null else -1
		_log_llm_request_skip(turn_no_config, player_index, "missing_llm_api_config", legal_actions)
		return
	var prompt_actions: Array = _select_llm_prompt_actions(legal_actions, game_state, player_index)
	if prompt_actions.is_empty():
		_llm_skip_count += 1
		var turn_empty_actions := int(game_state.turn_number) if game_state != null else -1
		_log_llm_request_skip(turn_empty_actions, player_index, "empty_prompt_actions", legal_actions)
		return
	_llm_pending = true
	_llm_request_count += 1
	_configure_prompt_builder(game_state, player_index)
	_llm_action_catalog = _build_action_catalog(prompt_actions, game_state, player_index)
	var payload: Dictionary = _prompt_builder.call("build_action_id_request_payload", game_state, player_index, prompt_actions)
	_merge_payload_action_refs_into_catalog(payload)
	_register_payload_candidate_routes(payload)
	payload["model"] = str(api_config.get("model", ""))
	var turn_at_request: int = int(game_state.turn_number)
	if _llm_replan_context_by_turn.has(turn_at_request):
		payload["replan_context"] = _llm_replan_context_by_turn.get(turn_at_request, {})
	_llm_soft_timeout_seconds = maxf(float(api_config.get("timeout_seconds", 60.0)), 0.0)
	_client.set_timeout_seconds(_llm_soft_timeout_seconds)
	_llm_request_turn = turn_at_request
	_llm_request_started_msec = Time.get_ticks_msec()
	_audit_log("request_fired", {
		"turn": turn_at_request,
		"player_index": player_index,
		"model": str(payload.get("model", "")),
		"timeout_seconds": _llm_soft_timeout_seconds,
		"legal_actions": _audit_logger.call("compact_action_catalog", _llm_action_catalog) if _audit_logger != null else _llm_action_catalog,
		"legal_action_groups": payload.get("legal_action_groups", {}),
		"candidate_routes": payload.get("candidate_routes", []),
		"decision_tree_contract": payload.get("decision_tree_contract", {}),
		"replan_context": payload.get("replan_context", {}),
		"game_state": payload.get("game_state", {}),
	})
	llm_thinking_started.emit(turn_at_request)
	var err: int = _client.request_json(
		_llm_host_node,
		endpoint,
		api_key,
		payload,
		_on_llm_response.bind(turn_at_request, game_state, player_index)
	)
	if err != OK:
		_llm_fail_count += 1
		_disable_llm_for_turn(turn_at_request, "request start failed")
		var reason := "鐠囬攱鐪伴崣鎴︹偓浣搞亼鐠? error=%d" % err
		_audit_log("request_start_failed", {
			"turn": turn_at_request,
			"player_index": player_index,
			"reason": reason,
			"error": err,
		})
		llm_thinking_failed.emit(turn_at_request, reason)


func _fire_fast_choice_request(prompt_kind: String, game_state: GameState, player_index: int, key: String) -> void:
	if _llm_host_node == null or not is_instance_valid(_llm_host_node):
		return
	var game_manager: Variant = AutoloadResolverScript.get_game_manager()
	if game_manager == null:
		return
	var api_config: Dictionary = game_manager.call("get_battle_review_api_config")
	var endpoint: String = str(api_config.get("endpoint", ""))
	var api_key: String = str(api_config.get("api_key", ""))
	if endpoint == "" or api_key == "":
		return
	var candidates := _fast_choice_candidates(prompt_kind, game_state, player_index)
	if candidates.is_empty():
		return
	_configure_prompt_builder(game_state, player_index)
	var payload: Dictionary = _prompt_builder.call("build_fast_choice_payload", game_state, player_index, prompt_kind, candidates)
	payload["model"] = str(api_config.get("model", ""))
	_client.set_timeout_seconds(minf(float(api_config.get("timeout_seconds", 30.0)), 4.0))
	_fast_choice_pending = true
	_fast_choice_request_key = key
	var turn_at_request: int = int(game_state.turn_number)
	_audit_log("fast_choice_request_fired", {
		"turn": turn_at_request,
		"player_index": player_index,
		"prompt_kind": prompt_kind,
		"model": str(payload.get("model", "")),
		"candidates": candidates,
	})
	llm_thinking_started.emit(turn_at_request)
	var err: int = _client.request_json(
		_llm_host_node,
		endpoint,
		api_key,
		payload,
		_on_fast_choice_response.bind(key, prompt_kind, turn_at_request)
	)
	if err != OK:
		_fast_choice_pending = false
		_fast_choice_request_key = ""
		_fast_choice_failed_keys[key] = true
		llm_thinking_failed.emit(turn_at_request, "fast choice request failed error=%d" % err)


func _on_fast_choice_response(response: Dictionary, key: String, prompt_kind: String, turn_at_request: int) -> void:
	_fast_choice_pending = false
	_fast_choice_request_key = ""
	if String(response.get("status", "")) == "error":
		_fast_choice_failed_keys[key] = true
		_audit_log("fast_choice_failed", {
			"turn": turn_at_request,
			"prompt_kind": prompt_kind,
			"response": response,
		})
		llm_thinking_failed.emit(turn_at_request, "fast choice failed: %s" % str(response.get("message", "unknown")))
		return
	var choice: Dictionary = _prompt_builder.call("parse_fast_choice_response", response)
	if int(choice.get("selected_index", -1)) < 0:
		_fast_choice_failed_keys[key] = true
		_audit_log("fast_choice_failed", {
			"turn": turn_at_request,
			"prompt_kind": prompt_kind,
			"response": response,
			"parsed_choice": choice,
			"reason": "missing selected_index",
		})
		llm_thinking_failed.emit(turn_at_request, "fast choice missing selected_index")
		return
	_fast_choice_cache[key] = choice
	_audit_log("fast_choice_finished", {
		"turn": turn_at_request,
		"prompt_kind": prompt_kind,
		"response": response,
		"parsed_choice": choice,
	})
	llm_thinking_finished.emit(turn_at_request, {"fast_choice": choice, "prompt_kind": prompt_kind}, str(choice.get("reasoning", "")))


func _on_llm_response(
	response: Dictionary,
	turn_at_request: int,
	game_state: GameState = null,
	player_index: int = -1
) -> void:
	_llm_pending = false
	_llm_request_turn = -1
	_llm_request_started_msec = 0
	_audit_log("response_received", {
		"turn": turn_at_request,
		"player_index": player_index,
		"response": response,
	})
	if is_llm_disabled_for_turn(turn_at_request):
		return
	var decision_tree: Dictionary = {}
	var reasoning: String = str(response.get("reasoning", ""))
	if String(response.get("status", "")) == "error":
		var reason := str(response.get("message", "unknown"))
		decision_tree = _candidate_route_fallback_tree() if turn_at_request == _cached_turn_number else {}
		if decision_tree.is_empty():
			_llm_fail_count += 1
			_audit_log("response_error", {
				"turn": turn_at_request,
				"player_index": player_index,
				"reason": reason,
				"response": response,
			})
			_disable_llm_for_turn(turn_at_request, reason)
			llm_thinking_failed.emit(turn_at_request, reason)
			return
		reasoning = "candidate route fallback after response error: %s" % reason
		_audit_log("candidate_route_fallback", {
			"turn": turn_at_request,
			"player_index": player_index,
			"reason": reason,
			"fallback_tree": decision_tree,
		})
	else:
		decision_tree = _prompt_builder.parse_llm_response_to_decision_tree(response)
	if decision_tree.is_empty():
		_llm_fail_count += 1
		_disable_llm_for_turn(turn_at_request, "invalid or missing decision tree")
		var reason := "閺冪姵纭剁憴锝嗙€介崘宕囩摜閺? %s" % str(response.get("error_type", response.keys()))
		llm_thinking_failed.emit(turn_at_request, reason)
		return
	_last_llm_reasoning = reasoning
	if turn_at_request == _cached_turn_number:
		if not _llm_action_catalog.is_empty():
			var contract_check: Dictionary = _validate_decision_tree_contract(decision_tree)
			if not bool(contract_check.get("valid", false)):
				var sanitize_check: Dictionary = _sanitize_decision_tree_contract(decision_tree)
				if bool(sanitize_check.get("valid", false)):
					var pruned_errors_text := PackedStringArray()
					for error: Variant in sanitize_check.get("pruned_errors", []):
						pruned_errors_text.append(str(error))
					_audit_log("contract_pruned", {
						"turn": turn_at_request,
						"player_index": player_index,
						"pruned_count": int(sanitize_check.get("pruned_count", 0)),
						"repaired_count": int(sanitize_check.get("repaired_count", 0)),
						"pruned_errors": Array(pruned_errors_text),
						"repair_notes": sanitize_check.get("repair_notes", []),
						"raw_decision_tree": decision_tree,
						"sanitized_decision_tree": sanitize_check.get("tree", {}),
					})
					decision_tree = sanitize_check.get("tree", {})
				else:
					var errors: Array = contract_check.get("errors", [])
					var error_text := PackedStringArray()
					for error: Variant in errors:
						error_text.append(str(error))
					var reason := "invalid decision tree contract: %s" % "; ".join(error_text)
					var fallback_tree := _candidate_route_fallback_tree()
					if not fallback_tree.is_empty():
						_audit_log("candidate_route_fallback", {
							"turn": turn_at_request,
							"player_index": player_index,
							"reason": reason,
							"errors": Array(error_text),
							"raw_decision_tree": decision_tree,
							"fallback_tree": fallback_tree,
						})
						decision_tree = fallback_tree
						reasoning = "candidate route fallback after contract rejection"
					else:
						_llm_fail_count += 1
						_audit_log("contract_rejected", {
							"turn": turn_at_request,
							"player_index": player_index,
							"errors": Array(error_text),
							"raw_decision_tree": decision_tree,
							"sanitized_errors": sanitize_check.get("errors", []),
							"pruned_errors": sanitize_check.get("pruned_errors", []),
						})
						_clear_rejected_llm_plan_for_turn(turn_at_request, reason)
						llm_thinking_failed.emit(turn_at_request, reason)
						return
		decision_tree = _materialize_action_refs_in_tree(decision_tree)
		decision_tree = _enrich_sparse_tree_for_raging_bolt(decision_tree)
		decision_tree = _augment_attack_first_tree_for_raging_bolt(decision_tree, game_state, player_index)
		var terminal_attack_repair: Dictionary = _repair_terminal_attack_routes_in_tree(decision_tree)
		if int(terminal_attack_repair.get("changed_count", 0)) > 0:
			decision_tree = terminal_attack_repair.get("tree", decision_tree)
			_audit_log("contract_repaired", {
				"turn": turn_at_request,
				"player_index": player_index,
				"reason": "normalized terminal attack routes",
				"changed_count": int(terminal_attack_repair.get("changed_count", 0)),
				"repair_notes": terminal_attack_repair.get("repair_notes", []),
			})
		var engine_repair: Dictionary = _repair_missing_productive_engine_in_tree(decision_tree, game_state, player_index)
		if int(engine_repair.get("added_count", 0)) > 0:
			decision_tree = engine_repair.get("tree", decision_tree)
			_audit_log("contract_repaired", {
				"turn": turn_at_request,
				"player_index": player_index,
				"reason": "inserted non-conflicting productive engine before terminal action",
				"added_count": int(engine_repair.get("added_count", 0)),
				"added_actions": _audit_logger.call("compact_actions", engine_repair.get("added_actions", [])) if _audit_logger != null else engine_repair.get("added_actions", []),
			})
		var short_route_repair: Dictionary = _repair_premature_short_routes_in_tree(decision_tree)
		if int(short_route_repair.get("added_count", 0)) > 0:
			decision_tree = short_route_repair.get("tree", decision_tree)
			_audit_log("contract_repaired", {
				"turn": turn_at_request,
				"player_index": player_index,
				"reason": "expanded premature short route before explicit end_turn",
				"added_count": int(short_route_repair.get("added_count", 0)),
				"added_actions": _audit_logger.call("compact_actions", short_route_repair.get("added_actions", [])) if _audit_logger != null else short_route_repair.get("added_actions", []),
			})
		var survival_tool_repair: Dictionary = _repair_missing_survival_tools_in_tree(decision_tree)
		if int(survival_tool_repair.get("added_count", 0)) > 0:
			decision_tree = survival_tool_repair.get("tree", decision_tree)
			_audit_log("contract_repaired", {
				"turn": turn_at_request,
				"player_index": player_index,
				"reason": "inserted legal survival tool before terminal action",
				"added_count": int(survival_tool_repair.get("added_count", 0)),
				"added_actions": _audit_logger.call("compact_actions", survival_tool_repair.get("added_actions", [])) if _audit_logger != null else survival_tool_repair.get("added_actions", []),
			})
		var resource_repair: Dictionary = _repair_resource_conflicts_in_tree(decision_tree)
		if int(resource_repair.get("removed_count", 0)) > 0:
			decision_tree = resource_repair.get("tree", decision_tree)
			_audit_log("contract_repaired", {
				"turn": turn_at_request,
				"player_index": player_index,
				"reason": "removed post-processed resource-conflicting actions",
				"removed_count": int(resource_repair.get("removed_count", 0)),
				"removed_actions": _audit_logger.call("compact_actions", resource_repair.get("removed_actions", [])) if _audit_logger != null else resource_repair.get("removed_actions", []),
			})
		_llm_decision_tree = decision_tree
		_llm_action_queue.clear()
		_llm_queue_turn = turn_at_request
		_llm_completed_queue_turns.erase(turn_at_request)
		var selected_queue: Array[Dictionary] = []
		if game_state != null and player_index >= 0:
			selected_queue = _select_current_action_queue(game_state, player_index)
			if selected_queue.is_empty():
				_llm_fail_count += 1
				_audit_log("empty_selected_queue", {
					"turn": turn_at_request,
					"player_index": player_index,
					"decision_tree": decision_tree,
				})
				_disable_llm_for_turn(turn_at_request, "empty selected queue")
				llm_thinking_failed.emit(turn_at_request, "decision tree selected no executable actions; fallback to rules")
				return
		_llm_success_count += 1
		_last_llm_error = ""
		var plan := {
			"decision_tree": decision_tree,
			"action_queue": selected_queue,
			"reasoning": reasoning,
		}
		_audit_log("plan_selected", {
			"turn": turn_at_request,
			"player_index": player_index,
			"reasoning": reasoning,
			"decision_tree": decision_tree,
			"action_queue": _audit_logger.call("compact_actions", selected_queue) if _audit_logger != null else selected_queue,
		})
		llm_thinking_finished.emit(turn_at_request, plan, reasoning)
	else:
		_disable_llm_for_turn(turn_at_request, "stale response")
		_audit_log("stale_response", {
			"turn": turn_at_request,
			"current_turn": _cached_turn_number,
			"player_index": player_index,
		})
		llm_thinking_failed.emit(turn_at_request, "Turn %d response is stale; current turn is %d" % [turn_at_request, _cached_turn_number])


func get_llm_stats() -> Dictionary:
	return {
		"requests": _llm_request_count,
		"successes": _llm_success_count,
		"failures": _llm_fail_count,
		"skipped_by_local_rules": _llm_skip_count,
		"replans_this_turn": int(_llm_replan_counts.get(_cached_turn_number, 0)),
		"last_error": _last_llm_error,
	}


func get_llm_replan_count() -> int:
	return int(_llm_replan_counts.get(_cached_turn_number, 0))


func get_llm_action_queue() -> Array[Dictionary]:
	return _llm_action_queue.duplicate(true)


func get_llm_decision_tree() -> Dictionary:
	return _llm_decision_tree.duplicate(true)


func _raging_bolt_setup_role_hint(cd: CardData) -> String:
	if cd == null:
		return ""
	if _name_contains(str(cd.name_en), "Raging Bolt ex") or _name_contains(str(cd.name), "Raging Bolt"):
		return "main_attacker"
	if _name_contains(str(cd.name_en), "Teal Mask Ogerpon ex"):
		return "energy_engine"
	if _name_contains(str(cd.name_en), "Radiant Greninja"):
		return "draw_engine"
	if _name_contains(str(cd.name_en), "Squawkabilly ex"):
		return "opening_draw_support"
	return "support"


func _raging_bolt_strategy_prompt(game_state: GameState, player_index: int) -> PackedStringArray:
	var attack_name: String = _active_bolt_burst_attack_name(game_state, player_index)
	var active_position_hint: String = _active_position_hint(game_state, player_index)
	var strategy_text: String = get_deck_strategy_text()
	if strategy_text.strip_edges() == "":
		strategy_text = _default_raging_bolt_strategy_text()
	var lines: Array[String] = [
		"【卡组打法思路】以下内容来自卡组编辑器的“打法思路”；玩家可以编辑它来调整这套猛雷鼓 AI 的战术偏好。",
	]
	lines.append_array(_strategy_text_to_prompt_lines(strategy_text, 18))
	lines.append("【当前场面提示】%s。如果前场猛雷鼓ex的爆发招式已经满足条件，攻击名必须复制为「%s」；除非没有拿奖压力或稳定展开路线，否则不要优先使用弃手牌抽牌的一技能。" % [active_position_hint, attack_name])
	lines.append("【执行边界】具体每张牌怎么结算，以 legal_actions、card_rules、interaction_hints 为准；打法思路只决定战术优先级，不允许编造动作 id、卡名、攻击名或交互字段。")
	lines.append("【决策树形状】优先给出能拿奖/高压、铺场后攻击、检索/蓄能后攻击、换位后攻击、下回合准备、保手牌兜底这些路线；能攻击时攻击必须放在路线末尾，不能用 end_turn 代替。")
	return PackedStringArray(lines)


func _strategy_text_to_prompt_lines(strategy_text: String, max_lines: int) -> Array[String]:
	var result: Array[String] = []
	for raw_line: String in strategy_text.split("\n", false):
		var line := raw_line.strip_edges()
		if line == "":
			continue
		result.append(line)
		if result.size() >= max_lines:
			break
	return result


func _default_raging_bolt_strategy_text() -> String:
	return "\n".join([
		"【卡组定位】猛雷鼓ex/厄诡椪·碧草面具ex高速爆发卡组。核心目标是让猛雷鼓ex满足【雷】【斗】攻击费用，并把我方场上的基本能量转化为「极雷轰」伤害。",
		"【核心计划】猛雷鼓ex是主要攻击手。「极雷轰」将我方场上任意数量基本能量放弃，造成70×张数伤害。3能量=210，4能量=280，5能量=350。",
		"厄诡椪·碧草面具ex负责把手牌草能贴到自己身上并抽1张，既增加场上能量数量，也不占用手动贴能。",
		"奥琳博士的气魄负责把弃牌区基本能量贴给古代宝可梦并抽牌，优先让猛雷鼓ex补齐雷+斗攻击费用或增加斩杀能量。",
		"大地容器、能量回收、夜晚担架等资源牌围绕缺失能量服务，优先找雷/斗满足攻击，再考虑草能供厄诡椪继续蓄力。",
		"勇气护符优先给前场或即将上前的基础攻击手，帮助猛雷鼓ex或厄诡椪ex多扛一击。",
		"【回合优先级】能拿奖或形成高压时，先做不影响攻击的安全铺场、贴工具、厄诡椪特性、奥琳/检索/手贴，然后用猛雷鼓ex攻击。",
		"打不出攻击时，目标是保留下回合资源：铺第二只猛雷鼓/厄诡椪，准备雷+斗，增加场上基本能量，不要无意义打空手牌。",
		"如果当前攻击已经足够击倒，不要继续过度抽滤或消耗手牌；停止挖牌并攻击。",
		"攻击会结束回合，所有想做的铺场、检索、贴能、贴工具、切换都必须放在攻击前。",
	])


func _active_bolt_burst_attack_name(game_state: GameState, player_index: int) -> String:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return "<copy from active.attacks>"
	var player: PlayerState = game_state.players[player_index]
	var active: PokemonSlot = player.active_pokemon
	if active == null or active.get_card_data() == null:
		return "<copy from active.attacks>"
	if not _name_contains(str(active.get_card_data().name_en), "Raging Bolt ex") and not _name_contains(str(active.get_card_data().name), "Raging Bolt"):
		return "<copy from active.attacks>"
	var attacks: Array = active.get_card_data().attacks
	if attacks.size() >= 2:
		return str((attacks[1] as Dictionary).get("name", ""))
	if attacks.size() == 1:
		return str((attacks[0] as Dictionary).get("name", ""))
	return "<copy from active.attacks>"


func _active_position_hint(game_state: GameState, player_index: int) -> String:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return "unknown"
	var player: PlayerState = game_state.players[player_index]
	if player.active_pokemon == null:
		return "no active Pokemon"
	return "active is %s at position active" % str(player.active_pokemon.get_pokemon_name())
