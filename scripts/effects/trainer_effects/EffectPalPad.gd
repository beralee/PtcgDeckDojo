## 朋友手册 - 从弃牌区选择最多2张支援者放回牌库
class_name EffectPalPad
extends BaseEffect


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for c: CardInstance in player.discard_pile:
		if c.card_data.card_type == "Supporter":
			items.append(c)
			labels.append(c.card_data.name)
	return [{
		"id": "supporters_to_return",
		"title": "选择最多2张支援者放回牌库",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": mini(2, items.size()),
		"allow_cancel": true,
	}]


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for c: CardInstance in player.discard_pile:
		if c.card_data.card_type == "Supporter":
			return true
	return false


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(_targets)

	var to_return: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("supporters_to_return", [])
	for c: Variant in selected_raw:
		if c is CardInstance and c in player.discard_pile and c.card_data.card_type == "Supporter":
			to_return.append(c)
			if to_return.size() >= 2:
				break

	if to_return.is_empty():
		for c: CardInstance in player.discard_pile:
			if to_return.size() >= 2:
				break
			if c.card_data.card_type == "Supporter":
				to_return.append(c)

	for c: CardInstance in to_return:
		player.discard_pile.erase(c)
		c.face_up = false
		player.deck.append(c)

	player.shuffle_deck()


func get_description() -> String:
	return "从弃牌区选择最多2张支援者放回牌库"
