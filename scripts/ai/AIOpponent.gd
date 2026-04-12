class_name AIOpponent
extends RefCounted

const AISetupPlannerScript = preload("res://scripts/ai/AISetupPlanner.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const AIFeatureExtractorScript = preload("res://scripts/ai/AIFeatureExtractor.gd")
const AIStepResolverScript = preload("res://scripts/ai/AIStepResolver.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")
const AIDecisionTraceScript = preload("res://scripts/ai/AIDecisionTrace.gd")
const MCTSPlannerScript = preload("res://scripts/ai/MCTSPlanner.gd")
const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")
const AIActionScorerScript = preload("res://scripts/ai/AIActionScorer.gd")
const AIInteractionScorerScript = preload("res://scripts/ai/AIInteractionScorer.gd")
const AutoloadResolverScript = preload("res://scripts/engine/AutoloadResolver.gd")
const DeckStrategyGardevoirScript = preload("res://scripts/ai/DeckStrategyGardevoir.gd")
const DeckStrategyMiraidonScript = preload("res://scripts/ai/DeckStrategyMiraidon.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const ACTION_SCORER_SUPPORTED_KINDS := {
	"play_trainer": true,
	"play_stadium": true,
	"play_basic_to_bench": true,
	"evolve": true,
	"use_ability": true,
	"attach_tool": true,
	"attach_energy": true,
	"retreat": true,
	"attack": true,
	"granted_attack": true,
	"end_turn": true,
}
var player_index: int = 1
var difficulty: int = 1
var heuristic_weights: Dictionary = {}
var value_net_path: String = ""
var action_scorer_path: String = ""
var interaction_scorer_path: String = ""
var _value_net: RefCounted = null
var _action_scorer: RefCounted = null
var _interaction_scorer: RefCounted = null
var _setup_planner = AISetupPlannerScript.new()
var _legal_action_builder = AILegalActionBuilderScript.new()
var _feature_extractor = AIFeatureExtractorScript.new()
var _step_resolver = AIStepResolverScript.new()
var _heuristics = AIHeuristicsScript.new()
var _planned_setup_bench_ids: Array[int] = []
var _last_legal_actions: Array[Dictionary] = []
var _last_decision_trace = null
var use_mcts: bool = false
var mcts_config: Dictionary = {}
var _mcts_planner = MCTSPlannerScript.new()
var _mcts_planned_sequence: Array = []
var _mcts_sequence_index: int = 0
var _event_counters: Dictionary = {}
var _deck_strategy = null
var _deck_strategy_detected: bool = false
var _deck_strategy_registry = DeckStrategyRegistryScript.new()
var _decision_exporter = null


func configure(next_player_index: int, next_difficulty: int) -> void:
	player_index = next_player_index
	difficulty = next_difficulty


func set_deck_strategy(strategy: RefCounted) -> void:
	_deck_strategy = strategy
	_deck_strategy_detected = strategy != null
	if _step_resolver != null and _step_resolver.has_method("set_deck_strategy"):
		_step_resolver.set_deck_strategy(strategy)
	elif _step_resolver != null:
		_step_resolver.deck_strategy = strategy
	if _legal_action_builder != null and _legal_action_builder.has_method("set_deck_strategy"):
		_legal_action_builder.set_deck_strategy(strategy)
	elif _legal_action_builder != null:
		_legal_action_builder._deck_strategy = strategy
		_legal_action_builder._deck_strategy_detected = strategy != null
	if _heuristics != null:
		_heuristics.deck_strategy = strategy
	if _mcts_planner != null:
		_mcts_planner.deck_strategy = strategy
		_mcts_planner.state_encoder_class = _get_state_encoder_class()
	if _step_resolver != null:
		_step_resolver.interaction_scorer = _interaction_scorer
		_step_resolver.decision_exporter = _decision_exporter


func _get_state_encoder_class():
	if _deck_strategy != null and _deck_strategy.has_method("get_state_encoder_class"):
		var encoder_class = _deck_strategy.get_state_encoder_class()
		if encoder_class != null:
			return encoder_class
	return StateEncoderScript


func _encode_state_features(game_state: GameState) -> Array:
	if game_state == null:
		return []
	var encoder_class = _get_state_encoder_class()
	if encoder_class != null and encoder_class.has_method("encode"):
		var encoded: Variant = encoder_class.call("encode", game_state, player_index)
		if encoded is Array:
			return (encoded as Array).duplicate(true)
	return StateEncoderScript.encode(game_state, player_index)


func _ensure_action_scorer_loaded() -> void:
	if _action_scorer != null or action_scorer_path == "":
		return
	_action_scorer = AIActionScorerScript.new()
	if not _action_scorer.load_weights(action_scorer_path):
		push_warning("[AIOpponent] 无法加载动作评分器: %s" % action_scorer_path)
		_action_scorer = null


func _ensure_interaction_scorer_loaded() -> void:
	if _interaction_scorer != null or interaction_scorer_path == "":
		return
	_interaction_scorer = AIInteractionScorerScript.new()
	if not _interaction_scorer.load_weights(interaction_scorer_path):
		push_warning("[AIOpponent] 无法加载交互评分器: %s" % interaction_scorer_path)
		_interaction_scorer = null
	if _step_resolver != null:
		_step_resolver.interaction_scorer = _interaction_scorer


func set_decision_exporter(exporter) -> void:
	_decision_exporter = exporter
	if _step_resolver != null:
		_step_resolver.decision_exporter = exporter


func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
	if game_state == null or ui_blocked:
		return false
	return game_state.current_player_index == player_index


func get_legal_actions(gsm: GameStateMachine) -> Array[Dictionary]:
	if gsm == null:
		_last_legal_actions.clear()
		return []
	_last_legal_actions = _legal_action_builder.build_actions(gsm, player_index)
	return _last_legal_actions.duplicate()


func get_last_decision_trace():
	if _last_decision_trace == null:
		return null
	return _last_decision_trace.clone()


func get_event_counters() -> Dictionary:
	return _event_counters.duplicate(true)


func run_single_step(battle_scene: Control, gsm: GameStateMachine) -> bool:
	if battle_scene == null or gsm == null or gsm.game_state == null:
		return false
	var pending_choice := str(battle_scene.get("_pending_choice"))
	var bridge_handles_prompts: bool = battle_scene.has_method("handles_bridge_owned_prompts") and bool(battle_scene.call("handles_bridge_owned_prompts"))
	if pending_choice == "mulligan_extra_draw":
		if bridge_handles_prompts and _is_bridge_owned_prompt(pending_choice):
			return false
		var dialog_data: Dictionary = battle_scene.get("_dialog_data")
		var beneficiary: int = int(dialog_data.get("beneficiary", -1))
		if beneficiary != player_index:
			return false
		_clear_consumed_prompt(battle_scene)
		gsm.resolve_mulligan_choice(beneficiary, _setup_planner.choose_mulligan_bonus_draw())
		return true
	if pending_choice == "take_prize":
		if bridge_handles_prompts and _is_bridge_owned_prompt(pending_choice):
			return false
		return _run_take_prize_step(battle_scene, gsm)
	if pending_choice == "heavy_baton_target":
		return _run_heavy_baton_step(battle_scene, gsm)
	if pending_choice == "send_out":
		if bridge_handles_prompts and _is_bridge_owned_prompt(pending_choice):
			return false
		return _run_send_out_step(battle_scene, gsm)
	if pending_choice.begins_with("setup_active_"):
		if bridge_handles_prompts and _is_bridge_owned_prompt(pending_choice):
			return false
		_clear_consumed_prompt(battle_scene)
		return _run_setup_active_step(battle_scene, gsm, pending_choice)
	if pending_choice.begins_with("setup_bench_"):
		if bridge_handles_prompts and _is_bridge_owned_prompt(pending_choice):
			return false
		var dialog_data: Dictionary = battle_scene.get("_dialog_data")
		_clear_consumed_prompt(battle_scene)
		return _run_setup_bench_step(battle_scene, gsm, pending_choice, dialog_data)
	if pending_choice == "effect_interaction":
		_ensure_interaction_scorer_loaded()
		if _step_resolver != null:
			_step_resolver.interaction_scorer = _interaction_scorer
			_step_resolver.decision_exporter = _decision_exporter
		return _step_resolver.resolve_pending_step(
			battle_scene,
			gsm,
			player_index,
			_encode_state_features(gsm.game_state)
		)
	var action := _choose_best_action(gsm)
	if action.is_empty():
		return false
	return _execute_action(battle_scene, gsm, action)


func _is_bridge_owned_prompt(pending_choice: String) -> bool:
	return pending_choice == "mulligan_extra_draw" \
		or pending_choice == "take_prize" \
		or pending_choice == "send_out" \
		or pending_choice.begins_with("setup_active_") \
		or pending_choice.begins_with("setup_bench_")


func _run_setup_active_step(battle_scene: Control, gsm: GameStateMachine, pending_choice: String) -> bool:
	var pi: int = int(pending_choice.split("_")[-1])
	if pi != player_index or pi >= gsm.game_state.players.size():
		return false
	var player: PlayerState = gsm.game_state.players[pi]
	_detect_and_load_deck_strategy(player)
	var choice: Dictionary
	if _deck_strategy != null and _deck_strategy.has_method("plan_opening_setup"):
		choice = _deck_strategy.plan_opening_setup(player)
	else:
		choice = _setup_planner.plan_opening_setup(player)
	var active_hand_index: int = int(choice.get("active_hand_index", -1))
	if active_hand_index < 0 or active_hand_index >= player.hand.size():
		return false
	_planned_setup_bench_ids.clear()
	for hand_index: int in choice.get("bench_hand_indices", []):
		if hand_index >= 0 and hand_index < player.hand.size():
			_planned_setup_bench_ids.append(player.hand[hand_index].instance_id)
	var active_card: CardInstance = player.hand[active_hand_index]
	if not gsm.setup_place_active_pokemon(pi, active_card):
		return false
	if battle_scene.has_method("_after_setup_active"):
		battle_scene.call("_after_setup_active", pi)
	_request_followup_ai_step_if_ready(battle_scene, gsm)
	return true


func _run_setup_bench_step(
	battle_scene: Control,
	gsm: GameStateMachine,
	pending_choice: String,
	dialog_data: Dictionary
) -> bool:
	var pi: int = int(pending_choice.split("_")[-1])
	if pi != player_index or pi >= gsm.game_state.players.size():
		return false
	var player: PlayerState = gsm.game_state.players[pi]
	var cards_raw: Array = dialog_data.get("cards", [])
	var available_cards: Array[CardInstance] = []
	for card_variant: Variant in cards_raw:
		if card_variant is CardInstance:
			available_cards.append(card_variant)
	var planned_card := _find_next_planned_bench_card(player, available_cards)
	if planned_card == null:
		if battle_scene.has_method("_after_setup_bench"):
			battle_scene.call("_after_setup_bench", pi)
		_request_followup_ai_step_if_ready(battle_scene, gsm)
		return true
	if not gsm.setup_place_bench_pokemon(pi, planned_card):
		return false
	_planned_setup_bench_ids.erase(planned_card.instance_id)
	if battle_scene.has_method("_refresh_ui"):
		battle_scene.call("_refresh_ui")
	if battle_scene.has_method("_show_setup_bench_dialog"):
		battle_scene.call("_show_setup_bench_dialog", pi)
	return true


func _request_followup_ai_step_if_ready(battle_scene: Control, gsm: GameStateMachine) -> void:
	if battle_scene == null or gsm == null or gsm.game_state == null:
		return
	if str(battle_scene.get("_pending_choice")) != "":
		return
	if gsm.game_state.current_player_index != player_index:
		return
	if gsm.game_state.phase == GameState.GamePhase.SETUP:
		return
	if not bool(battle_scene.get("_ai_step_scheduled")):
		battle_scene.set("_ai_step_scheduled", true)
		battle_scene.call_deferred("_run_ai_step")


func _find_next_planned_bench_card(player: PlayerState, available_cards: Array[CardInstance]) -> CardInstance:
	if _planned_setup_bench_ids.is_empty():
		var fallback_choice: Dictionary = _setup_planner.plan_opening_setup(player)
		for hand_index: int in fallback_choice.get("bench_hand_indices", []):
			if hand_index >= 0 and hand_index < player.hand.size():
				_planned_setup_bench_ids.append(player.hand[hand_index].instance_id)
		if _planned_setup_bench_ids.is_empty() and not player.hand.is_empty():
			var active_hand_index: int = int(fallback_choice.get("active_hand_index", -1))
			if active_hand_index >= 0 and active_hand_index < player.hand.size():
				_planned_setup_bench_ids.append(player.hand[active_hand_index].instance_id)
	for planned_id: int in _planned_setup_bench_ids:
		for card: CardInstance in available_cards:
			if card.instance_id == planned_id:
				return card
	return null


func _choose_best_action(gsm: GameStateMachine) -> Dictionary:
	## 优先级 1：MCTS + 策略评估（v8）
	if _deck_strategy != null and use_mcts:
		return _choose_mcts_action(gsm)
	## 优先级 2：贪心策略（v7.2）
	if _deck_strategy != null and _deck_strategy.has_method("score_action_absolute"):
		var result: Dictionary = _choose_greedy_strategy_action(gsm)
		if not result.is_empty():
			return result
	## 优先级 3：纯 MCTS（rollout）
	if use_mcts:
		return _choose_mcts_action(gsm)
	## 优先级 4：启发式
	return _choose_heuristic_action(gsm)
	## 同步权重到 heuristics
	_heuristics.weights = heuristic_weights
	## 原有 heuristic 逻辑
	var actions: Array[Dictionary] = get_legal_actions(gsm)
	var trace = AIDecisionTraceScript.new()
	trace.turn_number = int(gsm.game_state.turn_number) if gsm != null and gsm.game_state != null else -1
	trace.phase = str(gsm.game_state.phase) if gsm != null and gsm.game_state != null else ""
	trace.player_index = player_index
	trace.state_features = _encode_state_features(gsm.game_state if gsm != null else null)
	trace.used_mcts = false
	trace.legal_actions = actions.duplicate(true)
	if actions.is_empty():
		_last_decision_trace = trace
		return {}
	var best_action: Dictionary = {}
	var best_score := -INF
	var best_scored_action: Dictionary = {}
	for action: Dictionary in actions:
		var scored_action: Dictionary = _augment_action_for_scoring(gsm, action)
		var score_context := {
			"gsm": gsm,
			"game_state": gsm.game_state,
			"player_index": player_index,
			"action": scored_action,
			"features": _feature_extractor.build_context(gsm, player_index, scored_action),
		}
		var score: float = _heuristics.score_action(scored_action, score_context)
		var trace_scored_action: Dictionary = scored_action.duplicate(true)
		trace_scored_action["score"] = score
		trace_scored_action["features"] = score_context["features"].duplicate(true)
		trace.scored_actions.append(trace_scored_action)
		if best_action.is_empty() or score > best_score:
			best_action = action
			best_score = score
			best_scored_action = trace_scored_action
	trace.chosen_action = best_scored_action.duplicate(true)
	if best_scored_action.has("reason_tags") and best_scored_action.get("reason_tags") is Array:
		for tag_variant: Variant in best_scored_action.get("reason_tags", []):
			trace.reason_tags.append(str(tag_variant))
	if trace.reason_tags.is_empty() and trace.chosen_action.has("reason_tags") and trace.chosen_action.get("reason_tags") is Array:
		for tag_variant: Variant in trace.chosen_action.get("reason_tags", []):
			trace.reason_tags.append(str(tag_variant))
	_last_decision_trace = trace
	return best_action


func _augment_action_for_scoring(gsm: GameStateMachine, action: Dictionary) -> Dictionary:
	var scored_action: Dictionary = action.duplicate(true)
	match str(action.get("kind", "")):
		"attack":
			var attack_index: int = int(action.get("attack_index", -1))
			var damage: int = gsm.get_attack_preview_damage(player_index, attack_index)
			scored_action["projected_damage"] = damage
			var opponent_index: int = 1 - player_index
			if opponent_index >= 0 and opponent_index < gsm.game_state.players.size():
				var defender: PokemonSlot = gsm.game_state.players[opponent_index].active_pokemon
				if defender != null:
					scored_action["projected_knockout"] = damage >= defender.get_remaining_hp()
		"attach_energy":
			var player: PlayerState = gsm.game_state.players[player_index]
			scored_action["is_active_target"] = action.get("target_slot") == player.active_pokemon
		"play_trainer", "play_stadium", "use_ability", "evolve", "retreat", "play_basic_to_bench", "attach_tool":
			scored_action["productive"] = true
	return scored_action


func _build_trace_scored_actions(gsm: GameStateMachine, actions: Array[Dictionary]) -> Array[Dictionary]:
	_heuristics.weights = heuristic_weights
	var state_features: Array = _encode_state_features(gsm.game_state if gsm != null else null)
	var scored_actions: Array[Dictionary] = []
	var teacher_estimates: Array[Dictionary] = []
	if _should_collect_action_teachers():
		teacher_estimates = _estimate_action_teachers(gsm, actions)
	for action: Dictionary in actions:
		var scored_action: Dictionary = _augment_action_for_scoring(gsm, action)
		var score_context := {
			"gsm": gsm,
			"game_state": gsm.game_state,
			"player_index": player_index,
			"action": scored_action,
			"features": _feature_extractor.build_context(gsm, player_index, scored_action),
		}
		var heuristic_score: float = _heuristics.score_action(scored_action, score_context)
		var learned_action_score: float = _score_action_with_action_scorer(str(scored_action.get("kind", "")), state_features, score_context["features"])
		var score: float = heuristic_score + learned_action_score
		score_context["features"]["heuristic_score"] = heuristic_score
		score_context["features"]["learned_action_score"] = learned_action_score
		var trace_scored_action: Dictionary = scored_action.duplicate(true)
		trace_scored_action["score"] = score
		trace_scored_action["heuristic_score"] = heuristic_score
		trace_scored_action["learned_action_score"] = learned_action_score
		trace_scored_action["features"] = score_context["features"].duplicate(true)
		scored_actions.append(trace_scored_action)
	_annotate_scored_actions_with_teacher(scored_actions, teacher_estimates)
	return scored_actions


func _score_action_with_action_scorer(action_kind: String, state_features: Array, features: Dictionary) -> float:
	if not ACTION_SCORER_SUPPORTED_KINDS.has(action_kind):
		return 0.0
	var action_vector_variant: Variant = features.get("action_vector", [])
	if not (action_vector_variant is Array) or (action_vector_variant as Array).is_empty():
		return 0.0
	_ensure_action_scorer_loaded()
	if _action_scorer == null or not _action_scorer.has_method("score_delta"):
		return 0.0
	return float(_action_scorer.call("score_delta", state_features, action_vector_variant, action_kind))


func _should_collect_action_teachers() -> bool:
	return _decision_exporter != null


func _estimate_action_teachers(gsm: GameStateMachine, actions: Array[Dictionary]) -> Array[Dictionary]:
	if gsm == null or gsm.game_state == null or _mcts_planner == null:
		return []
	_mcts_planner.deck_strategy = _deck_strategy
	_mcts_planner.value_net = _value_net
	_mcts_planner.state_encoder_class = _get_state_encoder_class()
	if not _mcts_planner.has_method("estimate_action_teachers"):
		return []
	return _mcts_planner.call("estimate_action_teachers", gsm, player_index, actions)


func _annotate_scored_actions_with_teacher(scored_actions: Array[Dictionary], teacher_estimates: Array[Dictionary]) -> void:
	if scored_actions.is_empty() or teacher_estimates.is_empty():
		return
	for index: int in mini(scored_actions.size(), teacher_estimates.size()):
		var estimate: Dictionary = teacher_estimates[index]
		if estimate.is_empty():
			continue
		scored_actions[index]["teacher_available"] = bool(estimate.get("available", false))
		scored_actions[index]["teacher_baseline_value"] = float(estimate.get("baseline_value", 0.5))
		if bool(estimate.get("available", false)):
			scored_actions[index]["teacher_post_value"] = float(estimate.get("post_value", 0.5))
			scored_actions[index]["teacher_value_delta"] = float(estimate.get("value_delta", 0.0))
			scored_actions[index]["teacher_game_over_after"] = bool(estimate.get("game_over_after", false))
			scored_actions[index]["teacher_turn_number_after"] = int(estimate.get("turn_number_after", -1))
			scored_actions[index]["teacher_current_player_after"] = int(estimate.get("current_player_after", -1))
		else:
			scored_actions[index]["teacher_reason"] = str(estimate.get("reason", ""))


func _record_decision_trace_from_choice(
	gsm: GameStateMachine,
	actions: Array[Dictionary],
	scored_actions: Array[Dictionary],
	chosen_action: Dictionary,
	used_mcts: bool
) -> void:
	var trace = AIDecisionTraceScript.new()
	trace.turn_number = int(gsm.game_state.turn_number) if gsm != null and gsm.game_state != null else -1
	trace.phase = str(gsm.game_state.phase) if gsm != null and gsm.game_state != null else ""
	trace.player_index = player_index
	trace.state_features = _encode_state_features(gsm.game_state if gsm != null else null)
	trace.used_mcts = used_mcts
	trace.legal_actions = actions.duplicate(true)
	trace.scored_actions = scored_actions.duplicate(true)
	var chosen_scored_action: Dictionary = _find_matching_scored_action(scored_actions, chosen_action)
	if chosen_scored_action.is_empty() and not chosen_action.is_empty():
		var fallback_action: Dictionary = _augment_action_for_scoring(gsm, chosen_action)
		var fallback_features: Dictionary = _feature_extractor.build_context(gsm, player_index, fallback_action)
		chosen_scored_action = fallback_action.duplicate(true)
		chosen_scored_action["features"] = fallback_features.duplicate(true)
		chosen_scored_action["score"] = float(fallback_features.get("heuristic_score", 0.0))
	trace.chosen_action = chosen_scored_action.duplicate(true)
	if chosen_scored_action.has("reason_tags") and chosen_scored_action.get("reason_tags") is Array:
		for tag_variant: Variant in chosen_scored_action.get("reason_tags", []):
			trace.reason_tags.append(str(tag_variant))
	if trace.reason_tags.is_empty() and trace.chosen_action.has("reason_tags") and trace.chosen_action.get("reason_tags") is Array:
		for tag_variant: Variant in trace.chosen_action.get("reason_tags", []):
			trace.reason_tags.append(str(tag_variant))
	_last_decision_trace = trace


func _find_matching_scored_action(scored_actions: Array[Dictionary], chosen_action: Dictionary) -> Dictionary:
	for scored_action: Dictionary in scored_actions:
		if _actions_equivalent(scored_action, chosen_action):
			return scored_action
	return {}


func _actions_equivalent(lhs: Dictionary, rhs: Dictionary) -> bool:
	if lhs.is_empty() or rhs.is_empty():
		return false
	if str(lhs.get("kind", "")) != str(rhs.get("kind", "")):
		return false
	if int(lhs.get("attack_index", -1)) != int(rhs.get("attack_index", -1)):
		return false
	if int(lhs.get("ability_index", -1)) != int(rhs.get("ability_index", -1)):
		return false
	if _extract_action_card_id(lhs.get("card", null)) != _extract_action_card_id(rhs.get("card", null)):
		return false
	if _extract_action_slot_card_id(lhs.get("target_slot", null)) != _extract_action_slot_card_id(rhs.get("target_slot", null)):
		return false
	if _extract_action_slot_card_id(lhs.get("source_slot", null)) != _extract_action_slot_card_id(rhs.get("source_slot", null)):
		return false
	if _extract_action_slot_card_id(lhs.get("bench_target", null)) != _extract_action_slot_card_id(rhs.get("bench_target", null)):
		return false
	return true


func _extract_action_card_id(card_variant: Variant) -> int:
	if card_variant is CardInstance:
		return int((card_variant as CardInstance).instance_id)
	return -1


func _extract_action_slot_card_id(slot_variant: Variant) -> int:
	if slot_variant is PokemonSlot:
		var top_card: CardInstance = (slot_variant as PokemonSlot).get_top_card()
		if top_card != null:
			return int(top_card.instance_id)
	return -1


func _execute_action(battle_scene: Control, gsm: GameStateMachine, action: Dictionary) -> bool:
	match str(action.get("kind", "")):
		"attach_energy":
			var target_slot: PokemonSlot = action.get("target_slot")
			var energy_card: CardInstance = action.get("card")
			if gsm.attach_energy(player_index, energy_card, target_slot):
				_after_successful_action(battle_scene)
				return true
		"attach_tool":
			var tool_target_slot: PokemonSlot = action.get("target_slot")
			var tool_card: CardInstance = action.get("card")
			if gsm.attach_tool(player_index, tool_card, tool_target_slot):
				_after_successful_action(battle_scene)
				return true
		"play_basic_to_bench":
			var basic_card: CardInstance = action.get("card")
			if battle_scene != null and battle_scene.has_method("_try_play_to_bench"):
				battle_scene.call("_try_play_to_bench", player_index, basic_card, "")
				return true
			if gsm.play_basic_to_bench(player_index, basic_card):
				_after_successful_action(battle_scene)
				return true
		"evolve":
			var evolution_card: CardInstance = action.get("card")
			var evolve_target: PokemonSlot = action.get("target_slot")
			if gsm.evolve_pokemon(player_index, evolution_card, evolve_target):
				if battle_scene != null and battle_scene.has_method("_refresh_ui"):
					battle_scene.call("_refresh_ui")
				if battle_scene != null and battle_scene.has_method("_try_start_evolve_trigger_ability_interaction"):
					battle_scene.call("_try_start_evolve_trigger_ability_interaction", player_index, evolve_target)
				if battle_scene != null and battle_scene.has_method("_maybe_run_ai"):
					battle_scene.call("_maybe_run_ai")
				return true
		"play_trainer":
			if bool(action.get("requires_interaction", false)):
				if battle_scene != null and battle_scene.has_method("_try_play_trainer_with_interaction"):
					var trainer_result: Variant = battle_scene.call("_try_play_trainer_with_interaction", player_index, action.get("card"))
					return bool(trainer_result) if typeof(trainer_result) == TYPE_BOOL else true
				return false
			if gsm.play_trainer(player_index, action.get("card"), action.get("targets", [])):
				_after_successful_action(battle_scene)
				return true
		"play_stadium":
			if bool(action.get("requires_interaction", false)):
				if battle_scene != null and battle_scene.has_method("_try_play_stadium_with_interaction"):
					var stadium_result: Variant = battle_scene.call("_try_play_stadium_with_interaction", player_index, action.get("card"))
					return bool(stadium_result) if typeof(stadium_result) == TYPE_BOOL else true
				return false
			if gsm.play_stadium(player_index, action.get("card"), action.get("targets", [])):
				_after_successful_action(battle_scene)
				return true
		"use_ability":
			if bool(action.get("requires_interaction", false)):
				if battle_scene != null and battle_scene.has_method("_try_use_ability_with_interaction"):
					var ability_result: Variant = battle_scene.call(
						"_try_use_ability_with_interaction",
						player_index,
						action.get("source_slot"),
						int(action.get("ability_index", 0))
					)
					return bool(ability_result) if typeof(ability_result) == TYPE_BOOL else true
				return false
			if gsm.use_ability(player_index, action.get("source_slot"), int(action.get("ability_index", 0)), action.get("targets", [])):
				_after_successful_action(battle_scene, true)
				return true
		"retreat":
			if gsm.retreat(player_index, action.get("energy_to_discard", []), action.get("bench_target")):
				_after_successful_action(battle_scene)
				return true
		"attack":
			if bool(action.get("requires_interaction", false)):
				if battle_scene != null and battle_scene.has_method("_try_use_attack_with_interaction"):
					var player: PlayerState = gsm.game_state.players[player_index]
					var attack_result: Variant = battle_scene.call(
						"_try_use_attack_with_interaction",
						player_index,
						player.active_pokemon,
						int(action.get("attack_index", -1))
					)
					return bool(attack_result) if typeof(attack_result) == TYPE_BOOL else true
				return false
			if gsm.use_attack(player_index, int(action.get("attack_index", -1)), action.get("targets", [])):
				_after_successful_action(battle_scene, true)
				return true
		"granted_attack":
			var ga_data: Dictionary = action.get("granted_attack_data", {})
			var ga_slot: PokemonSlot = action.get("source_slot")
			if ga_slot == null:
				ga_slot = gsm.game_state.players[player_index].active_pokemon
			if bool(action.get("requires_interaction", false)):
				if battle_scene != null and battle_scene.has_method("_try_use_granted_attack_with_interaction"):
					var granted_result: Variant = battle_scene.call("_try_use_granted_attack_with_interaction", player_index, ga_slot, ga_data)
					return bool(granted_result) if typeof(granted_result) == TYPE_BOOL else true
				return false
			if gsm.use_granted_attack(player_index, ga_slot, ga_data, action.get("targets", [])):
				_after_successful_action(battle_scene, true)
				return true
		"end_turn":
			if battle_scene != null and battle_scene.has_method("_on_end_turn"):
				battle_scene.call("_on_end_turn")
				return true
			gsm.end_turn(player_index)
			return true
	return false


func _after_successful_action(battle_scene: Control, check_handover: bool = false) -> void:
	if battle_scene != null and battle_scene.has_method("_refresh_ui_after_successful_action"):
		battle_scene.call("_refresh_ui_after_successful_action", check_handover)


func _run_take_prize_step(battle_scene: Control, gsm: GameStateMachine) -> bool:
	var prize_player_index: int = int(battle_scene.get("_pending_prize_player_index"))
	if prize_player_index != player_index or gsm.game_state == null:
		return false
	var player: PlayerState = gsm.game_state.players[player_index]
	var prize_layout: Array = player.get_prize_layout()
	for slot_index: int in prize_layout.size():
		if player.get_prize_at_slot(slot_index) == null:
			continue
		var prizes_before: int = player.prizes.size()
		if battle_scene != null and battle_scene.has_method("_try_take_prize_from_slot"):
			battle_scene.call("_try_take_prize_from_slot", player_index, slot_index)
			if bool(battle_scene.get("_pending_prize_animating")):
				return true
			if player.prizes.size() < prizes_before:
				return true
		if gsm.resolve_take_prize(player_index, slot_index):
			_clear_consumed_prompt(battle_scene)
			battle_scene.set("_pending_prize_player_index", -1)
			battle_scene.set("_pending_prize_remaining", 0)
			if battle_scene != null and battle_scene.has_method("_refresh_ui"):
				battle_scene.call("_refresh_ui")
			return true
	return false


func _run_send_out_step(battle_scene: Control, gsm: GameStateMachine) -> bool:
	if battle_scene == null or gsm.game_state == null:
		return false
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var send_out_player_index: int = int(dialog_data.get("player", -1))
	if send_out_player_index != player_index or send_out_player_index >= gsm.game_state.players.size():
		return false
	var bench_raw: Array = dialog_data.get("bench", [])
	var bench_slots: Array[PokemonSlot] = []
	for slot_variant: Variant in bench_raw:
		if slot_variant is PokemonSlot:
			bench_slots.append(slot_variant)
	if bench_slots.is_empty():
		bench_slots = gsm.game_state.players[send_out_player_index].bench.duplicate()
	# 选最优后备宝可梦上前场：就绪攻击手 > 有能量的 > 其他
	var best_slot: PokemonSlot = _pick_best_send_out(bench_slots, gsm)
	if best_slot != null:
		if gsm.send_out_pokemon(send_out_player_index, best_slot):
			if str(battle_scene.get("_pending_choice")) == "send_out":
				_clear_consumed_prompt(battle_scene)
			var game_manager = AutoloadResolverScript.get_game_manager()
			if game_manager != null and game_manager.current_mode != game_manager.GameMode.VS_AI:
				battle_scene.set("_view_player", gsm.game_state.current_player_index)
			if battle_scene.has_method("_refresh_ui_after_successful_action"):
				battle_scene.call("_refresh_ui_after_successful_action", true)
			elif battle_scene.has_method("_refresh_ui"):
				battle_scene.call("_refresh_ui")
			return true
	# 兜底：按顺序尝试
	for bench_slot: PokemonSlot in bench_slots:
		if gsm.send_out_pokemon(send_out_player_index, bench_slot):
			if str(battle_scene.get("_pending_choice")) == "send_out":
				_clear_consumed_prompt(battle_scene)
			if battle_scene.has_method("_refresh_ui_after_successful_action"):
				battle_scene.call("_refresh_ui_after_successful_action", true)
			return true
	return false


func _run_heavy_baton_step(battle_scene: Control, gsm: GameStateMachine) -> bool:
	if battle_scene == null or gsm == null or gsm.game_state == null:
		return false
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var player_index_hb: int = int(dialog_data.get("player", -1))
	if player_index_hb != player_index or player_index_hb >= gsm.game_state.players.size():
		return false
	var bench_raw: Array = dialog_data.get("bench", [])
	var bench_slots: Array[PokemonSlot] = []
	for slot_variant: Variant in bench_raw:
		if slot_variant is PokemonSlot:
			bench_slots.append(slot_variant)
	if bench_slots.is_empty():
		return false
	var best_slot: PokemonSlot = _pick_best_send_out(bench_slots, gsm)
	if best_slot == null:
		best_slot = bench_slots[0]
	if str(battle_scene.get("_pending_choice")) == "heavy_baton_target":
		_clear_consumed_prompt(battle_scene)
	if gsm.resolve_heavy_baton_choice(player_index_hb, best_slot):
		if battle_scene.has_method("_refresh_ui_after_successful_action"):
			battle_scene.call("_refresh_ui_after_successful_action")
		elif battle_scene.has_method("_refresh_ui"):
			battle_scene.call("_refresh_ui")
		return true
	return false


func _pick_best_send_out(bench_slots: Array[PokemonSlot], gsm: GameStateMachine) -> PokemonSlot:
	## 选最优宝可梦上前场：有攻击力的攻击手 > 有能量的 > 引擎 > 辅助
	var best: PokemonSlot = null
	var best_score: float = -1.0
	for slot: PokemonSlot in bench_slots:
		if slot == null or slot.get_top_card() == null:
			continue
		var score: float = 0.0
		var name: String = slot.get_pokemon_name()
		# 攻击手有攻击力 → 最高优先
		if _deck_strategy != null and _deck_strategy.has_method("predict_attacker_damage"):
			var pred: Dictionary = _deck_strategy.predict_attacker_damage(slot)
			var dmg: int = int(pred.get("damage", 0))
			var can_atk: bool = bool(pred.get("can_attack", false))
			if dmg > 0 and can_atk:
				score = 500.0 + float(dmg)  # 攻击力越高越优先
			elif slot.attached_energy.size() >= 1:
				score = 200.0 + float(slot.attached_energy.size()) * 20.0
		elif slot.attached_energy.size() >= 1:
			score = 200.0 + float(slot.attached_energy.size()) * 20.0
		# 非攻击手基础分
		if score <= 0.0:
			# 控制型 > 引擎 > 辅助（不想把核心引擎放前场挨打）
			var cd: CardData = slot.get_card_data()
			if cd != null and (cd.mechanic == "ex" or cd.mechanic == "V"):
				score = 10.0  # ex/V 尽量不上前场（被击倒丢2张奖品）
			elif name == "钥圈儿" or name == "振翼发":
				score = 80.0  # 控制型可以挡
			else:
				score = 50.0  # 其他
		if score > best_score:
			best_score = score
			best = slot
	return best


func _clear_consumed_prompt(battle_scene: Control) -> void:
	if battle_scene == null:
		return
	battle_scene.set("_pending_choice", "")
	battle_scene.set("_dialog_data", {})


func _choose_mcts_action(gsm: GameStateMachine) -> Dictionary:
	## 加载价值网络（懒加载，只加载一次）
	if _value_net == null and value_net_path != "":
		_value_net = NeuralNetInferenceScript.new()
		if not _value_net.load_weights(value_net_path):
			push_warning("[AIOpponent] 无法加载价值网络: %s" % value_net_path)
			_value_net = null
	if _mcts_planner != null:
		_mcts_planner.value_net = _value_net
		_ensure_action_scorer_loaded()
		_mcts_planner.action_scorer = _action_scorer
		_mcts_planner.state_encoder_class = _get_state_encoder_class()
	## 如果还有预规划的序列动作，继续执行
	if _mcts_sequence_index < _mcts_planned_sequence.size():
		var planned_action: Dictionary = _mcts_planned_sequence[_mcts_sequence_index]
		var planned_kind: String = str(planned_action.get("kind", ""))

		## 核心修复：序列中的 end_turn 不直接执行，而是切换到 heuristic
		## 让 heuristic 处理交互式动作（道具/特性），只有 heuristic 也选 end_turn 才真正结束
		if planned_kind == "end_turn":
			_mcts_planned_sequence.clear()
			_mcts_sequence_index = 0
			var _mh := "[MCTS] 序列到达 end_turn，切换 heuristic 处理剩余动作"
			print(_mh)
			_mcts_log_to_file(_mh)
			return _choose_heuristic_action(gsm)

		_mcts_sequence_index += 1
		var resolved := _resolve_mcts_action(gsm, planned_action)
		if not resolved.is_empty():
			var _mc := "[MCTS] 续执行: %s (%d/%d)" % [str(resolved.get("kind", "")), _mcts_sequence_index, _mcts_planned_sequence.size()]
			print(_mc)
			_mcts_log_to_file(_mc)
			var continuation_actions: Array[Dictionary] = get_legal_actions(gsm)
			var continuation_scored_actions: Array[Dictionary] = _build_trace_scored_actions(gsm, continuation_actions)
			_record_decision_trace_from_choice(gsm, continuation_actions, continuation_scored_actions, resolved, true)
			return resolved
		## 解析失败，清空序列并回退到 heuristic
		var _mf := "[MCTS] 续解析失败步骤 %d: %s" % [_mcts_sequence_index, planned_kind]
		print(_mf)
		_mcts_log_to_file(_mf)
		_record_mcts_resolution_mismatch(planned_kind, gsm)
		_mcts_planned_sequence.clear()
		_mcts_sequence_index = 0
		return _choose_heuristic_action(gsm)

	## 否则规划新序列
	_mcts_planned_sequence = _mcts_planner.plan_turn(gsm, player_index, mcts_config)
	_merge_event_counters(_mcts_planner.get_execution_failure_diagnostics())
	_mcts_sequence_index = 0
	## 诊断输出
	var _dbg_kinds: Array[String] = []
	for _dbg_a: Dictionary in _mcts_planned_sequence:
		_dbg_kinds.append(str(_dbg_a.get("kind", "")))
	var _dbg_msg := "[MCTS] 规划序列: %s (%d步)" % [", ".join(_dbg_kinds), _mcts_planned_sequence.size()]
	print(_dbg_msg)
	_mcts_log_to_file(_dbg_msg)
	if _mcts_planned_sequence.is_empty():
		return _choose_heuristic_action(gsm)
	var planned_action: Dictionary = _mcts_planned_sequence[_mcts_sequence_index]
	var planned_kind: String = str(planned_action.get("kind", ""))

	## 如果序列第一步就是 end_turn，直接走 heuristic
	if planned_kind == "end_turn":
		_mcts_planned_sequence.clear()
		_mcts_sequence_index = 0
		var _mh2 := "[MCTS] 序列仅有 end_turn，切换 heuristic"
		print(_mh2)
		_mcts_log_to_file(_mh2)
		return _choose_heuristic_action(gsm)

	_mcts_sequence_index += 1
	var resolved := _resolve_mcts_action(gsm, planned_action)
	if not resolved.is_empty():
		var _m1 := "[MCTS] 执行: %s (解析成功)" % str(resolved.get("kind", ""))
		print(_m1)
		_mcts_log_to_file(_m1)
		var planned_actions: Array[Dictionary] = get_legal_actions(gsm)
		var planned_scored_actions: Array[Dictionary] = _build_trace_scored_actions(gsm, planned_actions)
		_record_decision_trace_from_choice(gsm, planned_actions, planned_scored_actions, resolved, true)
		return resolved
	## 解析失败，清空序列并回退到 heuristic
	var _mf2 := "[MCTS] 解析失败，回退 heuristic: kind=%s" % planned_kind
	print(_mf2)
	_mcts_log_to_file(_mf2)
	_record_mcts_resolution_mismatch(planned_kind, gsm)
	_mcts_planned_sequence.clear()
	_mcts_sequence_index = 0
	return _choose_heuristic_action(gsm)


func _choose_greedy_strategy_action(gsm: GameStateMachine) -> Dictionary:
	## v7.2 统一评估循环：所有动作（setup/attack/retreat）在同一标尺竞争
	## 不再分 setup → attack 两阶段，避免低价值 setup 阻挡高价值 attack
	var actions: Array[Dictionary] = get_legal_actions(gsm)
	var end_turn_action: Dictionary = {}
	var scoreable_actions: Array[Dictionary] = []
	for a: Dictionary in actions:
		if str(a.get("kind", "")) == "end_turn":
			end_turn_action = a
		else:
			scoreable_actions.append(a)
	# 统一评估：所有动作竞争，选最高分
	var best: Dictionary = _pick_best_absolute(scoreable_actions, gsm)
	if float(best.get("score", 0.0)) > 0.0:
		var chosen: Dictionary = best.get("action", {})
		# 攻击/granted_attack 是终结动作 — 执行前记录 trace
		var scored_actions: Array[Dictionary] = _build_trace_scored_actions(gsm, actions)
		_record_decision_trace_from_choice(gsm, actions, scored_actions, chosen, false)
		return chosen
	# 所有动作 ≤ 0 → end_turn
	if not end_turn_action.is_empty():
		var scored_actions: Array[Dictionary] = _build_trace_scored_actions(gsm, actions)
		_record_decision_trace_from_choice(gsm, actions, scored_actions, end_turn_action, false)
		return end_turn_action
	return {}


func _pick_best_absolute(candidate_actions: Array[Dictionary], gsm: GameStateMachine) -> Dictionary:
	## 返回 {action, score}，score = 绝对分
	var scored_candidates: Array[Dictionary] = []
	var state_features: Array = _encode_state_features(gsm.game_state if gsm != null else null)
	for a: Dictionary in candidate_actions:
		var augmented: Dictionary = _augment_action_for_scoring(gsm, a)
		var absolute_score: float = _deck_strategy.score_action_absolute(augmented, gsm.game_state, player_index)
		var features: Dictionary = _feature_extractor.build_context(gsm, player_index, augmented)
		var learned_action_score: float = _score_action_with_action_scorer(
			str(augmented.get("kind", "")),
			state_features,
			features
		)
		scored_candidates.append({
			"action": a,
			"score": absolute_score + learned_action_score,
			"absolute_score": absolute_score,
			"learned_action_score": learned_action_score,
		})
	return _pick_best_scored_absolute(scored_candidates)


func _pick_best_scored_absolute(scored_candidates: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {"action": {}, "score": 0.0}
	if scored_candidates.is_empty():
		return best
	var positive_setup_count: int = 0
	for entry: Dictionary in scored_candidates:
		var action: Dictionary = entry.get("action", {})
		var score: float = float(entry.get("score", 0.0))
		if score > 0.0 and _is_combo_setup_action(str(action.get("kind", ""))):
			positive_setup_count += 1
	for entry: Dictionary in scored_candidates:
		var action: Dictionary = entry.get("action", {})
		var score: float = float(entry.get("score", 0.0))
		var effective_score: float = score
		var kind: String = str(action.get("kind", ""))
		if positive_setup_count >= 2 and kind in ["play_trainer", "evolve", "use_ability"]:
			effective_score += 40.0
		if positive_setup_count >= 3 and kind in ["play_trainer", "evolve"]:
			effective_score += 20.0
		if best.get("action", {}).is_empty() or effective_score > float(best.get("score", 0.0)):
			best = {"action": action, "score": effective_score}
	return best


func _is_combo_setup_action(kind: String) -> bool:
	return kind in ["play_trainer", "evolve", "use_ability", "attach_energy", "play_basic_to_bench"]


func _choose_heuristic_action(gsm: GameStateMachine) -> Dictionary:
	## 与原 _choose_best_action 中的 heuristic 分支相同的逻辑
	var actions: Array[Dictionary] = get_legal_actions(gsm)
	if actions.is_empty():
		_record_decision_trace_from_choice(gsm, actions, [], {}, false)
		return {}
	var scored_actions: Array[Dictionary] = _build_trace_scored_actions(gsm, actions)
	var best_action: Dictionary = {}
	var best_score := -INF
	var best_scored_action: Dictionary = {}
	for index: int in actions.size():
		var action: Dictionary = actions[index]
		var trace_scored_action: Dictionary = scored_actions[index]
		var score: float = float(trace_scored_action.get("score", 0.0))
		if best_action.is_empty() or score > best_score:
			best_action = action
			best_score = score
			best_scored_action = trace_scored_action
	_record_decision_trace_from_choice(gsm, actions, scored_actions, best_scored_action, false)
	return best_action


func _resolve_mcts_action(gsm: GameStateMachine, planned_action: Dictionary) -> Dictionary:
	## 将 MCTS 序列中的序列化动作解析到当前真实 gsm 的对象上。
	## 策略：在当前合法动作中按 kind + 关键字段匹配。
	var kind: String = str(planned_action.get("kind", ""))

	## end_turn 不需要解析
	if kind == "end_turn":
		return {"kind": "end_turn"}

	## 获取当前合法动作
	var legal_actions: Array[Dictionary] = get_legal_actions(gsm)

	## 从序列化动作中提取匹配关键信息
	var card_id: int = int(planned_action.get("card_instance_id", -1))
	var target_slot_card_id: int = int(planned_action.get("target_slot_card_id", -1))
	var source_slot_card_id: int = int(planned_action.get("source_slot_card_id", -1))
	var bench_target_card_id: int = int(planned_action.get("bench_target_card_id", -1))
	var attack_index: int = int(planned_action.get("attack_index", -1))
	var ability_index: int = int(planned_action.get("ability_index", -1))

	for action: Dictionary in legal_actions:
		if str(action.get("kind", "")) != kind:
			continue
		## 按 kind 分别匹配关键字段
		match kind:
			"play_basic_to_bench":
				if _match_card_id(action, card_id):
					return action
			"attach_energy":
				if _match_card_id(action, card_id) and _match_slot_card_id(action, "target_slot", target_slot_card_id):
					return action
			"attach_tool":
				if _match_card_id(action, card_id) and _match_slot_card_id(action, "target_slot", target_slot_card_id):
					return action
			"evolve":
				if _match_card_id(action, card_id) and _match_slot_card_id(action, "target_slot", target_slot_card_id):
					return action
			"attack":
				if int(action.get("attack_index", -1)) == attack_index:
					return action
			"use_ability":
				if _match_slot_card_id(action, "source_slot", source_slot_card_id) and int(action.get("ability_index", -1)) == ability_index:
					return action
			"play_trainer":
				if _match_card_id(action, card_id):
					return action
			"play_stadium":
				if _match_card_id(action, card_id):
					return action
			"retreat":
				if _match_slot_card_id(action, "bench_target", bench_target_card_id):
					return action
	## 无法匹配到合法动作
	return {}


func _match_card_id(action: Dictionary, expected_id: int) -> bool:
	if expected_id < 0:
		return true
	var card: Variant = action.get("card")
	if card is CardInstance:
		return card.instance_id == expected_id
	return false


func _match_slot_card_id(action: Dictionary, slot_key: String, expected_id: int) -> bool:
	if expected_id < 0:
		return true
	var slot: Variant = action.get(slot_key)
	if slot is PokemonSlot:
		var top_card: CardInstance = slot.get_top_card()
		if top_card != null:
			return top_card.instance_id == expected_id
	return false


func _merge_event_counters(counters: Dictionary) -> void:
	for key_variant: Variant in counters.keys():
		var key: String = str(key_variant)
		var value: Variant = counters.get(key, null)
		if value is Dictionary:
			var existing: Dictionary = _event_counters.get(key, {})
			for subkey_variant: Variant in (value as Dictionary).keys():
				var subkey: String = str(subkey_variant)
				existing[subkey] = int(existing.get(subkey, 0)) + int((value as Dictionary).get(subkey, 0))
			_event_counters[key] = existing
		elif value is Array:
			var existing_array: Array = _event_counters.get(key, [])
			for entry: Variant in value:
				existing_array.append(entry)
			_event_counters[key] = existing_array
		else:
			_event_counters[key] = value


func _record_mcts_resolution_mismatch(kind: String, gsm: GameStateMachine) -> void:
	_merge_event_counters({
		"mcts_failure_category_counts": {"action_resolution_mismatch": 1},
		"mcts_failure_kind_counts": {kind: 1},
		"mcts_failure_samples": [{
			"category": "action_resolution_mismatch",
			"kind": kind,
			"turn_number": -1 if gsm == null or gsm.game_state == null else int(gsm.game_state.turn_number),
			"step_index": int((_event_counters.get("mcts_failure_samples", []) as Array).size()) + 1,
		}],
	})


func _mcts_log_to_file(msg: String) -> void:
	var file := FileAccess.open("user://mcts_debug.log", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("user://mcts_debug.log", FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(msg)
		file.close()


func _detect_and_load_deck_strategy(player: PlayerState) -> void:
	if _deck_strategy_detected:
		return
	_deck_strategy_detected = true
	if player == null:
		return
	set_deck_strategy(_deck_strategy_registry.create_strategy_for_player(player))
	return
	if player == null:
		return
	# 检查手牌 + 牌库中是否有沙奈朵卡组签名卡
	var has_gardevoir_sig: bool = false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null:
			var name: String = str(card.card_data.name)
			if name == "沙奈朵ex" or name == "奇鲁莉安" or name == "拉鲁拉丝":
				has_gardevoir_sig = true
				break
	if not has_gardevoir_sig:
		for card: CardInstance in player.deck:
			if card != null and card.card_data != null:
				var name: String = str(card.card_data.name)
				if name == "沙奈朵ex" or name == "奇鲁莉安":
					has_gardevoir_sig = true
					break
	if has_gardevoir_sig:
		_deck_strategy = DeckStrategyGardevoirScript.new()
		return
	# 检查密勒顿卡组签名卡
	var has_miraidon_sig: bool = false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null:
			var name: String = str(card.card_data.name)
			if name == "密勒顿ex" or name == "Miraidon ex":
				has_miraidon_sig = true
				break
	if not has_miraidon_sig:
		for card: CardInstance in player.deck:
			if card != null and card.card_data != null:
				var name: String = str(card.card_data.name)
				if name == "密勒顿ex" or name == "Miraidon ex":
					has_miraidon_sig = true
					break
	if has_miraidon_sig:
		_deck_strategy = DeckStrategyMiraidonScript.new()
	# 同步策略到 step_resolver，指导交互选择（搜索目标、贴能目标等）
	if _deck_strategy != null:
		_step_resolver.deck_strategy = _deck_strategy
