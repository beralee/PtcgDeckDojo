class_name EffectTrekkingShoes
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not state.players[card.owner_index].deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return []
	var top_card: CardInstance = player.deck[0]
	return [{
		"id": "trekking_choice",
		"title": "健行鞋：查看牌库顶的卡",
		"items": ["take", "discard"],
		"labels": [top_card.card_data.name],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
		"presentation": "cards",
		"card_items": [top_card],
		"card_indices": [0],
		"card_click_selectable": false,
		"utility_actions": [
			{"label": "加入手牌", "index": 0},
			{"label": "丢弃并再抽1张", "index": 1},
		],
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return
	var top_card: CardInstance = player.deck.pop_front()
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("trekking_choice", [])
	var choice: String = "take"
	if not selected_raw.is_empty():
		choice = str(selected_raw[0])

	if choice == "discard":
		top_card.face_up = true
		player.discard_pile.append(top_card)
		_draw_cards_with_log(state, card.owner_index, 1, card, "trainer")
		return

	top_card.face_up = true
	player.hand.append(top_card)


func get_description() -> String:
	return "查看自己牌库顶的 1 张卡。你可以将那张卡加入手牌；若不加入，则将其丢弃并抽 1 张牌。"
