class_name EffectJacq
extends BaseEffect

const MAX_SEARCH_COUNT: int = 2


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data.is_evolution_pokemon():
			return true
	return false


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var found: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("evolution_pokemon", [])
	var has_explicit_selection: bool = ctx.has("evolution_pokemon")
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and entry.card_data.is_evolution_pokemon():
			found.append(entry)
			if found.size() >= MAX_SEARCH_COUNT:
				break

	if found.is_empty() and not has_explicit_selection:
		for deck_card: CardInstance in player.deck:
			if found.size() >= MAX_SEARCH_COUNT:
				break
			if deck_card.card_data.is_evolution_pokemon():
				found.append(deck_card)

	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		found,
		card,
		"trainer",
		"search_to_hand",
		["进化宝可梦"]
	)

	player.shuffle_deck()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data.is_evolution_pokemon():
			items.append(deck_card)
			labels.append(deck_card.card_data.name)
	if items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有进化宝可梦。你仍可以使用这张卡。")]
	return [{
		"id": "evolution_pokemon",
		"title": "Choose up to two Evolution Pokemon",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": mini(MAX_SEARCH_COUNT, items.size()),
		"allow_cancel": true,
	}]


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, player.deck)]


func get_description() -> String:
	return "Search your deck for up to two Evolution Pokemon."
