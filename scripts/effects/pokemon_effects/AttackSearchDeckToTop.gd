class_name AttackSearchDeckToTop
extends BaseEffect

var search_count: int = 1


func _init(count: int = 1) -> void:
	search_count = count


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return []

	var items: Array = []
	var labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		items.append(deck_card)
		labels.append("%s [%s]" % [deck_card.card_data.name, deck_card.card_data.card_type])

	return [{
		"id": "search_cards",
		"title": "从牌库中选择1张牌放回牌库顶",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": mini(search_count, items.size()),
		"allow_cancel": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	if player.deck.is_empty():
		return

	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("search_cards", [])
	var chosen: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and entry not in chosen:
			chosen.append(entry)
			if chosen.size() >= search_count:
				break

	if chosen.is_empty():
		chosen.append(player.deck[0])

	for card: CardInstance in chosen:
		player.deck.erase(card)

	player.shuffle_deck()

	for i: int in range(chosen.size() - 1, -1, -1):
		player.deck.push_front(chosen[i])


func get_description() -> String:
	return "Search your deck for up to %d card and place it on top of your deck." % search_count
