class_name HeadlessMatchBridge
extends Control

const AISetupPlannerScript = preload("res://scripts/ai/AISetupPlanner.gd")

var _gsm: GameStateMachine = null
var _pending_choice: String = ""
var _dialog_data: Dictionary = {}
var _setup_done: Array[bool] = [false, false]
var _setup_order: Array[int] = [0, 1]
var _setup_order_index: int = 0
var _setup_planner = AISetupPlannerScript.new()
var _planned_setup_bench_ids: Array[int] = []

## 效果交互状态（与 BattleScene 同名以兼容 AIStepResolver）
var _pending_effect_card: CardInstance = null
var _pending_effect_steps: Array[Dictionary] = []
var _pending_effect_step_index: int = -1
var _pending_effect_context: Dictionary = {}
var _pending_effect_kind: String = ""
var _pending_effect_player_index: int = -1
var _pending_effect_slot: PokemonSlot = null
var _pending_effect_ability_index: int = -1
var _pending_effect_attack_data: Dictionary = {}
var _pending_effect_attack_effects: Array[BaseEffect] = []

## 场地交互状态（AIStepResolver 读取）
var _field_interaction_mode: String = ""
var _field_interaction_data: Dictionary = {}
var _field_interaction_selected_indices: Array[int] = []
var _field_interaction_assignment_selected_source_index: int = -1
var _field_interaction_assignment_entries: Array[Dictionary] = []

## 对话分配状态（AIStepResolver 读取）
var _dialog_assignment_selected_source_index: int = -1
var _dialog_assignment_assignments: Array[Dictionary] = []


func bind(next_gsm: GameStateMachine) -> void:
	if _gsm != null and _gsm.player_choice_required.is_connected(_on_player_choice_required):
		_gsm.player_choice_required.disconnect(_on_player_choice_required)
	_gsm = next_gsm
	if _gsm != null and not _gsm.player_choice_required.is_connected(_on_player_choice_required):
		_gsm.player_choice_required.connect(_on_player_choice_required)


func handles_bridge_owned_prompts() -> bool:
	return true


func supports_effect_interaction_execution() -> bool:
	return true


func bootstrap_pending_setup() -> void:
	if _gsm == null or _gsm.game_state == null:
		return
	if _gsm.game_state.phase != GameState.GamePhase.SETUP or _pending_choice != "":
		return
	if _bootstrap_pending_mulligan_prompt():
		return
	var resume_player_index: int = _get_setup_resume_player_index()
	if resume_player_index >= 0:
		_begin_setup_flow(resume_player_index)


func has_pending_prompt() -> bool:
	return _pending_choice != ""


func get_pending_prompt_type() -> String:
	return _pending_choice


func get_pending_prompt_owner() -> int:
	match _pending_choice:
		"mulligan_extra_draw":
			return int(_dialog_data.get("beneficiary", -1))
		"take_prize", "send_out", "heavy_baton_target":
			return int(_dialog_data.get("player", -1))
		_ when _pending_choice.begins_with("setup_active_") or _pending_choice.begins_with("setup_bench_"):
			return int(_dialog_data.get("player", -1))
		"effect_interaction":
			if _pending_effect_step_index >= 0 and _pending_effect_step_index < _pending_effect_steps.size():
				return _resolve_effect_step_chooser_player(_pending_effect_steps[_pending_effect_step_index])
			var chooser_owner: int = _get_effect_interaction_prompt_owner()
			if chooser_owner >= 0:
				return chooser_owner
			if _gsm != null and _gsm.game_state != null:
				return _gsm.game_state.current_player_index
			return -1
		_:
			return -1


func can_resolve_pending_prompt() -> bool:
	return _pending_choice == "mulligan_extra_draw" \
		or _pending_choice == "take_prize" \
		or _pending_choice == "send_out" \
		or _pending_choice.begins_with("setup_active_") \
		or _pending_choice.begins_with("setup_bench_")


func can_auto_resolve_pending_prompt() -> bool:
	return can_resolve_pending_prompt()


func resolve_pending_prompt() -> bool:
	if _gsm == null:
		return false
	var pending_choice := _pending_choice
	var dialog_data := _dialog_data.duplicate(true)
	_pending_choice = ""
	_dialog_data.clear()
	var resolved := false
	match pending_choice:
		"mulligan_extra_draw":
			resolved = _resolve_mulligan_extra_draw(dialog_data)
		"take_prize":
			resolved = _resolve_take_prize(dialog_data)
		"send_out":
			resolved = _resolve_send_out(dialog_data)
		_ when pending_choice.begins_with("setup_active_"):
			resolved = _resolve_setup_active(dialog_data)
		_ when pending_choice.begins_with("setup_bench_"):
			resolved = _resolve_setup_bench(dialog_data)
		_:
			resolved = false
	if not resolved:
		_pending_choice = pending_choice
		_dialog_data = dialog_data
	return resolved


func _on_player_choice_required(choice_type: String, data: Dictionary) -> void:
	match choice_type:
		"mulligan_extra_draw":
			_pending_choice = "mulligan_extra_draw"
			_dialog_data = data.duplicate(true)
		"setup_ready":
			_begin_setup_flow()
		"take_prize":
			_pending_choice = "take_prize"
			_dialog_data = {"player": int(data.get("player", -1))}
		"send_out_pokemon":
			_pending_choice = "send_out"
			_dialog_data = {"player": int(data.get("player", -1))}
		_:
			_pending_choice = choice_type
			_dialog_data = data.duplicate(true)


func _begin_setup_flow(start_player_index: int = 0) -> void:
	_setup_done = [false, false]
	_setup_order = [start_player_index, 1 - start_player_index]
	_setup_order_index = 0
	_setup_player_active(_setup_order[_setup_order_index])


func _setup_player_active(pi: int) -> void:
	_show_setup_active_dialog(pi)


func _show_setup_active_dialog(pi: int) -> void:
	if _gsm == null or _gsm.game_state == null or pi < 0 or pi >= _gsm.game_state.players.size():
		return
	var player: PlayerState = _gsm.game_state.players[pi]
	_pending_choice = "setup_active_%d" % pi
	_dialog_data = {
		"player": pi,
		"basics": player.get_basic_pokemon_in_hand(),
	}


func _after_setup_active(pi: int) -> void:
	_show_setup_bench_dialog(pi)


func _show_setup_bench_dialog(pi: int) -> void:
	if _gsm == null or _gsm.game_state == null or pi < 0 or pi >= _gsm.game_state.players.size():
		return
	var player: PlayerState = _gsm.game_state.players[pi]
	if player.is_bench_full() or player.get_basic_pokemon_in_hand().is_empty():
		_after_setup_bench(pi)
		return
	_pending_choice = "setup_bench_%d" % pi
	_dialog_data = {
		"player": pi,
		"cards": player.get_basic_pokemon_in_hand(),
	}


func _after_setup_bench(pi: int) -> void:
	if pi < 0 or pi >= _setup_done.size():
		return
	_setup_done[pi] = true
	if _gsm != null and _gsm.game_state != null:
		while _setup_order_index + 1 < _setup_order.size():
			_setup_order_index += 1
			var next_player_index: int = _setup_order[_setup_order_index]
			if next_player_index < 0 or next_player_index >= _gsm.game_state.players.size():
				continue
			var next_player: PlayerState = _gsm.game_state.players[next_player_index]
			if next_player == null or next_player.active_pokemon == null:
				_setup_player_active(next_player_index)
				return
	if _gsm != null:
		_gsm.setup_complete(0)


func _refresh_ui_after_successful_action(_check_handover: bool = false) -> void:
	pass


func _refresh_ui() -> void:
	pass


func _maybe_run_ai() -> void:
	pass


func _try_play_to_bench(player_index: int, basic_card: CardInstance, _source: String = "") -> bool:
	if _gsm == null:
		return false
	return _gsm.play_basic_to_bench(player_index, basic_card)


func _on_end_turn() -> void:
	if _gsm == null or _gsm.game_state == null:
		return
	_gsm.end_turn(_gsm.game_state.current_player_index)


## ===== 效果交互：_try_*_with_interaction 方法 =====

func _try_play_trainer_with_interaction(player_index: int, card: CardInstance) -> bool:
	if _gsm == null:
		return false
	var effect: BaseEffect = _gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		return _gsm.play_trainer(player_index, card, [])
	if not effect.can_execute(card, _gsm.game_state):
		return false
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, _gsm.game_state)
	if steps.is_empty():
		return _gsm.play_trainer(player_index, card, [])
	_start_effect_interaction("trainer", player_index, steps, card)
	return _pending_choice == "effect_interaction"


func _try_play_stadium_with_interaction(player_index: int, card: CardInstance) -> bool:
	if _gsm == null:
		return false
	var effect: BaseEffect = _gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		return _gsm.play_stadium(player_index, card)
	var steps: Array[Dictionary] = effect.get_on_play_interaction_steps(card, _gsm.game_state)
	if steps.is_empty():
		return _gsm.play_stadium(player_index, card)
	_start_effect_interaction("play_stadium", player_index, steps, card)
	return _pending_choice == "effect_interaction"


func _try_use_ability_with_interaction(player_index: int, slot: PokemonSlot, ability_index: int) -> bool:
	if _gsm == null:
		return false
	var card: CardInstance = _gsm.effect_processor.get_ability_source_card(slot, ability_index, _gsm.game_state)
	if card == null:
		return false
	var effect: BaseEffect = _gsm.effect_processor.get_ability_effect(slot, ability_index, _gsm.game_state)
	if effect == null:
		return _gsm.use_ability(player_index, slot, ability_index)
	if not _gsm.effect_processor.can_use_ability(slot, _gsm.game_state, ability_index):
		return false
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, _gsm.game_state)
	if steps.is_empty():
		return _gsm.use_ability(player_index, slot, ability_index)
	_start_effect_interaction("ability", player_index, steps, card, slot, ability_index)
	return _pending_choice == "effect_interaction"


func _try_use_stadium_with_interaction(player_index: int) -> bool:
	if _gsm == null or _gsm.game_state.stadium_card == null:
		return false
	var stadium_card: CardInstance = _gsm.game_state.stadium_card
	var effect: BaseEffect = _gsm.effect_processor.get_effect(stadium_card.card_data.effect_id)
	if effect == null:
		return _gsm.use_stadium_effect(player_index)
	if not _gsm.can_use_stadium_effect(player_index):
		return false
	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium_card, _gsm.game_state)
	if steps.is_empty():
		return _gsm.use_stadium_effect(player_index)
	_start_effect_interaction("stadium", player_index, steps, stadium_card)
	return _pending_choice == "effect_interaction"


func _try_use_attack_with_interaction(player_index: int, slot: PokemonSlot, attack_index: int) -> bool:
	if _gsm == null:
		return false
	if not _gsm.can_use_attack(player_index, attack_index):
		return false
	var card: CardInstance = slot.get_top_card()
	if card == null:
		return false
	var attack: Dictionary = card.card_data.attacks[attack_index]
	var steps: Array[Dictionary] = []
	var effects: Array[BaseEffect] = _gsm.effect_processor.get_attack_effects_for_slot(slot, attack_index)
	for effect: BaseEffect in effects:
		steps.append_array(effect.get_attack_interaction_steps(card, attack, _gsm.game_state))
	if steps.is_empty():
		return _gsm.use_attack(player_index, attack_index)
	_start_effect_interaction("attack", player_index, steps, card, slot, attack_index, {}, effects)
	return _pending_choice == "effect_interaction"


func _try_use_granted_attack_with_interaction(player_index: int, slot: PokemonSlot, granted_attack: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	if player_index < 0 or player_index >= _gsm.game_state.players.size():
		return false
	if _gsm.game_state.current_player_index != player_index:
		return false
	if _gsm.game_state.phase != GameState.GamePhase.MAIN:
		return false
	if slot == null or slot.get_top_card() == null:
		return false
	if slot != _gsm.game_state.players[player_index].active_pokemon:
		return false
	if slot.attached_tool == null:
		return false
	if _gsm.effect_processor.is_tool_effect_suppressed(slot, _gsm.game_state):
		return false
	var cost: String = str(granted_attack.get("cost", ""))
	if not _gsm.rule_validator.has_enough_energy(slot, cost, _gsm.effect_processor, _gsm.game_state):
		return false
	var steps: Array[Dictionary] = _gsm.effect_processor.get_granted_attack_interaction_steps(
		slot,
		granted_attack,
		_gsm.game_state
	)
	if steps.is_empty():
		return _gsm.use_granted_attack(player_index, slot, granted_attack)
	_start_effect_interaction("granted_attack", player_index, steps, slot.get_top_card(), slot, -1, granted_attack)
	return _pending_choice == "effect_interaction"


func _try_start_evolve_trigger_ability_interaction(player_index: int, slot: PokemonSlot) -> void:
	if _gsm == null or slot == null or slot.get_top_card() == null:
		return
	var steps: Array[Dictionary] = _gsm.get_evolve_ability_interaction_steps(slot)
	if steps.is_empty():
		return
	_start_effect_interaction("ability", player_index, steps, slot.get_top_card(), slot, 0)


## ===== 效果交互核心流程 =====

func _start_effect_interaction(
	kind: String,
	player_index: int,
	steps: Array[Dictionary],
	card: CardInstance,
	slot: PokemonSlot = null,
	ability_index: int = -1,
	attack_data: Dictionary = {},
	attack_effects: Array[BaseEffect] = []
) -> void:
	_reset_effect_interaction()
	_pending_effect_kind = kind
	_pending_effect_player_index = player_index
	_pending_effect_card = card
	_pending_effect_slot = slot
	_pending_effect_ability_index = ability_index
	_pending_effect_attack_data = attack_data.duplicate(true)
	_pending_effect_attack_effects = attack_effects.duplicate()
	_pending_effect_steps = steps
	_pending_effect_step_index = 0
	_pending_effect_context = {}
	_show_next_effect_interaction_step()


func _show_next_effect_interaction_step() -> void:
	if _pending_effect_card == null:
		return
	## 所有步骤完成 -> 执行效果
	if _pending_effect_step_index >= _pending_effect_steps.size():
		var success := false
		match _pending_effect_kind:
			"trainer":
				success = _gsm.play_trainer(
					_pending_effect_player_index,
					_pending_effect_card,
					[_pending_effect_context]
				)
			"play_stadium":
				success = _gsm.play_stadium(
					_pending_effect_player_index,
					_pending_effect_card,
					[_pending_effect_context]
				)
			"ability":
				success = _gsm.use_ability(
					_pending_effect_player_index,
					_pending_effect_slot,
					_pending_effect_ability_index,
					[_pending_effect_context]
				)
			"stadium":
				success = _gsm.use_stadium_effect(
					_pending_effect_player_index,
					[_pending_effect_context]
				)
			"attack":
				success = _gsm.use_attack(
					_pending_effect_player_index,
					_pending_effect_ability_index,
					[_pending_effect_context]
				)
			"granted_attack":
				success = _gsm.use_granted_attack(
					_pending_effect_player_index,
					_pending_effect_slot,
					_pending_effect_attack_data,
					[_pending_effect_context]
				)
		_reset_effect_interaction()
		return
	## 还有步骤未完成 -> 设置 pending_choice 等待 AI 解决
	_pending_choice = "effect_interaction"
	var step: Dictionary = _pending_effect_steps[_pending_effect_step_index]
	## 根据步骤类型设置对应的交互模式
	if _effect_step_uses_counter_distribution_ui(step):
		_field_interaction_mode = "counter_distribution"
		_field_interaction_data = step.duplicate(true)
		_field_interaction_assignment_entries.clear()
		_field_interaction_assignment_selected_source_index = -1
	elif _effect_step_uses_field_assignment_ui(step):
		_field_interaction_mode = "assignment"
		_field_interaction_data = step.duplicate(true)
		_field_interaction_assignment_entries.clear()
		_field_interaction_assignment_selected_source_index = -1
	elif _effect_step_uses_field_slot_ui(step):
		_field_interaction_mode = "slot_select"
		_field_interaction_data = step.duplicate(true)
		_field_interaction_selected_indices.clear()
	elif str(step.get("ui_mode", "")) == "card_assignment":
		_field_interaction_mode = ""
		_dialog_assignment_selected_source_index = -1
		_dialog_assignment_assignments.clear()
	else:
		_field_interaction_mode = ""


func _resolve_effect_step_chooser_player(step: Dictionary) -> int:
	if step.has("chooser_player_index"):
		var chooser_index: int = int(step.get("chooser_player_index", -1))
		if chooser_index >= 0:
			return chooser_index
	if bool(step.get("opponent_chooses", false)) and _pending_effect_player_index >= 0:
		return 1 - _pending_effect_player_index
	return _pending_effect_player_index


func _effect_step_uses_counter_distribution_ui(step: Dictionary) -> bool:
	if str(step.get("ui_mode", "")) != "counter_distribution":
		return false
	var target_items: Array = step.get("target_items", [])
	if target_items.is_empty():
		return false
	for item: Variant in target_items:
		if not (item is PokemonSlot):
			return false
	return true


func _effect_step_uses_field_slot_ui(step: Dictionary) -> bool:
	if str(step.get("ui_mode", "")) in ["card_assignment", "counter_distribution"]:
		return false
	var items: Array = step.get("items", [])
	if items.is_empty():
		return false
	for item: Variant in items:
		if not (item is PokemonSlot):
			return false
	return true


func _effect_step_uses_field_assignment_ui(step: Dictionary) -> bool:
	if str(step.get("ui_mode", "")) != "card_assignment":
		return false
	var target_items: Array = step.get("target_items", [])
	if target_items.is_empty():
		return false
	for item: Variant in target_items:
		if not (item is PokemonSlot):
			return false
	return true


## ===== AIStepResolver 调用的交互处理方法 =====

func _handle_effect_interaction_choice(selected_indices: PackedInt32Array) -> void:
	if _pending_effect_card == null or _pending_effect_step_index < 0 or _pending_effect_step_index >= _pending_effect_steps.size():
		_reset_effect_interaction()
		return
	var step: Dictionary = _pending_effect_steps[_pending_effect_step_index]
	var items_raw: Array = step.get("items", [])
	var selected_items: Array = []
	for selected_idx: int in selected_indices:
		if selected_idx >= 0 and selected_idx < items_raw.size():
			selected_items.append(items_raw[selected_idx])
	_pending_effect_context[step.get("id", "step_%d" % _pending_effect_step_index)] = selected_items
	_pending_effect_step_index += 1
	_inject_followup_steps()
	_show_next_effect_interaction_step()


func _handle_field_slot_select_index(target_index: int) -> void:
	var min_select: int = int(_field_interaction_data.get("min_select", 1))
	var max_select: int = int(_field_interaction_data.get("max_select", 1))
	if max_select <= 1 and min_select <= 1:
		_field_interaction_selected_indices = [target_index]
		_finalize_field_slot_selection()
		return
	if target_index in _field_interaction_selected_indices:
		_field_interaction_selected_indices.erase(target_index)
	else:
		if max_select > 0 and _field_interaction_selected_indices.size() >= max_select:
			return
		_field_interaction_selected_indices.append(target_index)
	if min_select == max_select and max_select > 1 and _field_interaction_selected_indices.size() == max_select:
		_finalize_field_slot_selection()


func _finalize_field_slot_selection() -> void:
	var min_select: int = int(_field_interaction_data.get("min_select", 1))
	if _field_interaction_selected_indices.size() < min_select:
		return
	var selected := PackedInt32Array(_field_interaction_selected_indices)
	_field_interaction_mode = ""
	_field_interaction_selected_indices.clear()
	if _pending_choice == "effect_interaction":
		_handle_effect_interaction_choice(selected)


func _on_field_assignment_source_chosen(source_index: int) -> void:
	var source_items: Array = _field_interaction_data.get("source_items", [])
	if source_index < 0 or source_index >= source_items.size():
		return
	var assigned_index := _find_field_assignment_index_for_source(source_index)
	if assigned_index >= 0:
		_field_interaction_assignment_entries.remove_at(assigned_index)
		if _field_interaction_assignment_selected_source_index == source_index:
			_field_interaction_assignment_selected_source_index = -1
		return
	var max_assignments: int = int(_field_interaction_data.get("max_select", source_items.size()))
	if max_assignments > 0 and _field_interaction_assignment_entries.size() >= max_assignments:
		return
	_field_interaction_assignment_selected_source_index = source_index


func _handle_field_assignment_target_index(target_index: int) -> void:
	if _field_interaction_assignment_selected_source_index < 0:
		return
	var source_items: Array = _field_interaction_data.get("source_items", [])
	var target_items: Array = _field_interaction_data.get("target_items", [])
	if _field_interaction_assignment_selected_source_index >= source_items.size():
		return
	if target_index < 0 or target_index >= target_items.size():
		return
	var exclude_map: Dictionary = _field_interaction_data.get("source_exclude_targets", {})
	var excluded: Array = exclude_map.get(_field_interaction_assignment_selected_source_index, [])
	if target_index in excluded:
		return
	_field_interaction_assignment_entries.append({
		"source_index": _field_interaction_assignment_selected_source_index,
		"source": source_items[_field_interaction_assignment_selected_source_index],
		"target_index": target_index,
		"target": target_items[target_index],
	})
	_field_interaction_assignment_selected_source_index = -1
	var min_assignments: int = int(_field_interaction_data.get("min_select", 0))
	var max_assignments: int = int(_field_interaction_data.get("max_select", 0))
	if min_assignments == max_assignments and max_assignments > 0 and _field_interaction_assignment_entries.size() == max_assignments:
		_finalize_field_assignment_selection()


func _finalize_field_assignment_selection() -> void:
	var min_select: int = int(_field_interaction_data.get("min_select", 0))
	if _field_interaction_assignment_entries.size() < min_select:
		return
	if _pending_choice != "effect_interaction":
		_field_interaction_mode = ""
		return
	var stored_assignments: Array[Dictionary] = []
	for assignment: Dictionary in _field_interaction_assignment_entries:
		stored_assignments.append(assignment.duplicate())
	_field_interaction_mode = ""
	_field_interaction_assignment_entries.clear()
	_commit_effect_assignment_selection(stored_assignments)


func _on_counter_distribution_amount_chosen(amount: int) -> void:
	var total_counters: int = int(_field_interaction_data.get("total_counters", 0))
	var assigned_count: int = _get_counter_distribution_assigned_total()
	var remaining: int = total_counters - assigned_count
	if amount < 1 or amount > remaining:
		return
	_field_interaction_assignment_selected_source_index = amount


func _handle_counter_distribution_target(target_index: int) -> void:
	var selected_amount: int = _field_interaction_assignment_selected_source_index
	if selected_amount <= 0:
		return
	var target_items: Array = _field_interaction_data.get("target_items", [])
	if target_index < 0 or target_index >= target_items.size():
		return
	var target: Variant = target_items[target_index]
	if not (target is PokemonSlot):
		return
	_field_interaction_assignment_entries.append({
		"target_index": target_index,
		"target": target,
		"amount": selected_amount * 10,
	})
	_field_interaction_assignment_selected_source_index = -1
	var total_counters: int = int(_field_interaction_data.get("total_counters", 0))
	if _get_counter_distribution_assigned_total() >= total_counters:
		_finalize_counter_distribution()


func _finalize_counter_distribution() -> void:
	if _pending_choice != "effect_interaction":
		_field_interaction_mode = ""
		return
	var stored_assignments: Array[Dictionary] = []
	for entry: Dictionary in _field_interaction_assignment_entries:
		stored_assignments.append(entry.duplicate())
	_field_interaction_mode = ""
	_field_interaction_assignment_entries.clear()
	_commit_effect_assignment_selection(stored_assignments)


func _get_counter_distribution_assigned_total() -> int:
	var total: int = 0
	for entry: Dictionary in _field_interaction_assignment_entries:
		total += int(entry.get("amount", 0)) / 10
	return total


func _on_assignment_source_chosen(source_index: int) -> void:
	var source_items: Array = _dialog_data.get("source_items", [])
	if source_index < 0 or source_index >= source_items.size():
		return
	var assigned_index := _find_dialog_assignment_index_for_source(source_index)
	if assigned_index >= 0:
		_dialog_assignment_assignments.remove_at(assigned_index)
		if _dialog_assignment_selected_source_index == source_index:
			_dialog_assignment_selected_source_index = -1
		return
	var max_assignments: int = int(_dialog_data.get("max_select", source_items.size()))
	if max_assignments > 0 and _dialog_assignment_assignments.size() >= max_assignments:
		return
	_dialog_assignment_selected_source_index = source_index


func _on_assignment_target_chosen(target_index: int) -> void:
	if _dialog_assignment_selected_source_index < 0:
		return
	var source_items: Array = _dialog_data.get("source_items", [])
	var target_items: Array = _dialog_data.get("target_items", [])
	if _dialog_assignment_selected_source_index >= source_items.size():
		return
	if target_index < 0 or target_index >= target_items.size():
		return
	var exclude_map: Dictionary = _dialog_data.get("source_exclude_targets", {})
	var excluded: Array = exclude_map.get(_dialog_assignment_selected_source_index, [])
	if target_index in excluded:
		return
	_dialog_assignment_assignments.append({
		"source_index": _dialog_assignment_selected_source_index,
		"source": source_items[_dialog_assignment_selected_source_index],
		"target_index": target_index,
		"target": target_items[target_index],
	})
	_dialog_assignment_selected_source_index = -1


func _confirm_assignment_dialog() -> void:
	var min_select: int = int(_dialog_data.get("min_select", 0))
	var max_select: int = int(_dialog_data.get("max_select", 0))
	var assignment_count: int = _dialog_assignment_assignments.size()
	if assignment_count < min_select:
		return
	if max_select > 0 and assignment_count > max_select:
		return
	if _pending_effect_step_index < 0 or _pending_effect_step_index >= _pending_effect_steps.size():
		return
	var stored_assignments: Array[Dictionary] = []
	for assignment: Dictionary in _dialog_assignment_assignments:
		stored_assignments.append(assignment.duplicate())
	_dialog_assignment_assignments.clear()
	_commit_effect_assignment_selection(stored_assignments)


func _commit_effect_assignment_selection(stored_assignments: Array[Dictionary]) -> void:
	if _pending_effect_step_index < 0 or _pending_effect_step_index >= _pending_effect_steps.size():
		return
	var step: Dictionary = _pending_effect_steps[_pending_effect_step_index]
	_pending_effect_context[step.get("id", "step_%d" % _pending_effect_step_index)] = stored_assignments
	_pending_effect_step_index += 1
	_inject_followup_steps()
	_show_next_effect_interaction_step()


func _inject_followup_steps() -> void:
	if _pending_effect_kind != "attack" or _pending_effect_card == null:
		return
	if _pending_effect_attack_effects.is_empty():
		return
	var card: CardInstance = _pending_effect_card
	var attack_index: int = _pending_effect_ability_index
	if card.card_data == null or attack_index < 0 or attack_index >= card.card_data.attacks.size():
		return
	var attack: Dictionary = card.card_data.attacks[attack_index]
	var followup_steps: Array[Dictionary] = []
	for effect: BaseEffect in _pending_effect_attack_effects:
		followup_steps.append_array(
			effect.get_followup_attack_interaction_steps(card, attack, _gsm.game_state, _pending_effect_context)
		)
	if followup_steps.is_empty():
		return
	var existing_step_ids: Dictionary = {}
	for i: int in range(_pending_effect_step_index, _pending_effect_steps.size()):
		var existing_id: String = str(_pending_effect_steps[i].get("id", ""))
		if existing_id != "":
			existing_step_ids[existing_id] = true
	var unique_followup_steps: Array[Dictionary] = []
	for step: Dictionary in followup_steps:
		var step_id: String = str(step.get("id", ""))
		if step_id != "" and (_pending_effect_context.has(step_id) or existing_step_ids.has(step_id)):
			continue
		unique_followup_steps.append(step)
		if step_id != "":
			existing_step_ids[step_id] = true
	if unique_followup_steps.is_empty():
		return
	var insert_pos: int = _pending_effect_step_index
	for i: int in unique_followup_steps.size():
		_pending_effect_steps.insert(insert_pos + i, unique_followup_steps[i])


func _reset_effect_interaction() -> void:
	_pending_effect_kind = ""
	_pending_effect_player_index = -1
	_pending_effect_card = null
	_pending_effect_slot = null
	_pending_effect_ability_index = -1
	_pending_effect_attack_data.clear()
	_pending_effect_attack_effects.clear()
	_pending_effect_steps.clear()
	_pending_effect_step_index = -1
	_pending_effect_context.clear()
	_field_interaction_mode = ""
	_field_interaction_data.clear()
	_field_interaction_selected_indices.clear()
	_field_interaction_assignment_selected_source_index = -1
	_field_interaction_assignment_entries.clear()
	_dialog_assignment_selected_source_index = -1
	_dialog_assignment_assignments.clear()
	if _pending_choice == "effect_interaction":
		_pending_choice = ""
		_dialog_data.clear()


func _find_field_assignment_index_for_source(source_index: int) -> int:
	for i: int in _field_interaction_assignment_entries.size():
		if int(_field_interaction_assignment_entries[i].get("source_index", -1)) == source_index:
			return i
	return -1


func _find_dialog_assignment_index_for_source(source_index: int) -> int:
	for i: int in _dialog_assignment_assignments.size():
		if int(_dialog_assignment_assignments[i].get("source_index", -1)) == source_index:
			return i
	return -1


func _bootstrap_pending_mulligan_prompt() -> bool:
	var last_mulligan_player := _get_last_mulligan_player_index()
	if last_mulligan_player < 0:
		return false
	_pending_choice = "mulligan_extra_draw"
	_dialog_data = {
		"beneficiary": 1 - last_mulligan_player,
		"mulligan_count": _count_mulligans_for_player(last_mulligan_player),
	}
	return true


func _get_last_mulligan_player_index() -> int:
	if _gsm == null:
		return -1
	var actions: Array = _gsm.get_action_log()
	for action_index: int in range(actions.size() - 1, -1, -1):
		var action_variant: Variant = actions[action_index]
		if action_variant is GameAction and action_variant.action_type == GameAction.ActionType.MULLIGAN:
			return int(action_variant.player_index)
	return -1


func _count_mulligans_for_player(player_index: int) -> int:
	if _gsm == null:
		return 0
	var count: int = 0
	for action_variant: Variant in _gsm.get_action_log():
		if action_variant is GameAction \
				and action_variant.action_type == GameAction.ActionType.MULLIGAN \
				and int(action_variant.player_index) == player_index:
			count += 1
	return count


func _resolve_mulligan_extra_draw(dialog_data: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	var beneficiary: int = int(dialog_data.get("beneficiary", -1))
	if beneficiary < 0 or beneficiary >= _gsm.game_state.players.size():
		return false
	_gsm.resolve_mulligan_choice(beneficiary, _setup_planner.choose_mulligan_bonus_draw())
	return true


func _resolve_setup_active(dialog_data: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	var pi: int = int(dialog_data.get("player", -1))
	if pi < 0 or pi >= _gsm.game_state.players.size():
		return false
	var player: PlayerState = _gsm.game_state.players[pi]
	var choice: Dictionary = _setup_planner.plan_opening_setup(player)
	var active_hand_index: int = int(choice.get("active_hand_index", -1))
	if active_hand_index < 0 or active_hand_index >= player.hand.size():
		return false
	_planned_setup_bench_ids.clear()
	for hand_index: int in choice.get("bench_hand_indices", []):
		if hand_index >= 0 and hand_index < player.hand.size():
			_planned_setup_bench_ids.append(player.hand[hand_index].instance_id)
	var active_card: CardInstance = player.hand[active_hand_index]
	if not _gsm.setup_place_active_pokemon(pi, active_card):
		return false
	_after_setup_active(pi)
	return true


func _resolve_setup_bench(dialog_data: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	var pi: int = int(dialog_data.get("player", -1))
	if pi < 0 or pi >= _gsm.game_state.players.size():
		return false
	var player: PlayerState = _gsm.game_state.players[pi]
	var cards_raw: Array = dialog_data.get("cards", [])
	var available_cards: Array[CardInstance] = []
	for card_variant: Variant in cards_raw:
		if card_variant is CardInstance:
			available_cards.append(card_variant)
	var planned_card := _find_next_planned_bench_card(player, available_cards)
	if planned_card == null:
		_after_setup_bench(pi)
		return true
	if not _gsm.setup_place_bench_pokemon(pi, planned_card):
		return false
	_planned_setup_bench_ids.erase(planned_card.instance_id)
	_show_setup_bench_dialog(pi)
	return true


func _resolve_take_prize(dialog_data: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	var player_index: int = int(dialog_data.get("player", -1))
	if player_index < 0 or player_index >= _gsm.game_state.players.size():
		return false
	var layout: Array = _gsm.game_state.players[player_index].get_prize_layout()
	for slot_index: int in layout.size():
		if _gsm.resolve_take_prize(player_index, slot_index):
			return true
	return false


func _resolve_send_out(dialog_data: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	var send_out_player: int = int(dialog_data.get("player", -1))
	if send_out_player < 0 or send_out_player >= _gsm.game_state.players.size():
		return false
	var bench: Array[PokemonSlot] = _gsm.game_state.players[send_out_player].bench
	# 选最优：就绪攻击手（有能量+有伤害）> 有能量的 > 其他
	var best: PokemonSlot = null
	var best_score: float = -1.0
	for slot: PokemonSlot in bench:
		if slot == null or slot.get_top_card() == null:
			continue
		var score: float = 50.0
		var energy_count: int = slot.attached_energy.size()
		if energy_count >= 1:
			score = 200.0 + float(energy_count) * 20.0
		# 有能量且有攻击招式 → 更高优先
		var cd: CardData = slot.get_card_data()
		if cd != null and not cd.attacks.is_empty() and energy_count >= 1:
			score = maxf(score, 300.0 + float(energy_count) * 30.0)
		# ex/V 不想上前场挨打
		if cd != null and (cd.mechanic == "ex" or cd.mechanic == "V") and score < 200.0:
			score = 10.0
		if score > best_score:
			best_score = score
			best = slot
	if best != null:
		if _gsm.send_out_pokemon(send_out_player, best):
			return true
	# 兜底
	for bench_slot: PokemonSlot in bench:
		if _gsm.send_out_pokemon(send_out_player, bench_slot):
			return true
	return false


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


func _get_setup_resume_player_index() -> int:
	if _gsm == null or _gsm.game_state == null:
		return -1
	for pi: int in _gsm.game_state.players.size():
		if _gsm.game_state.players[pi] != null and _gsm.game_state.players[pi].active_pokemon == null:
			return pi
	return -1


func _get_effect_interaction_prompt_owner() -> int:
	if _dialog_data.has("chooser_player_index"):
		var chooser_player_index: int = int(_dialog_data.get("chooser_player_index", -1))
		if chooser_player_index >= 0:
			return chooser_player_index
	if _dialog_data.has("player"):
		var player_index: int = int(_dialog_data.get("player", -1))
		if player_index >= 0:
			if bool(_dialog_data.get("opponent_chooses", false)):
				return 1 - player_index
			return player_index
	if bool(_dialog_data.get("opponent_chooses", false)) and _gsm != null and _gsm.game_state != null:
		var current_player_index: int = int(_gsm.game_state.current_player_index)
		if current_player_index >= 0:
			return 1 - current_player_index
	return -1
