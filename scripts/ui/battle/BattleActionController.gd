class_name BattleActionController
extends RefCounted


func _bt(scene: Object, key: String, params: Dictionary = {}) -> String:
	return str(scene.call("_bt", key, params))


func on_hand_card_clicked(scene: Object, inst: CardInstance, _panel: PanelContainer) -> void:
	scene.call(
		"_runtime_log",
		"hand_card_clicked",
		"card=%s selected_before=%s %s" % [
			scene.call("_card_instance_label", inst),
			scene.call("_card_instance_label", scene.get("_selected_hand_card")),
			scene.call("_state_snapshot"),
		]
	)
	if not bool(scene.call("_can_accept_live_action")):
		return
	if bool(scene.call("_is_field_interaction_active")):
		return
	if scene.get("_selected_hand_card") == inst:
		scene.set("_selected_hand_card", null)
		scene.call("_refresh_hand")
		return

	var gsm: Variant = scene.get("_gsm")
	var current_player: int = gsm.game_state.current_player_index
	var card_data: CardData = inst.card_data
	if card_data.card_type == "Supporter":
		if gsm.rule_validator.can_play_supporter(gsm.game_state, current_player) or gsm._can_play_supporter_exception(current_player, inst):
			try_play_trainer_with_interaction(scene, current_player, inst)
		else:
			scene.call("_log", _bt(scene, "battle.log.supporter_unavailable"))
		return
	if card_data.card_type == "Item":
		try_play_trainer_with_interaction(scene, current_player, inst)
		return
	if card_data.card_type == "Stadium":
		try_play_stadium_with_interaction(scene, current_player, inst)
		return
	if card_data.is_basic_pokemon():
		scene.set("_selected_hand_card", inst)
		scene.call("_refresh_hand")
		scene.call("_log", _bt(scene, "battle.log.select_basic_to_bench", {"name": card_data.name}))
		return
	if card_data.is_pokemon() and card_data.stage != "Basic":
		scene.set("_selected_hand_card", inst)
		scene.call("_refresh_hand")
		scene.call("_log", _bt(scene, "battle.log.select_evolution_target", {"name": card_data.name}))
		return
	if card_data.card_type == "Basic Energy" or card_data.card_type == "Special Energy":
		scene.set("_selected_hand_card", inst)
		scene.call("_refresh_hand")
		scene.call("_log", _bt(scene, "battle.log.select_attach_energy_target", {"name": card_data.name}))
		return
	if card_data.card_type == "Tool":
		scene.set("_selected_hand_card", inst)
		scene.call("_refresh_hand")
		scene.call("_log", _bt(scene, "battle.log.select_attach_tool_target", {"name": card_data.name}))


func try_play_trainer_with_interaction(scene: Object, player_index: int, card: CardInstance) -> void:
	var gsm: Variant = scene.get("_gsm")
	var card_type: String = card.card_data.card_type
	if card_type == "Item" and not gsm.rule_validator.can_play_item(gsm.game_state, player_index):
		scene.call("_log", _bt(scene, "battle.log.card_currently_unavailable", {"name": card.card_data.name}))
		return
	if card_type == "Supporter":
		if not gsm.rule_validator.can_play_supporter(gsm.game_state, player_index) and not gsm._can_play_supporter_exception(player_index, card):
			scene.call("_log", _bt(scene, "battle.log.supporter_unavailable"))
			return
	var effect: BaseEffect = gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		if not gsm.play_trainer(player_index, card, []):
			scene.call("_log", _bt(scene, "battle.log.cannot_use_card", {"name": card.card_data.name}))
		else:
			scene.call("_refresh_ui_after_successful_action", false, player_index)
		return
	if not effect.can_execute(card, gsm.game_state):
		scene.call("_log", _bt(scene, "battle.log.card_currently_unavailable", {"name": card.card_data.name}))
		return
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	if steps.is_empty():
		if not gsm.play_trainer(player_index, card, []):
			scene.call("_log", _bt(scene, "battle.log.cannot_use_card", {"name": card.card_data.name}))
		else:
			var empty_message: String = effect.get_empty_interaction_message(card, gsm.game_state)
			if empty_message != "":
				scene.call("_log", empty_message)
			scene.call("_refresh_ui_after_successful_action", false, player_index)
		return
	scene.call("_start_effect_interaction", "trainer", player_index, steps, card)
	scene.call("_maybe_run_ai")


func try_play_stadium_with_interaction(scene: Object, player_index: int, card: CardInstance) -> void:
	var gsm: Variant = scene.get("_gsm")
	var effect: BaseEffect = gsm.effect_processor.get_effect(card.card_data.effect_id)
	if effect == null:
		if not gsm.play_stadium(player_index, card):
			scene.call("_log", _bt(scene, "battle.log.cannot_play_stadium"))
		else:
			scene.call("_refresh_ui_after_successful_action", false, player_index)
		return
	var steps: Array[Dictionary] = effect.get_on_play_interaction_steps(card, gsm.game_state)
	if steps.is_empty():
		if not gsm.play_stadium(player_index, card):
			scene.call("_log", _bt(scene, "battle.log.cannot_play_stadium"))
		else:
			scene.call("_refresh_ui_after_successful_action", false, player_index)
		return
	scene.call("_start_effect_interaction", "play_stadium", player_index, steps, card)
	scene.call("_maybe_run_ai")


func try_use_ability_with_interaction(scene: Object, player_index: int, slot: PokemonSlot, ability_index: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var card: CardInstance = gsm.effect_processor.get_ability_source_card(slot, ability_index, gsm.game_state)
	if card == null:
		return
	var effect: BaseEffect = gsm.effect_processor.get_ability_effect(slot, ability_index, gsm.game_state)
	if effect == null:
		if gsm.use_ability(player_index, slot, ability_index):
			scene.call("_refresh_ui_after_successful_action", true, player_index)
		else:
			scene.call("_log", _bt(scene, "battle.log.ability_unavailable", {"name": card.card_data.name}))
		return
	if not gsm.effect_processor.can_use_ability(slot, gsm.game_state, ability_index):
		scene.call("_log", _bt(scene, "battle.log.ability_unavailable", {"name": card.card_data.name}))
		return
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)
	if steps.is_empty():
		if gsm.use_ability(player_index, slot, ability_index):
			var ability_name: String = gsm.effect_processor.get_ability_name(slot, ability_index, gsm.game_state)
			scene.call("_log", _bt(scene, "battle.log.ability_used", {"name": ability_name}))
			scene.call("_refresh_ui_after_successful_action", true, player_index)
		else:
			scene.call("_log", _bt(scene, "battle.log.ability_unavailable", {"name": card.card_data.name}))
		return
	scene.call("_start_effect_interaction", "ability", player_index, steps, card, slot, ability_index)
	scene.call("_maybe_run_ai")


func try_use_stadium_with_interaction(scene: Object, player_index: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state.stadium_card == null:
		return
	var stadium_card: CardInstance = gsm.game_state.stadium_card
	var effect: BaseEffect = gsm.effect_processor.get_effect(stadium_card.card_data.effect_id)
	if effect == null:
		if gsm.use_stadium_effect(player_index):
			scene.call("_refresh_ui_after_successful_action", false, player_index)
		else:
			scene.call("_log", _bt(scene, "battle.log.stadium_unavailable"))
		return
	if not gsm.can_use_stadium_effect(player_index):
		scene.call("_log", _bt(scene, "battle.log.stadium_unavailable"))
		return
	var steps: Array[Dictionary] = effect.get_interaction_steps(stadium_card, gsm.game_state)
	if steps.is_empty():
		if gsm.use_stadium_effect(player_index):
			scene.call("_refresh_ui_after_successful_action", false, player_index)
		else:
			scene.call("_log", _bt(scene, "battle.log.stadium_unavailable"))
		return
	scene.call("_start_effect_interaction", "stadium", player_index, steps, stadium_card)
	scene.call("_maybe_run_ai")
