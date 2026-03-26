class_name AIOpponent
extends RefCounted

const AISetupPlannerScript = preload("res://scripts/ai/AISetupPlanner.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const AIFeatureExtractorScript = preload("res://scripts/ai/AIFeatureExtractor.gd")
const AIStepResolverScript = preload("res://scripts/ai/AIStepResolver.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")
const AIDecisionTraceScript = preload("res://scripts/ai/AIDecisionTrace.gd")
const MCTSPlannerScript = preload("res://scripts/ai/MCTSPlanner.gd")

var player_index: int = 1
var difficulty: int = 1
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


func configure(next_player_index: int, next_difficulty: int) -> void:
	player_index = next_player_index
	difficulty = next_difficulty


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
		return _step_resolver.resolve_pending_step(battle_scene, gsm, player_index)
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
	var choice: Dictionary = _setup_planner.plan_opening_setup(player)
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
		return true
	if not gsm.setup_place_bench_pokemon(pi, planned_card):
		return false
	_planned_setup_bench_ids.erase(planned_card.instance_id)
	if battle_scene.has_method("_refresh_ui"):
		battle_scene.call("_refresh_ui")
	if battle_scene.has_method("_show_setup_bench_dialog"):
		battle_scene.call("_show_setup_bench_dialog", pi)
	return true


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
	## MCTS 模式：使用预规划序列
	if use_mcts:
		return _choose_mcts_action(gsm)
	## 原有 heuristic 逻辑
	var actions: Array[Dictionary] = get_legal_actions(gsm)
	var trace = AIDecisionTraceScript.new()
	trace.turn_number = int(gsm.game_state.turn_number) if gsm != null and gsm.game_state != null else -1
	trace.player_index = player_index
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
		"play_trainer", "play_stadium", "use_ability", "evolve", "retreat", "play_basic_to_bench":
			scored_action["productive"] = true
	return scored_action


func _execute_action(battle_scene: Control, gsm: GameStateMachine, action: Dictionary) -> bool:
	match str(action.get("kind", "")):
		"attach_energy":
			var target_slot: PokemonSlot = action.get("target_slot")
			var energy_card: CardInstance = action.get("card")
			if gsm.attach_energy(player_index, energy_card, target_slot):
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
					battle_scene.call("_try_play_trainer_with_interaction", player_index, action.get("card"))
					return true
				return false
			if gsm.play_trainer(player_index, action.get("card"), action.get("targets", [])):
				_after_successful_action(battle_scene)
				return true
		"play_stadium":
			if bool(action.get("requires_interaction", false)):
				if battle_scene != null and battle_scene.has_method("_try_play_stadium_with_interaction"):
					battle_scene.call("_try_play_stadium_with_interaction", player_index, action.get("card"))
					return true
				return false
			if gsm.play_stadium(player_index, action.get("card"), action.get("targets", [])):
				_after_successful_action(battle_scene)
				return true
		"use_ability":
			if bool(action.get("requires_interaction", false)):
				if battle_scene != null and battle_scene.has_method("_try_use_ability_with_interaction"):
					battle_scene.call(
						"_try_use_ability_with_interaction",
						player_index,
						action.get("source_slot"),
						int(action.get("ability_index", 0))
					)
					return true
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
					battle_scene.call(
						"_try_use_attack_with_interaction",
						player_index,
						player.active_pokemon,
						int(action.get("attack_index", -1))
					)
					return true
				return false
			if gsm.use_attack(player_index, int(action.get("attack_index", -1)), action.get("targets", [])):
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
	for bench_slot: PokemonSlot in bench_slots:
		if gsm.send_out_pokemon(send_out_player_index, bench_slot):
			_clear_consumed_prompt(battle_scene)
			if GameManager.current_mode != GameManager.GameMode.VS_AI:
				battle_scene.set("_view_player", gsm.game_state.current_player_index)
			if battle_scene.has_method("_refresh_ui_after_successful_action"):
				battle_scene.call("_refresh_ui_after_successful_action", true)
			elif battle_scene.has_method("_refresh_ui"):
				battle_scene.call("_refresh_ui")
			return true
	return false


func _clear_consumed_prompt(battle_scene: Control) -> void:
	if battle_scene == null:
		return
	battle_scene.set("_pending_choice", "")
	battle_scene.set("_dialog_data", {})


func _choose_mcts_action(gsm: GameStateMachine) -> Dictionary:
	## 如果还有预规划的序列动作，继续执行
	if _mcts_sequence_index < _mcts_planned_sequence.size():
		var planned_action: Dictionary = _mcts_planned_sequence[_mcts_sequence_index]
		_mcts_sequence_index += 1
		var resolved := _resolve_mcts_action(gsm, planned_action)
		if not resolved.is_empty():
			return resolved
		## 解析失败，清空序列并回退到 heuristic
		_mcts_planned_sequence.clear()
		_mcts_sequence_index = 0
		return _choose_heuristic_action(gsm)
	## 否则规划新序列
	_mcts_planned_sequence = _mcts_planner.plan_turn(gsm, player_index, mcts_config)
	_mcts_sequence_index = 0
	if _mcts_planned_sequence.is_empty():
		return {"kind": "end_turn"}
	var planned_action: Dictionary = _mcts_planned_sequence[_mcts_sequence_index]
	_mcts_sequence_index += 1
	var resolved := _resolve_mcts_action(gsm, planned_action)
	if not resolved.is_empty():
		return resolved
	## 解析失败，清空序列并回退到 heuristic
	_mcts_planned_sequence.clear()
	_mcts_sequence_index = 0
	return _choose_heuristic_action(gsm)


func _choose_heuristic_action(gsm: GameStateMachine) -> Dictionary:
	## 与原 _choose_best_action 中的 heuristic 分支相同的逻辑
	var actions: Array[Dictionary] = get_legal_actions(gsm)
	var trace = AIDecisionTraceScript.new()
	trace.turn_number = int(gsm.game_state.turn_number) if gsm != null and gsm.game_state != null else -1
	trace.player_index = player_index
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
