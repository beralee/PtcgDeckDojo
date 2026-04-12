class_name EffectSearchBasicEnergy
extends BaseEffect

var search_count: int = 2
var discard_cost: int = 0


func _init(count: int = 2, cost: int = 0) -> void:
	search_count = count
	discard_cost = cost


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return _can_pay_discard_cost(card, player) and not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return _can_pay_discard_cost(card, player) and not _get_basic_energy_cards(player).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var steps: Array[Dictionary] = []

	if discard_cost > 0:
		var hand_items: Array = []
		var hand_labels: Array[String] = []
		for hand_card: CardInstance in player.hand:
			if hand_card == card:
				continue
			hand_items.append(hand_card)
			hand_labels.append(hand_card.card_data.name)
		steps.append({
			"id": "discard_cards",
			"title": "Choose %d cards to discard" % discard_cost,
			"items": hand_items,
			"labels": hand_labels,
			"min_select": discard_cost,
			"max_select": discard_cost,
			"allow_cancel": true,
		})

	var deck_items: Array = _get_basic_energy_cards(player)
	if deck_items.is_empty():
		steps.append(build_empty_search_resolution_step("牌库里没有基础能量。你仍可以使用这张卡。"))
		return steps

	var deck_labels: Array[String] = []
	for deck_card: CardInstance in deck_items:
		deck_labels.append(deck_card.card_data.name)
	steps.append({
		"id": "search_energy",
		"title": "Choose up to %d Basic Energy cards" % search_count,
		"items": deck_items,
		"labels": deck_labels,
		"min_select": 0,
		"max_select": mini(search_count, deck_items.size()),
		"allow_cancel": true,
	})
	return steps


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, player.deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var discard_cards: Array[CardInstance] = []
	var discard_raw: Array = ctx.get("discard_cards", [])
	for entry: Variant in discard_raw:
		if entry is CardInstance and entry in player.hand and entry != card and entry not in discard_cards:
			discard_cards.append(entry)
			if discard_cards.size() >= discard_cost:
				break
	if discard_cards.size() < discard_cost:
		for hand_card: CardInstance in player.hand:
			if discard_cards.size() >= discard_cost:
				break
			if hand_card != card and hand_card not in discard_cards:
				discard_cards.append(hand_card)
	_discard_cards_from_hand_with_log(state, card.owner_index, discard_cards, card, "trainer")

	var selected_energy: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("search_energy", [])
	var has_explicit_selection: bool = ctx.has("search_energy")
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _is_basic_energy(entry):
			selected_energy.append(entry)
			if selected_energy.size() >= search_count:
				break
	if selected_energy.is_empty() and not has_explicit_selection:
		for deck_card: CardInstance in _get_basic_energy_cards(player):
			selected_energy.append(deck_card)
			if selected_energy.size() >= search_count:
				break

	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		selected_energy,
		card,
		"trainer",
		"search_to_hand",
		["基本能量"]
	)

	player.shuffle_deck()


func _is_basic_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	return card.card_data.card_type == "Basic Energy"


func get_description() -> String:
	if discard_cost > 0:
		return "Discard %d card(s), then search your deck for up to %d Basic Energy cards." % [discard_cost, search_count]
	return "Search your deck for up to %d Basic Energy cards." % search_count


func _can_pay_discard_cost(card: CardInstance, player: PlayerState) -> bool:
	var other_hand_cards: int = 0
	for hand_card: CardInstance in player.hand:
		if hand_card != card:
			other_hand_cards += 1
	return other_hand_cards >= discard_cost


func _get_basic_energy_cards(player: PlayerState) -> Array:
	var deck_items: Array = []
	for deck_card: CardInstance in player.deck:
		if _is_basic_energy(deck_card):
			deck_items.append(deck_card)
	return deck_items
