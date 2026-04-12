class_name BaseEffect
extends RefCounted

var _attack_interaction_context: Dictionary = {}

const EMPTY_SEARCH_CONTINUE := "continue"
const EMPTY_SEARCH_VIEW_DECK := "view_deck"


enum TargetType {
	NONE,
	OWN_ACTIVE,
	OPP_ACTIVE,
	OWN_BENCH,
	OPP_BENCH,
	OWN_ANY_POKEMON,
	OPP_ANY_POKEMON,
	ANY_POKEMON,
	HAND_CARD,
	DISCARD_CARD,
	ENERGY_ON_POKEMON,
	COIN_FLIP,
	PLAYER_CHOICE,
}


func get_target_type() -> TargetType:
	return TargetType.NONE


func get_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return []


func get_preview_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	return get_interaction_steps(card, state)


func get_empty_interaction_message(_card: CardInstance, _state: GameState) -> String:
	return ""


func get_attack_interaction_steps(
	_card: CardInstance,
	_attack: Dictionary,
	_state: GameState
) -> Array[Dictionary]:
	return []


func get_followup_attack_interaction_steps(
	_card: CardInstance,
	_attack: Dictionary,
	_state: GameState,
	_resolved_context: Dictionary
) -> Array[Dictionary]:
	return []


func get_followup_interaction_steps(
	_card: CardInstance,
	_state: GameState,
	_resolved_context: Dictionary
) -> Array[Dictionary]:
	return []


func get_interaction_context(targets: Array) -> Dictionary:
	if targets.is_empty():
		return {}
	var ctx: Variant = targets[0]
	return ctx.duplicate(false) if ctx is Dictionary else {}


func _draw_cards_with_log(
	state: GameState,
	player_index: int,
	count: int,
	source_card: CardInstance = null,
	source_kind: String = ""
) -> Array[CardInstance]:
	if state == null:
		return []
	var draw_processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if draw_processor != null and draw_processor.has_method("draw_cards_with_log"):
		return draw_processor.call("draw_cards_with_log", player_index, count, state, source_card, source_kind)
	if count <= 0:
		return []
	return state.players[player_index].draw_cards(count)


func _discard_cards_from_hand_with_log(
	state: GameState,
	player_index: int,
	cards: Array[CardInstance],
	source_card: CardInstance = null,
	source_kind: String = ""
) -> Array[CardInstance]:
	if state == null or cards.is_empty():
		return []
	var draw_processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if draw_processor != null and draw_processor.has_method("discard_cards_from_hand_with_log"):
		return draw_processor.call("discard_cards_from_hand_with_log", player_index, cards, state, source_card, source_kind)
	var player: PlayerState = state.players[player_index]
	var discarded: Array[CardInstance] = []
	for card: CardInstance in cards:
		if card == null or not (card in player.hand):
			continue
		player.remove_from_hand(card)
		player.discard_card(card)
		discarded.append(card)
	return discarded


func _move_public_cards_to_hand_with_log(
	state: GameState,
	player_index: int,
	cards: Array[CardInstance],
	source_card: CardInstance = null,
	source_kind: String = "",
	public_result_kind: String = "search_to_hand",
	public_result_labels: Array[String] = []
) -> Array[CardInstance]:
	if state == null or cards.is_empty():
		return []
	var draw_processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if draw_processor != null and draw_processor.has_method("move_public_cards_to_hand_with_log"):
		return draw_processor.call(
			"move_public_cards_to_hand_with_log",
			player_index,
			cards,
			state,
			source_card,
			source_kind,
			public_result_kind,
			public_result_labels
		)
	var player: PlayerState = state.players[player_index]
	var moved: Array[CardInstance] = []
	var seen_ids: Dictionary = {}
	for card: CardInstance in cards:
		if card == null or seen_ids.has(card.instance_id) or not (card in player.deck):
			continue
		seen_ids[card.instance_id] = true
		player.deck.erase(card)
		card.face_up = true
		player.hand.append(card)
		moved.append(card)
	return moved


func set_attack_interaction_context(targets: Array) -> void:
	_attack_interaction_context = get_interaction_context(targets)


func get_attack_interaction_context() -> Dictionary:
	return _attack_interaction_context


func clear_attack_interaction_context() -> void:
	_attack_interaction_context.clear()


func build_card_assignment_step(
	step_id: String,
	title: String,
	source_items: Array,
	source_labels: Array[String],
	target_items: Array,
	target_labels: Array[String],
	min_assignments: int,
	max_assignments: int,
	allow_cancel: bool = true
) -> Dictionary:
	return {
		"id": step_id,
		"title": title,
		"ui_mode": "card_assignment",
		"source_items": source_items,
		"source_labels": source_labels,
		"target_items": target_items,
		"target_labels": target_labels,
		"min_select": min_assignments,
		"max_select": max_assignments,
		"allow_cancel": allow_cancel,
	}


func can_execute(_card: CardInstance, _state: GameState) -> bool:
	return true


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return can_execute(card, state)


func execute(_card: CardInstance, _targets: Array, _state: GameState) -> void:
	pass


func get_on_play_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return []


func execute_on_play(_card: CardInstance, _state: GameState, _targets: Array = []) -> void:
	pass


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return false


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return ""


func build_empty_search_resolution_step(title: String) -> Dictionary:
	return build_empty_search_resolution_step_with_view_label(title, "查看牌库")


func build_empty_search_resolution_step_with_view_label(title: String, view_label: String) -> Dictionary:
	return {
		"id": "empty_search_resolution",
		"title": title,
		"items": [EMPTY_SEARCH_CONTINUE, EMPTY_SEARCH_VIEW_DECK],
		"labels": ["继续消耗", view_label],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}


func should_preview_empty_search_deck(resolved_context: Dictionary) -> bool:
	var selected_raw: Array = resolved_context.get("empty_search_resolution", [])
	if selected_raw.is_empty():
		return false
	return str(selected_raw[0]) == EMPTY_SEARCH_VIEW_DECK


func build_readonly_card_preview_step(
	title: String,
	cards: Array[CardInstance],
	close_label: String = "关闭并继续"
) -> Dictionary:
	var labels: Array[String] = []
	for card: CardInstance in cards:
		if card == null or card.card_data == null:
			labels.append("")
			continue
		if card.card_data.is_pokemon():
			labels.append("%s (HP %d)" % [card.card_data.name, card.card_data.hp])
		else:
			labels.append(card.card_data.name)
	return {
		"id": "empty_search_view_deck",
		"title": title,
		"items": cards.duplicate(),
		"labels": labels,
		"min_select": 0,
		"max_select": 0,
		"allow_cancel": false,
		"presentation": "cards",
		"utility_actions": [{"label": close_label, "index": -1}],
	}


func build_readonly_deck_preview_step(title: String, deck_cards: Array[CardInstance]) -> Dictionary:
	return build_readonly_card_preview_step(title, deck_cards)
