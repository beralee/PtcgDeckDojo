## Ultra Ball - discard 2 cards, then search for a Pokemon
class_name EffectUltraBall
extends BaseEffect


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var hand_labels: Array[String] = []
	var hand_items: Array = []
	for c: CardInstance in player.hand:
		if c == card:
			continue
		hand_items.append(c)
		hand_labels.append(c.card_data.name)
	var pokemon_labels: Array[String] = []
	var pokemon_items: Array = []
	for c: CardInstance in player.deck:
		if c.card_data.is_pokemon():
			pokemon_items.append(c)
			pokemon_labels.append(c.card_data.name)
	return [
		{
			"id": "discard_cards",
			"title": "Choose 2 cards to discard",
			"items": hand_items,
			"labels": hand_labels,
			"min_select": 2,
			"max_select": 2,
			"allow_cancel": true,
		},
		{
			"id": "search_pokemon",
			"title": "Choose a Pokemon",
			"items": pokemon_items,
			"labels": pokemon_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	var other_hand_cards: int = 0
	for hand_card: CardInstance in player.hand:
		if hand_card != card:
			other_hand_cards += 1
	if other_hand_cards < 2:
		return false
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data.is_pokemon():
			return true
	return false


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)

	var discard_cards_raw: Array = ctx.get("discard_cards", [])
	var discard_cards: Array[CardInstance] = []
	for c: Variant in discard_cards_raw:
		if c is CardInstance and c in player.hand:
			discard_cards.append(c)
	if discard_cards.size() < 2:
		for hand_card: CardInstance in player.hand:
			if discard_cards.size() >= 2:
				break
			if hand_card != card and hand_card not in discard_cards:
				discard_cards.append(hand_card)

	for discarded: CardInstance in discard_cards:
		if discarded in player.hand:
			player.hand.erase(discarded)
			player.discard_pile.append(discarded)

	var selected_pokemon: CardInstance = null
	var selected_raw: Array = ctx.get("search_pokemon", [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var chosen: CardInstance = selected_raw[0]
		if chosen in player.deck and chosen.card_data.is_pokemon():
			selected_pokemon = chosen

	if selected_pokemon == null:
		for deck_card: CardInstance in player.deck:
			if deck_card.card_data.is_pokemon():
				selected_pokemon = deck_card
				break

	if selected_pokemon != null:
		player.deck.erase(selected_pokemon)
		selected_pokemon.face_up = true
		player.hand.append(selected_pokemon)

	player.shuffle_deck()


func get_description() -> String:
	return "Discard 2 cards from your hand. Search your deck for a Pokemon."
