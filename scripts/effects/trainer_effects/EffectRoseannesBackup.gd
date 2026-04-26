class_name EffectRoseannesBackup
extends BaseEffect

const STEP_ID := "roseannes_backup_cards"


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not _get_candidates(state.players[card.owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = _get_candidates(player)
	var labels: Array[String] = []
	for discard_card: CardInstance in items:
		labels.append("%s - %s" % [_category(discard_card), discard_card.card_data.name])
	return [{
		"id": STEP_ID,
		"title": "Choose up to 1 Pokemon, Tool, Stadium, and Energy from discard",
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(4, items.size()),
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var chosen: Array[CardInstance] = []
	var used_categories: Dictionary = {}
	for entry: Variant in ctx.get(STEP_ID, []):
		if not (entry is CardInstance):
			continue
		var discard_card: CardInstance = entry
		var cat: String = _category(discard_card)
		if cat == "" or used_categories.has(cat) or discard_card not in player.discard_pile:
			continue
		chosen.append(discard_card)
		used_categories[cat] = true
	if chosen.is_empty() and not ctx.has(STEP_ID):
		for discard_card: CardInstance in _get_candidates(player):
			var cat: String = _category(discard_card)
			if used_categories.has(cat):
				continue
			chosen.append(discard_card)
			used_categories[cat] = true
	for discard_card: CardInstance in chosen:
		player.discard_pile.erase(discard_card)
		discard_card.face_up = false
		player.deck.append(discard_card)
	player.shuffle_deck()


func _get_candidates(player: PlayerState) -> Array:
	var result: Array = []
	for discard_card: CardInstance in player.discard_pile:
		if _category(discard_card) != "":
			result.append(discard_card)
	return result


func _category(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	var cd: CardData = card.card_data
	if cd.is_pokemon():
		return "Pokemon"
	if cd.card_type == "Tool":
		return "Tool"
	if cd.card_type == "Stadium":
		return "Stadium"
	if cd.is_energy():
		return "Energy"
	return ""
