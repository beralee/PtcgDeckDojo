## 枇琶 - 查看对手手牌，弃掉最多2张物品卡
class_name EffectEri
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var opp: PlayerState = state.players[1 - card.owner_index]
	return not opp.hand.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opp: PlayerState = state.players[1 - card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for c: CardInstance in opp.hand:
		if c.card_data != null and c.card_data.card_type == "Item":
			items.append(c)
			labels.append(c.card_data.name)
	if items.is_empty():
		return []
	var max_sel: int = mini(2, items.size())
	return [{
		"id": "discard_items",
		"title": "选择对手手牌中最多2张物品弃掉",
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": max_sel,
		"allow_cancel": true,
		"opponent_chooses": false,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var opp: PlayerState = state.players[1 - card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var raw: Array = ctx.get("discard_items", [])
	var discarded := 0
	for item: Variant in raw:
		if discarded >= 2:
			break
		if item is CardInstance and item in opp.hand and item.card_data.card_type == "Item":
			var resolved: Array[CardInstance] = _discard_cards_from_hand_with_log(state, opp.player_index, [item], card, "trainer")
			if not resolved.is_empty():
				discarded += 1


func get_description() -> String:
	return "查看对手手牌，弃掉最多2张物品卡"
