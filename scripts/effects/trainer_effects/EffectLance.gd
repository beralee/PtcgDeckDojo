class_name EffectLance
extends BaseEffect

const DRAGON_TYPE: String = "N"
const MAX_SEARCH_COUNT: int = 3


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for deck_card: CardInstance in player.deck:
		if _is_dragon_pokemon(deck_card):
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		if not _is_dragon_pokemon(deck_card):
			continue
		items.append(deck_card)
		labels.append(deck_card.card_data.name)
	if items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有龙属性宝可梦。你仍可以使用这张卡。")]
	return [{
		"id": "dragon_pokemon",
		"title": "Choose up to 3 Dragon Pokemon",
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(MAX_SEARCH_COUNT, items.size()),
		"allow_cancel": true,
	}]


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, player.deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("dragon_pokemon", [])
	var has_explicit_selection: bool = ctx.has("dragon_pokemon")
	var found: Array[CardInstance] = []

	for entry: Variant in selected_raw:
		if not (entry is CardInstance):
			continue
		var selected: CardInstance = entry
		if selected in player.deck and _is_dragon_pokemon(selected) and selected not in found:
			found.append(selected)
			if found.size() >= MAX_SEARCH_COUNT:
				break

	if found.is_empty() and not has_explicit_selection:
		for deck_card: CardInstance in player.deck:
			if not _is_dragon_pokemon(deck_card):
				continue
			found.append(deck_card)
			if found.size() >= MAX_SEARCH_COUNT:
				break

	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		found,
		card,
		"trainer",
		"search_to_hand",
		["龙属性宝可梦"]
	)

	player.shuffle_deck()


func _is_dragon_pokemon(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.is_pokemon() and card.card_data.energy_type == DRAGON_TYPE


func get_description() -> String:
	return "Search your deck for up to 3 Dragon Pokemon."
