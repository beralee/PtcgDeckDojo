class_name EffectTeamYellsCheer
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not _get_valid_targets(card, state).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var items: Array = _get_valid_targets(card, state)
	if items.is_empty():
		return []
	var labels: Array[String] = []
	for discard_card: CardInstance in items:
		labels.append(discard_card.card_data.name)
	return [{
		"id": "return_cards",
		"title": "选择最多3张宝可梦或支援者放回牌库",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": mini(3, items.size()),
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("return_cards", [])
	var chosen: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.discard_pile and _is_valid_target(card, entry) and not chosen.has(entry):
			chosen.append(entry)
			if chosen.size() >= 3:
				break
	if chosen.is_empty():
		for discard_card: CardInstance in _get_valid_targets(card, state):
			chosen.append(discard_card)
			if chosen.size() >= 3:
				break
	for discard_card: CardInstance in chosen:
		player.discard_pile.erase(discard_card)
		discard_card.face_up = false
		player.deck.append(discard_card)
	player.shuffle_deck()


func get_description() -> String:
	return "选择自己弃牌区中的宝可梦和支援者（除「呐喊队的应援」外）合计最多3张，在给对手看过之后，放回牌库并重洗牌库。"


func _get_valid_targets(card: CardInstance, state: GameState) -> Array:
	var player: PlayerState = state.players[card.owner_index]
	var result: Array = []
	for discard_card: CardInstance in player.discard_pile:
		if _is_valid_target(card, discard_card):
			result.append(discard_card)
	return result


func _is_valid_target(card: CardInstance, discard_card: CardInstance) -> bool:
	if discard_card == null or discard_card.card_data == null:
		return false
	if discard_card.card_data.is_pokemon():
		return true
	if discard_card.card_data.card_type == "Supporter":
		return discard_card.card_data.name != card.card_data.name
	return false
