class_name EffectArven
extends BaseEffect


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var item_cards: Array = []
	var item_labels: Array[String] = []
	var tool_cards: Array = []
	var tool_labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data.card_type == "Item":
			item_cards.append(deck_card)
			item_labels.append(deck_card.card_data.name)
		elif deck_card.card_data.card_type == "Tool":
			tool_cards.append(deck_card)
			tool_labels.append(deck_card.card_data.name)
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
	if steps.is_empty():
		return [build_empty_search_resolution_step("牌库里没有物品卡或宝可梦道具。你仍可以使用这张卡。")]
	return steps


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data.card_type == "Item" or deck_card.card_data.card_type == "Tool":
			return true
	return false


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	var player: PlayerState = state.players[card.owner_index]
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, player.deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

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

	for deck_card: CardInstance in player.deck:
		if found_item == null and deck_card.card_data.card_type == "Item":
			found_item = deck_card
		if found_tool == null and deck_card.card_data.card_type == "Tool":
			found_tool = deck_card
		if found_item != null and found_tool != null:
			break

	var revealed_cards: Array[CardInstance] = []
	var public_labels: Array[String] = []
	if found_item != null:
		revealed_cards.append(found_item)
		public_labels.append("物品")
	if found_tool != null:
		revealed_cards.append(found_tool)
		public_labels.append("宝可梦道具")
	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		revealed_cards,
		card,
		"trainer",
		"search_to_hand",
		public_labels
	)

	player.shuffle_deck()


func get_description() -> String:
	return "从牌库检索物品卡和宝可梦道具各1张加入手牌。"
