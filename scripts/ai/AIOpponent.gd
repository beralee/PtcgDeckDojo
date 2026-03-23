class_name AIOpponent
extends RefCounted

const AISetupPlannerScript = preload("res://scripts/ai/AISetupPlanner.gd")

var player_index: int = 1
var difficulty: int = 1
var _setup_planner = AISetupPlannerScript.new()
var _planned_setup_bench_ids: Array[int] = []


func configure(next_player_index: int, next_difficulty: int) -> void:
	player_index = next_player_index
	difficulty = next_difficulty


func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
	if game_state == null or ui_blocked:
		return false
	return game_state.current_player_index == player_index


func run_single_step(battle_scene: Control, gsm: GameStateMachine) -> bool:
	if battle_scene == null or gsm == null or gsm.game_state == null:
		return false
	var pending_choice := str(battle_scene.get("_pending_choice"))
	if pending_choice == "mulligan_extra_draw":
		var dialog_data: Dictionary = battle_scene.get("_dialog_data")
		gsm.resolve_mulligan_choice(int(dialog_data.get("beneficiary", player_index)), _setup_planner.choose_mulligan_bonus_draw())
		return true
	if pending_choice.begins_with("setup_active_"):
		return _run_setup_active_step(battle_scene, gsm, pending_choice)
	if pending_choice.begins_with("setup_bench_"):
		return _run_setup_bench_step(battle_scene, gsm, pending_choice)
	return false


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


func _run_setup_bench_step(battle_scene: Control, gsm: GameStateMachine, pending_choice: String) -> bool:
	var pi: int = int(pending_choice.split("_")[-1])
	if pi != player_index or pi >= gsm.game_state.players.size():
		return false
	var player: PlayerState = gsm.game_state.players[pi]
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
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
