class_name EffectUltraBall
extends BaseEffect

const DISCARD_COUNT := 2


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var hand_labels: Array[String] = []
	var hand_items: Array = []
	for hand_card: CardInstance in player.hand:
		if hand_card == card:
			continue
		hand_items.append(hand_card)
		hand_labels.append(hand_card.card_data.name)

	var pokemon_items: Array = _get_pokemon_cards(player)
	var pokemon_labels: Array[String] = []
	for pokemon_card: CardInstance in pokemon_items:
		pokemon_labels.append(pokemon_card.card_data.name)

	var steps: Array[Dictionary] = [{
		"id": "discard_cards",
		"title": "Choose 2 cards to discard",
		"items": hand_items,
		"labels": hand_labels,
		"min_select": DISCARD_COUNT,
		"max_select": DISCARD_COUNT,
		"allow_cancel": true,
	}]
	if pokemon_items.is_empty():
		steps.append(build_empty_search_resolution_step("牌库里没有宝可梦。你仍可以使用这张卡。"))
		return steps
	steps.append({
		"id": "search_pokemon",
		"title": "Choose a Pokemon",
		"items": pokemon_items,
		"labels": pokemon_labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	})
	return steps


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return _can_pay_discard_cost(card, player) and not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return _can_pay_discard_cost(card, player) and not _get_pokemon_cards(player).is_empty()


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, player.deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var discard_cards: Array[CardInstance] = []
	var discard_cards_raw: Array = ctx.get("discard_cards", [])
	for entry: Variant in discard_cards_raw:
		if entry is CardInstance and entry in player.hand and entry != card and entry not in discard_cards:
			discard_cards.append(entry)
	if discard_cards.size() < DISCARD_COUNT:
		for hand_card: CardInstance in player.hand:
			if discard_cards.size() >= DISCARD_COUNT:
				break
			if hand_card != card and hand_card not in discard_cards:
				discard_cards.append(hand_card)

	_discard_cards_from_hand_with_log(state, card.owner_index, discard_cards, card, "trainer")

	var selected_pokemon: CardInstance = null
	var selected_raw: Array = ctx.get("search_pokemon", [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var chosen: CardInstance = selected_raw[0]
		if chosen in player.deck and chosen.card_data.is_pokemon():
			selected_pokemon = chosen

	if selected_pokemon == null:
		for deck_card: CardInstance in _get_pokemon_cards(player):
			selected_pokemon = deck_card
			break

	if selected_pokemon != null:
		_move_public_cards_to_hand_with_log(
			state,
			card.owner_index,
			[selected_pokemon],
			card,
			"trainer",
			"search_to_hand",
			["宝可梦"]
		)

	player.shuffle_deck()


func get_description() -> String:
	return "Discard 2 cards from your hand. Search your deck for a Pokemon."


func _can_pay_discard_cost(card: CardInstance, player: PlayerState) -> bool:
	var other_hand_cards: int = 0
	for hand_card: CardInstance in player.hand:
		if hand_card != card:
			other_hand_cards += 1
	return other_hand_cards >= DISCARD_COUNT


func _get_pokemon_cards(player: PlayerState) -> Array:
	var pokemon_items: Array = []
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data.is_pokemon():
			pokemon_items.append(deck_card)
	return pokemon_items
