class_name EffectXerosicsMachinations
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	return opponent.hand.size() > 3


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var discard_count: int = maxi(0, opponent.hand.size() - 3)
	if discard_count <= 0:
		return []
	var items: Array = opponent.hand.duplicate()
	var labels: Array[String] = []
	for hand_card: CardInstance in items:
		labels.append(hand_card.card_data.name if hand_card.card_data != null else "")
	return [{
		"id": "opponent_discards_to_three",
		"title": "选择要弃掉的手牌，直到手牌变为3张",
		"items": items,
		"labels": labels,
		"min_select": discard_count,
		"max_select": discard_count,
		"allow_cancel": false,
		"chooser_player_index": opponent.player_index,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var discard_count: int = maxi(0, opponent.hand.size() - 3)
	if discard_count <= 0:
		return
	var to_discard: Array[CardInstance] = []
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("opponent_discards_to_three", [])
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in opponent.hand and not to_discard.has(entry):
			to_discard.append(entry)
			if to_discard.size() >= discard_count:
				break
	if to_discard.size() < discard_count:
		for hand_card: CardInstance in opponent.hand:
			if hand_card in to_discard:
				continue
			to_discard.append(hand_card)
			if to_discard.size() >= discard_count:
				break
	_discard_cards_from_hand_with_log(state, opponent.player_index, to_discard, card, "trainer")


func get_description() -> String:
	return "对手将对手自己的手牌放于弃牌区，直到手牌变为3张为止。"
