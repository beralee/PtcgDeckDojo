## 派帕 - 从牌库检索物品卡和宝可梦道具各1张，加入手牌
class_name EffectArven
extends BaseEffect


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var item_cards: Array = []
	var item_labels: Array[String] = []
	var tool_cards: Array = []
	var tool_labels: Array[String] = []
	for c: CardInstance in player.deck:
		if c.card_data.card_type == "Item":
			item_cards.append(c)
			item_labels.append(c.card_data.name)
		elif c.card_data.card_type == "Tool":
			tool_cards.append(c)
			tool_labels.append(c.card_data.name)
	var steps: Array[Dictionary] = []
	if not item_cards.is_empty():
		steps.append({
			"id": "search_item",
			"title": "选择1张物品卡加入手牌",
			"items": item_cards,
			"labels": item_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		})
	if not tool_cards.is_empty():
		steps.append({
			"id": "search_tool",
			"title": "选择1张宝可梦道具加入手牌",
			"items": tool_cards,
			"labels": tool_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		})
	return steps


func can_execute(card: CardInstance, state: GameState) -> bool:
	## 牌库中至少有物品卡或宝可梦道具才可使用
	var player: PlayerState = state.players[card.owner_index]
	for c: CardInstance in player.deck:
		if c.card_data.card_type == "Item" or c.card_data.card_type == "Tool":
			return true
	return false


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(_targets)

	var found_item: CardInstance = null
	var found_tool: CardInstance = null
	var item_raw: Array = ctx.get("search_item", [])
	if not item_raw.is_empty() and item_raw[0] is CardInstance:
		var selected_item: CardInstance = item_raw[0]
		if selected_item in player.deck and selected_item.card_data.card_type == "Item":
			found_item = selected_item
	var tool_raw: Array = ctx.get("search_tool", [])
	if not tool_raw.is_empty() and tool_raw[0] is CardInstance:
		var selected_tool: CardInstance = tool_raw[0]
		if selected_tool in player.deck and selected_tool.card_data.card_type == "Tool":
			found_tool = selected_tool

	for c: CardInstance in player.deck:
		if found_item == null and c.card_data.card_type == "Item":
			found_item = c
		if found_tool == null and c.card_data.card_type == "Tool":
			found_tool = c
		if found_item != null and found_tool != null:
			break

	## 将检索到的卡牌移出牌库并加入手牌
	if found_item != null:
		player.deck.erase(found_item)
		found_item.face_up = true
		player.hand.append(found_item)

	if found_tool != null:
		player.deck.erase(found_tool)
		found_tool.face_up = true
		player.hand.append(found_tool)

	## 检索后洗牌
	player.shuffle_deck()


func get_description() -> String:
	return "从牌库检索物品卡和宝可梦道具各1张加入手牌"
