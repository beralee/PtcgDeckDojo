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
		"title": "Top card: %s" % top_card.card_data.name,
		"items": ["take", "discard"],
		"labels": ["Put it into hand", "Discard it and draw 1 card"],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
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
		player.draw_cards(1)
		return

	top_card.face_up = true
	player.hand.append(top_card)


func get_description() -> String:
	return "Look at the top card of your deck. Put it into your hand, or discard it and draw a card."
