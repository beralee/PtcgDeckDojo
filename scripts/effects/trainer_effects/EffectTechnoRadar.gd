## Techno Radar - discard 2 cards, then search for up to 2 Future Pokemon
class_name EffectTechnoRadar
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
		if _is_future(c.card_data):
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
			"id": "search_future_pokemon",
			"title": "Choose up to 2 Future Pokemon",
			"items": pokemon_items,
			"labels": pokemon_labels,
			"min_select": 0,
			"max_select": mini(2, pokemon_items.size()),
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
		if _is_future(deck_card.card_data):
			return true
	return false


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)

	var discard_cards_raw: Array = ctx.get("discard_cards", [])
	var discard_cards: Array[CardInstance] = []
	for c: Variant in discard_cards_raw:
		if c is CardInstance and c in player.hand and c != card:
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

	var selected_raw: Array = ctx.get("search_future_pokemon", [])
	var selected_cards: Array[CardInstance] = []
	for c: Variant in selected_raw:
		if c is CardInstance and c in player.deck and _is_future(c.card_data):
			selected_cards.append(c)
		if selected_cards.size() >= 2:
			break

	if selected_cards.is_empty():
		for deck_card: CardInstance in player.deck:
			if _is_future(deck_card.card_data):
				selected_cards.append(deck_card)
			if selected_cards.size() >= 2:
				break

	for selected: CardInstance in selected_cards:
		if selected in player.deck:
			player.deck.erase(selected)
			selected.face_up = true
			player.hand.append(selected)

	player.shuffle_deck()


func _is_future(cd: CardData) -> bool:
	return cd != null and cd.is_future_pokemon()


func get_description() -> String:
	return "Discard 2 cards from your hand. Search your deck for up to 2 Future Pokemon."
