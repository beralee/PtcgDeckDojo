## 厉害钓竿 - 从弃牌区选择宝可梦和基本能量合计最多3张放回牌库
class_name EffectSuperRod
extends BaseEffect


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for c: CardInstance in player.discard_pile:
		if c.card_data.is_pokemon() or c.card_data.card_type == "Basic Energy":
			items.append(c)
			labels.append(c.card_data.name)
	return [{
		"id": "cards_to_return",
		"title": "选择最多3张宝可梦或基本能量放回牌库",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": mini(3, items.size()),
		"allow_cancel": true,
	}]


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for c: CardInstance in player.discard_pile:
		if c.card_data.is_pokemon() or c.card_data.card_type == "Basic Energy":
			return true
	return false


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(_targets)

	var to_return: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("cards_to_return", [])
	for c: Variant in selected_raw:
		if c is CardInstance and c in player.discard_pile:
			if c.card_data.is_pokemon() or c.card_data.card_type == "Basic Energy":
				to_return.append(c)
				if to_return.size() >= 3:
					break

	if to_return.is_empty():
		for c: CardInstance in player.discard_pile:
			if to_return.size() >= 3:
				break
			if c.card_data.is_pokemon() or c.card_data.card_type == "Basic Energy":
				to_return.append(c)

	for c: CardInstance in to_return:
		player.discard_pile.erase(c)
		c.face_up = false
		player.deck.append(c)

	player.shuffle_deck()


func get_description() -> String:
	return "从弃牌区选择宝可梦和基本能量合计最多3张放回牌库"
