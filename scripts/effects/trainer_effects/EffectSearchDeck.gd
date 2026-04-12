class_name EffectSearchDeck
extends BaseEffect

var search_count: int = 1
var discard_cost: int = 0
var card_type_filter: String = ""
var require_coin_flip: bool = false


func _init(count: int = 1, discard: int = 0, filter: String = "", coin: bool = false) -> void:
	search_count = count
	discard_cost = discard
	card_type_filter = filter
	require_coin_flip = coin


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return _can_pay_discard_cost(card, player) and not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return _can_pay_discard_cost(card, player) and not _get_matching_cards(player).is_empty()


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
			"title": "选择要弃置的%d张手牌" % discard_cost,
			"items": hand_items,
			"labels": hand_labels,
			"min_select": discard_cost,
			"max_select": discard_cost,
			"allow_cancel": true,
		})

	var deck_items: Array = _get_matching_cards(player)
	if deck_items.is_empty():
		steps.append(build_empty_search_resolution_step("牌库里没有可检索的%s。你仍可以使用这张卡。" % _get_filter_label()))
		return steps

	var deck_labels: Array[String] = []
	for deck_card: CardInstance in deck_items:
		deck_labels.append(deck_card.card_data.name)
	steps.append({
		"id": "search_cards",
		"title": "选择最多%d张符合条件的卡" % search_count,
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

	var found: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("search_cards", [])
	var has_explicit_selection: bool = ctx.has("search_cards")
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _matches_filter(entry):
			found.append(entry)
			if found.size() >= search_count:
				break
	if found.is_empty() and not has_explicit_selection:
		for deck_card: CardInstance in _get_matching_cards(player):
			found.append(deck_card)
			if found.size() >= search_count:
				break

	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		found,
		card,
		"trainer",
		"search_to_hand",
		[_get_filter_label()]
	)

	player.shuffle_deck()


func _matches_filter(card: CardInstance) -> bool:
	if card_type_filter == "":
		return true
	var cd: CardData = card.card_data
	match card_type_filter:
		"Pokemon":
			return cd.is_pokemon()
		"Basic":
			return cd.is_basic_pokemon()
		"Trainer":
			return cd.is_trainer()
		"Energy":
			return cd.is_energy()
		"Item":
			return cd.card_type == "Item"
		"Supporter":
			return cd.card_type == "Supporter"
		_:
			return cd.card_type == card_type_filter


func get_description() -> String:
	var parts: Array[String] = []
	if discard_cost > 0:
		parts.append("弃掉%d张手牌" % discard_cost)
	var filter_str: String = ""
	if card_type_filter != "":
		var filter_map := {
			"Pokemon": "宝可梦",
			"Basic": "基础宝可梦",
			"Trainer": "训练家",
			"Energy": "能量",
			"Item": "物品",
			"Supporter": "支援者",
		}
		filter_str = filter_map.get(card_type_filter, card_type_filter)
	parts.append("从牌库检索%d张%s" % [search_count, filter_str])
	return "，".join(parts)


func _can_pay_discard_cost(card: CardInstance, player: PlayerState) -> bool:
	var available_hand_cards: int = 0
	for hand_card: CardInstance in player.hand:
		if hand_card != card:
			available_hand_cards += 1
	return available_hand_cards >= discard_cost


func _get_matching_cards(player: PlayerState) -> Array:
	var matches: Array = []
	for deck_card: CardInstance in player.deck:
		if _matches_filter(deck_card):
			matches.append(deck_card)
	return matches


func _get_filter_label() -> String:
	match card_type_filter:
		"Pokemon":
			return "宝可梦"
		"Basic":
			return "基础宝可梦"
		"Trainer":
			return "训练家"
		"Energy":
			return "能量"
		"Item":
			return "物品"
		"Supporter":
			return "支援者"
		_:
			return "卡牌" if card_type_filter == "" else card_type_filter
