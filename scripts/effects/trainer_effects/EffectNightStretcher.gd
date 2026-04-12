class_name EffectNightStretcher
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for discard_card: CardInstance in player.discard_pile:
		if discard_card.card_data.is_pokemon():
			return true
		if discard_card.card_data.card_type == "Basic Energy":
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for discard_card: CardInstance in player.discard_pile:
		if discard_card.card_data.is_pokemon():
			items.append(discard_card)
			labels.append("%s [宝可梦]" % discard_card.card_data.name)
		elif discard_card.card_data.card_type == "Basic Energy":
			items.append(discard_card)
			labels.append("%s [基本能量]" % discard_card.card_data.name)

	return [{
		"id": "night_stretcher_choice",
		"title": "选择弃牌区中的 1 张宝可梦或基本能量加入手牌",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	var recover_card: CardInstance = null
	if ctx.has("night_stretcher_choice"):
		var selected_raw: Array = ctx.get("night_stretcher_choice", [])
		if not selected_raw.is_empty():
			var selected: Variant = selected_raw[0]
			if selected is CardInstance:
				recover_card = selected
			elif selected is Dictionary:
				recover_card = selected.get("card", null)

	if recover_card == null or recover_card not in player.discard_pile:
		return

	player.discard_pile.erase(recover_card)
	recover_card.face_up = true
	player.hand.append(recover_card)


func get_description() -> String:
	return "选择自己弃牌区中的 1 张宝可梦或 1 张基本能量，加入手牌。"
